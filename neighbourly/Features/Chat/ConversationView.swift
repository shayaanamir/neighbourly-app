//
//  ConversationView.swift
//  neighbourly
//
//  One chat: message bubbles grouped by day, a composer, and a link back to the listing.
//

import SwiftUI

struct ConversationView: View {
    let dependencies: AppDependencies

    @State private var viewModel: ConversationViewModel
    @State private var listingToShow: Listing?
    @State private var showListingMissing = false

    init(conversation: Conversation, user: AppUser, dependencies: AppDependencies) {
        self.dependencies = dependencies
        _viewModel = State(initialValue: ConversationViewModel(
            conversation: conversation,
            currentUser: user,
            chat: dependencies.chatRepository
        ))
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    if viewModel.loadFailed {
                        Label(
                            "Couldn't load this conversation. Check your connection and reopen it.",
                            systemImage: "exclamationmark.triangle"
                        )
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(.red)
                        .padding(.vertical, Theme.Spacing.m)
                    } else if viewModel.hasLoaded && viewModel.items.isEmpty {
                        emptyState
                    }

                    ForEach(viewModel.days) { day in
                        Text(ChatTimeline.dayTitle(for: day.id))
                            .font(Theme.Typography.caption.weight(.semibold))
                            .foregroundStyle(Theme.Colors.secondaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.s)

                        ForEach(day.items) { item in
                            MessageBubble(
                                item: item,
                                isMine: viewModel.isFromCurrentUser(item),
                                senderName: viewModel.otherName,
                                onRetry: { Task { await viewModel.retry(item.id) } },
                                onDiscard: { viewModel.discard(item.id) }
                            )
                            .id(item.id)
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.vertical, Theme.Spacing.s)
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.items.last?.id) { _, newest in
                guard let newest else { return }
                withAnimation(.snappy) { proxy.scrollTo(newest, anchor: .bottom) }
            }
        }
        .background(Theme.Colors.groupedBackground)
        .safeAreaInset(edge: .top, spacing: 0) { listingBar }
        .safeAreaInset(edge: .bottom, spacing: 0) { composer }
        .navigationTitle(viewModel.otherName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $listingToShow) { listing in
            // allowsMessaging is off so the listing can't open this same chat again.
            ListingDetailView(listing: listing, dependencies: dependencies, allowsMessaging: false)
        }
        .alert("Listing unavailable", isPresented: $showListingMissing) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This listing is no longer available. It may have been removed by its owner.")
        }
        .task { await viewModel.start() }
        .onAppear {
            viewModel.isActive = true
            Task { await viewModel.markReadIfNeeded() }
        }
        .onDisappear { viewModel.isActive = false }
    }

    // MARK: - Pieces

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.s) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.largeTitle)
            Text("No messages yet")
                .font(Theme.Typography.headline)
            Text("Say hello to \(viewModel.otherName) to get the conversation started.")
                .font(Theme.Typography.subheadline)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(Theme.Colors.secondaryText)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xxl)
    }

    private var listingBar: some View {
        Button(action: openListing) {
            HStack {
                Label {
                    Text(verbatim: viewModel.conversation.listingTitle)
                        .lineLimit(1)
                } icon: {
                    Image(systemName: "tag")
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
            }
            .font(Theme.Typography.subheadline)
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, Theme.Spacing.s)
            .background(.bar)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("About listing: \(viewModel.conversation.listingTitle)")
        .accessibilityHint("Opens the listing")
    }

    private var composer: some View {
        VStack(spacing: Theme.Spacing.xs) {
            if viewModel.isOverLimit || viewModel.remainingCharacters <= 100 {
                Text("\(viewModel.remainingCharacters)")
                    .font(Theme.Typography.caption.monospacedDigit())
                    .foregroundStyle(viewModel.isOverLimit ? Color.red : Theme.Colors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .accessibilityLabel(viewModel.isOverLimit
                        ? "\(-viewModel.remainingCharacters) characters over the limit"
                        : "\(viewModel.remainingCharacters) characters left")
            }

            HStack(alignment: .bottom, spacing: Theme.Spacing.s) {
                TextField("Message", text: $viewModel.draft, axis: .vertical)
                    .lineLimit(1...5)
                    .padding(.horizontal, Theme.Spacing.m)
                    .padding(.vertical, Theme.Spacing.s)
                    .background(Theme.Colors.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.l))

                Button {
                    Task { await viewModel.send() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 34))
                }
                .disabled(!viewModel.canSend)
                .accessibilityLabel("Send message")
            }
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.vertical, Theme.Spacing.s)
        .background(.bar)
    }

    private func openListing() {
        let id = viewModel.conversation.listingID
        Task {
            let listings = (try? await dependencies.listingRepository.fetchListings()) ?? []
            if let listing = listings.first(where: { $0.id == id }) {
                listingToShow = listing
            } else {
                showListingMissing = true
            }
        }
    }
}

#Preview {
    let dependencies = AppDependencies.preview()
    let conversation = Conversation(
        id: "preview", listingID: UUID(), listingTitle: "Study table with drawer",
        sellerID: "seller", buyerID: "buyer", sellerName: "Asha", buyerName: "Bob"
    )
    NavigationStack {
        ConversationView(
            conversation: conversation,
            user: AppUser(uid: "buyer", displayName: "Bob", email: nil),
            dependencies: dependencies
        )
    }
    .environment(AuthViewModel(service: dependencies.authService, isCloudBacked: false))
}
