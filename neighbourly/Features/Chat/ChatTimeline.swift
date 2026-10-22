//
//  ChatTimeline.swift
//  neighbourly
//
//  What the conversation screen shows: server messages merged with the ones still being
//  sent, grouped by day. Pure logic, unit tested.
//

import Foundation

/// A message as the screen shows it, whether or not the server has confirmed it yet.
nonisolated struct ChatItem: Identifiable, Equatable, Sendable {
    enum Delivery: Equatable, Sendable {
        case sent
        case sending
        case failed(String)
    }

    let id: String
    let senderID: String
    let text: String
    let createdAt: Date
    var delivery: Delivery = .sent
}

nonisolated struct ChatDay: Identifiable, Equatable, Sendable {
    /// Midnight at the start of the day.
    let id: Date
    var items: [ChatItem]
}

nonisolated enum ChatTimeline {
    /// Items grouped by calendar day, oldest first, each day's items oldest first.
    static func days(from items: [ChatItem], calendar: Calendar = .current) -> [ChatDay] {
        let sorted = items.sorted {
            $0.createdAt == $1.createdAt ? $0.id < $1.id : $0.createdAt < $1.createdAt
        }
        var days: [ChatDay] = []
        for item in sorted {
            let start = calendar.startOfDay(for: item.createdAt)
            if let last = days.indices.last, days[last].id == start {
                days[last].items.append(item)
            } else {
                days.append(ChatDay(id: start, items: [item]))
            }
        }
        return days
    }

    /// "Today", "Yesterday", or a date like "12 Oct 2026".
    static func dayTitle(for day: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        if calendar.isDate(day, inSameDayAs: now) { return "Today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(day, inSameDayAs: yesterday) {
            return "Yesterday"
        }
        return day.formatted(.dateTime.day().month(.abbreviated).year())
    }

    /// Messages from the server plus those still being sent or that failed. A message
    /// that has arrived from the server replaces its local copy (same ID).
    static func merge(server: [ChatMessage], outbox: [ChatItem]) -> [ChatItem] {
        let confirmed = Set(server.map { $0.id })
        let serverItems = server.map {
            ChatItem(id: $0.id, senderID: $0.senderID, text: $0.text, createdAt: $0.createdAt)
        }
        return serverItems + outbox.filter { !confirmed.contains($0.id) }
    }
}
