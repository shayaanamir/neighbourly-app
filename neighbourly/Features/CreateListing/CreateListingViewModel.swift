//
//  CreateListingViewModel.swift
//  neighbourly
//
//  Form state for creating or editing a listing. New photos are only held in
//  memory while the form is open; they're copied into `PhotoStore` on save.
//  Photos that already belong to the listing being edited stay on disk.
//

import Foundation
import Observation
import UIKit

@Observable
final class CreateListingViewModel {
    static let maxPhotos = 5
    static let defaultSellerName = "Me"

    struct SelectedPhoto: Identifiable {
        enum Source {
            /// Picked in this form, not yet stored.
            case new(Data)
            /// Already stored for the listing being edited.
            case existing(fileName: String)
        }

        let id = UUID()
        let source: Source
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
        var photoIDs: [SelectedPhoto.ID]
        var latitude: Double?
        var longitude: Double?
    }

    enum LocationStatus: Equatable {
        case idle
        case locating
        case failed(LocationError)
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
    /// Set by "Use my current location" (rounded for sharing), or kept from the listing being
    /// edited. Always both or neither.
    private(set) var latitude: Double?
    private(set) var longitude: Double?

    // MARK: State

    private(set) var photos: [SelectedPhoto] = []
    private(set) var attemptedSave = false
    private(set) var isSaving = false
    private(set) var assistState: AssistState = .idle
    private(set) var locationStatus: LocationStatus = .idle
    /// The place name suggested from the location, remembered so the screen can say the area
    /// came from there until the person changes it.
    private var suggestedAreaName: String?
    var photoMessage: String?
    var saveError: String?

    @ObservationIgnored private let repository: any ListingRepository
    @ObservationIgnored private let photoStore: PhotoStore
    @ObservationIgnored private let visionAssist: any VisionAssisting
    /// Source of the current position; nil hides the "Use my current location" button.
    @ObservationIgnored private let location: (any LocationProviding)?
    /// Account posting the listing (ignored when editing: the original keeps its owner).
    @ObservationIgnored private let sellerID: String?
    /// The listing being edited, or nil when creating a new one.
    @ObservationIgnored private let original: Listing?
    /// What the form looked like when it opened; `isDirty` compares against this.
    @ObservationIgnored private var baseline: Snapshot
    @ObservationIgnored private var hasLoadedExistingPhotos = false
    /// Identifies the analysis whose result is still wanted; stale results are dropped.
    @ObservationIgnored private var analysisToken: UUID?
    @ObservationIgnored private var analyzedPhotoID: SelectedPhoto.ID?

    init(
        repository: any ListingRepository,
        photoStore: PhotoStore,
        visionAssist: any VisionAssisting = VisionAssistService(),
        editing original: Listing? = nil,
        defaultSellerName: String? = nil,
        sellerID: String? = nil,
        location: (any LocationProviding)? = nil
    ) {
        self.repository = repository
        self.photoStore = photoStore
        self.visionAssist = visionAssist
        self.original = original
        self.sellerID = sellerID
        self.location = location

        // Build the baseline from the listing itself (not from self's observable
        // properties), then copy it into the form fields.
        let initial = Self.initialSnapshot(for: original, defaultSellerName: defaultSellerName)
        baseline = initial
        title = initial.title
        description = initial.description
        category = initial.category
        mode = initial.mode
        condition = initial.condition
        priceInput = initial.priceInput
        areaName = initial.areaName
        sellerName = initial.sellerName
        sellerContact = initial.sellerContact
        latitude = initial.latitude
        longitude = initial.longitude
    }

    private static func initialSnapshot(for original: Listing?, defaultSellerName: String?) -> Snapshot {
        Snapshot(
            title: original?.title ?? "",
            description: original?.description ?? "",
            category: original?.category ?? .other,
            mode: original?.mode ?? .sell,
            condition: original?.condition ?? .good,
            priceInput: original?.price.map(priceInput(from:)) ?? "",
            areaName: original?.areaName ?? "",
            sellerName: original?.sellerName ?? defaultSellerName ?? Self.defaultSellerName,
            sellerContact: original?.sellerContact ?? "",
            photoIDs: [],
            latitude: original?.latitude,
            longitude: original?.longitude
        )
    }

    var isEditing: Bool { original != nil }

    // MARK: Location

    /// Whether this form can fetch the device's location at all.
    var canUseLocation: Bool { location != nil }
    var hasLocation: Bool { latitude != nil && longitude != nil }
    /// True while the area field still holds the name filled in from the location.
    var areaFilledFromLocation: Bool {
        suggestedAreaName != nil && areaName == suggestedAreaName
    }
    var isLocating: Bool { locationStatus == .locating }

