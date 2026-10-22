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
    let visionAssist: any VisionAssisting
    let authService: any AuthService
    /// False in demo mode (no Firebase config yet): accounts are in memory only.
    let isCloudBacked: Bool

    /// On-device storage in Application Support/Neighbourly.
    @MainActor
    static func live() -> AppDependencies {
        let auth = AuthServiceFactory.makeLive()
        let root = URL.applicationSupportDirectory
            .appending(path: "Neighbourly", directoryHint: .isDirectory)
        let photoStore = PhotoStore(directory: root.appending(path: "Photos", directoryHint: .isDirectory))
        return AppDependencies(
            listingRepository: ListingRepositoryFactory.makeLive(
                root: root, photoStore: photoStore, isCloudBacked: auth.isCloudBacked
            ),
            photoStore: photoStore,
            locationService: LocationService(),
            visionAssist: VisionAssistService(),
            authService: auth.service,
            isCloudBacked: auth.isCloudBacked
        )
    }

    /// Sample data in memory, for SwiftUI previews.
    @MainActor
    static func preview() -> AppDependencies {
        AppDependencies(
            listingRepository: InMemoryListingRepository(),
            photoStore: PhotoStore(directory: URL.temporaryDirectory.appending(path: "PreviewPhotos")),
            locationService: LocationService(),
            visionAssist: VisionAssistService(),
            authService: MockAuthService(),
            isCloudBacked: false
        )
    }
}
