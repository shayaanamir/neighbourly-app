//
//  SharedListingsTests.swift
//  neighbourlyTests
//
//  Phase 9: sellerID, the Firestore field mapping, photo compression, and the
//  repository that merges cloud listings with local samples. None of these touch
//  the network.
//

import Foundation
import Testing
import UIKit
@testable import neighbourly

// MARK: - Field mapping

struct ListingMappingTests {
    private let created = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeListing(
        mode: ListingMode = .sell,
        price: Decimal? = 1800.50,
        photos: [String] = ["a.jpg", "b.jpg"]
    ) -> Listing {
        Listing(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            title: "Study table", description: "Solid wood", category: .furniture, mode: mode,
            price: price, condition: .likeNew, imageFileNames: photos,
            latitude: 19.08, longitude: 72.9, areaName: "Vidyavihar",
            sellerID: "uid-1", sellerName: "Asha", sellerContact: "asha@example.com",
            createdAt: created, isDemo: false
        )
    }

    @Test func roundTripPreservesTheListing() throws {
        let original = makeListing()
        let data = ListingMapping.data(for: original, thumbnail: Data([1, 2, 3]))
        let result = try #require(ListingMapping.listing(from: data, id: original.id.uuidString))

        var expected = original
        expected.sellerContact = nil // never published
        #expect(result.listing == expected)
        #expect(result.thumbnail == Data([1, 2, 3]))
    }

    @Test func publicDocumentsNeverContainContactDetailsOrDemoFlag() {
        let data = ListingMapping.data(for: makeListing(), thumbnail: nil)
        #expect(data["sellerContact"] == nil)
        #expect(data["isDemo"] == nil)
        #expect(data["id"] == nil)
    }

    @Test func pricesAreStoredAsWholePaise() {
        let data = ListingMapping.data(for: makeListing(price: 1800.50), thumbnail: nil)
        #expect(data[ListingMapping.Field.priceMinor] as? Int == 180050)
    }

    @Test func minorUnitsRoundsToTheNearestPaisa() {
        #expect(ListingMapping.minorUnits(from: 0) == 0)
        #expect(ListingMapping.minorUnits(from: 250) == 25000)
        #expect(ListingMapping.minorUnits(from: Decimal(string: "19.999")!) == 2000)
        #expect(ListingMapping.minorUnits(from: Decimal(string: "0.10")!) == 10)
    }

    @Test(arguments: [ListingMode.exchange, .donate])
    func nonSellListingsHaveNoPrice(mode: ListingMode) throws {
        let listing = makeListing(mode: mode, price: nil)
        let data = ListingMapping.data(for: listing, thumbnail: nil)
        #expect(data[ListingMapping.Field.priceMinor] == nil)

        let result = try #require(ListingMapping.listing(from: data, id: listing.id.uuidString))
        #expect(result.listing.price == nil)
    }

    @Test func wholeNumbersFromTheServerMayArriveInAnyNumericType() throws {
        let base = ListingMapping.data(for: makeListing(), thumbnail: nil)
        let id = makeListing().id.uuidString

        let spellings: [Any] = [180050, Int64(180050), 180050.0]
        for value in spellings {
            var data = base
            data[ListingMapping.Field.priceMinor] = value
            let result = try #require(ListingMapping.listing(from: data, id: id))
            #expect(result.listing.price == Decimal(string: "1800.5"))
        }
    }

    @Test func listingWithoutCoordinatesOrAreaOmitsThem() throws {
        var listing = makeListing()
        listing.latitude = nil
        listing.longitude = nil
        listing.areaName = nil
        let data = ListingMapping.data(for: listing, thumbnail: nil)
        #expect(data[ListingMapping.Field.latitude] == nil)
        #expect(data[ListingMapping.Field.longitude] == nil)
        #expect(data[ListingMapping.Field.areaName] == nil)

        let result = try #require(ListingMapping.listing(from: data, id: listing.id.uuidString))
        #expect(!result.listing.hasCoordinates)
        #expect(result.listing.areaName == nil)
    }

