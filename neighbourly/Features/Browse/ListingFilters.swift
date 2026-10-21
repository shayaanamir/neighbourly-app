//
//  ListingFilters.swift
//  neighbourly
//
//  Search text plus category/mode filters for Browse. Pure value logic so it
//  can be unit tested without any UI.
//

import Foundation

nonisolated struct ListingFilters: Equatable, Sendable {
    var searchText = ""
    var category: ListingCategory?
    var mode: ListingMode?

    var isActive: Bool {
        !searchTerms.isEmpty || category != nil || mode != nil
    }

    /// Whitespace-separated terms; every term must match somewhere.
    private var searchTerms: [String] {
        searchText.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    func matches(_ listing: Listing) -> Bool {
        if let category, listing.category != category { return false }
        if let mode, listing.mode != mode { return false }

        let fields = [listing.title, listing.description, listing.areaName ?? ""]
        return searchTerms.allSatisfy { term in
            // Case- and diacritic-insensitive, locale-aware.
            fields.contains { $0.localizedStandardContains(term) }
        }
    }

    func apply(to listings: [Listing]) -> [Listing] {
        listings.filter(matches)
    }

    mutating func clear() {
        self = ListingFilters()
    }
}