    /// Fetches the device's position when the person taps the button. The position is rounded
    /// to about 1 km before it is stored, and the area name is suggested from it, but only
    /// if the person hasn't typed one.
    func useCurrentLocation() async {
        guard let location, !isLocating else { return }
        locationStatus = .locating
        do {
            let coordinate = try await location.currentCoordinate().roundedForSharing()
            latitude = coordinate.latitude
            longitude = coordinate.longitude
            locationStatus = .idle

            if areaName.trimmed.isEmpty, let name = await location.placeName(for: coordinate) {
                // Re-check: they may have started typing while the lookup ran.
                if areaName.trimmed.isEmpty {
                    areaName = name
                    suggestedAreaName = name
                }
            }
        } catch {
            locationStatus = .failed((error as? LocationError) ?? .unavailable)
        }
    }

    /// Takes the position off the listing again.
    func clearLocation() {
        latitude = nil
        longitude = nil
        suggestedAreaName = nil
        locationStatus = .idle
    }

    /// Plain number in the current locale, matching what the price field parses.
    nonisolated private static func priceInput(from price: Decimal) -> String {
        price.formatted(.number.locale(.current).grouping(.never).precision(.fractionLength(0...2)))
    }

    /// Loads thumbnails for the edited listing's stored photos. Files that have gone
    /// missing are skipped, so saving quietly drops the dead references.
    func loadExistingPhotos() async {
        guard let original, !hasLoadedExistingPhotos else { return }
        hasLoadedExistingPhotos = true

        let store = photoStore
        var loaded: [SelectedPhoto] = []
        for fileName in original.imageFileNames.prefix(Self.maxPhotos) {
            // A shared listing's photo may not be cached on this device (for example after
            // signing in on a new phone). Download it first: dropping it here would delete
            // it from the cloud when the edit is saved.
            if !store.fileExists(named: fileName),
               let data = try? await repository.fetchPhoto(listingID: original.id, fileName: fileName) {
                store.cache(data: data, named: fileName)
            }
            let thumbnail = await Task.detached(priority: .userInitiated) {
                store.image(named: fileName)?.preparingThumbnail(of: CGSize(width: 400, height: 400))
            }.value
            if let thumbnail {
                loaded.append(SelectedPhoto(source: .existing(fileName: fileName), thumbnail: thumbnail))
            }
        }
        // Keep anything the user added while this was loading.
        photos = loaded + photos
        baseline.photoIDs = loaded.map { $0.id }
        if loaded.count < original.imageFileNames.count {
            photoMessage = "Some photos for this listing are missing and will be removed when you save."
        }
    }

    // MARK: Derived state

    var remainingPhotoSlots: Int {
        max(0, Self.maxPhotos - photos.count)
    }

    var isDirty: Bool {
        snapshot != baseline
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
                photos.append(SelectedPhoto(source: .new(data), thumbnail: thumbnail))
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
            let imageData = try await Self.imageData(for: photo, in: photoStore)
            let suggestions = try await visionAssist.analyze(imageData: imageData)
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
        description = existing.isEmpty ? line : existing + "\n" + line
    }

    func dismissSuggestions() {
        analysisToken = nil
        analyzedPhotoID = nil
        assistState = .idle
    }

    /// Bytes of a form photo: in memory for new ones, read from disk for stored ones.
    private static func imageData(for photo: SelectedPhoto, in store: PhotoStore) async throws -> Data {
        switch photo.source {
        case .new(let data):
            return data
        case .existing(let fileName):
            let url = store.url(for: fileName)
            let data = await Task.detached(priority: .userInitiated) { try? Data(contentsOf: url) }.value
            guard let data else { throw VisionAssistError.unreadableImage }
            return data
        }
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
        let newPhotoData: [Data] = photos.compactMap {
            if case .new(let data) = $0.source { return data }
            return nil
        }
        var newFileNames: [String] = []
        do {
            // Decoding and re-encoding photos is slow; keep it off the main actor.
            newFileNames = try await Task.detached(priority: .userInitiated) {
                try store.save(imagesData: newPhotoData)
            }.value

            // Final order matches the form: kept photos stay where they were, new ones follow.
            var remainingNew = newFileNames.makeIterator()
            let fileNames: [String] = photos.compactMap {
                switch $0.source {
                case .existing(let fileName): fileName
                case .new: remainingNew.next()
                }
            }
            let listing = makeListing(imageFileNames: fileNames)
            // When editing, the repository deletes files the listing no longer references.
            try await repository.save(listing)
            return listing
        } catch {
            // Don't leave new photos behind for a listing that wasn't saved.
            for fileName in newFileNames { store.delete(named: fileName) }
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
            id: original?.id ?? UUID(),
            title: title.trimmed,
            description: description.trimmed,
            category: category,
            mode: mode,
            price: price,
            condition: condition,
            imageFileNames: imageFileNames,
            latitude: latitude,
            longitude: longitude,
            areaName: areaName.trimmed.nilIfEmpty,
            sellerID: original?.sellerID ?? sellerID,
            sellerName: sellerName.trimmed,
            sellerContact: sellerContact.trimmed.nilIfEmpty,
            createdAt: original?.createdAt ?? .now,
            isDemo: original?.isDemo ?? false
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
            sellerName: sellerName, sellerContact: sellerContact, photoIDs: photos.map { $0.id },
            latitude: latitude, longitude: longitude
        )
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
