//
//  BrowseView.swift
//  neighbourly
//
//  Search, filter, and switch between list and map. Both views show the
//  same filtered results.
//

import SwiftUI

struct BrowseView: View {
    @State private var viewModel: BrowseViewModel
    private let photoStore: PhotoStore
    private let locationService: LocationService

    init(repository: any ListingRepository, photoStore: PhotoStore, locationService: LocationService) {
        _viewModel = State(initialValue: BrowseViewModel(repository: repository))
        self.photoStore = photoStore
        self.locationService = locationService
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Display", selection: $viewModel.displayMode) {
                    ForEach(BrowseViewModel.DisplayMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.vertical, Theme.Spacing.s)

                filterBar

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Theme.Colors.groupedBackground)
            .navigationTitle("Browse")
            .searchable(text: $viewModel.filters.searchText, prompt: "Search items or areas")
            .task {
                if !viewModel.hasLoaded { await viewModel.load() }
            }
        }
    }

    // MARK: - Filter bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.s) {
                if viewModel.filters.isActive {
                    CategoryChip(title: "Clear", systemImage: "xmark", isSelected: false) {
                        viewModel.clearFilters()
                    }
                    .accessibilityLabel("Clear filters")
                    .accessibilityHint("Shows all listings")
                }

                ForEach(ListingMode.allCases) { mode in
                    CategoryChip(
                        title: mode.displayName,
                        systemImage: mode.systemImage,
                        isSelected: viewModel.filters.mode == mode
                    ) {
                        viewModel.toggle(mode)
                    }
                }

                Divider()
                    .frame(height: 24)

                ForEach(ListingCategory.allCases) { category in
                    CategoryChip(
                        title: category.displayName,
                        systemImage: category.systemImage,
                        isSelected: viewModel.filters.category == category
                    ) {
                        viewModel.toggle(category)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.s)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if let errorMessage = viewModel.errorMessage {
            ContentUnavailableView {
                Label("Couldn't load listings", systemImage: "exclamationmark.triangle")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("Reset sample data") {
                    Task { await viewModel.resetSampleData() }
                }
            }
        } else if !viewModel.hasLoaded {
            ProgressView("Loading listings…")
        } else if viewModel.listings.isEmpty {
            ContentUnavailableView {
                Label("No listings yet", systemImage: "shippingbox")
            } description: {
                Text("Items to sell, exchange, or donate in your neighbourhood will appear here.")
            } actions: {
                Button("Load sample listings") {
                    Task { await viewModel.resetSampleData() }
                }
            }
        } else if viewModel.results.isEmpty {
            ContentUnavailableView {
                Label("No matching listings", systemImage: "magnifyingglass")
            } description: {
                Text("Try a different search or remove some filters.")
            } actions: {
                Button("Clear filters") { viewModel.clearFilters() }
            }
        } else {
            switch viewModel.displayMode {
            case .list: listingList
            case .map:
                ListingMapView(
                    listings: viewModel.results,
                    photoStore: photoStore,
                    locationService: locationService,
                    onShowList: { viewModel.displayMode = .list }
                )
            }
        }
    }

    private var listingList: some View {
        let results = viewModel.results
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: Theme.Spacing.m) {
                Text(results.count == 1 ? "1 listing" : "\(results.count) listings")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)

                ForEach(results) { listing in
                    ListingCard(listing: listing, photoStore: photoStore)
                }
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, Theme.Spacing.s)
        }
        .refreshable { await viewModel.load() }
    }

}

#Preview {
    let dependencies = AppDependencies.preview()
    BrowseView(
        repository: dependencies.listingRepository,
        photoStore: dependencies.photoStore,
        locationService: dependencies.locationService
    )
}
