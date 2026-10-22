//
//  InboxViewModel.swift
//  neighbourly
//
//  The signed-in person's conversations, newest activity first. One instance lives at
//  the root so the Messages tab can show an unread badge from anywhere.
//

import Foundation
import Observation

@Observable
final class InboxViewModel {
    private(set) var conversations: [Conversation] = []
    private(set) var hasLoaded = false
    private(set) var userID: String?

    @ObservationIgnored private let chat: any ChatRepository

    init(chat: any ChatRepository) {
        self.chat = chat
    }

    /// Number of conversations whose latest message the person hasn't read.
    var unreadCount: Int {
        guard let userID else { return 0 }
        return conversations.filter { $0.isUnread(for: userID) }.count
    }

    func isUnread(_ conversation: Conversation) -> Bool {
        guard let userID else { return false }
        return conversation.isUnread(for: userID)
    }

    /// Follows the inbox for one account. Run from a `.task(id:)` keyed on the user's ID:
    /// when the account changes or signs out the task is cancelled and this runs again,
    /// so one person's conversations are never shown to the next.
    func run(userID: String?) async {
        conversations = []
        hasLoaded = false
        self.userID = userID
        guard let userID else { return }

        for await list in chat.conversations(for: userID) {
            // A late update for a previous account must never overwrite the current one.
            if Task.isCancelled || self.userID != userID { break }
            conversations = list.sorted { $0.sortDate > $1.sortDate }
            hasLoaded = true
        }
    }
}
