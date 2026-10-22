//
//  StoredPhotoView.swift
//  neighbourly
//

import SwiftUI
import UIKit

/// A photo from `PhotoStore`, loaded off the main thread. If the file isn't cached on this
/// device (a listing from someone else), it is downloaded once through the repository and
/// cached. Shows a placeholder while loading and a clear "unavailable" state if the photo
/// can't be found anywhere.
struct StoredPhotoView: View {
    let fileName: String
    let listingID: UUID
    let photoStore: PhotoStore
    let repository: any ListingRepository

    private enum LoadState {
        case loading
        case loaded(UIImage)
        case missing
    }

    @State private var state: LoadState = .loading

    var body: some View {
        // The colour layer sets the size; the photo is an overlay so it can only be clipped to it.
        Color(uiColor: .secondarySystemFill)
            .overlay {
                switch state {
                case .loading:
                    ProgressView()
                case .loaded(let image):
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                case .missing:
                    VStack(spacing: Theme.Spacing.s) {
                        Image(systemName: "photo.badge.exclamationmark")
                            .font(.largeTitle)
                        Text("Photo unavailable")
                            .font(Theme.Typography.caption)
                    }
                    .foregroundStyle(Theme.Colors.secondaryText)
                }
            }
            .clipped()
            .task(id: fileName) {
                state = .loading
                let store = photoStore
                var image = await Task.detached(priority: .userInitiated) {
                    store.image(named: fileName)?.preparingForDisplay()
                }.value

                if image == nil, let data = try? await repository.fetchPhoto(listingID: listingID, fileName: fileName) {
                    store.cache(data: data, named: fileName)
                    image = await Task.detached(priority: .userInitiated) {
                        store.image(named: fileName)?.preparingForDisplay()
                    }.value
                }
                state = image.map { LoadState.loaded($0) } ?? LoadState.missing
            }
    }
}
