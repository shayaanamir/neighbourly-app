//
//  Listing+Validation.swift
//  neighbourly
//

import Foundation

nonisolated enum ListingValidationError: LocalizedError, Equatable, Sendable {
    case emptyTitle
    case titleTooLong(max: Int)
    case descriptionTooLong(max: Int)
    case missingPrice
    case negativePrice
    case priceNotAllowed(ListingMode)
    case emptySellerName
    case incompleteCoordinates
    case latitudeOutOfRange
    case longitudeOutOfRange

    var errorDescription: String? {
        switch self {
        case .emptyTitle: "Add a title."
        case .titleTooLong(let max): "Title must be \(max) characters or fewer."
        case .descriptionTooLong(let max): "Description must be \(max) characters or fewer."
        case .missingPrice: "Add a price for items you're selling."
        case .negativePrice: "Price can't be negative."
        case .priceNotAllowed(let mode): "\(mode.displayName) listings don't have a price."
        case .emptySellerName: "Add a seller name."
        case .incompleteCoordinates: "Location needs both latitude and longitude."
        case .latitudeOutOfRange: "Latitude must be between -90 and 90."
        case .longitudeOutOfRange: "Longitude must be between -180 and 180."
        }
    }
}

nonisolated extension Listing {
    static let maxTitleLength = 80
    static let maxDescriptionLength = 1_000

    /// Every rule the listing currently breaks, in form order. Empty means valid.
    var validationErrors: [ListingValidationError] {
        var errors: [ListingValidationError] = []

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty {
            errors.append(.emptyTitle)
        } else if trimmedTitle.count > Self.maxTitleLength {
            errors.append(.titleTooLong(max: Self.maxTitleLength))
        }

        if description.count > Self.maxDescriptionLength {
            errors.append(.descriptionTooLong(max: Self.maxDescriptionLength))
        }

        if mode.requiresPrice {
            if let price {
                if price < 0 { errors.append(.negativePrice) }
            } else {
                errors.append(.missingPrice)
            }
        } else if price != nil {
            errors.append(.priceNotAllowed(mode))
        }

        if sellerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptySellerName)
        }

        switch (latitude, longitude) {
        case (nil, nil):
            break
        case let (lat?, lon?):
            if !(-90...90).contains(lat) { errors.append(.latitudeOutOfRange) }
            if !(-180...180).contains(lon) { errors.append(.longitudeOutOfRange) }
        default:
            errors.append(.incompleteCoordinates)
        }

        return errors
    }

    var isValid: Bool { validationErrors.isEmpty }

    /// Throws the first validation error, if any.
    func validate() throws {
        if let first = validationErrors.first { throw first }
    }
}
