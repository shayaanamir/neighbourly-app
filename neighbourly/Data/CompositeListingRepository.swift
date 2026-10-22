//
//  CompositeListingRepository.swift
//  neighbourly
//
//  Browse shows two kinds of listing side by side: shared listings from the cloud
//  and the local sample (demo) listings. This repository routes each operation to
//  the right store and keeps the app usable when the cloud isn't reachable.
//

import Foundation

actor CompositeListingRepository: ListingRepository {
    private let demo: any ListingRepository
    private let shared: any ListingRepository
    private var warning: String?

    /// - Parameters:
    ///   - demo: local store holding the sample listings.
    ///   - shared: cloud store holding everyone's real listings.
    init(demo: any ListingRepository, shared: any ListingRepository) {
        self.demo = demo
        self.shared = shared
    }

    func fetchListings() async throws -> [Listing] {
        // Only sample listings come from the local store; anything else in it predates accounts.
        let samples = try await demo.fetchListings().filter { $0.isDemo }

        var cloud: [Listing] = []
        do {
            cloud = try await shared.fetchListings()
            warning = nil
        } catch {
            // Don't fail the whole screen: show the samples and say what happened.
            let reason = (error as? LocalizedError)?.errorDescription ?? "The server couldn't be reached."
            warning = "Showing sample listings only. \(reason)"
        }
        return (cloud + samples).sorted { $0.createdAt > $1.createdAt }
    }

    func save(_ listing: Listing) async throws {
        if listing.isDemo {
            try await demo.save(listing)
        } else {
            try await shared.save(listing)
        }
    }

    func delete(id: UUID) async throws {
        // Deleting an ID the cloud has never seen would be refused, so check for samples first.
        let isSample = (try? await demo.fetchListings())?.contains { $0.id == id && $0.isDemo } ?? false
        if isSample {
            try await demo.delete(id: id)
        } else {
            try await shared.delete(id: id)
        }
    }

    func resetToSampleData() async throws {
        try await demo.resetToSampleData()
    }

    func fetchPhoto(listingID: UUID, fileName: String) async throws -> Data? {
        try await shared.fetchPhoto(listingID: listingID, fileName: fileName)
    }

    func deleteAllListings(ownedBy userID: String) async throws {
        try await shared.deleteAllListings(ownedBy: userID)
    }

    func loadWarning() async -> String? {
        warning
    }
}
