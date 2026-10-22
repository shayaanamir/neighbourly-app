//
//  MyListingsViewModel.swift
//  neighbourly
//

import Foundation
import Observation

@Observable
final class MyListingsViewModel {
    private(set) var listings: [Listing] = []
    private(set) var hasLoaded = false
    private(set) var errorMessage: String?

    @ObservationIgnored private let repository: any ListingRepository

    init(repository: any ListingRepository) {
        self.repository = repository
    }

    /// Loads listings created on this device (sample/demo listings are not "mine").
    func load() async {
        do {
            let all = try await repository.fetchListings()
            listings = all.filter { !$0.isDemo }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        hasLoaded = true
    }

    /// Returns true if the listing was removed.
    func delete(_ listing: Listing) async -> Bool {
        do {
            try await repository.delete(id: listing.id)
            listings.removeAll { $0.id == listing.id }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Replaces every listing on this device (including your own) with the sample data.
    func resetSampleData() async -> Bool {
        do {
            try await repository.resetToSampleData()
            await load()
            return errorMessage == nil
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func dismissError() {
        errorMessage = nil
    }
}
