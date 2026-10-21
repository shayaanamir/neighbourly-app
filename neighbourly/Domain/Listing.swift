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
    var imageFileNames: [String]
    var latitude: Double?
    var longitude: Double?
    /// User-entered neighbourhood / locality label, never a street address.
    var areaName: String?
    var sellerName: String
    /// Optional; stays on device and is only shown on user action.
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
        self.sellerName = sellerName
        self.sellerContact = sellerContact
        self.createdAt = createdAt
        self.isDemo = isDemo
    }

    var hasCoordinates: Bool { latitude != nil && longitude != nil }
}
