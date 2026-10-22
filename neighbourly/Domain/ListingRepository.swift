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
    /// Replaces local data with the sample listings. Never touches shared (cloud) data.
    func resetToSampleData() async throws

    /// Full-size bytes of one photo that isn't cached on this device yet, or nil if the
    /// repository has no such photo. Local-only repositories always return nil.
    func fetchPhoto(listingID: UUID, fileName: String) async throws -> Data?
    /// Removes every shared listing (and its photos) posted by this account. Used just
    /// before the account itself is deleted.
    func deleteAllListings(ownedBy userID: String) async throws
    /// A short, user-facing note when the last load was only partial (for example the
    /// server couldn't be reached and only sample listings are shown), otherwise nil.
    func loadWarning() async -> String?
}

extension ListingRepository {
    func fetchPhoto(listingID: UUID, fileName: String) async throws -> Data? { nil }
    func deleteAllListings(ownedBy userID: String) async throws {}
    func loadWarning() async -> String? { nil }
}

nonisolated enum ListingRepositoryError: LocalizedError, Equatable, Sendable {
    case unreadableStore(reason: String)
    /// Posting or changing a shared listing needs an account.
    case notSignedIn
    /// The server (or its free-plan quota) couldn't be used; the reason is already friendly.
    case sharedUnavailable(reason: String)

    var errorDescription: String? {
        switch self {
        case .unreadableStore: "Saved listings couldn't be read. You can reset to the sample data."
        case .notSignedIn: "Sign in to post or change listings."
        case .sharedUnavailable(let reason): reason
        }
    }
}
