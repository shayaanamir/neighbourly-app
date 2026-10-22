//
//  ChatMapping.swift
//  neighbourly
//
//  Conversation and message <-> Firestore field dictionaries. Pure Foundation (no
//  Firebase import) so it can be unit tested; the Firestore layer converts
//  Timestamp <-> Date at the edge, including inside the `readAt` map.
//

import Foundation

nonisolated enum ChatMapping {
    enum ConversationField {
        static let listingID = "listingID"
        static let listingTitle = "listingTitle"
        static let sellerID = "sellerID"
        static let buyerID = "buyerID"
        static let sellerName = "sellerName"
        static let buyerName = "buyerName"
        static let participantIDs = "participantIDs"
        static let lastMessageText = "lastMessageText"
        static let lastMessageAt = "lastMessageAt"
        static let lastMessageSenderID = "lastMessageSenderID"
        static let readAt = "readAt"
    }

    enum MessageField {
        static let senderID = "senderID"
        static let text = "text"
        static let createdAt = "createdAt"
    }

    /// Fields for creating a new conversation (no messages yet).
    static func newConversationData(for conversation: Conversation) -> [String: Any] {
        [
            ConversationField.listingID: conversation.listingID.uuidString,
            ConversationField.listingTitle: conversation.listingTitle,
            ConversationField.sellerID: conversation.sellerID,
            ConversationField.buyerID: conversation.buyerID,
            ConversationField.sellerName: conversation.sellerName,
            ConversationField.buyerName: conversation.buyerName,
            ConversationField.participantIDs: conversation.participantIDs,
            ConversationField.readAt: [String: Date](),
        ]
    }

    /// nil if a required field is missing, so one bad document doesn't break the inbox.
    static func conversation(from data: [String: Any], id: String) -> Conversation? {
        guard let listingIDString = data[ConversationField.listingID] as? String,
              let listingID = UUID(uuidString: listingIDString),
              let listingTitle = data[ConversationField.listingTitle] as? String,
              let sellerID = data[ConversationField.sellerID] as? String,
              let buyerID = data[ConversationField.buyerID] as? String
        else { return nil }

        var readAt: [String: Date] = [:]
        if let raw = data[ConversationField.readAt] as? [String: Any] {
            for (uid, value) in raw {
                if let date = value as? Date { readAt[uid] = date }
            }
        }

        var conversation = Conversation(
            id: id, listingID: listingID, listingTitle: listingTitle,
            sellerID: sellerID, buyerID: buyerID,
            sellerName: data[ConversationField.sellerName] as? String ?? "Seller",
            buyerName: data[ConversationField.buyerName] as? String ?? "Buyer"
        )
        conversation.lastMessageText = data[ConversationField.lastMessageText] as? String
        conversation.lastMessageAt = data[ConversationField.lastMessageAt] as? Date
        conversation.lastMessageSenderID = data[ConversationField.lastMessageSenderID] as? String
        conversation.readAt = readAt
        return conversation
    }

    /// nil if the sender, text, or time is missing (for example, a server timestamp
    /// that hasn't resolved yet and has no estimate).
    static func message(from data: [String: Any], id: String) -> ChatMessage? {
        guard let senderID = data[MessageField.senderID] as? String,
              let text = data[MessageField.text] as? String,
              let createdAt = data[MessageField.createdAt] as? Date
        else { return nil }
        return ChatMessage(id: id, senderID: senderID, text: text, createdAt: createdAt)
    }
}
