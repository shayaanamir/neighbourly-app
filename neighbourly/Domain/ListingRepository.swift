//
//  ListingRepository.swift
//  neighbourly
//

import Foundation

/// Persistence boundary for listings. Views and view models depend on this,
/// never on a concrete store.
nonisolated protocol ListingRepository: Sendable {
    /// All listings, newest first.
    func fetchListings() async throws -> [Listing]
    /// Inserts a new listing or replaces the one with the same id. Validates first.
    func save(_ listing: Listing) async throws
    /// Removes the listing (and its photos). Unknown ids are ignored.
    func delete(id: UUID) async throws
    /// Replaces all data with the sample listings.
    func resetToSampleData() async throws
}

nonisolated enum ListingRepositoryError: LocalizedError, Sendable {
    case unreadableStore(reason: String)

    var errorDescription: String? {
        switch self {
        case .unreadableStore: "Saved listings couldn't be read. You can reset to the sample data."
        }
    }
}
