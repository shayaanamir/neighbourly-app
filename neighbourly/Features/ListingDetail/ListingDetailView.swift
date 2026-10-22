//
//  ListingDetailView.swift
//  neighbourly
//
//  Full details for one listing: photo gallery, price, description, seller,
//  and a Contact Seller action. Listings created on this device can also be
//  edited or deleted from here.
//

import SwiftUI

struct ListingDetailView: View {
    let dependencies: AppDependencies
    /// Called after an edit or delete so list screens can reload.
    let onChanged: () -> Void

    @State private var listing: Listing
    @State private var showEditor = false
    @State private var showDeleteConfirmation = false
    @State private var showContactDetails = false
    @State private var errorMessage: String?

    @Environment(\.dismiss) private var dismiss

    init(listing: Listing, dependencies: AppDependencies, onChanged: @escaping () -> Void = {}) {
        _listing = State(initialValue: listing)
        self.dependencies = dependencies
        self.onChanged = onChanged
    }

    private var isOwnListing: Bool { !listing.isDemo }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                gallery

                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    header
                    if !listing.description.isEmpty { descriptionSection }
                    sellerSection
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.bottom, Theme.Spacing.xl)
            }
        }
        .background(Theme.Colors.groupedBackground)
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isOwnListing {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Edit", systemImage: "pencil") { showEditor = true }
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            showDeleteConfirmation = true
                        }
                    } label: {
                        Label("Actions", systemImage: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            CreateListingView(
                repository: dependencies.listingRepository,
                photoStore: dependencies.photoStore,
                visionAssist: dependencies.visionAssist,
                editing: listing
            ) { updated in
                listing = updated
                onChanged()
            }
        }
        .confirmationDialog("Delete this listing?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Listing", role: .destructive) { Task { await delete() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("“\(listing.title)” and its photos will be removed from this device.")
        }
        .alert("Couldn't delete listing", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Gallery

    @ViewBuilder
    private var gallery: some View {
        if listing.imageFileNames.isEmpty {
            Theme.Colors.accent.opacity(0.12)
                .frame(height: 220)
                .overlay {
                    VStack(spacing: Theme.Spacing.s) {
                        Image(systemName: listing.category.systemImage)
                            .font(.system(size: 48))
                        Text("No photos")
                            .font(Theme.Typography.caption)
                    }
                    .foregroundStyle(Theme.Colors.accent)
                }
                .accessibilityLabel("No photos for this listing")
        } else {
            TabView {
                ForEach(Array(listing.imageFileNames.enumerated()), id: \.element) { index, fileName in
                    StoredPhotoView(fileName: fileName, photoStore: dependencies.photoStore)
                        .accessibilityLabel("Photo \(index + 1) of \(listing.imageFileNames.count)")
                }
            }
            .tabViewStyle(.page(indexDisplayMode: listing.imageFileNames.count > 1 ? .always : .never))
            .frame(height: 300)
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(listing.title)
                .font(Theme.Typography.title)
                .fixedSize(horizontal: false, vertical: true)

            Text(listing.priceText())
                .font(Theme.Typography.price)
                .foregroundStyle(listing.mode.tint)

            HStack(spacing: Theme.Spacing.s) {
                ModeBadge(mode: listing.mode)
                Text(listing.condition.displayName)
                    .font(Theme.Typography.caption)
                    .padding(.horizontal, Theme.Spacing.s)
                    .padding(.vertical, Theme.Spacing.xs / 2)
                    .background(Theme.Colors.cardBackground, in: Capsule())
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Label(listing.category.displayName, systemImage: listing.category.systemImage)
                Label(listing.areaText, systemImage: "mappin.and.ellipse")
                Label("Listed \(listing.createdAt.formatted(.relative(presentation: .named)))", systemImage: "clock")
            }
            .font(Theme.Typography.subheadline)
            .foregroundStyle(Theme.Colors.secondaryText)
        }
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("Description")
                .font(Theme.Typography.headline)
            Text(verbatim: listing.description)
                .font(Theme.Typography.body)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .cardStyle()
    }

    private var sellerSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text("Seller")
                .font(Theme.Typography.headline)

            Label(listing.sellerName, systemImage: "person.circle")

            if listing.isDemo {
                Label(
                    "Demo listing. This seller is fictional and has no real contact details. Contact Seller only opens the share sheet with a draft message; nothing is sent from the app.",
                    systemImage: "info.circle"
                )
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.secondaryText)
            }

            ShareLink(
                item: ContactService.message(for: listing),
                subject: Text(ContactService.subject(for: listing)),
                message: Text(ContactService.message(for: listing))
            ) {
                Label("Contact Seller", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            contactDetails
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    /// The seller's own email/phone stays hidden until the user asks to see it.
    @ViewBuilder
    private var contactDetails: some View {
        if let contact = listing.sellerContact, !contact.isEmpty, !listing.isDemo {
            if showContactDetails {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    Text(verbatim: contact)
                        .textSelection(.enabled)
                    if let action = ContactService.action(for: listing) {
                        Link(destination: action.url) {
                            Label(action.title, systemImage: action.systemImage)
                        }
                    }
                }
            } else {
                Button("Show contact details") { showContactDetails = true }
                    .font(Theme.Typography.subheadline)
            }
        }
    }

    // MARK: - Actions

    private func delete() async {
        do {
            try await dependencies.listingRepository.delete(id: listing.id)
            onChanged()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        ListingDetailView(listing: SampleListings.make()[0], dependencies: .preview())
    }
}
