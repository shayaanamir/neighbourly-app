//
//  InMemoryChatRepository.swift
//  neighbourly
//
//  Chat kept in memory. Used by tests and previews, and as "demo mode" when Firebase
//  isn't set up: two demo accounts on one Simulator can chat while the app is running
//  (switch accounts to read the reply), but nothing survives a relaunch.
//

import Foundation

final class InMemoryChatRepository: ChatRepository {
    private var conversationsByID: [String: Conversation] = [:]
    private var messagesByConversation: [String: [ChatMessage]] = [:]

    private var conversationListeners: [UUID: (userID: String, continuation: AsyncStream<[Conversation]>.Continuation)] = [:]
    private var messageListeners: [UUID: (conversationID: String, continuation: AsyncStream<[ChatMessage]>.Continuation)] = [:]

    /// Clock, replaceable in tests.
    var now: () -> Date = { .now }

    /// Test hook: the next `send` throws this, then clears it.
    var failNextSend: ChatError?

    /// Pretend network latency, so sending states are visible in demos.
    private let delay: Duration

    init(delay: Duration = .zero) {
        self.delay = delay
    }

    // MARK: ChatRepository

    func conversations(for userID: String) -> AsyncStream<[Conversation]> {
        let (stream, continuation) = AsyncStream<[Conversation]>.makeStream()
        let id = UUID()
        conversationListeners[id] = (userID, continuation)
        continuation.yield(conversations(visibleTo: userID))
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.conversationListeners[id] = nil }
        }
        return stream
    }

    func messages(in conversationID: String) -> AsyncStream<[ChatMessage]> {
        let (stream, continuation) = AsyncStream<[ChatMessage]>.makeStream()
        let id = UUID()
        messageListeners[id] = (conversationID, continuation)
        continuation.yield(messagesByConversation[conversationID] ?? [])
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.messageListeners[id] = nil }
        }
        return stream
    }

    func startConversation(listing: Listing, buyer: AppUser) async throws -> Conversation {
        guard !listing.isDemo, let sellerID = listing.sellerID else { throw ChatError.listingNotMessageable }
        guard buyer.uid != sellerID else { throw ChatError.cannotMessageYourself }

        let id = Conversation.makeID(listingID: listing.id, buyerID: buyer.uid)
        if let existing = conversationsByID[id] { return existing }

        let conversation = Conversation(
            id: id, listingID: listing.id, listingTitle: listing.title,
            sellerID: sellerID, buyerID: buyer.uid,
            sellerName: listing.sellerName, buyerName: buyer.displayName
        )
        conversationsByID[id] = conversation
        notifyConversationListeners()
        return conversation
    }

    func send(_ message: ChatMessage, in conversation: Conversation) async throws {
        if delay > .zero { try await Task.sleep(for: delay) }
        if let failure = failNextSend {
            failNextSend = nil
            throw failure
        }

        let text = try ChatMessage.validated(message.text)
        guard var stored = conversationsByID[conversation.id], stored.isParticipant(message.senderID) else {
            throw ChatError.permissionDenied
        }

        // Re-sending a message that already arrived is a no-op, so retries can't duplicate it.
        if messagesByConversation[conversation.id]?.contains(where: { $0.id == message.id }) == true { return }

        let sentAt = now()
        messagesByConversation[conversation.id, default: []].append(
            ChatMessage(id: message.id, senderID: message.senderID, text: text, createdAt: sentAt)
        )
        stored.lastMessageText = text
        stored.lastMessageAt = sentAt
        stored.lastMessageSenderID = message.senderID
        stored.readAt[message.senderID] = sentAt
        conversationsByID[conversation.id] = stored

        notifyMessageListeners(conversationID: conversation.id)
        notifyConversationListeners()
    }

    func markRead(_ conversation: Conversation, by userID: String) async throws {
        guard var stored = conversationsByID[conversation.id], stored.isParticipant(userID) else {
            throw ChatError.permissionDenied
        }
        stored.readAt[userID] = now()
        conversationsByID[conversation.id] = stored
        notifyConversationListeners()
    }

    // MARK: Inspection (tests and previews)

    func conversation(withID id: String) -> Conversation? {
        conversationsByID[id]
    }

    // MARK: Helpers

    private func conversations(visibleTo userID: String) -> [Conversation] {
        conversationsByID.values.filter { $0.isParticipant(userID) }
    }

    private func notifyConversationListeners() {
        for listener in conversationListeners.values {
            listener.continuation.yield(conversations(visibleTo: listener.userID))
        }
    }

    private func notifyMessageListeners(conversationID: String) {
        let current = messagesByConversation[conversationID] ?? []
        for listener in messageListeners.values where listener.conversationID == conversationID {
            listener.continuation.yield(current)
        }
    }
}
