//
//  PhotoStoreTests.swift
//  neighbourlyTests
//

import Foundation
import Testing
import UIKit
@testable import neighbourly

final class PhotoStoreTests {
    private let directory: URL
    private let store: PhotoStore

    init() {
        directory = URL.temporaryDirectory.appending(path: "PhotoTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        store = PhotoStore(directory: directory)
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    private func makeImageData(width: CGFloat, height: CGFloat) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        return image.pngData()!
    }

    @Test func saveWritesFileWithUniqueName() throws {
        let data = makeImageData(width: 40, height: 30)
        let first = try store.save(imageData: data)
        let second = try store.save(imageData: data)

        #expect(first != second)
        #expect(first.hasSuffix(".jpg"))
        #expect(store.fileExists(named: first))
        #expect(store.image(named: first) != nil)
    }

    @Test func largeImagesAreDownscaled() throws {
        let name = try store.save(imageData: makeImageData(width: 4000, height: 2000))
        let image = try #require(store.image(named: name))
        let longestEdge = max(image.size.width, image.size.height) * image.scale
        #expect(longestEdge <= PhotoStore.maxPixelDimension)
    }

    @Test func nonImageDataIsRejected() {
        #expect(throws: PhotoStore.PhotoStoreError.unreadableImage) {
            try self.store.save(imageData: Data("hello".utf8))
        }
    }

    @Test func deleteRemovesFile() throws {
        let name = try store.save(imageData: makeImageData(width: 10, height: 10))
        store.delete(named: name)
        #expect(!store.fileExists(named: name))
        #expect(store.image(named: name) == nil)
    }

    @Test func removeOrphansKeepsReferencedFiles() throws {
        let kept = try store.save(imageData: makeImageData(width: 10, height: 10))
        let orphan = try store.save(imageData: makeImageData(width: 10, height: 10))

        store.removeOrphans(keeping: [kept])
        #expect(store.fileExists(named: kept))
        #expect(!store.fileExists(named: orphan))
    }

    @Test func fileNamesCannotEscapeDirectory() {
        let url = store.url(for: "../../secret.txt")
        #expect(url.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL)
    }

    @Test func repositoryDeletesPhotosWithListing() async throws {
        let photo = try store.save(imageData: makeImageData(width: 10, height: 10))
        let repository = LocalListingRepository(
            directory: directory.appending(path: "Repository", directoryHint: .isDirectory),
            photoStore: store,
            seedListings: { [] }
        )
        let listing = Listing(
            title: "Chair", category: .furniture, mode: .donate, condition: .good,
            imageFileNames: [photo], sellerName: "Tester"
        )
        try await repository.save(listing)
        try await repository.delete(id: listing.id)

        #expect(!store.fileExists(named: photo))
    }
}
