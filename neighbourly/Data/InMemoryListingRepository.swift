//
//  InMemoryListingRepository.swift
//  neighbourly
//
//  Non-persistent repository for SwiftUI previews.
//

import Foundation

actor InMemoryListingRepository: ListingRepository {
    private var listings: [Listing]

    init(listings: [Listing] = SampleListings.make()) {
        self.listings = listings
    }

    func fetchListings() async throws -> [Listing] {
        listings.sorted { $0.createdAt > $1.createdAt }
    }

    func save(_ listing: Listing) async throws {
        try listing.validate()
        if let index = listings.firstIndex(where: { $0.id == listing.id }) {
            listings[index] = listing
        } else {
            listings.append(listing)
        }
    }

    func delete(id: UUID) async throws {
        listings.removeAll { $0.id == id }
    }

    func resetToSampleData() async throws {
        listings = SampleListings.make()
    }
}
