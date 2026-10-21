//
//  ListingEnums.swift
//  neighbourly
//

import Foundation

/// How the item is being offered.
nonisolated enum ListingMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case sell
    case exchange
    case donate

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sell: "Sell"
        case .exchange: "Exchange"
        case .donate: "Donate"
        }
    }

    var systemImage: String {
        switch self {
        case .sell: "tag"
        case .exchange: "arrow.left.arrow.right"
        case .donate: "gift"
        }
    }

    /// Only sell listings carry a price.
    var requiresPrice: Bool { self == .sell }
}

nonisolated enum ListingCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case electronics
    case books
    case furniture
    case clothing
    case home
    case sports
    case toys
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .electronics: "Electronics"
        case .books: "Books"
        case .furniture: "Furniture"
        case .clothing: "Clothing"
        case .home: "Home & Kitchen"
        case .sports: "Sports"
        case .toys: "Toys & Games"
        case .other: "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .electronics: "desktopcomputer"
        case .books: "book"
        case .furniture: "sofa"
        case .clothing: "tshirt"
        case .home: "fork.knife"
        case .sports: "figure.run"
        case .toys: "puzzlepiece"
        case .other: "shippingbox"
        }
    }
}

nonisolated enum ItemCondition: String, Codable, CaseIterable, Identifiable, Sendable {
    case new
    case likeNew
    case good
    case fair

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .new: "New"
        case .likeNew: "Like new"
        case .good: "Good"
        case .fair: "Fair"
        }
    }
}
