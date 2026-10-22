//
//  CreateListingViewModelTests.swift
//  neighbourlyTests
//

import Foundation
import Testing
import UIKit
@testable import neighbourly

/// Repository stub whose saves always fail, to check cleanup.
private struct FailingRepository: ListingRepository {
    struct Failure: LocalizedError {
        var errorDescription: String? { "Disk full" }
    }

    func fetchListings() async throws -> [Listing] { [] }
    func save(_ listing: Listing) async throws { throw Failure() }
    func delete(id: UUID) async throws {}
    func resetToSampleData() async throws {}
}

@MainActor
final class CreateListingViewModelTests {
    private let photoDirectory: URL
    private let photoStore: PhotoStore
    private let repository = InMemoryListingRepository(listings: [])

    init() {
        photoDirectory = URL.temporaryDirectory.appending(path: "CreateTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        photoStore = PhotoStore(directory: photoDirectory)
    }

    deinit {
        try? FileManager.default.removeItem(at: photoDirectory)
    }

    private func makeViewModel(repository: (any ListingRepository)? = nil) -> CreateListingViewModel {
        CreateListingViewModel(repository: repository ?? self.repository, photoStore: photoStore)
    }

    private func imageData(width: CGFloat = 40, height: CGFloat = 30) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        return image.pngData()!
    }

    private func storedPhotoCount() -> Int {
        (try? FileManager.default.contentsOfDirectory(atPath: photoDirectory.path(percentEncoded: false)).count) ?? 0
    }

    // MARK: - Validation

    @Test func emptyTitleBlocksSave() async throws {
        let viewModel = makeViewModel()
        viewModel.priceInput = "100"

        let saved = await viewModel.save()
        #expect(saved == nil)
        #expect(viewModel.visibleErrors.title != nil)
        #expect(try await repository.fetchListings().isEmpty)
    }

    @Test func errorsAreHiddenUntilFirstSaveAttempt() async {
        let viewModel = makeViewModel()
        #expect(viewModel.fieldErrors.title != nil)
        #expect(viewModel.visibleErrors.isEmpty)

        _ = await viewModel.save()
        #expect(viewModel.visibleErrors.title != nil)
    }

    @Test func sellRequiresPrice() {
        let viewModel = makeViewModel()
        viewModel.title = "Lamp"
        viewModel.mode = .sell
        #expect(viewModel.fieldErrors.price != nil)

        viewModel.priceInput = "250"
        #expect(viewModel.fieldErrors.isEmpty)
    }

    @Test(arguments: ["abc", "12abc", "1.2.3", "--5", "."])
    func malformedPriceIsRejected(input: String) {
        let viewModel = makeViewModel()
        viewModel.title = "Lamp"
        viewModel.priceInput = input
        #expect(viewModel.fieldErrors.price != nil)
    }

    @Test func negativePriceIsRejected() {
        let viewModel = makeViewModel()
        viewModel.title = "Lamp"
        viewModel.priceInput = "-5"
        #expect(viewModel.fieldErrors.price != nil)
    }

    @Test(arguments: [ListingMode.exchange, .donate])
    func priceIsIgnoredForNonSellModes(mode: ListingMode) {
        let viewModel = makeViewModel()
        viewModel.title = "Books"
        viewModel.mode = mode
        viewModel.priceInput = "garbage"

        #expect(viewModel.fieldErrors.isEmpty)
        #expect(viewModel.makeListing(imageFileNames: []).price == nil)
    }

    @Test func blankSellerNameIsRejected() {
        let viewModel = makeViewModel()
        viewModel.title = "Lamp"
        viewModel.priceInput = "10"
        viewModel.sellerName = "   "
        #expect(viewModel.fieldErrors.sellerName != nil)
    }

    @Test func overlongTitleIsRejected() {
        let viewModel = makeViewModel()
        viewModel.mode = .donate
        viewModel.title = String(repeating: "a", count: Listing.maxTitleLength + 1)
        #expect(viewModel.fieldErrors.title != nil)
    }

    // MARK: - Saving

