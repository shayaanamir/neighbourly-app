//
//  ListingAutofillTests.swift
//  neighbourlyTests
//

import Foundation
import Testing
import UIKit
@testable import neighbourly

// MARK: - Wording logic

struct ListingAutofillWritingTests {
    private func suggestions(
        category: ListingCategory = .furniture,
        labels: [String] = [],
        text: [String] = []
    ) -> ImageSuggestions {
        ImageSuggestions(category: category, labels: labels, textLines: text)
    }

    private func draft(
        _ suggestions: ImageSuggestions,
        mode: ListingMode = .donate,
        condition: ItemCondition = .good
    ) -> AutofillDraft {
        ListingAutofill.draft(from: suggestions, mode: mode, condition: condition)
    }

    // MARK: Title

    @Test func theTopLabelBecomesTheTitle() {
        let result = draft(suggestions(labels: ["Rocking chair", "Chair"]))
        #expect(result.title == "Rocking chair")
        #expect(result.category == .furniture)
    }

    @Test(arguments: [
        ("Book jacket", "Book"),
        ("Notebook", "Laptop"),
        ("Cellular telephone", "Mobile phone"),
        ("Studio couch", "Sofa"),
        ("Jean", "Jeans"),
        ("Chair", "Chair"),
    ])
    func researchLabelsBecomeEverydayWords(label: String, expected: String) {
        #expect(ListingAutofill.friendlyName(for: label) == expected)
        #expect(draft(suggestions(labels: [label])).title == expected)
    }

    @Test func printedBrandGoesInFrontOfTheItemType() {
        let result = draft(suggestions(category: .clothing, labels: ["Backpack"], text: ["ZARA"]))
        #expect(result.title == "Zara backpack")
    }

    @Test func printedTextThatAlreadyNamesTheItemStandsAlone() {
        let result = draft(suggestions(category: .electronics, labels: ["Laptop"], text: ["Dell Laptop"]))
        #expect(result.title == "Dell Laptop")
    }

    @Test func printedTextAloneCanBeTheTitle() {
        let result = draft(suggestions(category: .books, text: ["Crime and Punishment"]))
        #expect(result.title == "Crime and Punishment")
    }

    @Test func shoutingTextIsTidied() {
        let result = draft(suggestions(category: .books, text: ["CRIME.,", "FYODOR-"]))
        #expect(result.title == "Crime")
    }

    @Test func tooLongACombinationFallsBackToTheLabel() {
        let longName = String(repeating: "a", count: 39)
        let label = String(repeating: "b", count: 50)
        let result = draft(suggestions(labels: [label], text: [longName]))
        #expect(result.title == label)
    }

    @Test func titlesRespectTheLengthLimit() {
        let result = draft(suggestions(labels: [String(repeating: "x", count: 200)]))
        #expect((result.title?.count ?? 0) <= Listing.maxTitleLength)
    }

    @Test func nothingRecognisedMeansNothingToFill() {
        let result = draft(suggestions(category: .other))
        #expect(result.isEmpty)
        #expect(result.title == nil)
        #expect(result.description == nil)
        #expect(result.category == nil)
    }

    @Test func otherIsNotSuggestedAsACategory() {
        #expect(draft(suggestions(category: .other, labels: ["Thing"])).category == nil)
    }

    // MARK: Text that must not be copied

    @Test(arguments: [
        "Call 98200 12345", "9820012345", "seller@example.com", "www.shop.com", "https://example.com",
        "Rs 450", "MRP 1,999", "₹ 500", "$20", "20% off", "WhatsApp us", "Price drop",
    ])
    func contactDetailsAndPricesAreNeverUsed(line: String) {
        #expect(ListingAutofill.usableTextLines([line]).isEmpty)

        let result = draft(suggestions(category: .books, labels: ["Book"], text: [line]))
        #expect(result.title == "Book")
        #expect(!(result.description ?? "").contains(line))
    }

    @Test func nonsenseLinesAreSkipped() {
        #expect(ListingAutofill.usableTextLines(["12", "!!", "", "a b", "1234 5678 99"]).isEmpty)
        #expect(ListingAutofill.usableTextLines([String(repeating: "word ", count: 20)]).isEmpty, "far too long to be a name")
    }

    @Test func wordsThatMerelyContainShortCodesAreNotMistakenForPrices() {
        // "Mirrors" contains "rs" but is a perfectly good name.
        #expect(ListingAutofill.usableTextLines(["Wall Mirrors"]) == ["Wall Mirrors"])
    }

