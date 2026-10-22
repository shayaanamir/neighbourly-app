//
//  CreateListingViewModel.swift
//  neighbourly
//
//  Form state for creating a listing. Photos are only held in memory while
//  the form is open; they're copied into `PhotoStore` when the user saves.
//

import Foundation
import Observation
import UIKit

@Observable
final class CreateListingViewModel {
    static let maxPhotos = 5
    static let defaultSellerName = "Me"

    struct SelectedPhoto: Identifiable {
        let id = UUID()
        let data: Data
        let thumbnail: UIImage
    }

    /// Error text per field; nil means that field is fine.
    struct FieldErrors: Equatable {
        var title: String?
        var description: String?
        var price: String?
        var sellerName: String?

        var isEmpty: Bool {
            title == nil && description == nil && price == nil && sellerName == nil
        }
    }

    /// Everything the user can change, used to detect unsaved edits.
    private struct Snapshot: Equatable {
        var title: String
        var description: String
        var category: ListingCategory
        var mode: ListingMode
        var condition: ItemCondition
        var priceInput: String
        var areaName: String
        var sellerName: String
        var sellerContact: String
        var photoCount: Int
    }

    /// Progress of the optional "Suggest details" on-device analysis.
    enum AssistState: Equatable {
        case idle
        case analyzing
        case result(ImageSuggestions)
        case noResult
        case failed(String)
    }

    private enum ParsedPrice {
        case empty
        case value(Decimal)
        case invalid
    }

    // MARK: Form fields

    var title = ""
    var description = ""
    var category: ListingCategory = .other
    var mode: ListingMode = .sell
    var condition: ItemCondition = .good
    var priceInput = ""
    var areaName = ""
    var sellerName = CreateListingViewModel.defaultSellerName
    var sellerContact = ""

    // MARK: State

    private(set) var photos: [SelectedPhoto] = []
    private(set) var attemptedSave = false
    private(set) var isSaving = false
    private(set) var assistState: AssistState = .idle
    var photoMessage: String?
    var saveError: String?

    @ObservationIgnored private let repository: any ListingRepository
    @ObservationIgnored private let photoStore: PhotoStore
    @ObservationIgnored private let visionAssist: any VisionAssisting
    /// Identifies the analysis whose result is still wanted; stale results are dropped.
    @ObservationIgnored private var analysisToken: UUID?
    @ObservationIgnored private var analyzedPhotoID: SelectedPhoto.ID?

    init(
        repository: any ListingRepository,
        photoStore: PhotoStore,
        visionAssist: any VisionAssisting = VisionAssistService()
    ) {
        self.repository = repository
        self.photoStore = photoStore
        self.visionAssist = visionAssist
    }

    // MARK: Derived state

    var remainingPhotoSlots: Int {
        max(0, Self.maxPhotos - photos.count)
    }

    var isDirty: Bool {
        snapshot != Self.pristine
    }

    /// Errors for every field, whether or not the user has tried to save yet.
    var fieldErrors: FieldErrors {
        var errors = FieldErrors()

        if case .invalid = parsedPrice {
            errors.price = "Enter a valid price, like 250."
        }

        for error in makeListing(imageFileNames: []).validationErrors {
            let message = error.errorDescription
            switch error {
            case .emptyTitle, .titleTooLong:
                errors.title = errors.title ?? message
            case .descriptionTooLong:
                errors.description = errors.description ?? message
            case .missingPrice, .negativePrice, .priceNotAllowed:
                errors.price = errors.price ?? message
            case .emptySellerName:
                errors.sellerName = errors.sellerName ?? message
            case .incompleteCoordinates, .latitudeOutOfRange, .longitudeOutOfRange:
                break // the form never sets coordinates
            }
        }
        return errors
    }

    /// Errors to show inline: hidden until the first save attempt so the form
    /// doesn't open covered in red.
    var visibleErrors: FieldErrors {
        attemptedSave ? fieldErrors : FieldErrors()
    }

    // MARK: Photos

    /// Adds photos from raw image data. Unreadable files are skipped and reported.
    func addPhotos(_ datas: [Data]) async {
        var skipped = 0
        for data in datas {
            guard remainingPhotoSlots > 0 else {
                photoMessage = "You can add up to \(Self.maxPhotos) photos."
                break
            }
            if let thumbnail = await Self.makeThumbnail(from: data) {
                photos.append(SelectedPhoto(data: data, thumbnail: thumbnail))
            } else {
                skipped += 1
            }
        }
        if skipped > 0 {
            photoMessage = skipped == 1 ? "One photo couldn't be read." : "\(skipped) photos couldn't be read."
        }
    }

