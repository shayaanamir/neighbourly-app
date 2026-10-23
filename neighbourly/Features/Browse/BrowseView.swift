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
    @Environment(AuthViewModel.self) private var auth
    @State private var showCreateListing = false
    @State private var savedBannerTitle: String?
    private let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        _viewModel = State(initialValue: BrowseViewModel(repository: dependencies.listingRepository))
        self.dependencies = dependencies
    }

    private var photoStore: PhotoStore { dependencies.photoStore }

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

                if let warning = viewModel.warning {
                    Label(warning, systemImage: "wifi.exclamationmark")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Theme.Spacing.l)
                        .padding(.bottom, Theme.Spacing.s)
                }

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Theme.Colors.groupedBackground)
            .navigationTitle("Neighbourly")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.filters.searchText, prompt: "Search items or areas")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Neighbourly")
                        .font(Theme.Typography.script(34, relativeTo: .title))
                        .foregroundStyle(Theme.Colors.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .accessibilityAddTraits(.isHeader)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        auth.requireSignIn { showCreateListing = true }
                    } label: {
                        Label("Add Listing", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateListing) {
                CreateListingView(
                    repository: dependencies.listingRepository,
                    photoStore: dependencies.photoStore,
                    visionAssist: dependencies.visionAssist,
                    defaultSellerName: auth.user?.displayName,
                    sellerID: auth.user?.uid
                ) { listing in
                    Task {
                        await viewModel.listingAdded()
                        await showSavedBanner(for: listing)
                    }
                }
            }
            .overlay(alignment: .bottom) { savedBanner }
            .navigationDestination(for: Listing.self) { listing in
                ListingDetailView(listing: listing, dependencies: dependencies) {
                    Task { await viewModel.load() }
                }
            }
            // Runs each time the tab is shown, so edits and deletes made in My Listings appear here.
            .task { await viewModel.load() }
        }
    }

    // MARK: - Saved banner

    @ViewBuilder
    private var savedBanner: some View {
        if let title = savedBannerTitle {
            Label("“\(title)” added", systemImage: "checkmark.circle.fill")
                .font(Theme.Typography.subheadline.weight(.semibold))
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.vertical, Theme.Spacing.m)
                .foregroundStyle(Theme.Colors.primaryText)
                .background(Theme.Colors.cardBackground, in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.Colors.separator.opacity(0.6), lineWidth: 0.5))
                .shadow(color: Theme.Colors.shadow, radius: 6, y: 2)
                .padding(.bottom, Theme.Spacing.xl)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .accessibilityAddTraits(.isStaticText)
        }
    }

    private func showSavedBanner(for listing: Listing) async {
        withAnimation { savedBannerTitle = listing.title }
        UIAccessibility.post(notification: .announcement, argument: "\(listing.title) added")
        try? await Task.sleep(for: .seconds(2.5))
        withAnimation { savedBannerTitle = nil }
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
                Button("Add a listing") { auth.requireSignIn { showCreateListing = true } }
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
                    locationService: dependencies.locationService,
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
                    NavigationLink(value: listing) {
                        ListingCard(listing: listing, photoStore: photoStore)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens listing details")
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
    BrowseView(dependencies: dependencies)
        .environment(AuthViewModel(service: dependencies.authService, isCloudBacked: false))
}
