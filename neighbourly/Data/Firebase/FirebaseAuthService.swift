//
//  FirebaseAuthService.swift
//  neighbourly
//
//  Real accounts through Firebase Authentication (email/password) on the free
//  Spark plan. This whole file is compiled only once the firebase-ios-sdk package
//  (FirebaseAuth + FirebaseFirestore) has been added in Xcode; until then the app
//  uses `MockAuthService`. See firebase/README.md.
//
//  Written without a Firebase-enabled compiler: if Xcode flags anything here on
//  the first build, fix it here. Nothing else in the app imports Firebase.
//

#if canImport(FirebaseAuth) && canImport(FirebaseFirestore) && canImport(FirebaseCore)

import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Foundation
import OSLog

/// Configures Firebase once at launch, but only if the config file was added.
enum FirebaseBootstrap {
    static func configureIfPossible() -> Bool {
        guard Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil else {
            return false
        }
        if FirebaseApp.app() == nil { FirebaseApp.configure() }
        return true
    }
}

final class FirebaseAuthService: AuthService {
    private static let logger = Logger(subsystem: "com.kjsce.neighbourly", category: "Auth")

    func authStateChanges() -> AsyncStream<AppUser?> {
        let (stream, continuation) = AsyncStream<AppUser?>.makeStream()
        // The listener fires once right away with the restored session (or nil).
        let handle = Auth.auth().addStateDidChangeListener { _, user in
            continuation.yield(user.map(Self.appUser(from:)))
        }
        continuation.onTermination = { _ in
            Auth.auth().removeStateDidChangeListener(handle)
        }
        return stream
    }

    func signUp(name: String, email: String, password: String) async throws -> AppUser {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)

            let change = result.user.createProfileChangeRequest()
            change.displayName = name
            try await change.commitChanges()

            // A small public profile so other users can see who they're chatting with.
            // The email is deliberately not stored here. Best effort: a failure doesn't undo sign-up.
            do {
                try await Firestore.firestore().collection("users").document(result.user.uid).setData([
                    "displayName": name,
                    "createdAt": FieldValue.serverTimestamp(),
                ])
            } catch {
                Self.logger.error("Couldn't write profile document: \(error.localizedDescription, privacy: .public)")
            }

            return AppUser(uid: result.user.uid, displayName: name, email: result.user.email)
        } catch {
            throw Self.failure(from: error)
        }
    }

    func signIn(email: String, password: String) async throws -> AppUser {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            return Self.appUser(from: result.user)
        } catch {
            throw Self.failure(from: error)
        }
    }

    func sendPasswordReset(email: String) async throws {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
        } catch {
            let failure = Self.failure(from: error)
            // Don't reveal whether an email has an account: treat "no such user" as success.
            if failure != .wrongCredentials { throw failure }
        }
    }

    func signOut() throws {
        do {
            try Auth.auth().signOut()
        } catch {
            throw Self.failure(from: error)
        }
    }

    func deleteAccount(password: String) async throws {
        guard let user = Auth.auth().currentUser, let email = user.email else {
            throw AuthFailure.notSignedIn
        }
        do {
            let credential = EmailAuthProvider.credential(withEmail: email, password: password)
            try await user.reauthenticate(with: credential)

            // Remove the public profile first; the Auth account goes last.
            try? await Firestore.firestore().collection("users").document(user.uid).delete()
            try await user.delete()
        } catch {
            throw Self.failure(from: error)
        }
    }

    // MARK: - Mapping

    private static func appUser(from user: User) -> AppUser {
        let fallbackName = user.email?.split(separator: "@").first.map(String.init) ?? "Neighbour"
        let name = user.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        return AppUser(
            uid: user.uid,
            displayName: (name?.isEmpty == false ? name : nil) ?? fallbackName,
            email: user.email
        )
    }

    private static func failure(from error: Error) -> AuthFailure {
        if let failure = error as? AuthFailure { return failure }
        let nsError = error as NSError
        guard nsError.domain == AuthErrorDomain, let code = AuthErrorCode.Code(rawValue: nsError.code) else {
            return .unknown
        }
        switch code {
        case .invalidEmail: return .invalidEmail
        case .weakPassword: return .weakPassword
        case .emailAlreadyInUse: return .emailAlreadyInUse
        case .wrongPassword, .userNotFound, .invalidCredential: return .wrongCredentials
        case .networkError: return .network
        case .tooManyRequests: return .tooManyAttempts
        case .requiresRecentLogin: return .requiresRecentLogin
        case .userDisabled: return .userDisabled
        default:
            logger.error("Unmapped auth error code \(nsError.code)")
            return .unknown
        }
    }
}

#endif
