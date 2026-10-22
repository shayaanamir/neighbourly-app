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
    /// False when this screen was opened from the chat about the same listing, so Message
    /// Seller can't open that chat a second time on top of itself.
    let allowsMessaging: Bool

    @State private var listing: Listing
    @State private var showEditor = false
    @State private var showDeleteConfirmation = false
    @State private var showContactDetails = false
    @State private var errorMessage: String?
    @State private var conversationToOpen: Conversation?
    @State private var isStartingChat = false
    @State private var chatErrorMessage: String?

    @Environment(\.dismiss) private var dismiss
    @Environment(AuthViewModel.self) private var auth

    init(
        listing: Listing,
        dependencies: AppDependencies,
        allowsMessaging: Bool = true,
        onChanged: @escaping () -> Void = {}
    ) {
        _listing = State(initialValue: listing)
        self.dependencies = dependencies
        self.allowsMessaging = allowsMessaging
        self.onChanged = onChanged
    }

    /// Only the account that posted a listing can edit or delete it (the database rules
    /// enforce the same thing; this just hides buttons that wouldn't work).
    private var isOwnListing: Bool {
        guard let sellerID = listing.sellerID, let uid = auth.user?.uid else { return false }
        return sellerID == uid
    }

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
        .navigationDestination(item: $conversationToOpen) { conversation in
            if let user = auth.user {
                ConversationView(conversation: conversation, user: user, dependencies: dependencies)
            }
        }
        .alert("Couldn't start chat", isPresented: Binding(
            get: { chatErrorMessage != nil },
            set: { if !$0 { chatErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(chatErrorMessage ?? "")
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
                    StoredPhotoView(
                        fileName: fileName,
                        listingID: listing.id,
                        photoStore: dependencies.photoStore,
                        repository: dependencies.listingRepository
                    )
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

            switch ChatEligibility.check(listing: listing, user: auth.user) {
            case .canMessage, .signInRequired:
                if allowsMessaging { messageSellerButton }

            case .ownListing:
                Label(
                    "This is your listing. When someone messages you about it, the chat appears in the Messages tab.",
                    systemImage: "info.circle"
                )
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.secondaryText)

            case .sampleListing:
                sampleContact
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var messageSellerButton: some View {
        Button {
            auth.requireSignIn { Task { await startChat() } }
        } label: {
            HStack {
                if isStartingChat {
                    ProgressView()
                } else {
                    Label("Message Seller", systemImage: "bubble.left.and.bubble.right")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(isStartingChat)
    }

    /// Sample listings have fictional sellers, and listings saved before accounts existed
    /// have no account to message, so both keep the share-sheet contact.
    @ViewBuilder
    private var sampleContact: some View {
        if listing.isDemo {
            Label(
                "Demo listing. This seller is fictional, so there's no one to message. Contact Seller only opens the share sheet with a draft message; nothing is sent from the app.",
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

    private func startChat() async {
        guard let user = auth.user, !isStartingChat else { return }
        isStartingChat = true
        defer { isStartingChat = false }
        do {
            conversationToOpen = try await dependencies.chatRepository.startConversation(listing: listing, buyer: user)
        } catch {
            chatErrorMessage = (error as? LocalizedError)?.errorDescription ?? ChatError.unknown.errorDescription
        }
    }

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
    let dependencies = AppDependencies.preview()
    NavigationStack {
        ListingDetailView(listing: SampleListings.make()[0], dependencies: dependencies)
    }
    .environment(AuthViewModel(service: dependencies.authService, isCloudBacked: false))
}
