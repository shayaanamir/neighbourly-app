//
//  Listing+Display.swift
//  neighbourly
//
//  Presentation helpers shared by cards, detail, and map previews.
//

import Foundation
import SwiftUI

nonisolated extension Listing {
    /// "₹1,800" for sell, "Free" for donate, "Exchange" for exchange.
    func priceText(locale: Locale = .current) -> String {
        switch mode {
        case .sell:
            guard let price else { return "Price on request" }
            return price.formatted(
                .currency(code: "INR").locale(locale).precision(.fractionLength(0...2))
            )
        case .exchange:
            return "Exchange"
        case .donate:
            return "Free"
        }
    }

    var areaText: String {
        let trimmed = areaName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Area not set" : trimmed
    }
}

extension ListingMode {
    var tint: Color {
        switch self {
        case .sell: Theme.Colors.sell
        case .exchange: Theme.Colors.exchange
        case .donate: Theme.Colors.donate
        }
    }
}
