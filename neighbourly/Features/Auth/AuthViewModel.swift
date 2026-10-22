//
//  AuthViewModel.swift
//  neighbourly
//
//  App-wide session state. Created once at the root and shared through the
//  SwiftUI environment; screens read `user` and call `requireSignIn` to gate
//  actions that need an account.
//

import Foundation
import Observation

@Observable
final class AuthViewModel {
    enum Session: Equatable {
        /// Waiting for the first answer from the auth service at launch.
        case loading
        case signedOut
        case signedIn(AppUser)
    }

    private(set) var session: Session = .loading
    private(set) var isWorking = false
    private(set) var errorMessage: String?

    /// Drives the sign-in / sign-up sheet.
    var isPresentingAuth = false

    /// False in demo mode, where accounts live in memory only.
    let isCloudBacked: Bool

    @ObservationIgnored private let service: any AuthService
    @ObservationIgnored private var pendingAction: (() -> Void)?

    init(service: any AuthService, isCloudBacked: Bool = true) {
        self.service = service
        self.isCloudBacked = isCloudBacked
    }

    var user: AppUser? {
        if case .signedIn(let user) = session { return user }
        return nil
    }

    var isSignedIn: Bool { user != nil }

    // MARK: Session

    /// Follows the auth service for the life of the app. Run from a `.task` at the root.
    func start() async {
        for await user in service.authStateChanges() {
            apply(user)
        }
    }

    private func apply(_ user: AppUser?) {
        if let user {
            session = .signedIn(user)
            isPresentingAuth = false
        } else {
            session = .signedOut
            pendingAction = nil
        }
    }

    // MARK: Gating

    /// Runs `action` now if signed in; otherwise shows the sign-in sheet and runs it
    /// once the person has signed in, so they land back where they were.
    func requireSignIn(then action: @escaping () -> Void = {}) {
        if isSignedIn {
            action()
        } else {
            pendingAction = action
            errorMessage = nil
            isPresentingAuth = true
        }
    }

    /// Call when the sign-in sheet closes: runs the saved action if sign-in succeeded,
    /// drops it if the person cancelled.
    func runPendingAction() {
        let action = pendingAction
        pendingAction = nil
        if isSignedIn { action?() }
    }

    // MARK: Account actions (each returns true on success)

    func signIn(email: String, password: String) async -> Bool {
        if let problem = AuthValidation.email(email) ?? AuthValidation.existingPassword(password) {
            errorMessage = problem
            return false
        }
        return await perform {
            apply(try await service.signIn(email: Self.clean(email), password: password))
        }
    }

    func signUp(name: String, email: String, password: String, confirmation: String) async -> Bool {
        if let problem = AuthValidation.displayName(name)
            ?? AuthValidation.email(email)
            ?? AuthValidation.newPassword(password)
            ?? AuthValidation.confirmation(confirmation, matches: password) {
            errorMessage = problem
            return false
        }
        return await perform {
            let user = try await service.signUp(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                email: Self.clean(email),
                password: password
            )
            // Use the returned user: it already carries the display name.
            apply(user)
        }
    }

    func sendPasswordReset(email: String) async -> Bool {
        if let problem = AuthValidation.email(email) {
            errorMessage = problem
            return false
        }
        return await perform {
            try await service.sendPasswordReset(email: Self.clean(email))
        }
    }

    func signOut() {
        errorMessage = nil
        do {
            try service.signOut()
            apply(nil)
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    func deleteAccount(password: String) async -> Bool {
        if let problem = AuthValidation.existingPassword(password) {
            errorMessage = problem
            return false
        }
        return await perform {
            try await service.deleteAccount(password: password)
            apply(nil)
        }
    }

    func clearError() {
        errorMessage = nil
    }

    // MARK: Helpers

    private func perform(_ work: () async throws -> Void) async -> Bool {
        guard !isWorking else { return false }
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }
        do {
            try await work()
            return true
        } catch {
            errorMessage = Self.message(for: error)
            return false
        }
    }

    private static func message(for error: Error) -> String {
        (error as? AuthFailure ?? .unknown).errorDescription ?? AuthFailure.unknown.errorDescription ?? ""
    }

    private static func clean(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