    func removePhoto(id: SelectedPhoto.ID) {
        photos.removeAll { $0.id == id }
        photoMessage = nil
        // Suggestions describe the removed photo, so they no longer apply.
        if id == analyzedPhotoID { dismissSuggestions() }
    }

    // MARK: Suggest details (on-device Vision)

    /// Analyses the first photo. Never changes the form by itself: the user picks
    /// which suggestions to apply.
    func suggestDetails() async {
        guard let photo = photos.first, assistState != .analyzing else { return }

        let token = UUID()
        analysisToken = token
        analyzedPhotoID = photo.id
        assistState = .analyzing

        do {
            let suggestions = try await visionAssist.analyze(imageData: photo.data)
            guard analysisToken == token else { return }
            assistState = suggestions.isEmpty ? .noResult : .result(suggestions)
        } catch {
            guard analysisToken == token else { return }
            assistState = .failed(error.localizedDescription)
        }
    }

    func applySuggestedCategory(_ suggested: ListingCategory) {
        category = suggested
    }

    func useAsTitle(_ line: String) {
        title = String(line.trimmed.prefix(Listing.maxTitleLength))
    }

    func appendToDescription(_ line: String) {
        let existing = description.trimmed
        description = existing.isEmpty ? line : existing + "
" + line
    }

    func dismissSuggestions() {
        analysisToken = nil
        analyzedPhotoID = nil
        assistState = .idle
    }

    private static func makeThumbnail(from data: Data) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            UIImage(data: data)?.preparingThumbnail(of: CGSize(width: 400, height: 400))
        }.value
    }

    // MARK: Saving

    /// Validates, stores photos, and saves the listing. Returns the saved listing, or nil
    /// if validation failed or saving threw (see `fieldErrors` / `saveError`).
    func save() async -> Listing? {
        attemptedSave = true
        guard !isSaving, fieldErrors.isEmpty else { return nil }

        isSaving = true
        defer { isSaving = false }

        let store = photoStore
        let photoData = photos.map { $0.data }
        var fileNames: [String] = []
        do {
            // Decoding and re-encoding photos is slow; keep it off the main actor.
            fileNames = try await Task.detached(priority: .userInitiated) {
                try store.save(imagesData: photoData)
            }.value
            let listing = makeListing(imageFileNames: fileNames)
            try await repository.save(listing)
            return listing
        } catch {
            // Don't leave photos behind for a listing that wasn't saved.
            for fileName in fileNames { store.delete(named: fileName) }
            saveError = error.localizedDescription
            return nil
        }
    }

    // MARK: Building the listing

    func makeListing(imageFileNames: [String]) -> Listing {
        var price: Decimal?
        if mode.requiresPrice, case .value(let value) = parsedPrice {
            price = value
        }

        return Listing(
            title: title.trimmed,
            description: description.trimmed,
            category: category,
            mode: mode,
            price: price,
            condition: condition,
            imageFileNames: imageFileNames,
            areaName: areaName.trimmed.nilIfEmpty,
            sellerName: sellerName.trimmed,
            sellerContact: sellerContact.trimmed.nilIfEmpty
        )
    }

    private var parsedPrice: ParsedPrice {
        guard mode.requiresPrice else { return .empty }
        let text = priceInput.trimmed
        if text.isEmpty { return .empty }
        // Decimal(string:) quietly accepts trailing junk ("12abc" -> 12), so check
        // the characters first: digits, one decimal separator, optional leading minus.
        let separator = Locale.current.decimalSeparator ?? "."
        let body = text.hasPrefix("-") ? String(text.dropFirst()) : text
        let separatorCount = body.filter { String($0) == separator }.count
        let onlyNumeric = body.allSatisfy { $0.isASCII && $0.isNumber || String($0) == separator }
        guard body.contains(where: { $0.isNumber }), onlyNumeric, separatorCount <= 1,
              let value = Decimal(string: text, locale: .current) else { return .invalid }
        return .value(value)
    }

    private var snapshot: Snapshot {
        Snapshot(
            title: title, description: description, category: category, mode: mode,
            condition: condition, priceInput: priceInput, areaName: areaName,
            sellerName: sellerName, sellerContact: sellerContact, photoCount: photos.count
        )
    }

    private static let pristine = Snapshot(
        title: "", description: "", category: .other, mode: .sell, condition: .good,
        priceInput: "", areaName: "", sellerName: defaultSellerName, sellerContact: "",
        photoCount: 0
    )
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
