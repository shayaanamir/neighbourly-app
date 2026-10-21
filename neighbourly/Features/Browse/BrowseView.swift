//
//  BrowseView.swift
//  neighbourly
//
//  Interim Browse screen: a plain list straight from the repository so
//  persistence can be checked in the Simulator. Cards, search, filters,
//  and the map arrive in Phase 2–3.
//

import SwiftUI

struct BrowseView: View {
    let repository: any ListingRepository

    @State private var listings: [Listing] = []
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Browse")
                .task { await load() }
                .refreshable { await load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let errorMessage {
            ContentUnavailableView {
                Label("Couldn't load listings", systemImage: "exclamationmark.triangle")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("Reset sample data") {
                    Task { await resetSampleData() }
                }
            }
        } else if listings.isEmpty {
            ContentUnavailableView {
                Label("No listings yet", systemImage: "shippingbox")
            } description: {
                Text("Items to sell, exchange, or donate in your neighbourhood will appear here.")
            }
        } else {
            List(listings) { listing in
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(listing.title)
                        .font(Theme.Typography.headline)
                    Text("\(listing.mode.displayName) · \(listing.category.displayName) · \(listing.areaName ?? "No area")")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                }
            }
        }
    }

    private func load() async {
        do {
            listings = try await repository.fetchListings()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resetSampleData() async {
        do {
            try await repository.resetToSampleData()
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        await load()
    }
}

#Preview {
    BrowseView(repository: InMemoryListingRepository())
}