    @Test func optionalFieldsDefaultWhenMissing() throws {
        var data = ListingMapping.data(for: makeListing(), thumbnail: nil)
        data[ListingMapping.Field.description] = nil
        data[ListingMapping.Field.photoIDs] = nil

        let result = try #require(ListingMapping.listing(from: data, id: makeListing().id.uuidString))
        #expect(result.listing.description == "")
        #expect(result.listing.imageFileNames.isEmpty)
        #expect(result.thumbnail == nil)
    }

    @Test(arguments: [
        ListingMapping.Field.title, ListingMapping.Field.category, ListingMapping.Field.mode,
        ListingMapping.Field.condition, ListingMapping.Field.sellerID,
        ListingMapping.Field.sellerName, ListingMapping.Field.createdAt,
    ])
    func documentsMissingARequiredFieldAreSkipped(field: String) {
        var data = ListingMapping.data(for: makeListing(), thumbnail: nil)
        data[field] = nil
        #expect(ListingMapping.listing(from: data, id: makeListing().id.uuidString) == nil)
    }

    @Test func unknownEnumValuesAndBadIDsAreSkipped() {
        let id = makeListing().id.uuidString
        var data = ListingMapping.data(for: makeListing(), thumbnail: nil)

        data[ListingMapping.Field.category] = "spaceships"
        #expect(ListingMapping.listing(from: data, id: id) == nil)

        data = ListingMapping.data(for: makeListing(), thumbnail: nil)
        #expect(ListingMapping.listing(from: data, id: "not-a-uuid") == nil)
    }

    @Test func writtenFieldsStayWithinWhatTheSecurityRulesAllow() {
        // Keep in sync with validListing() in firebase/firestore.rules.
        let allowed: Set<String> = [
            "title", "description", "category", "mode", "priceMinor", "condition", "photoIDs",
            "latitude", "longitude", "areaName", "sellerID", "sellerName", "createdAt", "thumbnail",
        ]
        let data = ListingMapping.data(for: makeListing(), thumbnail: Data([1]))
        #expect(Set(data.keys).isSubset(of: allowed))

        let required: Set<String> = [
            "title", "category", "mode", "condition", "photoIDs", "sellerID", "sellerName", "createdAt",
        ]
        #expect(required.isSubset(of: Set(data.keys)))
    }
}

// MARK: - Backward compatibility

struct ListingCodableCompatibilityTests {
    @Test func listingsSavedBeforeAccountsStillDecode() throws {
        // JSON written by the app before `sellerID` existed.
        let json = """
        [{
          "id": "11111111-1111-1111-1111-111111111111",
          "title": "Old listing", "description": "", "category": "books", "mode": "donate",
          "condition": "good", "imageFileNames": [], "sellerName": "Me",
          "createdAt": 700000000, "isDemo": false
        }]
        """
        let listings = try JSONDecoder().decode([Listing].self, from: Data(json.utf8))
        #expect(listings.count == 1)
        #expect(listings.first?.sellerID == nil)
        #expect(listings.first?.title == "Old listing")
    }

    @Test func sellerIDSurvivesEncoding() throws {
        let listing = Listing(
            title: "Chair", category: .furniture, mode: .donate, condition: .good,
            sellerID: "uid-1", sellerName: "Asha"
        )
        let decoded = try JSONDecoder().decode(Listing.self, from: JSONEncoder().encode(listing))
        #expect(decoded.sellerID == "uid-1")
    }
}

// MARK: - Photo compression