    @Test func duplicateLinesAreMergedIgnoringCase() {
        #expect(ListingAutofill.usableTextLines(["Samsung", "SAMSUNG", "samsung"]) == ["Samsung"])
    }

    // MARK: Description

    @Test func descriptionUsesTheChosenConditionAndMode() {
        let free = draft(suggestions(labels: ["Rocking chair"]), mode: .donate, condition: .good)
        #expect(free.description == "Rocking chair in good condition. Free to a good home.")

        let swap = draft(suggestions(labels: ["Rocking chair"]), mode: .exchange, condition: .likeNew)
        #expect(swap.description == "Rocking chair in like-new condition. Happy to exchange it.")

        let sale = draft(suggestions(labels: ["Rocking chair"]), mode: .sell, condition: .new)
        #expect(sale.description == "Rocking chair in brand-new condition.")

        let worn = draft(suggestions(labels: ["Rocking chair"]), mode: .sell, condition: .fair)
        #expect(worn.description == "Rocking chair in fair condition.")
    }

    @Test func otherPrintedLinesAreQuotedAsText() {
        let result = draft(
            suggestions(category: .electronics, labels: ["Laptop"], text: ["Dell", "Inspiron 15", "Core i5"]),
            mode: .sell
        )
        // "Dell" went into the title, so the rest are quoted.
        #expect(result.title == "Dell laptop")
        #expect(result.description == "Dell laptop in good condition. Text on the item: “Inspiron 15”, “Core i5”.")
    }

    @Test func atMostThreeLinesAreQuoted() {
        let lines = ["One alpha", "Two beta", "Three gamma", "Four delta", "Five epsilon", "Six zeta"]
        let result = draft(suggestions(category: .other, text: lines), mode: .sell)
        let description = result.description ?? ""
        #expect(description.contains("“Two beta”"))
        #expect(description.contains("“Four delta”"))
        #expect(!description.contains("Five epsilon"), "only three quoted lines")
    }

    @Test func descriptionIsWithinTheLimit() {
        let lines = (0..<10).map { "Line \($0) alpha beta gamma" }
        let result = draft(suggestions(text: lines))
        #expect((result.description?.count ?? 0) <= Listing.maxDescriptionLength)
    }

    @Test func aBareCategoryWithNoLabelStillGetsASentence() {
        let result = draft(suggestions(category: .furniture))
        #expect(result.title == nil)
        #expect(result.description == "Furniture in good condition. Free to a good home.")
    }

    @Test func neverMentionsPriceOrContactDetails() {
        let result = draft(suggestions(labels: ["Laptop"], text: ["Dell"]), mode: .sell)
        let description = (result.description ?? "").lowercased()
        #expect(!description.contains("₹"))
        #expect(!description.contains("price"))
        #expect(!description.contains("@"))
    }
}

// MARK: - Form behaviour

private struct FixedVision: VisionAssisting {
    var outcome: Result<ImageSuggestions, VisionAssistError>
    func analyze(imageData: Data) async throws -> ImageSuggestions { try outcome.get() }
}

@MainActor
final class AutofillFormTests {
    private let directory = URL.temporaryDirectory.appending(path: "AutofillForm-\(UUID().uuidString)", directoryHint: .isDirectory)
    private lazy var photoStore = PhotoStore(directory: directory)

