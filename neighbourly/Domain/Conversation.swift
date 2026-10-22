//
//  Conversation.swift
//  neighbourly
//

import Foundation

/// A chat between one buyer and the seller of one listing. A buyer has at most one
/// conversation per listing, because the ID is derived from both.
nonisolated struct Conversation: Identifiable, Hashable, Sendable {
    let id: String
    let listingID: UUID
    /// Title when the chat began; shown in the inbox even if the listing is edited or removed.
    var listingTitle: String
    let sellerID: String
    let buyerID: String
    /// Display names copied when the chat began, so the inbox needs no extra lookups.
    var sellerName: String
    var buyerName: String

    var lastMessageText: String?
    var lastMessageAt: Date?
    var lastMessageSenderID: String?
    /// When each participant last opened the conversation.
    var readAt: [String: Date] = [:]

    var participantIDs: [String] { [sellerID, buyerID] }

    /// The one conversation ID a buyer can have for a listing.
    static func makeID(listingID: UUID, buyerID: String) -> String {
        "\(listingID.uuidString)_\(buyerID)"
    }

    func isParticipant(_ userID: String) -> Bool {
        userID == sellerID || userID == buyerID
    }

    func otherParticipantID(for userID: String) -> String {
        userID == sellerID ? buyerID : sellerID
    }

    func otherParticipantName(for userID: String) -> String {
        userID == sellerID ? buyerName : sellerName
    }

    /// True when the other person wrote last and this user hasn't opened the chat since.
    func isUnread(for userID: String) -> Bool {
        guard let lastMessageAt, let sender = lastMessageSenderID, sender != userID else { return false }
        return (readAt[userID] ?? .distantPast) < lastMessageAt
    }

    /// For ordering the inbox; conversations with no messages yet sort last.
    var sortDate: Date { lastMessageAt ?? .distantPast }
}
