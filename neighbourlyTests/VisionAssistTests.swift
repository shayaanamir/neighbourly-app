//
//  VisionAssistTests.swift
//  neighbourlyTests
//

import Foundation
import Testing
import UIKit
@testable import neighbourly

// MARK: - Category mapping and cleaning (pure logic)

struct ListingCategoryMapperTests {
    private func label(_ identifier: String, _ confidence: Float = 0.9) -> ClassifiedLabel {
        ClassifiedLabel(identifier: identifier, confidence: confidence)
    }

    @Test(arguments: [
        ("book", ListingCategory.books),
        ("textbook", .books),
        ("laptop", .electronics),
        ("computer_keyboard", .electronics),
        ("chair", .furniture),
        ("coffee_table", .furniture),
        ("jacket", .clothing),
        ("kettle", .home),
        ("football", .sports),
        ("teddy_bear", .toys),
    ])
    func knownLabelsMapToCategory(identifier: String, expected: ListingCategory) {
        #expect(ListingCategoryMapper.category(for: [label(identifier)]) == expected)
    }

    @Test func unknownLabelsDefaultToOther() {
        #expect(ListingCategoryMapper.category(for: [label("sky"), label("structure")]) == .other)
    }

    @Test func noLabelsDefaultToOther() {
        #expect(ListingCategoryMapper.category(for: []) == .other)
    }

    @Test func mostConfidentMappedLabelWins() {
        let labels = [label("chair", 0.4), label("laptop", 0.8), label("sky", 0.95)]
        #expect(ListingCategoryMapper.category(for: labels) == .electronics)
    }

    @Test func matchingIsCaseInsensitive() {
        #expect(ListingCategoryMapper.category(for: [label("Book")]) == .books)
    }

    @Test func wordsMustMatchWholeTokens() {
        // "bookmarks" contains "book" but is a different word, so it must not match.
        #expect(ListingCategoryMapper.category(for: [label("bookmarks_tab")]) == .other)
    }

    @Test func displayNameIsReadable() {
        #expect(ListingCategoryMapper.displayName(for: "coffee_table") == "Coffee table")
    }
}

struct SuggestionBuilderTests {
    @Test func lowConfidenceLabelsAreDropped() {
        let result = SuggestionBuilder.make(
            labels: [ClassifiedLabel(identifier: "book", confidence: 0.05)],
            recognizedText: []
        )
        #expect(result.labels.isEmpty)
        #expect(result.category == .other)
        #expect(result.isEmpty)
    }

    @Test func labelsAreSortedAndCapped() {
        let labels = (0..<10).map { ClassifiedLabel(identifier: "label_\($0)", confidence: 0.2 + Float($0) / 20) }
        let result = SuggestionBuilder.make(labels: labels, recognizedText: [])
        #expect(result.labels.count == SuggestionBuilder.maxLabels)
        #expect(result.labels.first == "Label 9")
    }

    @Test func textLinesAreTrimmedFilteredAndDeduplicated() {
        let cleaned = SuggestionBuilder.cleanTextLines([
            "  Samsung Galaxy  ", "samsung galaxy", "!!", "ab", "", "Model SM-A515F", "---",
        ])
        #expect(cleaned == ["Samsung Galaxy", "Model SM-A515F"])
    }

    @Test func textLinesAreCappedInCountAndLength() {
        let many = (0..<20).map { "Line number \($0)" }
        #expect(SuggestionBuilder.cleanTextLines(many).count == SuggestionBuilder.maxTextLines)

        let long = String(repeating: "a", count: 500)
        #expect(SuggestionBuilder.cleanTextLines([long]).first?.count == SuggestionBuilder.maxTextLineLength)
    }

    @Test func printedBookWordsSuggestBooksWhenLabelsDoNot() {
        let result = SuggestionBuilder.make(labels: [], recognizedText: ["A NOVEL", "Fyodor Dostoevsky"])
        #expect(result.category == .books)
    }

    @Test func imageLabelsTakePrecedenceOverPrintedWords() {
        let labels = [ClassifiedLabel(identifier: "laptop", confidence: 0.8)]
        let result = SuggestionBuilder.make(labels: labels, recognizedText: ["A NOVEL"])
        #expect(result.category == .electronics)
    }

    @Test func failedClassificationIsFlagged() {
        let result = SuggestionBuilder.make(labels: [], recognizedText: ["Hello there"], classificationAvailable: false)
        #expect(result.classificationUnavailable)
        #expect(!SuggestionBuilder.make(labels: [], recognizedText: ["Hello there"]).classificationUnavailable)
    }

    @Test func textAloneIsAResult() {
        let result = SuggestionBuilder.make(labels: [], recognizedText: ["Harry Potter"])
        #expect(!result.isEmpty)
        #expect(result.category == .other)
    }
}

// MARK: - View model integration

private struct StubVision: VisionAssisting {
    var outcome: Result<ImageSuggestions, VisionAssistError>
    var delay: Duration = .zero

    func analyze(imageData: Data) async throws -> ImageSuggestions {
        if delay > .zero { try await Task.sleep(for: delay) }
        return try outcome.get()
    }
}

