//
//  AuthValidation.swift
//  neighbourly
//
//  Client-side checks for the auth forms. Each returns an error message, or nil
//  if the value is fine. These only save a round trip; the provider re-checks.
//

import Foundation

nonisolated enum AuthValidation {
    static let minPasswordLength = 8
    static let maxPasswordLength = 128
    static let nameLengthRange = 2...40

    static func email(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Enter your email address." }
        return ContactService.isEmail(trimmed) ? nil : "Enter a valid email address, like name@example.com."
    }

    /// For creating an account or changing a password.
    static func newPassword(_ value: String) -> String? {
        if value.isEmpty { return "Choose a password." }
        if value.count < minPasswordLength { return "Use at least \(minPasswordLength) characters." }
        if value.count > maxPasswordLength { return "Use \(maxPasswordLength) characters or fewer." }
        return nil
    }

    /// For signing in: any non-empty password may be right, so don't judge its strength.
    static func existingPassword(_ value: String) -> String? {
        value.isEmpty ? "Enter your password." : nil
    }

    static func confirmation(_ confirmation: String, matches password: String) -> String? {
        if confirmation.isEmpty { return "Re-enter your password." }
        return confirmation == password ? nil : "The passwords don't match."
    }

    static func displayName(_ value: String) -> String? {
        let count = value.trimmingCharacters(in: .whitespacesAndNewlines).count
        if count == 0 { return "Enter your name." }
        if count < nameLengthRange.lowerBound { return "Use at least \(nameLengthRange.lowerBound) characters." }
        if count > nameLengthRange.upperBound { return "Use \(nameLengthRange.upperBound) characters or fewer." }
        return nil
    }
}
