//
//  ChatMessage.swift
//  neighbourly
//

import Foundation

/// One text message. Messages never change after they are sent.
nonisolated struct ChatMessage: Identifiable, Equatable, Sendable {
    static let maxLength = 1_000

    /// Chosen by the sender's device, so a retry can't create a duplicate.
    let id: String
    let senderID: String
    let text: String
    let createdAt: Date

    /// The trimmed text if it can be sent: 1 to 1,000 characters.
    static func validated(_ text: String) throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { throw ChatError.emptyMessage }
        if trimmed.count > maxLength { throw ChatError.messageTooLong }
        return trimmed
    }
}