@MainActor
final class CreateListingSuggestionTests {
    private let photoStore = PhotoStore(
        directory: URL.temporaryDirectory.appending(path: "AssistTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    )

    private let sample = ImageSuggestions(
        category: .books,
        labels: ["Book", "Publication"],
        textLines: ["Harry Potter", "J. K. Rowling", "Price Rs 450", "contact 98200 12345"]
    )

    deinit {
        try? FileManager.default.removeItem(at: photoStore.directory)
    }

    private func imageData() -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 30), format: format).image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 30))
        }
        return image.pngData()!
    }

    private func makeViewModel(
        _ outcome: Result<ImageSuggestions, VisionAssistError>,
        delay: Duration = .zero,
        withPhoto: Bool = true
    ) async -> CreateListingViewModel {
        let viewModel = CreateListingViewModel(
            repository: InMemoryListingRepository(listings: []),
            photoStore: photoStore,
            visionAssist: StubVision(outcome: outcome, delay: delay)
        )
        if withPhoto { await viewModel.addPhotos([imageData()]) }
        return viewModel
    }

    @Test func suggestionsAppearAfterAnalysis() async {
        let viewModel = await makeViewModel(.success(sample))
        await viewModel.suggestDetails()
        #expect(viewModel.assistState == .result(sample))
    }

    @Test func analysisNeverChangesTheForm() async {
        let viewModel = await makeViewModel(.success(sample))
        await viewModel.suggestDetails()

        #expect(viewModel.title == "")
        #expect(viewModel.description == "")
        #expect(viewModel.priceInput == "")
        #expect(viewModel.sellerContact == "")
        #expect(viewModel.category == .other)
    }

    @Test func noPhotoMeansNoAnalysis() async {
        let viewModel = await makeViewModel(.success(sample), withPhoto: false)
        await viewModel.suggestDetails()
        #expect(viewModel.assistState == .idle)
    }

    @Test func emptyResultShowsNoResultState() async {
        let empty = ImageSuggestions(category: .other, labels: [], textLines: [])
        let viewModel = await makeViewModel(.success(empty))
        await viewModel.suggestDetails()
        #expect(viewModel.assistState == .noResult)
    }

    @Test func failureShowsMessageAndFormStillWorks() async {
        let viewModel = await makeViewModel(.failure(.unavailable))
        await viewModel.suggestDetails()
        #expect(viewModel.assistState == .failed(VisionAssistError.unavailable.localizedDescription))

        viewModel.title = "Still editable"
        #expect(viewModel.title == "Still editable")
    }

    @Test func userCanApplyCategory() async {
        let viewModel = await makeViewModel(.success(sample))
        await viewModel.suggestDetails()
        viewModel.applySuggestedCategory(sample.category)
        #expect(viewModel.category == .books)
    }

    @Test func useAsTitleReplacesTitleAndRespectsLengthLimit() async {
        let viewModel = await makeViewModel(.success(sample))
        viewModel.useAsTitle("  Harry Potter ")
        #expect(viewModel.title == "Harry Potter")

        viewModel.useAsTitle(String(repeating: "x", count: 200))
        #expect(viewModel.title.count == Listing.maxTitleLength)
    }

    @Test func appendToDescriptionKeepsExistingText() async {
        let viewModel = await makeViewModel(.success(sample))
        viewModel.appendToDescription("J. K. Rowling")
        #expect(viewModel.description == "J. K. Rowling")

        viewModel.appendToDescription("Hardcover")
        #expect(viewModel.description == "J. K. Rowling\nHardcover")
    }

    @Test func recognisedTextNeverBecomesPriceOrContactOnItsOwn() async {
        let viewModel = await makeViewModel(.success(sample))
        await viewModel.suggestDetails()
        viewModel.useAsTitle("Price Rs 450")
        viewModel.appendToDescription("contact 98200 12345")

        #expect(viewModel.priceInput == "")
        #expect(viewModel.sellerContact == "")
    }

    @Test func dismissReturnsToIdle() async {
        let viewModel = await makeViewModel(.success(sample))
        await viewModel.suggestDetails()
        viewModel.dismissSuggestions()
        #expect(viewModel.assistState == .idle)
    }

    @Test func removingTheAnalysedPhotoDiscardsSuggestions() async throws {
        let viewModel = await makeViewModel(.success(sample))
        await viewModel.suggestDetails()
        let photo = try #require(viewModel.photos.first)

        viewModel.removePhoto(id: photo.id)
        #expect(viewModel.assistState == .idle)
    }

    @Test func staleResultIsIgnoredIfPhotoIsRemovedMidAnalysis() async throws {
        let viewModel = await makeViewModel(.success(sample), delay: .milliseconds(150))
        let photo = try #require(viewModel.photos.first)

        let task = Task { @MainActor in await viewModel.suggestDetails() }
        var attempts = 0
        while viewModel.assistState != .analyzing && attempts < 200 {
            await Task.yield()
            attempts += 1
        }
        #expect(viewModel.assistState == .analyzing)

        viewModel.removePhoto(id: photo.id)
        await task.value
        #expect(viewModel.assistState == .idle)
    }

    @Test func suggestionsDoNotMakeFormDirty() async {
        let viewModel = await makeViewModel(.success(sample), withPhoto: false)
        await viewModel.suggestDetails()
        #expect(!viewModel.isDirty)
    }
}