    private let chair = ImageSuggestions(category: .furniture, labels: ["Rocking chair"], textLines: ["Zara"])

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    private func imageData() -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 30, height: 30), format: format).image { context in
            UIColor.brown.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 30, height: 30))
        }.pngData()!
    }

    private func makeViewModel(
        _ outcome: Result<ImageSuggestions, VisionAssistError>,
        withPhoto: Bool = true
    ) async -> CreateListingViewModel {
        let viewModel = CreateListingViewModel(
            repository: InMemoryListingRepository(listings: []), photoStore: photoStore,
            visionAssist: FixedVision(outcome: outcome), sellerID: "uid-1"
        )
        if withPhoto { await viewModel.addPhotos([imageData()]) }
        return viewModel
    }

    @Test func oneTapAnalysesAndFillsEmptyFields() async {
        let viewModel = await makeViewModel(.success(chair))
        viewModel.mode = .donate
        await viewModel.autofillFromPhoto()

        #expect(viewModel.title == "Zara rocking chair")
        #expect(viewModel.description == "Zara rocking chair in good condition. Free to a good home.")
        #expect(viewModel.category == .furniture)
        #expect(viewModel.autofillNoteVisible)
        #expect(viewModel.autofillMessage?.hasPrefix("Filled in: title, description, category") == true)
    }

    @Test func autofillNeverTouchesPriceContactOrLocation() async {
        let viewModel = await makeViewModel(.success(chair))
        await viewModel.autofillFromPhoto()

        #expect(viewModel.priceInput.isEmpty)
        #expect(viewModel.sellerContact.isEmpty)
        #expect(!viewModel.hasLocation)
    }

    @Test func typedTextIsNeverOverwritten() async {
        let viewModel = await makeViewModel(.success(chair))
        viewModel.title = "My lovely chair"
        viewModel.description = "Bought last year."
        viewModel.category = .home // already chosen, so Autofill leaves it alone too
        await viewModel.autofillFromPhoto()

        #expect(viewModel.title == "My lovely chair")
        #expect(viewModel.description == "Bought last year.")
        #expect(viewModel.autofillSkippedExisting)
        #expect(viewModel.autofillMessage == "Your title and description already have text, so nothing was changed.")
        #expect(!viewModel.autofillNoteVisible)
    }

    @Test func onlyTheEmptyFieldIsFilled() async {
        let viewModel = await makeViewModel(.success(chair))
        viewModel.title = "My lovely chair"
        await viewModel.autofillFromPhoto()

        #expect(viewModel.title == "My lovely chair")
        #expect(viewModel.description.contains("Zara rocking chair"))
        #expect(viewModel.autofillSkippedExisting)
    }

    @Test func replacingIsAnExplicitChoice() async {
        let viewModel = await makeViewModel(.success(chair))
        viewModel.title = "My lovely chair"
        viewModel.description = "Bought last year."
        await viewModel.autofillFromPhoto()

        viewModel.autofill(replaceExisting: true)
        #expect(viewModel.title == "Zara rocking chair")
        #expect(viewModel.description.hasPrefix("Zara rocking chair in good condition"))
    }

    @Test func aCategoryTheyChoseIsKept() async {
        let viewModel = await makeViewModel(.success(chair))
        viewModel.category = .home
        await viewModel.autofillFromPhoto()
        #expect(viewModel.category == .home)
    }

    @Test func editingAutofilledTextMakesItTheirs() async {
        let viewModel = await makeViewModel(.success(chair))
        await viewModel.autofillFromPhoto()
        #expect(viewModel.autofillNoteVisible)

        viewModel.title = "Zara rocking chair, solid wood"
        #expect(viewModel.autofillNoteVisible, "the description is still the autofilled text")
        viewModel.description = "Solid wood, very comfy."
        #expect(!viewModel.autofillNoteVisible)
    }

    @Test func autofilledFormCanBeSaved() async throws {
        let viewModel = await makeViewModel(.success(chair))
        viewModel.mode = .donate
        await viewModel.autofillFromPhoto()

        let saved = try #require(await viewModel.save())
        #expect(saved.title == "Zara rocking chair")
        #expect(saved.category == .furniture)
        #expect(saved.price == nil)
    }

    @Test func withoutAPhotoNothingHappens() async {
        let viewModel = await makeViewModel(.success(chair), withPhoto: false)
        await viewModel.autofillFromPhoto()
        #expect(viewModel.title.isEmpty)
        #expect(viewModel.autofillMessage == nil)
    }

    @Test func aFailedAnalysisSaysSoAndChangesNothing() async {
        let viewModel = await makeViewModel(.failure(.unavailable))
        await viewModel.autofillFromPhoto()

        #expect(viewModel.title.isEmpty)
        #expect(viewModel.description.isEmpty)
        #expect(viewModel.autofillMessage == "The photo couldn't be analysed, so nothing was filled in.")
    }

    @Test func anEmptyAnalysisSaysNothingWasFound() async {
        let empty = ImageSuggestions(category: .other, labels: [], textLines: [])
        let viewModel = await makeViewModel(.success(empty))
        await viewModel.autofillFromPhoto()

        #expect(viewModel.title.isEmpty)
        #expect(viewModel.autofillMessage?.contains("Nothing in the photo") == true)
    }

    @Test func autofillWorksFromAnExistingAnalysis() async {
        let viewModel = await makeViewModel(.success(chair))
        await viewModel.suggestDetails() // the "review first" path
        #expect(viewModel.title.isEmpty, "suggesting alone changes nothing")

        viewModel.autofill()
        #expect(viewModel.title == "Zara rocking chair")
    }

    @Test func dismissingSuggestionsClearsTheAutofillMessage() async {
        let viewModel = await makeViewModel(.success(chair))
        await viewModel.autofillFromPhoto()
        viewModel.dismissSuggestions()
        #expect(viewModel.autofillMessage == nil)
        #expect(!viewModel.autofillSkippedExisting)
    }
}
