//
//  MockAuthService.swift
//  neighbourly
//
//  In-memory accounts. Used by previews and unit tests, and as "demo mode" when
//  Firebase isn't configured yet: sign-up and sign-in work, but nothing survives
//  a relaunch and nothing is shared with other devices.
//

import Foundation

final class MockAuthService: AuthService {
    private struct Account {
        var password: String
        var user: AppUser
    }

    private var accounts: [String: Account] = [:]
    private var current: AppUser?
    private var listeners: [UUID: AsyncStream<AppUser?>.Continuation] = [:]

    /// Pretend network latency, so loading states are visible in demos.
    private let delay: Duration

    /// Test hook: the next account call throws this, then clears it.
    var failNextCall: AuthFailure?

    /// Emails that were sent a password reset, for tests.
    private(set) var passwordResetRequests: [String] = []

    init(delay: Duration = .zero) {
        self.delay = delay
    }

    /// Pre-registers an account (optionally signed in) without going through sign-up.
    @discardableResult
    func seedAccount(name: String, email: String, password: String, signedIn: Bool = false) -> AppUser {
        let user = AppUser(uid: UUID().uuidString, displayName: name, email: Self.normalized(email))
        accounts[Self.normalized(email)] = Account(password: password, user: user)
        if signedIn { setCurrent(user) }
        return user
    }

    // MARK: AuthService

    func authStateChanges() -> AsyncStream<AppUser?> {
        let (stream, continuation) = AsyncStream<AppUser?>.makeStream()
        let id = UUID()
        listeners[id] = continuation
        continuation.yield(current)
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.listeners[id] = nil }
        }
        return stream
    }

    func signUp(name: String, email: String, password: String) async throws -> AppUser {
        try await simulateLatency()
        let key = Self.normalized(email)
        guard accounts[key] == nil else { throw AuthFailure.emailAlreadyInUse }
        guard password.count >= 6 else { throw AuthFailure.weakPassword }

        let user = AppUser(uid: UUID().uuidString, displayName: name, email: key)
        accounts[key] = Account(password: password, user: user)
        setCurrent(user)
        return user
    }

    func signIn(email: String, password: String) async throws -> AppUser {
        try await simulateLatency()
        guard let account = accounts[Self.normalized(email)], account.password == password else {
            throw AuthFailure.wrongCredentials
        }
        setCurrent(account.user)
        return account.user
    }

    func sendPasswordReset(email: String) async throws {
        try await simulateLatency()
        // Like Firebase, succeed whether or not the email has an account.
        passwordResetRequests.append(Self.normalized(email))
    }

    func signOut() throws {
        if let failure = failNextCall {
            failNextCall = nil
            throw failure
        }
        setCurrent(nil)
    }

    func deleteAccount(password: String) async throws {
        try await simulateLatency()
        guard let user = current, let email = user.email else { throw AuthFailure.notSignedIn }
        guard accounts[email]?.password == password else { throw AuthFailure.wrongCredentials }
        accounts[email] = nil
        setCurrent(nil)
    }

    // MARK: Helpers

    private func simulateLatency() async throws {
        if delay > .zero { try await Task.sleep(for: delay) }
        if let failure = failNextCall {
            failNextCall = nil
            throw failure
        }
    }

    private func setCurrent(_ user: AppUser?) {
        current = user
        for continuation in listeners.values { continuation.yield(user) }
    }

    private static func normalized(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
