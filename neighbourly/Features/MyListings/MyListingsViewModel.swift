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

    /// Loads the listings posted by this account. Sample listings and other people's
    /// listings are never "mine"; with no signed-in user the list is empty.
    func load(for userID: String?) async {
        guard let userID else {
            listings = []
            errorMessage = nil
            hasLoaded = true
            return
        }
        do {
            let all = try await repository.fetchListings()
            listings = all.filter { !$0.isDemo && $0.sellerID == userID }
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

    /// Resets the local sample data (shared listings in the cloud are not touched).
    func resetSampleData(for userID: String?) async -> Bool {
        do {
            try await repository.resetToSampleData()
            await load(for: userID)
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
