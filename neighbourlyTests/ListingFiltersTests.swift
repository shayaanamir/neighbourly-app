//
//  ListingFiltersTests.swift
//  neighbourlyTests
//

import Foundation
import Testing
@testable import neighbourly

struct ListingFiltersTests {
    private let table = Listing(
        title: "Study table", description: "Solid wood with a drawer",
        category: .furniture, mode: .sell, price: 1800, condition: .good,
        areaName: "Vidyavihar", sellerName: "A"
    )
    private let books = Listing(
        title: "Maths textbooks", description: "Second year engineering",
        category: .books, mode: .donate, condition: .fair,
        areaName: "Ghatkopar East", sellerName: "B"
    )
    private let bat = Listing(
        title: "Cricket bat", description: "Swap for a football",
        category: .sports, mode: .exchange, condition: .good,
        areaName: "Chembur", sellerName: "C"
    )
    private let chairs = Listing(
        title: "Café chairs", description: "",
        category: .furniture, mode: .exchange, condition: .fair,
        sellerName: "D"
    )

    private var all: [Listing] { [table, books, bat, chairs] }

    private func titles(_ filters: ListingFilters) -> [String] {
        filters.apply(to: all).map { $0.title }
    }

    @Test func emptyFiltersReturnEverything() {
        let filters = ListingFilters()
        #expect(!filters.isActive)
        #expect(titles(filters).count == all.count)
    }

    @Test func searchMatchesTitle() {
        #expect(titles(ListingFilters(searchText: "table")) == ["Study table"])
    }

    @Test func searchMatchesDescription() {
        #expect(titles(ListingFilters(searchText: "football")) == ["Cricket bat"])
    }

    @Test func searchMatchesArea() {
        #expect(titles(ListingFilters(searchText: "ghatkopar")) == ["Maths textbooks"])
    }

    @Test func searchIsCaseAndDiacriticInsensitive() {
        #expect(titles(ListingFilters(searchText: "STUDY")) == ["Study table"])
        #expect(titles(ListingFilters(searchText: "cafe")) == ["Café chairs"])
    }

    @Test func everySearchTermMustMatch() {
        #expect(titles(ListingFilters(searchText: "wood vidyavihar")) == ["Study table"])
        #expect(titles(ListingFilters(searchText: "wood chembur")).isEmpty)
    }

    @Test func whitespaceOnlySearchIsIgnored() {
        let filters = ListingFilters(searchText: "   ")
        #expect(!filters.isActive)
        #expect(titles(filters).count == all.count)
    }

    @Test func categoryFilter() {
        #expect(titles(ListingFilters(category: .furniture)) == ["Study table", "Café chairs"])
    }

    @Test func modeFilter() {
        #expect(titles(ListingFilters(mode: .exchange)) == ["Cricket bat", "Café chairs"])
    }

    @Test func filtersCombine() {
        let filters = ListingFilters(searchText: "chairs", category: .furniture, mode: .exchange)
        #expect(filters.isActive)
        #expect(titles(filters) == ["Café chairs"])
        #expect(titles(ListingFilters(category: .books, mode: .sell)).isEmpty)
    }

    @Test func clearResetsEverything() {
        var filters = ListingFilters(searchText: "x", category: .books, mode: .donate)
        filters.clear()
        #expect(filters == ListingFilters())
    }

    @Test func sampleDataSearchAndFilters() {
        let samples = SampleListings.make()
        let donations = ListingFilters(mode: .donate).apply(to: samples)
        let powai = ListingFilters(searchText: "powai").apply(to: samples)
        #expect(donations.count == 2)
        #expect(powai.count == 1)
    }
}

struct ListingDisplayTests {
    private let india = Locale(identifier: "en_IN")

    private func listing(mode: ListingMode, price: Decimal?, area: String? = nil) -> Listing {
        Listing(title: "Item", category: .other, mode: mode, price: price,
                condition: .good, areaName: area, sellerName: "S")
    }

    @Test func sellShowsRupeePrice() {
        #expect(listing(mode: .sell, price: 1800).priceText(locale: india) == "₹1,800")
    }

    @Test func donateShowsFree() {
        #expect(listing(mode: .donate, price: nil).priceText(locale: india) == "Free")
    }

    @Test func exchangeShowsExchange() {
        #expect(listing(mode: .exchange, price: nil).priceText(locale: india) == "Exchange")
    }

    @Test func blankAreaShowsPlaceholder() {
        #expect(listing(mode: .donate, price: nil, area: "  ").areaText == "Area not set")
        #expect(listing(mode: .donate, price: nil, area: "Powai").areaText == "Powai")
    }
}
