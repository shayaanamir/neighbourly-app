//
//  ListingMapping.swift
//  neighbourly
//
//  Converts a Listing to and from the field dictionary stored in a Firestore
//  document. Pure Foundation (no Firebase import) so it can be unit tested; the
//  Firestore layer converts Timestamp <-> Date at the edge.
//
//  Shared documents deliberately leave out `sellerContact` (chat replaces it),
//  `isDemo` (sample listings never go to the cloud), and the local `id` (the
//  document ID is the listing's UUID).
//

import Foundation

nonisolated enum ListingMapping {
    enum Field {
        static let title = "title"
        static let description = "description"
        static let category = "category"
        static let mode = "mode"
        static let priceMinor = "priceMinor"
        static let condition = "condition"
        static let photoIDs = "photoIDs"
        static let latitude = "latitude"
        static let longitude = "longitude"
        static let areaName = "areaName"
        static let sellerID = "sellerID"
        static let sellerName = "sellerName"
        static let createdAt = "createdAt"
        static let thumbnail = "thumbnail"
    }

    /// Fields for a listing's document. `thumbnail` is the small inline preview for cards.
    static func data(for listing: Listing, thumbnail: Data?) -> [String: Any] {
        var data: [String: Any] = [
            Field.title: listing.title,
            Field.description: listing.description,
            Field.category: listing.category.rawValue,
            Field.mode: listing.mode.rawValue,
            Field.condition: listing.condition.rawValue,
            Field.photoIDs: listing.imageFileNames,
            Field.sellerName: listing.sellerName,
            Field.createdAt: listing.createdAt,
        ]
        if let sellerID = listing.sellerID { data[Field.sellerID] = sellerID }
        if let price = listing.price, listing.mode.requiresPrice {
            data[Field.priceMinor] = minorUnits(from: price)
        }
        if let latitude = listing.latitude, let longitude = listing.longitude {
            data[Field.latitude] = latitude
            data[Field.longitude] = longitude
        }
        if let area = listing.areaName, !area.isEmpty { data[Field.areaName] = area }
        if let thumbnail { data[Field.thumbnail] = thumbnail }
        return data
    }

    /// The listing and its inline thumbnail, or nil if the document is malformed (a missing
    /// required field or an unknown category/mode/condition). Callers skip those documents
    /// instead of failing the whole load.
    static func listing(from data: [String: Any], id: String) -> (listing: Listing, thumbnail: Data?)? {
        guard let uuid = UUID(uuidString: id),
              let title = data[Field.title] as? String,
              let categoryRaw = data[Field.category] as? String, let category = ListingCategory(rawValue: categoryRaw),
              let modeRaw = data[Field.mode] as? String, let mode = ListingMode(rawValue: modeRaw),
              let conditionRaw = data[Field.condition] as? String, let condition = ItemCondition(rawValue: conditionRaw),
              let sellerID = data[Field.sellerID] as? String,
              let sellerName = data[Field.sellerName] as? String,
              let createdAt = data[Field.createdAt] as? Date
        else { return nil }

        var price: Decimal?
        if mode.requiresPrice, let minor = intValue(data[Field.priceMinor]) {
            price = Decimal(minor) / 100
        }

        var latitude: Double?
        var longitude: Double?
        if let lat = data[Field.latitude] as? Double, let lon = data[Field.longitude] as? Double {
            latitude = lat
            longitude = lon
        }

        let listing = Listing(
            id: uuid,
            title: title,
            description: data[Field.description] as? String ?? "",
            category: category,
            mode: mode,
            price: price,
            condition: condition,
            imageFileNames: data[Field.photoIDs] as? [String] ?? [],
            latitude: latitude,
            longitude: longitude,
            areaName: data[Field.areaName] as? String,
            sellerID: sellerID,
            sellerName: sellerName,
            createdAt: createdAt,
            isDemo: false
        )
        return (listing, data[Field.thumbnail] as? Data)
    }

    /// 1800.50 -> 180050 (paise). Whole numbers keep prices exact; floating point wouldn't.
    static func minorUnits(from price: Decimal) -> Int {
        var scaled = price * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, .plain)
        return NSDecimalNumber(decimal: rounded).intValue
    }

    /// Firestore returns whole numbers as Int or Int64 (and sometimes Double), depending on the path.
    private static func intValue(_ value: Any?) -> Int? {
        switch value {
        case let int as Int: int
        case let int64 as Int64: Int(int64)
        case let double as Double: Int(double.rounded())
        default: nil
        }
    }
}
