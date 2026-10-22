//
//  EditListingTests.swift
//  neighbourlyTests
//

import Foundation
import Testing
import UIKit
@testable import neighbourly

/// Editing an existing listing through the form view model, against the real
/// file-backed repository and photo store.
@MainActor
final class EditListingTests {
    private let directory: URL
    private let photoStore: PhotoStore
    private let repository: LocalListingRepository

    init() {
        directory = URL.temporaryDirectory.appending(path: "EditTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        photoStore = PhotoStore(directory: directory.appending(path: "Photos", directoryHint: .isDirectory))
        repository = LocalListingRepository(
            directory: directory.appending(path: "Data", directoryHint: .isDirectory),
            photoStore: photoStore,
            seedListings: { [] }
        )
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    private func imageData() -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 30), format: format).image { context in
            UIColor.systemPurple.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 30))
        }
        return image.pngData()!
    }

    /// Saves a listing with `photoCount` real photos and returns it.
    private func makeSavedListing(photoCount: Int = 2) async throws -> Listing {
        let names = try (0..<photoCount).map { _ in try photoStore.save(imageData: imageData()) }
        let listing = Listing(
            title: "Study table", description: "Solid wood", category: .furniture, mode: .sell,
            price: 1800, condition: .likeNew, imageFileNames: names,
            latitude: 19.08, longitude: 72.9, areaName: "Vidyavihar",
            sellerName: "Asha", sellerContact: "asha@example.com",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        try await repository.save(listing)
        return listing
    }

    private func makeViewModel(editing listing: Listing) -> CreateListingViewModel {
        CreateListingViewModel(
            repository: repository, photoStore: photoStore,
            visionAssist: VisionAssistService(), editing: listing
        )
    }

    // MARK: - Prefill and dirty tracking

    @Test func formIsPrefilledFromTheListing() async throws {
        let listing = try await makeSavedListing()
        let viewModel = makeViewModel(editing: listing)

        #expect(viewModel.isEditing)
        #expect(viewModel.title == "Study table")
        #expect(viewModel.description == "Solid wood")
        #expect(viewModel.category == .furniture)
        #expect(viewModel.mode == .sell)
        #expect(viewModel.condition == .likeNew)
        #expect(viewModel.priceInput == "1800")
        #expect(viewModel.areaName == "Vidyavihar")
        #expect(viewModel.sellerName == "Asha")
        #expect(viewModel.sellerContact == "asha@example.com")
    }

    @Test func existingPhotosLoadAndFormStartsClean() async throws {
        let listing = try await makeSavedListing(photoCount: 2)
        let viewModel = makeViewModel(editing: listing)
        #expect(!viewModel.isDirty)

        await viewModel.loadExistingPhotos()
        #expect(viewModel.photos.count == 2)
        #expect(!viewModel.isDirty)
        #expect(viewModel.photoMessage == nil)
    }

    @Test func loadingExistingPhotosTwiceDoesNotDuplicate() async throws {
        let viewModel = makeViewModel(editing: try await makeSavedListing(photoCount: 2))
        await viewModel.loadExistingPhotos()
        await viewModel.loadExistingPhotos()
        #expect(viewModel.photos.count == 2)
    }

    @Test func editingMakesFormDirty() async throws {
        let viewModel = makeViewModel(editing: try await makeSavedListing())
        await viewModel.loadExistingPhotos()
        viewModel.title = "Bigger study table"
        #expect(viewModel.isDirty)
    }

    @Test func removingAPhotoMakesFormDirty() async throws {
        let viewModel = makeViewModel(editing: try await makeSavedListing())
        await viewModel.loadExistingPhotos()
        let first = try #require(viewModel.photos.first)
        viewModel.removePhoto(id: first.id)
        #expect(viewModel.isDirty)
    }

    // MARK: - Saving edits

    @Test func savingUpdatesTheSameListing() async throws {
        let original = try await makeSavedListing()
        let viewModel = makeViewModel(editing: original)
        await viewModel.loadExistingPhotos()
        viewModel.title = "Bigger study table"
        viewModel.priceInput = "2000"

        let saved = try #require(await viewModel.save())
        #expect(saved.id == original.id)
        #expect(saved.createdAt == original.createdAt)
        #expect(saved.latitude == 19.08)
        #expect(saved.longitude == 72.9)
        #expect(saved.title == "Bigger study table")
        #expect(saved.price == 2000)
        #expect(saved.imageFileNames == original.imageFileNames)

        let stored = try await repository.fetchListings()
        #expect(stored == [saved])
    }

    @Test func switchingToDonateClearsThePrice() async throws {
        let viewModel = makeViewModel(editing: try await makeSavedListing())
        viewModel.mode = .donate

        let saved = try #require(await viewModel.save())
        #expect(saved.mode == .donate)
        #expect(saved.price == nil)
    }

    @Test func removedPhotoIsDeletedFromDiskAfterSave() async throws {
        let original = try await makeSavedListing(photoCount: 2)
        let viewModel = makeViewModel(editing: original)
        await viewModel.loadExistingPhotos()
        let first = try #require(viewModel.photos.first)
        viewModel.removePhoto(id: first.id)

        let saved = try #require(await viewModel.save())
        #expect(saved.imageFileNames == [original.imageFileNames[1]])
        #expect(!photoStore.fileExists(named: original.imageFileNames[0]))
        #expect(photoStore.fileExists(named: original.imageFileNames[1]))
    }

    @Test func newPhotosAreAppendedAfterExistingOnes() async throws {
        let original = try await makeSavedListing(photoCount: 1)
        let viewModel = makeViewModel(editing: original)
        await viewModel.loadExistingPhotos()
        await viewModel.addPhotos([imageData()])

        let saved = try #require(await viewModel.save())
        #expect(saved.imageFileNames.count == 2)
        #expect(saved.imageFileNames.first == original.imageFileNames[0])
        let added = try #require(saved.imageFileNames.last)
        #expect(photoStore.fileExists(named: added))
    }

    @Test func cancellingLeavesTheListingUntouched() async throws {
        let original = try await makeSavedListing()
        let viewModel = makeViewModel(editing: original)
        await viewModel.loadExistingPhotos()
        viewModel.title = "Changed but never saved"

        let stored = try await repository.fetchListings()
        #expect(stored == [original])
    }

    // MARK: - Missing photo files

    @Test func missingPhotoFilesAreReportedAndDroppedOnSave() async throws {
        var original = try await makeSavedListing(photoCount: 1)
        original.imageFileNames.append("deleted-long-ago.jpg")
        try await repository.save(original)

        let viewModel = makeViewModel(editing: original)
        await viewModel.loadExistingPhotos()
        #expect(viewModel.photos.count == 1)
        #expect(viewModel.photoMessage != nil)

        let saved = try #require(await viewModel.save())
        #expect(saved.imageFileNames == [original.imageFileNames[0]])
    }
}
