//
//  InboxView.swift
//  neighbourly
//
//  The Messages tab: every conversation the person is part of, newest activity first.
//

import SwiftUI

struct InboxView: View {
    let dependencies: AppDependencies

    @Environment(AuthViewModel.self) private var auth
    @Environment(InboxViewModel.self) private var inbox

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.Colors.groupedBackground)
                .navigationTitle("Messages")
                .navigationDestination(for: Conversation.self) { conversation in
                    if let user = auth.user {
                        ConversationView(conversation: conversation, user: user, dependencies: dependencies)
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if auth.session == .loading {
            ProgressView()
        } else if !auth.isSignedIn {
            SignInPromptView(
                title: "Sign in to see your messages",
                message: "Chats with buyers and sellers appear here once you have an account.",
                systemImage: "bubble.left.and.bubble.right"
            )
        } else if inbox.loadFailed {
            ContentUnavailableView {
                Label("Couldn't load messages", systemImage: "exclamationmark.triangle")
            } description: {
                Text("Check your internet connection. If it keeps happening, the app's database rules may not be published yet.")
            } actions: {
                Button("Try Again") { inbox.retry() }
            }
        } else if !inbox.hasLoaded {
            ProgressView("Loading messages…")
        } else if inbox.conversations.isEmpty {
            ContentUnavailableView {
                Label("No conversations yet", systemImage: "bubble.left.and.bubble.right")
            } description: {
                Text("Open a listing and tap Message Seller to start chatting. When someone messages you about your listing, it shows up here.")
            }
        } else {
            List(inbox.conversations) { conversation in
                NavigationLink(value: conversation) {
                    ConversationRow(
                        conversation: conversation,
                        currentUserID: auth.user?.uid ?? "",
                        isUnread: inbox.isUnread(conversation)
                    )
                }
                .listRowBackground(Theme.Colors.cardBackground)
                .listRowSeparatorTint(Theme.Colors.separator)
            }
            .listStyle(.plain)
            .warmForm()
        }
    }
}

private struct ConversationRow: View {
    let conversation: Conversation
    let currentUserID: String
    let isUnread: Bool

    private var name: String { conversation.otherParticipantName(for: currentUserID) }

    private var preview: String {
        guard let text = conversation.lastMessageText else { return "No messages yet" }
        return conversation.lastMessageSenderID == currentUserID ? "You: \(text)" : text
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            Text(verbatim: String(name.prefix(1)).uppercased())
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.accent)
                .frame(width: 44, height: 44)
                .background(Theme.Colors.accent.opacity(0.15), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack {
                    Text(verbatim: name)
                        .font(isUnread ? Theme.Typography.headline : Theme.Typography.body.weight(.medium))
                        .lineLimit(1)
                    Spacer()
                    if let date = conversation.lastMessageAt {
                        Text(date, format: .relative(presentation: .numeric, unitsStyle: .narrow))
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.secondaryText)
                    }
                }

                Text(verbatim: conversation.listingTitle)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.accent)
                    .lineLimit(1)

                HStack {
                    Text(verbatim: preview)
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(isUnread ? Theme.Colors.primaryText : Theme.Colors.secondaryText)
                        .fontWeight(isUnread ? .semibold : .regular)
                        .lineLimit(2)
                    if isUnread {
                        Spacer()
                        Circle()
                            .fill(Theme.Colors.accent)
                            .frame(width: 10, height: 10)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(isUnread ? "Unread. " : "")\(name), about \(conversation.listingTitle). \(preview)")
    }
}

#Preview {
    let dependencies = AppDependencies.preview()
    InboxView(dependencies: dependencies)
        .environment(AuthViewModel(service: dependencies.authService, isCloudBacked: false))
        .environment(InboxViewModel(chat: dependencies.chatRepository))
}
