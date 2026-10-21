//
//  AppDependencies.swift
//  neighbourly
//
//  Builds the app's shared services once at launch. Feature screens receive
//  what they need from here instead of reaching for singletons.
//

import Foundation

struct AppDependencies {
    let listingRepository: any ListingRepository
    let photoStore: PhotoStore
    let locationService: LocationService

    /// On-device storage in Application Support/Neighbourly.
    static func live() -> AppDependencies {
        let root = URL.applicationSupportDirectory
            .appending(path: "Neighbourly", directoryHint: .isDirectory)
        let photoStore = PhotoStore(directory: root.appending(path: "Photos", directoryHint: .isDirectory))
        return AppDependencies(
            listingRepository: LocalListingRepository(directory: root, photoStore: photoStore),
            photoStore: photoStore,
            locationService: LocationService()
        )
    }

    /// Sample data in memory, for SwiftUI previews.
    static func preview() -> AppDependencies {
        AppDependencies(
            listingRepository: InMemoryListingRepository(),
            photoStore: PhotoStore(directory: URL.temporaryDirectory.appending(path: "PreviewPhotos")),
            locationService: LocationService()
        )
    }
}