struct PhotoCompressorTests {
    /// A busy picture that doesn't compress well, like a real photo.
    private func noisyImageData(width: CGFloat, height: CGFloat) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            var generator = SystemRandomNumberGenerator()
            for _ in 0..<6000 {
                UIColor(
                    red: .random(in: 0...1, using: &generator),
                    green: .random(in: 0...1, using: &generator),
                    blue: .random(in: 0...1, using: &generator),
                    alpha: 1
                ).setFill()
                context.fill(CGRect(
                    x: .random(in: 0..<width, using: &generator),
                    y: .random(in: 0..<height, using: &generator),
                    width: .random(in: 4...60, using: &generator),
                    height: .random(in: 4...60, using: &generator)
                ))
            }
        }
        return image.pngData()!
    }

    @Test func fullPhotosFitTheSizeBudget() throws {
        let compressed = try #require(PhotoCompressor.fullPhoto(from: noisyImageData(width: 2400, height: 1800)))
        #expect(compressed.count <= PhotoCompressor.fullPhotoMaxBytes)

        let image = try #require(UIImage(data: compressed))
        #expect(max(image.size.width, image.size.height) <= PhotoCompressor.fullPhotoMaxEdge)
    }

    @Test func thumbnailsAreSmallAndTiny() throws {
        let thumbnail = try #require(PhotoCompressor.thumbnail(from: noisyImageData(width: 1600, height: 1200)))
        #expect(thumbnail.count <= PhotoCompressor.thumbnailMaxBytes)

        let image = try #require(UIImage(data: thumbnail))
        #expect(max(image.size.width, image.size.height) <= PhotoCompressor.thumbnailMaxEdge)
    }

    @Test func smallImagesAreNotEnlarged() throws {
        let compressed = try #require(PhotoCompressor.fullPhoto(from: noisyImageData(width: 200, height: 100)))
        let image = try #require(UIImage(data: compressed))
        #expect(image.size.width <= 200)
    }

    @Test func nonImageDataIsRejected() {
        #expect(PhotoCompressor.fullPhoto(from: Data("not an image".utf8)) == nil)
        #expect(PhotoCompressor.thumbnail(from: Data()) == nil)
    }
}

// MARK: - Photo cache

struct PhotoCacheTests {
    private func makeStore() -> PhotoStore {
        PhotoStore(directory: URL.temporaryDirectory.appending(path: "CacheTests-\(UUID().uuidString)", directoryHint: .isDirectory))
    }

    private func pngData(color: UIColor, size: CGFloat) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: size, height: size))
        }.pngData()!
    }

    @Test func cachedBytesAreReadableAsAnImage() {
        let store = makeStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }

        store.cache(data: pngData(color: .red, size: 20), named: "remote.jpg")
        #expect(store.fileExists(named: "remote.jpg"))
        #expect(store.image(named: "remote.jpg") != nil)
    }

    @Test func thumbnailIsPreferredOverTheFullPhoto() throws {
        let store = makeStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }

        store.cache(data: pngData(color: .red, size: 100), named: "p.jpg")
        store.saveThumbnail(pngData(color: .blue, size: 10), for: "p.jpg")

        let image = try #require(store.thumbnailImage(for: "p.jpg"))
        #expect(image.size.width == 10, "the small preview wins")
    }

    @Test func thumbnailFallsBackToTheFullPhoto() throws {
        let store = makeStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }

        store.cache(data: pngData(color: .red, size: 100), named: "p.jpg")
        let image = try #require(store.thumbnailImage(for: "p.jpg"))
        #expect(image.size.width == 100)
        #expect(store.thumbnailImage(for: "missing.jpg") == nil)
    }

    @Test func thumbnailNamesStayInsideTheCacheFolder() {
        let store = makeStore()
        #expect(store.thumbnailFileName(for: "../../evil.jpg") == "thumb-evil.jpg")
    }
}

// MARK: - Merging cloud and local listings

