//
//  ListingMapTests.swift
//  neighbourlyTests
//

import CoreLocation
import Foundation
import Testing
@testable import neighbourly

struct ListingMapTests {
    @Test func coordinateRequiresBothValues() {
        var listing = Listing(title: "Lamp", category: .other, mode: .donate, condition: .good, sellerName: "S")
        #expect(listing.coordinate == nil)

        listing.latitude = 19.1
        #expect(listing.coordinate == nil)

        listing.longitude = 72.9
        let coordinate = listing.coordinate
        #expect(coordinate?.latitude == 19.1)
        #expect(coordinate?.longitude == 72.9)
    }

    @Test func sampleCoordinatesStayInDemoArea() {
        // Approximate box around central/eastern Mumbai suburbs.
        let located = SampleListings.make().compactMap { $0.coordinate }
        let insideDemoArea = located.allSatisfy { coordinate in
            (18.9...19.3).contains(coordinate.latitude) && (72.7...73.1).contains(coordinate.longitude)
        }
        #expect(located.count >= 5)
        #expect(insideDemoArea)
    }

    @Test func sampleListingsAllHaveAreaLabels() {
        let missingArea = SampleListings.make().filter { ($0.areaName ?? "").isEmpty }
        #expect(missingArea.isEmpty)
    }
}
