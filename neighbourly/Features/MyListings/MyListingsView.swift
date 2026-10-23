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
    @Environment(AuthViewModel.self) private var auth
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
                        Task { await viewModel.load(for: auth.user?.uid) }
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button { auth.requireSignIn { showCreate = true } } label: {
                            Label("Add Listing", systemImage: "plus")
                        }
                    }
                    ToolbarItem(placement: .secondaryAction) {
                        Button("Reset Sample Data", systemImage: "arrow.counterclockwise", role: .destructive) {
                            showResetConfirmation = true
                        }
                    }
                }
                .task(id: auth.user?.uid) { await viewModel.load(for: auth.user?.uid) }
                .sheet(isPresented: $showCreate) {
                    CreateListingView(
                        repository: dependencies.listingRepository,
                        photoStore: dependencies.photoStore,
                        visionAssist: dependencies.visionAssist,
                        defaultSellerName: auth.user?.displayName,
                        sellerID: auth.user?.uid
                    ) { _ in
                        Task { await viewModel.load(for: auth.user?.uid) }
                    }
                }
                .sheet(item: $listingToEdit) { listing in
                    CreateListingView(
                        repository: dependencies.listingRepository,
                        photoStore: dependencies.photoStore,
                        visionAssist: dependencies.visionAssist,
                        editing: listing
                    ) { _ in
                        Task { await viewModel.load(for: auth.user?.uid) }
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
                .confirmationDialog("Reset the sample listings?", isPresented: $showResetConfirmation, titleVisibility: .visible) {
                    Button("Reset Samples", role: .destructive) {
                        Task { _ = await viewModel.resetSampleData(for: auth.user?.uid) }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This restores the original sample listings on this device. Listings you posted to your account are not affected.")
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if auth.session == .loading {
            ProgressView()
        } else if !auth.isSignedIn {
            SignInPromptView(
                title: "Sign in to see your listings",
                message: "Listings you post live in your account, where you can edit or delete them."
            )
        } else if let message = viewModel.errorMessage {
            ContentUnavailableView {
                Label("Something went wrong", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") {
                    viewModel.dismissError()
                    Task { await viewModel.load(for: auth.user?.uid) }
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
                Button("Add a Listing") { auth.requireSignIn { showCreate = true } }
                    .buttonStyle(.warmCompact)
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
            .warmForm()
            .refreshable { await viewModel.load(for: auth.user?.uid) }
        }
    }
}

#Preview {
    let dependencies = AppDependencies.preview()
    MyListingsView(dependencies: dependencies)
        .environment(AuthViewModel(service: dependencies.authService, isCloudBacked: false))
}
