//
//  LocalListingRepositoryTests.swift
//  neighbourlyTests
//

import Foundation
import Testing
@testable import neighbourly

/// Each test gets its own temporary directory, removed afterwards.
final class LocalListingRepositoryTests {
    private let directory: URL

    init() {
        directory = URL.temporaryDirectory.appending(path: "RepoTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    private func makeRepository(seeds: [Listing] = []) -> LocalListingRepository {
        LocalListingRepository(directory: directory, seedListings: { seeds })
    }

    private func makeListing(title: String = "Bookshelf", createdAt: Date = .now) -> Listing {
        Listing(
            title: title, category: .furniture, mode: .donate, condition: .good,
            latitude: 19.08, longitude: 72.9, areaName: "Test area",
            sellerName: "Tester", createdAt: createdAt
        )
    }

    @Test func firstLaunchSeedsSampleData() async throws {
        let seeds = SampleListings.make()
        let listings = try await makeRepository(seeds: seeds).fetchListings()
        #expect(listings.count == seeds.count)
    }

    @Test func doesNotReseedAfterAllListingsAreDeleted() async throws {
        let seeds = SampleListings.make()
        let repository = makeRepository(seeds: seeds)
        for listing in try await repository.fetchListings() {
            try await repository.delete(id: listing.id)
        }

        let relaunched = makeRepository(seeds: seeds)
        #expect(try await relaunched.fetchListings().isEmpty)
    }

    @Test func createAndRead() async throws {
        let repository = makeRepository()
        let listing = makeListing()
        try await repository.save(listing)

        #expect(try await repository.fetchListings() == [listing])
    }

    @Test func updateReplacesExistingListing() async throws {
        let repository = makeRepository()
        var listing = makeListing()
        try await repository.save(listing)

        listing.title = "Tall bookshelf"
        try await repository.save(listing)

        let listings = try await repository.fetchListings()
        #expect(listings.count == 1)
        #expect(listings.first?.title == "Tall bookshelf")
    }

    @Test func deleteRemovesListing() async throws {
        let repository = makeRepository()
        let keep = makeListing(title: "Keep")
        let remove = makeListing(title: "Remove")
        try await repository.save(keep)
        try await repository.save(remove)

        try await repository.delete(id: remove.id)
        let ids = try await repository.fetchListings().map { $0.id }
        #expect(ids == [keep.id])
    }

    @Test func deletingUnknownIdIsIgnored() async throws {
        let repository = makeRepository()
        try await repository.save(makeListing())
        try await repository.delete(id: UUID())
        #expect(try await repository.fetchListings().count == 1)
    }

    @Test func invalidListingIsNotSaved() async throws {
        let repository = makeRepository()
        await #expect(throws: ListingValidationError.emptyTitle) {
            try await repository.save(self.makeListing(title: " "))
        }
        #expect(try await repository.fetchListings().isEmpty)
    }

    @Test func listingsSurviveRelaunch() async throws {
        let listing = makeListing()
        try await makeRepository().save(listing)

        // A new instance has no in-memory cache, so this reads the JSON file.
        let relaunched = makeRepository()
        #expect(try await relaunched.fetchListings() == [listing])
    }

    @Test func fetchReturnsNewestFirst() async throws {
        let repository = makeRepository()
        let older = makeListing(title: "Older", createdAt: .now.addingTimeInterval(-60))
        let newer = makeListing(title: "Newer")
        try await repository.save(older)
        try await repository.save(newer)

        let titles = try await repository.fetchListings().map { $0.title }
        #expect(titles == ["Newer", "Older"])
    }

    @Test func corruptedFileThrowsAndResetRecovers() async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: directory.appending(path: "listings.json"))

        let seeds = SampleListings.make()
        let repository = makeRepository(seeds: seeds)
        await #expect(throws: ListingRepositoryError.self) {
            try await repository.fetchListings()
        }

        try await repository.resetToSampleData()
        #expect(try await repository.fetchListings().count == seeds.count)
    }
}