    @Test func savesTrimmedListing() async throws {
        let viewModel = makeViewModel()
        viewModel.title = "  Study table \n"
        viewModel.description = "  Solid wood  "
        viewModel.mode = .sell
        viewModel.priceInput = "1800"
        viewModel.areaName = "   "
        viewModel.sellerContact = " "
        viewModel.category = .furniture
        viewModel.condition = .likeNew

        let saved = try #require(await viewModel.save())
        #expect(saved.title == "Study table")
        #expect(saved.description == "Solid wood")
        #expect(saved.price == 1800)
        #expect(saved.areaName == nil)
        #expect(saved.sellerContact == nil)
        #expect(saved.category == .furniture)
        #expect(saved.condition == .likeNew)
        #expect(!saved.isDemo)

        let stored = try await repository.fetchListings()
        #expect(stored == [saved])
    }

    @Test(arguments: [ListingMode.exchange, .donate])
    func savesNonSellListingWithoutPrice(mode: ListingMode) async throws {
        let viewModel = makeViewModel()
        viewModel.title = "Old books"
        viewModel.mode = mode

        let saved = try #require(await viewModel.save())
        #expect(saved.mode == mode)
        #expect(saved.price == nil)
    }

    @Test func savedListingKeepsPhotosInStore() async throws {
        let viewModel = makeViewModel()
        viewModel.title = "Chair"
        viewModel.mode = .donate
        await viewModel.addPhotos([imageData(), imageData()])
        #expect(viewModel.photos.count == 2)
        #expect(storedPhotoCount() == 0, "photos are only copied on save")

        let saved = try #require(await viewModel.save())
        #expect(saved.imageFileNames.count == 2)
        for name in saved.imageFileNames {
            #expect(photoStore.fileExists(named: name))
        }
    }

    @Test func failedSaveRemovesCopiedPhotos() async {
        let viewModel = makeViewModel(repository: FailingRepository())
        viewModel.title = "Chair"
        viewModel.mode = .donate
        await viewModel.addPhotos([imageData()])

        let saved = await viewModel.save()
        #expect(saved == nil)
        #expect(viewModel.saveError == "Disk full")
        #expect(storedPhotoCount() == 0)
        #expect(!viewModel.isSaving)
    }

    // MARK: - Photos

    @Test func photosCanBeRemoved() async throws {
        let viewModel = makeViewModel()
        await viewModel.addPhotos([imageData(), imageData()])
        let first = try #require(viewModel.photos.first)

        viewModel.removePhoto(id: first.id)
        let remainingIDs = viewModel.photos.map { $0.id }
        #expect(remainingIDs.count == 1)
        #expect(!remainingIDs.contains(first.id))
    }

    @Test func photoCountIsCapped() async {
        let viewModel = makeViewModel()
        let many = (0..<(CreateListingViewModel.maxPhotos + 2)).map { _ in imageData() }
        await viewModel.addPhotos(many)

        #expect(viewModel.photos.count == CreateListingViewModel.maxPhotos)
        #expect(viewModel.remainingPhotoSlots == 0)
        #expect(viewModel.photoMessage != nil)
    }

    @Test func unreadablePhotosAreSkipped() async {
        let viewModel = makeViewModel()
        await viewModel.addPhotos([Data("not an image".utf8), imageData()])

        #expect(viewModel.photos.count == 1)
        #expect(viewModel.photoMessage == "One photo couldn't be read.")
    }

    // MARK: - Unsaved changes

    @Test func pristineFormIsNotDirty() {
        #expect(!makeViewModel().isDirty)
    }

    @Test func editingAnyFieldMakesFormDirty() {
        let edits: [(CreateListingViewModel) -> Void] = [
            { $0.title = "x" },
            { $0.description = "x" },
            { $0.category = .books },
            { $0.mode = .donate },
            { $0.condition = .fair },
            { $0.priceInput = "1" },
            { $0.areaName = "x" },
            { $0.sellerName = "Someone" },
            { $0.sellerContact = "x" },
        ]
        for edit in edits {
            let viewModel = makeViewModel()
            edit(viewModel)
            #expect(viewModel.isDirty)
        }
    }

    @Test func revertingEditsMakesFormCleanAgain() {
        let viewModel = makeViewModel()
        viewModel.title = "x"
        viewModel.title = ""
        #expect(!viewModel.isDirty)
    }

    @Test func addingPhotoMakesFormDirty() async {
        let viewModel = makeViewModel()
        await viewModel.addPhotos([imageData()])
        #expect(viewModel.isDirty)
    }
}
