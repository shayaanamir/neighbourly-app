//
//  ChatRepository.swift
//  neighbourly
//

import Foundation

nonisolated enum ChatError: LocalizedError, Equatable, Sendable {
    case emptyMessage
    case messageTooLong
    case cannotMessageYourself
    /// Sample listings have fictional sellers, and old local listings have no owner.
    case listingNotMessageable
    case notSignedIn
    case permissionDenied
    case network
    /// The free plan's daily limit was reached.
    case quotaExceeded
    case unknown

    var errorDescription: String? {
        switch self {
        case .emptyMessage: "Write a message first."
        case .messageTooLong: "Messages can be up to \(ChatMessage.maxLength) characters."
        case .cannotMessageYourself: "This is your own listing. Buyers will message you here."
        case .listingNotMessageable: "This is a sample listing, so there's no real seller to message."
        case .notSignedIn: "Sign in to send messages."
        case .permissionDenied: "You don't have permission to do that. Try signing in again."
        case .network: "Couldn't reach the server. Check your connection and try again."
        case .quotaExceeded: "The free daily limit has been reached. Try again tomorrow."
        case .unknown: "Something went wrong. Please try again."
        }
    }
}

/// Real-time text chat. UI-facing, so it lives on the main actor like the view models
/// that use it. Implementations: `FirestoreChatRepository` (shared between devices) and
/// `InMemoryChatRepository` (tests, previews, and demo mode when Firebase isn't set up).
@MainActor
protocol ChatRepository {
    /// Conversations this user is part of, re-emitted whenever any of them changes.
    /// The stream ends when its consumer stops listening.
    func conversations(for userID: String) -> AsyncStream<[Conversation]>

    /// A conversation's messages, oldest first, re-emitted as new ones arrive.
    func messages(in conversationID: String) -> AsyncStream<[ChatMessage]>

    /// Opens the buyer's conversation about a listing, creating it if needed.
    func startConversation(listing: Listing, buyer: AppUser) async throws -> Conversation

    /// Sends a message. Re-sending the same message (same `id`) is safe and creates no duplicate.
    func send(_ message: ChatMessage, in conversation: Conversation) async throws

    /// Records that `userID` has read everything up to now.
    func markRead(_ conversation: Conversation, by userID: String) async throws
}

/// Whether a person can start a chat from a listing, and if not, why.
nonisolated enum ChatEligibility: Equatable, Sendable {
    case canMessage
    case signInRequired
    case ownListing
    case sampleListing

    static func check(listing: Listing, user: AppUser?) -> ChatEligibility {
        if listing.isDemo || listing.sellerID == nil { return .sampleListing }
        guard let user else { return .signInRequired }
        return listing.sellerID == user.uid ? .ownListing : .canMessage
    }
}
