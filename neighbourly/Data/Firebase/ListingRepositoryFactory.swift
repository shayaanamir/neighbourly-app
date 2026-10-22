//
//  ListingRepositoryFactory.swift
//  neighbourly
//
//  Picks where listings live: cloud + local samples when Firebase is set up,
//  otherwise everything stays in the local JSON store (demo mode). Always
//  compiled, so the project builds before Firebase has been added.
//

import Foundation

enum ListingRepositoryFactory {
    static func makeLive(root: URL, photoStore: PhotoStore, isCloudBacked: Bool) -> any ListingRepository {
        let local = LocalListingRepository(directory: root, photoStore: photoStore)

        #if canImport(FirebaseFirestore)
        if isCloudBacked {
            return CompositeListingRepository(
                demo: local,
                shared: FirestoreListingRepository(photoStore: photoStore)
            )
        }
        #endif
        return local
    }
}
