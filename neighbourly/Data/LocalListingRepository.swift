//
//  LocalListingRepository.swift
//  neighbourly
//
//  Stores listings as one Codable JSON file (listings.json) in the given
//  directory, normally Application Support/Neighbourly. Sample data is
//  written on first launch only, i.e. when the file doesn't exist yet.
//

import Foundation

actor LocalListingRepository: ListingRepository {
    private let fileURL: URL
    private let photoStore: PhotoStore?
    private let makeSeedListings: @Sendable () -> [Listing]
    private var cache: [Listing]?

    init(
        directory: URL,
        photoStore: PhotoStore? = nil,
        seedListings: @escaping @Sendable () -> [Listing] = { SampleListings.make() }
    ) {
        self.fileURL = directory.appending(path: "listings.json", directoryHint: .notDirectory)
        self.photoStore = photoStore
        self.makeSeedListings = seedListings
    }

    func fetchListings() async throws -> [Listing] {
        try loadIfNeeded().sorted { $0.createdAt > $1.createdAt }
    }

    func save(_ listing: Listing) async throws {
        try listing.validate()
        var listings = try loadIfNeeded()
        var removedPhotos: [String] = []
        if let index = listings.firstIndex(where: { $0.id == listing.id }) {
            removedPhotos = listings[index].imageFileNames.filter { !listing.imageFileNames.contains($0) }
            listings[index] = listing
        } else {
            listings.append(listing)
        }
        try persist(listings)
        removedPhotos.forEach { photoStore?.delete(named: $0) }
    }

    func delete(id: UUID) async throws {
        var listings = try loadIfNeeded()
        guard let index = listings.firstIndex(where: { $0.id == id }) else { return }
        let removed = listings.remove(at: index)
        try persist(listings)
        removed.imageFileNames.forEach { photoStore?.delete(named: $0) }
    }

    func resetToSampleData() async throws {
        let seeds = makeSeedListings()
        try persist(seeds)
        photoStore?.removeOrphans(keeping: Set(seeds.flatMap(\.imageFileNames)))
    }

    // MARK: - File I/O

    private func loadIfNeeded() throws -> [Listing] {
        if let cache { return cache }

        guard FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)) else {
            let seeds = makeSeedListings()
            try persist(seeds)
            return seeds
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let listings = try Self.makeDecoder().decode([Listing].self, from: data)
            cache = listings
            return listings
        } catch {
            throw ListingRepositoryError.unreadableStore(reason: error.localizedDescription)
        }
    }

    private func persist(_ listings: [Listing]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try Self.makeEncoder().encode(listings)
        try data.write(to: fileURL, options: .atomic)
        cache = listings
    }

    private static func makeEncoder() -> JSONEncoder {
        // Default date strategy keeps sub-second precision, so dates round-trip exactly.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        JSONDecoder()
    }
}
