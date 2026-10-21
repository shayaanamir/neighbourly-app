//
//  ListingCard.swift
//  neighbourly
//

import SwiftUI

struct ListingCard: View {
    let listing: Listing
    let photoStore: PhotoStore

    @ScaledMetric(relativeTo: .headline) private var thumbnailSize: CGFloat = 76
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // Stack vertically at accessibility text sizes so nothing gets squeezed.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Spacing.m))
            : AnyLayout(HStackLayout(alignment: .top, spacing: Theme.Spacing.m))

        layout {
            ListingThumbnail(
                fileName: listing.imageFileNames.first,
                category: listing.category,
                photoStore: photoStore
            )
            .frame(width: thumbnailSize, height: thumbnailSize)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(listing.title)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.primaryText)
                    .lineLimit(2)

                Text(listing.priceText())
                    .font(Theme.Typography.price)
                    .foregroundStyle(listing.mode.tint)

                HStack(spacing: Theme.Spacing.s) {
                    ModeBadge(mode: listing.mode)
                    Label(listing.category.displayName, systemImage: listing.category.systemImage)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .lineLimit(1)
                }

                Label(listing.areaText, systemImage: "mappin.and.ellipse")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        [
            listing.title,
            listing.priceText(),
            listing.mode.displayName,
            listing.category.displayName,
            listing.areaText,
        ].joined(separator: ", ")
    }
}

#Preview {
    VStack {
        ForEach(SampleListings.make().prefix(3)) { listing in
            ListingCard(listing: listing, photoStore: AppDependencies.preview().photoStore)
        }
    }
    .padding()
    .background(Theme.Colors.groupedBackground)
}
