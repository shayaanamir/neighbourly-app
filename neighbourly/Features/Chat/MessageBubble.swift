//
//  MessageBubble.swift
//  neighbourly
//

import SwiftUI

struct MessageBubble: View {
    let item: ChatItem
    let isMine: Bool
    let senderName: String
    let onRetry: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if isMine { Spacer(minLength: Theme.Spacing.xxl) }

            VStack(alignment: isMine ? .trailing : .leading, spacing: Theme.Spacing.xs) {
                // Plain text only: message content is never interpreted as markup or links.
                Text(verbatim: item.text)
                    .font(Theme.Typography.body)
                    .foregroundStyle(isMine ? Theme.Colors.onAccent : Theme.Colors.primaryText)
                    .padding(.horizontal, Theme.Spacing.m)
                    .padding(.vertical, Theme.Spacing.s)
                    .background(
                        isMine ? Theme.Colors.accent : Theme.Colors.cardBackground,
                        in: UnevenRoundedRectangle(
                            topLeadingRadius: Theme.Radius.l,
                            bottomLeadingRadius: isMine ? Theme.Radius.l : 6,
                            bottomTrailingRadius: isMine ? 6 : Theme.Radius.l,
                            topTrailingRadius: Theme.Radius.l,
                            style: .continuous
                        )
                    )
                    .shadow(color: isMine ? .clear : Theme.Colors.shadow, radius: 3, x: 0, y: 1)
                    .opacity(item.delivery == .sending ? 0.6 : 1)
                    .textSelection(.enabled)

                status
            }

            if !isMine { Spacer(minLength: Theme.Spacing.xxl) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder
    private var status: some View {
        switch item.delivery {
        case .sent:
            Text(item.createdAt, format: .dateTime.hour().minute())
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.secondaryText)
        case .sending:
            Text("Sending…")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.secondaryText)
        case .failed(let message):
            VStack(alignment: .trailing, spacing: Theme.Spacing.xs) {
                Label(message, systemImage: "exclamationmark.circle")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.danger)
                HStack(spacing: Theme.Spacing.m) {
                    Button("Retry", action: onRetry)
                    Button("Delete", role: .destructive, action: onDiscard)
                }
                .font(Theme.Typography.caption.weight(.semibold))
                .buttonStyle(.borderless)
            }
        }
    }

    private var accessibilityText: String {
        let who = isMine ? "You" : senderName
        let time = item.createdAt.formatted(.dateTime.hour().minute())
        switch item.delivery {
        case .sent: return "\(who), \(time): \(item.text)"
        case .sending: return "\(who), sending: \(item.text)"
        case .failed(let message): return "\(who), failed to send: \(item.text). \(message)"
        }
    }
}

#Preview {
    let now = Date()
    VStack(spacing: Theme.Spacing.m) {
        MessageBubble(
            item: ChatItem(id: "1", senderID: "a", text: "Hi! Is the table still available?", createdAt: now),
            isMine: false, senderName: "Asha", onRetry: {}, onDiscard: {}
        )
        MessageBubble(
            item: ChatItem(id: "2", senderID: "b", text: "Yes, it is. You can pick it up this weekend.", createdAt: now),
            isMine: true, senderName: "Me", onRetry: {}, onDiscard: {}
        )
        MessageBubble(
            item: ChatItem(id: "3", senderID: "b", text: "Saturday works.", createdAt: now, delivery: .failed("No connection.")),
            isMine: true, senderName: "Me", onRetry: {}, onDiscard: {}
        )
    }
    .padding()
}
