//
//  ListingThumbnail.swift
//  neighbourly
//

import SwiftUI
import UIKit

/// First listing photo, loaded off the main thread. Falls back to the
/// category icon when there is no photo or the file is missing.
struct ListingThumbnail: View {
    let fileName: String?
    let category: ListingCategory
    let photoStore: PhotoStore

    @State private var image: UIImage?

    var body: some View {
        // The colour layer takes exactly the proposed size; the photo is an overlay,
        // so a scaledToFill image can't enlarge the view, only get clipped to it.
        Theme.Colors.accent.opacity(0.12)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: category.systemImage)
                        .font(.title2)
                        .foregroundStyle(Theme.Colors.accent)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.s))
        .accessibilityHidden(true)
        .task(id: fileName) {
            image = await loadThumbnail()
        }
    }

    private func loadThumbnail() async -> UIImage? {
        guard let fileName else { return nil }
        let store = photoStore
        return await Task.detached(priority: .utility) {
            store.image(named: fileName)?.preparingThumbnail(of: CGSize(width: 300, height: 300))
        }.value
    }
}