/// A stand-in for the cloud store that can fail and records what it was asked to do.
private actor StubSharedRepository: ListingRepository {
    var listings: [Listing]
    var fetchError: ListingRepositoryError?
    var photos: [String: Data] = [:]
    private(set) var savedIDs: [UUID] = []
    private(set) var deletedIDs: [UUID] = []
    private(set) var ownersCleared: [String] = []

    init(listings: [Listing] = [], fetchError: ListingRepositoryError? = nil) {
        self.listings = listings
        self.fetchError = fetchError
    }

    func setFetchError(_ error: ListingRepositoryError?) { fetchError = error }
    func setPhoto(_ data: Data, named name: String) { photos[name] = data }

    func fetchListings() async throws -> [Listing] {
        if let fetchError { throw fetchError }
        return listings
    }
    func save(_ listing: Listing) async throws {
        savedIDs.append(listing.id)
        listings.append(listing)
    }
    func delete(id: UUID) async throws {
        deletedIDs.append(id)
        listings.removeAll { $0.id == id }
    }
    func resetToSampleData() async throws {}
    func fetchPhoto(listingID: UUID, fileName: String) async throws -> Data? { photos[fileName] }
    func deleteAllListings(ownedBy userID: String) async throws { ownersCleared.append(userID) }
}

struct CompositeListingRepositoryTests {
    private let now = Date()

    private func sample(_ title: String, hoursAgo: Double) -> Listing {
        Listing(
            title: title, category: .other, mode: .donate, condition: .good,
            sellerName: "Demo (demo)", createdAt: now.addingTimeInterval(-hoursAgo * 3600), isDemo: true
        )
    }

    private func real(_ title: String, hoursAgo: Double, seller: String = "uid-1") -> Listing {
        Listing(
            title: title, category: .books, mode: .donate, condition: .good,
            sellerID: seller, sellerName: "Real", createdAt: now.addingTimeInterval(-hoursAgo * 3600)
        )
    }

    @Test func cloudAndSampleListingsAreMergedNewestFirst() async throws {
        let demo = InMemoryListingRepository(listings: [sample("Sample old", hoursAgo: 10), sample("Sample new", hoursAgo: 1)])
        let shared = StubSharedRepository(listings: [real("Cloud middle", hoursAgo: 5), real("Cloud newest", hoursAgo: 0.5)])
        let repository = CompositeListingRepository(demo: demo, shared: shared)

        let titles = try await repository.fetchListings().map { $0.title }
        let warning = await repository.loadWarning()
        #expect(titles == ["Cloud newest", "Sample new", "Cloud middle", "Sample old"])
        #expect(warning == nil)
    }

    @Test func legacyLocalListingsAreHidden() async throws {
        let legacy = real("Saved before accounts", hoursAgo: 2, seller: "x")
        var legacyWithoutOwner = legacy
        legacyWithoutOwner.sellerID = nil
        let demo = InMemoryListingRepository(listings: [sample("Sample", hoursAgo: 1), legacyWithoutOwner])
        let repository = CompositeListingRepository(demo: demo, shared: StubSharedRepository())

        let titles = try await repository.fetchListings().map { $0.title }
        #expect(titles == ["Sample"])
    }

    @Test func unreachableServerFallsBackToSamplesWithAWarning() async throws {
        let demo = InMemoryListingRepository(listings: [sample("Sample", hoursAgo: 1)])
        let shared = StubSharedRepository(fetchError: .sharedUnavailable(reason: "The server couldn't be reached."))
        let repository = CompositeListingRepository(demo: demo, shared: shared)

        let titles = try await repository.fetchListings().map { $0.title }
        #expect(titles == ["Sample"])

        let warning = try #require(await repository.loadWarning())
        #expect(warning.contains("sample listings only"))
        #expect(warning.contains("couldn't be reached"))
    }

    @Test func warningClearsOnceTheServerIsBackAgain() async throws {
        let demo = InMemoryListingRepository(listings: [sample("Sample", hoursAgo: 1)])
        let shared = StubSharedRepository(fetchError: .sharedUnavailable(reason: "Offline."))
        let repository = CompositeListingRepository(demo: demo, shared: shared)

        _ = try await repository.fetchListings()
        let whileOffline = await repository.loadWarning()
        #expect(whileOffline != nil)

        await shared.setFetchError(nil)
        _ = try await repository.fetchListings()
        let afterRecovery = await repository.loadWarning()
        #expect(afterRecovery == nil)
    }

