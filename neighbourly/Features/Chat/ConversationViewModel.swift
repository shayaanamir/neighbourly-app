//
//  ConversationViewModel.swift
//  neighbourly
//
//  One open chat: live messages, the draft being typed, and messages still on their
//  way. A sent message appears at once as "sending"; when the server's copy arrives
//  (same ID) it replaces the local one, and if sending fails it shows Retry.
//

import Foundation
import Observation

@Observable
final class ConversationViewModel {
    let conversation: Conversation
    let currentUser: AppUser

    var draft = ""
    private(set) var serverMessages: [ChatMessage] = []
    private(set) var outbox: [ChatItem] = []
    private(set) var hasLoaded = false
    /// True when the live connection ended before any messages arrived (for example the
    /// server refused it), so the screen can say so.
    private(set) var loadFailed = false

    /// True while the screen is on display. Messages only count as read when someone can see them.
    var isActive = false

    @ObservationIgnored private let chat: any ChatRepository
    @ObservationIgnored private var lastMarkedReadAt: Date?
    @ObservationIgnored private let now: () -> Date

    init(
        conversation: Conversation,
        currentUser: AppUser,
        chat: any ChatRepository,
        now: @escaping () -> Date = { .now }
    ) {
        self.conversation = conversation
        self.currentUser = currentUser
        self.chat = chat
        self.now = now
    }

    // MARK: Derived state

    var items: [ChatItem] {
        ChatTimeline.merge(server: serverMessages, outbox: outbox)
    }

    var days: [ChatDay] {
        ChatTimeline.days(from: items)
    }

    var otherName: String {
        conversation.otherParticipantName(for: currentUser.uid)
    }

    var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSend: Bool {
        !trimmedDraft.isEmpty && trimmedDraft.count <= ChatMessage.maxLength
    }

    var isOverLimit: Bool {
        trimmedDraft.count > ChatMessage.maxLength
    }

    var remainingCharacters: Int {
        ChatMessage.maxLength - trimmedDraft.count
    }

    func isFromCurrentUser(_ item: ChatItem) -> Bool {
        item.senderID == currentUser.uid
    }

    // MARK: Live messages

    /// Follows the conversation for as long as the screen is open. Run from a `.task`.
    func start() async {
        for await messages in chat.messages(in: conversation.id) {
            serverMessages = messages
            hasLoaded = true
            // Anything the server now has no longer needs its local "sending" copy.
            let confirmed = Set(messages.map { $0.id })
            outbox.removeAll { confirmed.contains($0.id) }
            await markReadIfNeeded()
        }
        if !hasLoaded && !Task.isCancelled {
            loadFailed = true
        }
    }

    /// Records that the other person's latest message has been seen, once per new message.
    func markReadIfNeeded() async {
        guard isActive, let newest = serverMessages.last, newest.senderID != currentUser.uid else { return }
        guard lastMarkedReadAt != newest.createdAt else { return }
        lastMarkedReadAt = newest.createdAt
        try? await chat.markRead(conversation, by: currentUser.uid)
    }

    // MARK: Sending

    /// Sends the draft. The draft clears immediately and the message appears as "sending".
    func send() async {
        guard canSend else { return }
        let text = trimmedDraft
        draft = ""

        let item = ChatItem(
            id: UUID().uuidString, senderID: currentUser.uid, text: text,
            createdAt: now(), delivery: .sending
        )
        outbox.append(item)
        await deliver(item)
    }

    func retry(_ id: String) async {
        guard let index = outbox.firstIndex(where: { $0.id == id }), case .failed = outbox[index].delivery else { return }
        outbox[index].delivery = .sending
        await deliver(outbox[index])
    }

    /// Gives up on a message that failed to send.
    func discard(_ id: String) {
        outbox.removeAll { $0.id == id }
    }

    private func deliver(_ item: ChatItem) async {
        let message = ChatMessage(id: item.id, senderID: item.senderID, text: item.text, createdAt: item.createdAt)
        do {
            try await chat.send(message, in: conversation)
            // Sent. Its local copy stays until the server's copy arrives through `start()`,
            // so there's no flicker; `merge` hides it as soon as the real one shows up.
            if let index = outbox.firstIndex(where: { $0.id == item.id }) {
                outbox[index].delivery = .sent
            }
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? ChatError.unknown.errorDescription ?? ""
            if let index = outbox.firstIndex(where: { $0.id == item.id }) {
                outbox[index].delivery = .failed(message)
            }
        }
    }
}
