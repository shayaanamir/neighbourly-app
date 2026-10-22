//
//  ContactService.swift
//  neighbourly
//
//  Builds the draft message and, when a seller entered an email or phone
//  number, the matching system action. The prototype has no messaging
//  backend: everything goes through the iOS share sheet or Mail/Messages.
//

import Foundation

nonisolated struct ContactAction: Equatable, Sendable {
    let title: String
    let systemImage: String
    let url: URL
}

nonisolated enum ContactService {
    /// Draft text for the share sheet / email body.
    static func message(for listing: Listing) -> String {
        var text = "Hi, I'm interested in your listing “\(listing.title)” on Neighbourly"
        switch listing.mode {
        case .sell: text += " (\(listing.priceText()))"
        case .exchange: text += " (exchange)"
        case .donate: text += " (free)"
        }
        text += ". Is it still available?"
        return text
    }

    static func subject(for listing: Listing) -> String {
        "Neighbourly: \(listing.title)"
    }

    /// An email or SMS action for the contact the seller entered, or nil if it
    /// is empty or looks like neither. Demo listings never get one.
    static func action(for listing: Listing) -> ContactAction? {
        guard !listing.isDemo,
              let contact = listing.sellerContact?.trimmingCharacters(in: .whitespacesAndNewlines),
              !contact.isEmpty
        else { return nil }

        if isEmail(contact) {
            var components = URLComponents()
            components.scheme = "mailto"
            components.path = contact
            components.queryItems = [
                URLQueryItem(name: "subject", value: subject(for: listing)),
                URLQueryItem(name: "body", value: message(for: listing)),
            ]
            guard let url = components.url else { return nil }
            return ContactAction(title: "Email Seller", systemImage: "envelope", url: url)
        }

        if let number = phoneNumber(contact), let url = URL(string: "sms:\(number)") {
            return ContactAction(title: "Message Seller", systemImage: "message", url: url)
        }
        return nil
    }

    static func isEmail(_ text: String) -> Bool {
        let parts = text.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty,
              !text.contains(where: { $0.isWhitespace }) else { return false }
        let domain = parts[1]
        return domain.contains(".") && !domain.hasPrefix(".") && !domain.hasSuffix(".")
    }

    /// Digits with an optional leading "+", or nil if it doesn't look like a phone number.
    static func phoneNumber(_ text: String) -> String? {
        let allowed = Set("+-() .0123456789")
        guard text.allSatisfy({ allowed.contains($0) }) else { return nil }
        let digits = text.filter { $0.isASCII && $0.isNumber }
        guard (7...15).contains(digits.count) else { return nil }
        return (text.hasPrefix("+") ? "+" : "") + digits
    }
}
