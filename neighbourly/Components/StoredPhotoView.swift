//
//  StoredPhotoView.swift
//  neighbourly
//

import SwiftUI
import UIKit

/// A photo from `PhotoStore`, loaded off the main thread. Shows a placeholder
/// while loading and a clear "unavailable" state if the file is missing.
struct StoredPhotoView: View {
    let fileName: String
    let photoStore: PhotoStore

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
                let image = await Task.detached(priority: .userInitiated) {
                    store.image(named: fileName)?.preparingForDisplay()
                }.value
                state = image.map { LoadState.loaded($0) } ?? LoadState.missing
            }
    }
}
