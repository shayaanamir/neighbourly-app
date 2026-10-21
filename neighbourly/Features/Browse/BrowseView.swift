//
//  BrowseView.swift
//  neighbourly
//
//  Placeholder Browse screen (Phase 0). Listing data arrives in Phase 1–2.
//

import SwiftUI

struct BrowseView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.l) {
                ContentUnavailableView {
                    Label("No listings yet", systemImage: "shippingbox")
                } description: {
                    Text("Items to sell, exchange, or donate in your neighbourhood will appear here.")
                }

                Text("Local-only prototype · data stays on this device")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .padding(.bottom, Theme.Spacing.l)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.Colors.groupedBackground)
            .navigationTitle("Browse")
        }
    }
}

#Preview {
    BrowseView()
}
