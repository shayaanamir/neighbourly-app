//
//  ListingValidationTests.swift
//  neighbourlyTests
//

import Foundation
import Testing
@testable import neighbourly

struct ListingValidationTests {
    private func makeListing(
        title: String = "Desk lamp",
        description: String = "",
        mode: ListingMode = .sell,
        price: Decimal? = 300,
        sellerName: String = "Test seller",
        latitude: Double? = nil,
        longitude: Double? = nil
    ) -> Listing {
        Listing(
            title: title, description: description, category: .other, mode: mode,
            price: price, condition: .good, latitude: latitude, longitude: longitude,
            sellerName: sellerName
        )
    }

    @Test func validSellListingPasses() throws {
        let listing = makeListing()
        #expect(listing.isValid)
        try listing.validate()
    }

    @Test(arguments: ["", "   ", "\n"])
    func blankTitleFails(title: String) {
        #expect(makeListing(title: title).validationErrors == [.emptyTitle])
    }

    @Test func titleLengthLimit() {
        #expect(makeListing(title: String(repeating: "a", count: Listing.maxTitleLength)).isValid)
        #expect(makeListing(title: String(repeating: "a", count: Listing.maxTitleLength + 1)).validationErrors
            == [.titleTooLong(max: Listing.maxTitleLength)])
    }

    @Test func descriptionLengthLimit() {
        let long = String(repeating: "a", count: Listing.maxDescriptionLength + 1)
        #expect(makeListing(description: long).validationErrors
            == [.descriptionTooLong(max: Listing.maxDescriptionLength)])
    }

    @Test func sellRequiresPrice() {
        #expect(makeListing(mode: .sell, price: nil).validationErrors == [.missingPrice])
    }

    @Test func sellRejectsNegativePrice() {
        #expect(makeListing(mode: .sell, price: -1).validationErrors == [.negativePrice])
    }

    @Test func sellAllowsZeroPrice() {
        #expect(makeListing(mode: .sell, price: 0).isValid)
    }

    @Test(arguments: [ListingMode.exchange, .donate])
    func nonSellModesNeedNoPrice(mode: ListingMode) {
        #expect(makeListing(mode: mode, price: nil).isValid)
        #expect(makeListing(mode: mode, price: 100).validationErrors == [.priceNotAllowed(mode)])
    }

    @Test func blankSellerNameFails() {
        #expect(makeListing(sellerName: "  ").validationErrors == [.emptySellerName])
    }

    @Test func coordinatesMustBePaired() {
        #expect(makeListing(latitude: 19.08, longitude: nil).validationErrors == [.incompleteCoordinates])
        #expect(makeListing(latitude: nil, longitude: 72.9).validationErrors == [.incompleteCoordinates])
        #expect(makeListing(latitude: 19.08, longitude: 72.9).isValid)
    }

    @Test func coordinatesMustBeInRange() {
        #expect(makeListing(latitude: 91, longitude: 0).validationErrors == [.latitudeOutOfRange])
        #expect(makeListing(latitude: 0, longitude: -181).validationErrors == [.longitudeOutOfRange])
        #expect(makeListing(latitude: -90, longitude: 180).isValid)
    }

    @Test func validateThrowsFirstError() {
        #expect(throws: ListingValidationError.emptyTitle) {
            try makeListing(title: "", price: nil).validate()
        }
    }

    @Test func sampleListingsAreValidAndCoverEveryMode() {
        let samples = SampleListings.make()
        #expect(samples.allSatisfy(\.isValid))
        #expect(samples.allSatisfy(\.isDemo))
        #expect(Set(samples.map(\.mode)) == Set(ListingMode.allCases))
        #expect(samples.contains { $0.hasCoordinates })
        #expect(samples.contains { !$0.hasCoordinates })
    }
}