    @Test func realListingsGoToTheCloudAndSamplesStayLocal() async throws {
        let demo = InMemoryListingRepository(listings: [])
        let shared = StubSharedRepository()
        let repository = CompositeListingRepository(demo: demo, shared: shared)

        let cloudListing = real("Posted", hoursAgo: 0)
        let sampleListing = sample("Sample", hoursAgo: 0)
        try await repository.save(cloudListing)
        try await repository.save(sampleListing)

        let cloudSaves = await shared.savedIDs
        let localIDs = try await demo.fetchListings().map { $0.id }
        #expect(cloudSaves == [cloudListing.id])
        #expect(localIDs == [sampleListing.id])
    }

    @Test func deletingASampleNeverAsksTheCloud() async throws {
        let sampleListing = sample("Sample", hoursAgo: 1)
        let demo = InMemoryListingRepository(listings: [sampleListing])
        let shared = StubSharedRepository()
        let repository = CompositeListingRepository(demo: demo, shared: shared)

        try await repository.delete(id: sampleListing.id)
        let cloudDeletes = await shared.deletedIDs
        let remaining = try await demo.fetchListings()
        #expect(cloudDeletes.isEmpty)
        #expect(remaining.isEmpty)
    }

    @Test func deletingARealListingGoesToTheCloud() async throws {
        let cloudListing = real("Posted", hoursAgo: 1)
        let shared = StubSharedRepository(listings: [cloudListing])
        let repository = CompositeListingRepository(demo: InMemoryListingRepository(listings: []), shared: shared)

        try await repository.delete(id: cloudListing.id)
        let cloudDeletes = await shared.deletedIDs
        #expect(cloudDeletes == [cloudListing.id])
    }

    @Test func resetOnlyTouchesTheSamples() async throws {
        let cloudListing = real("Posted", hoursAgo: 1)
        let shared = StubSharedRepository(listings: [cloudListing])
        let demo = InMemoryListingRepository(listings: [])
        let repository = CompositeListingRepository(demo: demo, shared: shared)

        try await repository.resetToSampleData()
        let cloudListings = await shared.listings
        let local = try await demo.fetchListings()
        let allSamples = local.allSatisfy { $0.isDemo }
        #expect(cloudListings == [cloudListing])
        #expect(allSamples)
        #expect(!local.isEmpty)
    }

    @Test func photoDownloadsAndAccountCleanupGoToTheCloud() async throws {
        let shared = StubSharedRepository()
        await shared.setPhoto(Data([9, 9]), named: "p.jpg")
        let repository = CompositeListingRepository(demo: InMemoryListingRepository(listings: []), shared: shared)

        let photo = try await repository.fetchPhoto(listingID: UUID(), fileName: "p.jpg")
        #expect(photo == Data([9, 9]))

        try await repository.deleteAllListings(ownedBy: "uid-1")
        let cleared = await shared.ownersCleared
        #expect(cleared == ["uid-1"])
    }

    @Test func localOnlyRepositoriesHaveNoCloudBehaviour() async throws {
        let repository = InMemoryListingRepository(listings: [])
        let photo = try await repository.fetchPhoto(listingID: UUID(), fileName: "x.jpg")
        let warning = await repository.loadWarning()
        #expect(photo == nil)
        #expect(warning == nil)
        try await repository.deleteAllListings(ownedBy: "anyone") // no-op, no crash
    }
}

// MARK: - Creating and editing shared listings

