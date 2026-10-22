//
//  CoreMLClassificationTests.swift
//  neighbourlyTests
//

import Foundation
import Testing
import UIKit
@testable import neighbourly

// MARK: - ImageNet label mapping

struct ImageNetMappingTests {
    @Test(arguments: [
        ("rocking chair, rocker", ListingCategory.furniture),
        ("folding chair", .furniture),
        ("studio couch, day bed", .furniture),
        ("dining table, board", .furniture),
        ("four-poster", .furniture),
        ("book jacket, dust cover, dust jacket, dust wrapper", .books),
        ("comic book", .books),
        ("binder, ring-binder", .books),
        ("laptop, laptop computer", .electronics),
        ("notebook, notebook computer", .electronics),
        ("desktop computer", .electronics),
        ("cellular telephone, cellular phone, cellphone, cell, mobile phone", .electronics),
        ("mouse, computer mouse", .electronics),
        ("running shoe", .clothing),
        ("sweatshirt", .clothing),
        ("jean, blue jean, denim", .clothing),
        ("backpack, back pack, knapsack, packsack, rucksack, haversack", .clothing),
        ("table lamp", .home),
        ("coffee mug", .home),
        ("teapot", .home),
        ("pool table, billiard table, snooker table", .sports),
        ("soccer ball", .sports),
        ("dumbbell", .sports),
        ("teddy, teddy bear", .toys),
        ("jigsaw puzzle", .toys),
    ])
    func imageNetLabelMapsToCategory(label: String, expected: ListingCategory) {
        #expect(ListingCategoryMapper.category(forLabel: label) == expected)
    }

    @Test(arguments: ["volcano", "goldfish, Carassius auratus", "cheeseburger", "alp"])
    func unrelatedLabelsDoNotMap(label: String) {
        #expect(ListingCategoryMapper.category(forLabel: label) == nil)
    }

    @Test func totalConfidenceDecidesTheCategory() {
        // Two weaker furniture labels together outweigh one stronger electronics label.
        let labels = [
            ClassifiedLabel(identifier: "laptop, laptop computer", confidence: 0.4),
            ClassifiedLabel(identifier: "rocking chair, rocker", confidence: 0.3),
            ClassifiedLabel(identifier: "folding chair", confidence: 0.2),
        ]
        #expect(ListingCategoryMapper.category(for: labels) == .furniture)
    }

    @Test func unmappedLabelsNeverWinOverMappedOnes() {
        let labels = [
            ClassifiedLabel(identifier: "volcano", confidence: 0.9),
            ClassifiedLabel(identifier: "book jacket", confidence: 0.05),
        ]
        #expect(ListingCategoryMapper.category(for: labels) == .books)
    }

    @Test func allUnmappedFallsBackToOther() {
        let labels = [ClassifiedLabel(identifier: "volcano", confidence: 0.9)]
        #expect(ListingCategoryMapper.category(for: labels) == .other)
    }

    @Test func displayNameUsesTheFirstSynonym() {
        #expect(ListingCategoryMapper.displayName(for: "rocking chair, rocker") == "Rocking chair")
        #expect(ListingCategoryMapper.displayName(for: "coffee_table") == "Coffee table")
    }

    @Test func suggestionsFromModelLabelsShowReadableNames() {
        let labels = [
            ClassifiedLabel(identifier: "rocking chair, rocker", confidence: 0.82),
            ClassifiedLabel(identifier: "volcano", confidence: 0.06),
        ]
        let result = SuggestionBuilder.make(labels: labels, recognizedText: [])
        #expect(result.category == .furniture)
        #expect(result.labels == ["Rocking chair"])
        #expect(result.allLabels == ["Rocking chair 82%", "Volcano 6%"])
    }
}

// MARK: - Classification helpers

