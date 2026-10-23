//
//  FirestoreListingRepository.swift
//  neighbourly
//
//  Shared listings in Cloud Firestore (free Spark plan). Compiled only once the
//  firebase-ios-sdk package is added; see firebase/README.md.
//
//  Layout:
//    listings/{listingID}                 fields from ListingMapping + inline thumbnail
//    listings/{listingID}/photos/{name}   data (Bytes, about 150 KB), order, ownerID
//
//  Photos go in Firestore documents because Cloud Storage needs a billing plan.
//  Written without a Firebase-enabled compiler: if Xcode flags anything on the first
//  build, fix it here.
//

#if canImport(FirebaseFirestore)

import FirebaseFirestore
import Foundation
import OSLog

final class FirestoreListingRepository: ListingRepository, @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.kjsce.neighbourly", category: "Listings")

    /// Newest listings loaded per refresh; keeps reads well inside the free quota.
    static let fetchLimit = 100

    private let photoStore: PhotoStore
    private var db: Firestore { Firestore.firestore() }

    init(photoStore: PhotoStore) {
        self.photoStore = photoStore
    }

    // MARK: - Reading

    func fetchListings() async throws -> [Listing] {
        do {
            let snapshot = try await db.collection("listings")
                .order(by: "createdAt", descending: true)
                .limit(to: Self.fetchLimit)
                .getDocuments()

            var listings: [Listing] = []
            for document in snapshot.documents {
                guard let (listing, thumbnail) = ListingMapping.listing(
                    from: Self.plainFields(document.data()), id: document.documentID
                ) else {
                    Self.logger.error("Skipping malformed listing \(document.documentID, privacy: .public)")
                    continue
                }
                // Cards show the first photo, so cache the inline thumbnail for it.
                if let thumbnail, let first = listing.imageFileNames.first {
                    photoStore.saveThumbnail(thumbnail, for: first)
                }
                listings.append(listing)
            }
            return listings
        } catch {
            throw Self.friendly(error)
        }
    }

    func fetchPhoto(listingID: UUID, fileName: String) async throws -> Data? {
        do {
            let document = try await photoDocument(listingID: listingID, fileName: fileName).getDocument()
            return document.data()?["data"] as? Data
        } catch {
            throw Self.friendly(error)
        }
    }

    // MARK: - Writing

    func save(_ listing: Listing) async throws {
        guard let sellerID = listing.sellerID else { throw ListingRepositoryError.notSignedIn }
        try listing.validate()

        do {
            let listingRef = db.collection("listings").document(listing.id.uuidString)
            let existing = try? await listingRef.getDocument()
            let oldPhotoIDs = (existing?.data()?[ListingMapping.Field.photoIDs] as? [String]) ?? []
            let oldThumbnail = existing?.data()?[ListingMapping.Field.thumbnail] as? Data

            // 1. Upload photos the listing doesn't have in the cloud yet (before the listing
            //    references them, so nobody sees a listing whose photos are missing).
            for (index, photoID) in listing.imageFileNames.enumerated() where !oldPhotoIDs.contains(photoID) {
                guard let local = try? Data(contentsOf: photoStore.url(for: photoID)),
                      let compressed = PhotoCompressor.fullPhoto(from: local) else {
                    throw ListingRepositoryError.sharedUnavailable(reason: "A photo couldn't be prepared for upload.")
                }
                try await photoDocument(listingID: listing.id, fileName: photoID).setData([
                    "data": compressed,
                    "order": index,
                    "ownerID": sellerID,
                ])
            }

            // 2. Thumbnail for cards: rebuilt from the first photo, or kept if the file isn't cached.
            var thumbnail = oldThumbnail
            if let first = listing.imageFileNames.first,
               let local = try? Data(contentsOf: photoStore.url(for: first)) {
                thumbnail = PhotoCompressor.thumbnail(from: local)
            } else if listing.imageFileNames.isEmpty {
                thumbnail = nil
            }

            // 3. The listing itself.
            try await listingRef.setData(ListingMapping.data(for: listing, thumbnail: thumbnail))

            // 4. Photos that were removed in this edit.
            for removed in oldPhotoIDs where !listing.imageFileNames.contains(removed) {
                try? await photoDocument(listingID: listing.id, fileName: removed).delete()
            }
        } catch {
            throw Self.friendly(error)
        }
    }

    func delete(id: UUID) async throws {
        do {
            // Photos first: the rules check ownership on each photo document itself.
            let photos = try await db.collection("listings").document(id.uuidString)
                .collection("photos").getDocuments()
            for photo in photos.documents {
                try await photo.reference.delete()
            }
            try await db.collection("listings").document(id.uuidString).delete()
        } catch {
            throw Self.friendly(error)
        }
    }

    func resetToSampleData() async throws {
        // Sample data is local-only; shared listings are never reset from the app.
    }

    func deleteAllListings(ownedBy userID: String) async throws {
        do {
            let owned = try await db.collection("listings").whereField("sellerID", isEqualTo: userID).getDocuments()
            for document in owned.documents {
                if let id = UUID(uuidString: document.documentID) {
                    try await delete(id: id)
                }
            }
        } catch {
            throw Self.friendly(error)
        }
    }

    // MARK: - Helpers

    private func photoDocument(listingID: UUID, fileName: String) -> DocumentReference {
        db.collection("listings").document(listingID.uuidString).collection("photos").document(fileName)
    }

    /// Firestore hands back `Timestamp`; the pure mapping layer works with `Date`.
    private static func plainFields(_ data: [String: Any]) -> [String: Any] {
        data.mapValues { ($0 as? Timestamp)?.dateValue() ?? $0 }
    }

    private static func friendly(_ error: Error) -> Error {
        if error is ListingRepositoryError { return error }
        let nsError = error as NSError
        // Raw gRPC status codes (FIRFirestoreErrorDomain), which don't change between SDK versions.
        guard nsError.domain == "FIRFirestoreErrorDomain" else {
            logger.error("Firestore error: \(error.localizedDescription, privacy: .public)")
            return ListingRepositoryError.sharedUnavailable(reason: "Something went wrong talking to the server.")
        }
        switch nsError.code {
        case 14, 4: // unavailable, deadline exceeded
            return ListingRepositoryError.sharedUnavailable(reason: "The server couldn't be reached. Check your connection.")
        case 8: // resource exhausted
            return ListingRepositoryError.sharedUnavailable(reason: "The free daily limit has been reached. Try again tomorrow.")
        case 7, 16: // permission denied, unauthenticated
            return ListingRepositoryError.sharedUnavailable(reason: "You don't have permission to do that. Try signing in again.")
        default:
            logger.error("Unmapped Firestore error code \(nsError.code)")
            return ListingRepositoryError.sharedUnavailable(reason: "Something went wrong talking to the server.")
        }
    }
}

#endif
