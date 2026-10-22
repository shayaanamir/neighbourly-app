//
//  Listing.swift
//  neighbourly
//

import Foundation

/// A single item offered to the neighbourhood.
/// Photos are stored as file names managed by `PhotoStore`, never as image bytes.
nonisolated struct Listing: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var title: String
    var description: String
    var category: ListingCategory
    var mode: ListingMode
    /// Required for `.sell`; must be nil for `.exchange` and `.donate`.
    var price: Decimal?
    var condition: ItemCondition
    /// Photo file names. For shared listings these double as the photo document IDs in the cloud.
    var imageFileNames: [String]
    var latitude: Double?
    var longitude: Double?
    /// User-entered neighbourhood / locality label, never a street address.
    var areaName: String?
    /// Account ID (Firebase UID) of the person who posted it. nil for sample listings
    /// and for listings saved before accounts existed.
    var sellerID: String?
    var sellerName: String
    /// Legacy and local only: never uploaded. Chat replaces published contact details.
    var sellerContact: String?
    var createdAt: Date
    /// True for seeded sample content, false for listings created on this device.
    var isDemo: Bool

    init(
        id: UUID = UUID(),
        title: String,
        description: String = "",
        category: ListingCategory,
        mode: ListingMode,
        price: Decimal? = nil,
        condition: ItemCondition,
        imageFileNames: [String] = [],
        latitude: Double? = nil,
        longitude: Double? = nil,
        areaName: String? = nil,
        sellerID: String? = nil,
        sellerName: String,
        sellerContact: String? = nil,
        createdAt: Date = .now,
        isDemo: Bool = false
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
        self.mode = mode
        self.price = price
        self.condition = condition
        self.imageFileNames = imageFileNames
        self.latitude = latitude
        self.longitude = longitude
        self.areaName = areaName
        self.sellerID = sellerID
        self.sellerName = sellerName
        self.sellerContact = sellerContact
        self.createdAt = createdAt
        self.isDemo = isDemo
    }

    var hasCoordinates: Bool { latitude != nil && longitude != nil }
}