@MainActor
final class SharedListingFormTests {
    private let directory = URL.temporaryDirectory.appending(path: "SharedForm-\(UUID().uuidString)", directoryHint: .isDirectory)
    private lazy var photoStore = PhotoStore(directory: directory)

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    private func pngData() -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 30, height: 30), format: format).image { context in
            UIColor.green.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 30, height: 30))
        }.pngData()!
    }

    @Test func newListingsCarryTheAccountID() async throws {
        let viewModel = CreateListingViewModel(
            repository: InMemoryListingRepository(listings: []), photoStore: photoStore,
            visionAssist: VisionAssistService(), defaultSellerName: "Asha", sellerID: "uid-1"
        )
        viewModel.title = "Chair"
        viewModel.mode = .donate

        let saved = try #require(await viewModel.save())
        #expect(saved.sellerID == "uid-1")
        #expect(saved.sellerName == "Asha")
    }

    @Test func editingKeepsTheOriginalOwner() async throws {
        let original = Listing(
            title: "Chair", category: .furniture, mode: .donate, condition: .good,
            sellerID: "uid-1", sellerName: "Asha"
        )
        let viewModel = CreateListingViewModel(
            repository: InMemoryListingRepository(listings: [original]), photoStore: photoStore,
            visionAssist: VisionAssistService(), editing: original, sellerID: "someone-else"
        )
        viewModel.title = "Better chair"

        let saved = try #require(await viewModel.save())
        #expect(saved.sellerID == "uid-1", "an edit must never reassign the listing")
    }

    @Test func missingPhotosAreDownloadedBeforeEditing() async throws {
        let shared = StubSharedRepository()
        await shared.setPhoto(pngData(), named: "remote.jpg")
        let original = Listing(
            title: "Chair", category: .furniture, mode: .donate, condition: .good,
            imageFileNames: ["remote.jpg"], sellerID: "uid-1", sellerName: "Asha"
        )
        #expect(!photoStore.fileExists(named: "remote.jpg"))

        let viewModel = CreateListingViewModel(
            repository: shared, photoStore: photoStore, visionAssist: VisionAssistService(), editing: original
        )
        await viewModel.loadExistingPhotos()

        #expect(viewModel.photos.count == 1, "the photo was fetched, not dropped")
        #expect(photoStore.fileExists(named: "remote.jpg"), "and cached for next time")
        #expect(viewModel.photoMessage == nil)
    }

    @Test func formNoLongerOffersAPublicContactField() {
        // Contact details are not published; the model keeps the legacy value but the
        // form starts empty for new listings.
        let viewModel = CreateListingViewModel(
            repository: InMemoryListingRepository(listings: []), photoStore: photoStore,
            visionAssist: VisionAssistService()
        )
        #expect(viewModel.sellerContact.isEmpty)
        #expect(viewModel.makeListing(imageFileNames: []).sellerContact == nil)
    }
}

// MARK: - Account deletion cleans up listings first

@MainActor
struct AccountDeletionCleanupTests {
    private func makeViewModel() -> AuthViewModel {
        let service = MockAuthService()
        service.seedAccount(name: "Asha", email: "asha@example.com", password: "password1", signedIn: true)
        return AuthViewModel(service: service)
    }

    private func startAndSettle(_ viewModel: AuthViewModel) async {
        let task = Task { await viewModel.start() }
        var attempts = 0
        while viewModel.session == .loading && attempts < 500 {
            await Task.yield()
            attempts += 1
        }
        task.cancel()
    }

    @Test func cleanupRunsBeforeTheAccountIsDeleted() async {
        let viewModel = makeViewModel()
        await startAndSettle(viewModel)

        var cleanedUp = false
        let ok = await viewModel.deleteAccount(password: "password1") { cleanedUp = true }
        #expect(ok)
        #expect(cleanedUp)
        #expect(viewModel.session == .signedOut)
    }

    @Test func wrongPasswordDoesNotTouchAnyData() async {
        let viewModel = makeViewModel()
        await startAndSettle(viewModel)

        var cleanedUp = false
        let ok = await viewModel.deleteAccount(password: "wrong") { cleanedUp = true }
        #expect(!ok)
        #expect(!cleanedUp, "listings must survive a mistyped password")
        #expect(viewModel.isSignedIn)
    }

    @Test func failedCleanupKeepsTheAccount() async {
        let viewModel = makeViewModel()
        await startAndSettle(viewModel)

        let ok = await viewModel.deleteAccount(password: "password1") {
            throw ListingRepositoryError.sharedUnavailable(reason: "Couldn't remove your listings.")
        }
        #expect(!ok)
        #expect(viewModel.isSignedIn)
        #expect(viewModel.errorMessage == "Couldn't remove your listings.")
    }
}