struct ClassificationImageTests {
    private func pngData(width: CGFloat, height: CGFloat) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        return image.pngData()!
    }

    @Test func regionsIncludeFullImageAndCentreCrop() throws {
        let regions = try ClassificationImage.regions(from: pngData(width: 200, height: 100), includeCorners: false)
        #expect(regions.count == 2)
        // ImageIO may rescale the thumbnail, so compare the crop with the full region.
        let full = regions[0]
        #expect(regions[1].width == Int((Double(full.width) * 0.6).rounded()))
        #expect(regions[1].height == Int((Double(full.height) * 0.6).rounded()))
        #expect(full.width == 2 * full.height)
    }

    @Test func cornersAddFourMoreRegions() throws {
        let regions = try ClassificationImage.regions(from: pngData(width: 200, height: 100), includeCorners: true)
        #expect(regions.count == 6)
    }

    @Test func largeImagesAreDownscaled() throws {
        let regions = try ClassificationImage.regions(from: pngData(width: 4000, height: 2000), includeCorners: false)
        let longest = max(regions[0].width, regions[0].height)
        #expect(longest <= ClassificationImage.maxPixelSize)
    }

    @Test func unreadableDataThrows() {
        #expect(throws: VisionAssistError.unreadableImage) {
            try ClassificationImage.regions(from: Data("nope".utf8), includeCorners: false)
        }
    }

    @Test func mergeKeepsBestConfidencePerLabelSortedDescending() {
        let merged = ClassificationImage.merge([
            [ClassifiedLabel(identifier: "chair", confidence: 0.2), ClassifiedLabel(identifier: "lamp", confidence: 0.5)],
            [ClassifiedLabel(identifier: "chair", confidence: 0.7)],
        ])
        #expect(merged.map { $0.identifier } == ["chair", "lamp"])
        #expect(merged.first?.confidence == 0.7)
    }
}

// MARK: - Service behaviour with stand-in classifiers

private struct StubClassifier: ImageClassifying {
    var result: Result<[ClassifiedLabel], VisionAssistError>
    func classify(imageData: Data) async throws -> [ClassifiedLabel] { try result.get() }
}

struct VisionAssistServiceTests {
    private func pngData() -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 60, height: 40), format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 60, height: 40))
        }
        return image.pngData()!
    }

    private let chair = [ClassifiedLabel(identifier: "rocking chair, rocker", confidence: 0.9)]
    private let laptop = [ClassifiedLabel(identifier: "laptop, laptop computer", confidence: 0.9)]

    private func analyze(primary: Result<[ClassifiedLabel], VisionAssistError>,
                         fallback: Result<[ClassifiedLabel], VisionAssistError>?) async throws -> ImageSuggestions {
        let service = VisionAssistService(
            primary: StubClassifier(result: primary),
            fallback: fallback.map { StubClassifier(result: $0) }
        )
        return try await service.analyze(imageData: pngData())
    }

    @Test func primaryClassifierResultIsUsed() async throws {
        let result = try await analyze(primary: .success(chair), fallback: .success(laptop))
        #expect(result.category == .furniture)
        #expect(!result.classificationUnavailable)
    }

    @Test func fallbackIsUsedWhenPrimaryFails() async throws {
        let result = try await analyze(primary: .failure(.modelUnavailable), fallback: .success(laptop))
        #expect(result.category == .electronics)
        #expect(!result.classificationUnavailable)
    }

    @Test func classificationIsReportedUnavailableWhenNothingWorks() async throws {
        let result = try await analyze(primary: .failure(.modelUnavailable), fallback: nil)
        #expect(result.classificationUnavailable)
        #expect(result.category == .other)
    }

    @Test func unreadableImageThrows() async {
        let service = VisionAssistService(primary: StubClassifier(result: .success([])), fallback: nil)
        await #expect(throws: VisionAssistError.unreadableImage) {
            try await service.analyze(imageData: Data("nope".utf8))
        }
    }
}

// MARK: - The bundled model

struct CoreMLClassificationServiceTests {
    @Test func missingModelIsReportedAsUnavailable() async {
        let service = CoreMLClassificationService(modelName: "ThisModelDoesNotExist")
        #expect(!service.isModelAvailable)
        await #expect(throws: VisionAssistError.modelUnavailable) {
            try await service.classify(imageData: Data())
        }
    }

    /// Runs only once MobileNetV2 has been added to the app; otherwise it passes trivially.
    @Test func bundledModelReturnsLabels() async throws {
        let service = CoreMLClassificationService()
        guard service.isModelAvailable else { return }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let data = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 300), format: format).image { context in
            UIColor.brown.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 300, height: 300))
        }.pngData()!

        let labels = try await service.classify(imageData: data)
        let confidences = labels.map { $0.confidence }
        let inRange = confidences.allSatisfy { $0 >= 0 && $0 <= 1 }
        #expect(!labels.isEmpty)
        #expect(inRange)
    }
}
