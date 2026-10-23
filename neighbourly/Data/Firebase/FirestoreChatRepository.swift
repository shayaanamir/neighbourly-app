//
//  FirestoreChatRepository.swift
//  neighbourly
//
//  Real-time chat in Cloud Firestore (free Spark plan). Compiled only once the
//  firebase-ios-sdk package is added; see firebase/README.md.
//
//  Layout:
//    conversations/{listingID_buyerID}            see ChatMapping.ConversationField
//    conversations/{id}/messages/{messageID}      senderID, text, createdAt (server time)
//
//  Live updates use snapshot listeners; they work while the app is open (no push
//  notifications). Neither listener uses orderBy together with array-contains, so no
//  composite index has to be created in the console.
//
//  Written without a Firebase-enabled compiler: if Xcode flags anything on the first
//  build, fix it here.
//

#if canImport(FirebaseFirestore)

import FirebaseFirestore
import Foundation
import OSLog

final class FirestoreChatRepository: ChatRepository {
    nonisolated private static let logger = Logger(subsystem: "com.kjsce.neighbourly", category: "Chat")

    /// Newest messages loaded per conversation; keeps reads inside the free quota.
    static let messageLimit = 200

    private var db: Firestore { Firestore.firestore() }

    // MARK: - Live streams

    func conversations(for userID: String) -> AsyncStream<[Conversation]> {
        let (stream, continuation) = AsyncStream<[Conversation]>.makeStream()
        let registration = db.collection("conversations")
            .whereField(ChatMapping.ConversationField.participantIDs, arrayContains: userID)
            .addSnapshotListener { snapshot, error in
                if let error {
                    Self.logger.error("Conversation listener failed: \(error.localizedDescription, privacy: .public)")
                    return // keep the last good list on screen
                }
                guard let snapshot else { return }
                let conversations = snapshot.documents.compactMap {
                    ChatMapping.conversation(from: Self.plainFields($0.data(with: .estimate)), id: $0.documentID)
                }
                continuation.yield(conversations)
            }
        continuation.onTermination = { _ in registration.remove() }
        return stream
    }

    func messages(in conversationID: String) -> AsyncStream<[ChatMessage]> {
        let (stream, continuation) = AsyncStream<[ChatMessage]>.makeStream()
        let registration = db.collection("conversations").document(conversationID).collection("messages")
            .order(by: ChatMapping.MessageField.createdAt)
            .limit(toLast: Self.messageLimit)
            .addSnapshotListener { snapshot, error in
                if let error {
                    Self.logger.error("Message listener failed: \(error.localizedDescription, privacy: .public)")
                    return
                }
                guard let snapshot else { return }
                // `.estimate` fills in a local time for messages whose server timestamp is
                // still pending, so a message you just sent shows up immediately.
                let messages = snapshot.documents.compactMap {
                    ChatMapping.message(from: Self.plainFields($0.data(with: .estimate)), id: $0.documentID)
                }
                continuation.yield(messages)
            }
        continuation.onTermination = { _ in registration.remove() }
        return stream
    }

    // MARK: - Actions

    func startConversation(listing: Listing, buyer: AppUser) async throws -> Conversation {
        guard !listing.isDemo, let sellerID = listing.sellerID else { throw ChatError.listingNotMessageable }
        guard buyer.uid != sellerID else { throw ChatError.cannotMessageYourself }

        let id = Conversation.makeID(listingID: listing.id, buyerID: buyer.uid)
        let reference = db.collection("conversations").document(id)
        do {
            let existing = try await reference.getDocument()
            if existing.exists,
               let data = existing.data(with: .estimate),
               let conversation = ChatMapping.conversation(from: Self.plainFields(data), id: id) {
                return conversation
            }

            let conversation = Conversation(
                id: id, listingID: listing.id, listingTitle: listing.title,
                sellerID: sellerID, buyerID: buyer.uid,
                sellerName: listing.sellerName, buyerName: buyer.displayName
            )
            try await reference.setData(ChatMapping.newConversationData(for: conversation))
            return conversation
        } catch {
            throw Self.chatError(from: error)
        }
    }

    func send(_ message: ChatMessage, in conversation: Conversation) async throws {
        let text = try ChatMessage.validated(message.text)
        let conversationRef = db.collection("conversations").document(conversation.id)
        let messageRef = conversationRef.collection("messages").document(message.id)

        // The message and the conversation's "last message" summary are written together,
        // so the inbox can never show a message that doesn't exist (or the reverse).
        // The sender's own read marker moves too, so their own message isn't "unread".
        let batch = db.batch()
        batch.setData([
            ChatMapping.MessageField.senderID: message.senderID,
            ChatMapping.MessageField.text: text,
            ChatMapping.MessageField.createdAt: FieldValue.serverTimestamp(),
        ], forDocument: messageRef)
        batch.updateData([
            ChatMapping.ConversationField.lastMessageText: text,
            ChatMapping.ConversationField.lastMessageAt: FieldValue.serverTimestamp(),
            ChatMapping.ConversationField.lastMessageSenderID: message.senderID,
            "\(ChatMapping.ConversationField.readAt).\(message.senderID)": FieldValue.serverTimestamp(),
        ], forDocument: conversationRef)

        do {
            // Offline, this waits until the connection returns; the screen shows the
            // message as "sending" in the meantime.
            try await batch.commit()
        } catch {
            throw Self.chatError(from: error)
        }
    }

    func markRead(_ conversation: Conversation, by userID: String) async throws {
        do {
            try await db.collection("conversations").document(conversation.id).updateData([
                "\(ChatMapping.ConversationField.readAt).\(userID)": FieldValue.serverTimestamp(),
            ])
        } catch {
            throw Self.chatError(from: error)
        }
    }

    // MARK: - Helpers

    /// Firestore hands back `Timestamp`; the pure mapping layer works with `Date`
    /// (including inside nested maps such as `readAt`).
    nonisolated private static func plainFields(_ data: [String: Any]) -> [String: Any] {
        data.mapValues(plainValue)
    }

    nonisolated private static func plainValue(_ value: Any) -> Any {
        if let timestamp = value as? Timestamp { return timestamp.dateValue() }
        if let map = value as? [String: Any] { return map.mapValues(plainValue) }
        return value
    }

    nonisolated private static func chatError(from error: Error) -> ChatError {
        if let chatError = error as? ChatError { return chatError }
        let nsError = error as NSError
        // Raw gRPC status codes (FIRFirestoreErrorDomain), which don't change between SDK versions.
        guard nsError.domain == "FIRFirestoreErrorDomain" else {
            logger.error("Chat error: \(error.localizedDescription, privacy: .public)")
            return .unknown
        }
        switch nsError.code {
        case 14, 4: return .network               // unavailable, deadline exceeded
        case 7, 16: return .permissionDenied      // permission denied, unauthenticated
        case 8: return .quotaExceeded             // resource exhausted
        default:
            logger.error("Unmapped Firestore chat error code \(nsError.code)")
            return .unknown
        }
    }
}

#endif
