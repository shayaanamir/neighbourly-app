//
//  MyListingsView.swift
//  neighbourly
//
//  Listings created on this device, with edit and delete.
//

import SwiftUI

struct MyListingsView: View {
    let dependencies: AppDependencies

    @State private var viewModel: MyListingsViewModel
    @State private var showCreate = false
    @State private var listingToEdit: Listing?
    @State private var listingToDelete: Listing?
    @State private var showResetConfirmation = false

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _viewModel = State(initialValue: MyListingsViewModel(repository: dependencies.listingRepository))
    }

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.Colors.groupedBackground)
                .navigationTitle("My Listings")
                .navigationDestination(for: Listing.self) { listing in
                    ListingDetailView(listing: listing, dependencies: dependencies) {
                        Task { await viewModel.load() }
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button { showCreate = true } label: {
                            Label("Add Listing", systemImage: "plus")
                        }
                    }
                    ToolbarItem(placement: .secondaryAction) {
                        Button("Reset Sample Data", systemImage: "arrow.counterclockwise", role: .destructive) {
                            showResetConfirmation = true
                        }
                    }
                }
                .task { await viewModel.load() }
                .sheet(isPresented: $showCreate) {
                    CreateListingView(
                        repository: dependencies.listingRepository,
                        photoStore: dependencies.photoStore,
                        visionAssist: dependencies.visionAssist
                    ) { _ in
                        Task { await viewModel.load() }
                    }
                }
                .sheet(item: $listingToEdit) { listing in
                    CreateListingView(
                        repository: dependencies.listingRepository,
                        photoStore: dependencies.photoStore,
                        visionAssist: dependencies.visionAssist,
                        editing: listing
                    ) { _ in
                        Task { await viewModel.load() }
                    }
                }
                .confirmationDialog(
                    "Delete this listing?",
                    isPresented: Binding(
                        get: { listingToDelete != nil },
                        set: { if !$0 { listingToDelete = nil } }
                    ),
                    titleVisibility: .visible,
                    presenting: listingToDelete
                ) { listing in
                    Button("Delete Listing", role: .destructive) {
                        Task { _ = await viewModel.delete(listing) }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: { listing in
                    Text("“\(listing.title)” and its photos will be removed from this device.")
                }
                .confirmationDialog("Reset sample data?", isPresented: $showResetConfirmation, titleVisibility: .visible) {
                    Button("Reset Everything", role: .destructive) {
                        Task { _ = await viewModel.resetSampleData() }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This replaces all listings on this device, including your own, with the original sample listings. It can't be undone.")
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let message = viewModel.errorMessage {
            ContentUnavailableView {
                Label("Something went wrong", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") {
                    viewModel.dismissError()
                    Task { await viewModel.load() }
                }
            }
        } else if !viewModel.hasLoaded {
            ProgressView("Loading your listings…")
        } else if viewModel.listings.isEmpty {
            ContentUnavailableView {
                Label("No listings yet", systemImage: "tray")
            } description: {
                Text("Items you add on this device will show up here, where you can edit or delete them.")
            } actions: {
                Button("Add a Listing") { showCreate = true }
                    .buttonStyle(.borderedProminent)
            }
        } else {
            List {
                ForEach(viewModel.listings) { listing in
                    NavigationLink(value: listing) {
                        ListingCard(listing: listing, photoStore: dependencies.photoStore)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            listingToDelete = listing
                        }
                        Button("Edit", systemImage: "pencil") {
                            listingToEdit = listing
                        }
                        .tint(.accentColor)
                    }
                    .contextMenu {
                        Button("Edit", systemImage: "pencil") { listingToEdit = listing }
                        Button("Delete", systemImage: "trash", role: .destructive) { listingToDelete = listing }
                    }
                }
            }
            .listStyle(.plain)
            .refreshable { await viewModel.load() }
        }
    }
}

#Preview {
    MyListingsView(dependencies: .preview())
}
