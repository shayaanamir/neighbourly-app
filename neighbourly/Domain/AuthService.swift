//
//  AuthService.swift
//  neighbourly
//

import Foundation

/// Everything that can go wrong with an account action, in words a person can act on.
/// Implementations translate provider errors into these; wrong password and unknown
/// email deliberately share one case so the app never reveals which emails have accounts.
nonisolated enum AuthFailure: LocalizedError, Equatable, Sendable {
    case invalidEmail
    case weakPassword
    case emailAlreadyInUse
    case wrongCredentials
    case network
    case tooManyAttempts
    case requiresRecentLogin
    case userDisabled
    case notSignedIn
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidEmail: "That email address doesn't look right."
        case .weakPassword: "Choose a stronger password of at least 8 characters."
        case .emailAlreadyInUse: "An account with this email already exists. Try signing in instead."
        case .wrongCredentials: "Incorrect email or password."
        case .network: "Couldn't reach the server. Check your internet connection and try again."
        case .tooManyAttempts: "Too many attempts. Wait a moment, then try again."
        case .requiresRecentLogin: "For your security, sign in again and retry."
        case .userDisabled: "This account has been disabled."
        case .notSignedIn: "You need to be signed in to do that."
        case .unknown: "Something went wrong. Please try again."
        }
    }
}

/// Account operations. UI-facing, so it lives on the main actor like the view models
/// that call it. Implementations: `FirebaseAuthService` (real accounts) and
/// `MockAuthService` (previews, tests, and demo mode when Firebase isn't set up).
@MainActor
protocol AuthService {
    /// Emits the current user immediately, then again on every sign-in or sign-out.
    /// Emits nil when nobody is signed in.
    func authStateChanges() -> AsyncStream<AppUser?>

    func signUp(name: String, email: String, password: String) async throws -> AppUser
    func signIn(email: String, password: String) async throws -> AppUser
    func sendPasswordReset(email: String) async throws
    func signOut() throws
    /// Permanently deletes the signed-in account after re-checking the password.
    func deleteAccount(password: String) async throws
}
