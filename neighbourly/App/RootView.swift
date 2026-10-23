//
//  RootView.swift
//  neighbourly
//
//  App composition root: hands dependencies to feature screens.
//

import SwiftUI

/// Which top-level screen to show at launch and after signing in or out.
nonisolated enum AppEntry: Equatable {
    /// Still restoring a saved session.
    case launch
    /// The tab bar: for signed-in people, and for guests who chose to browse.
    case main
    /// The welcome screen with sign up and sign in.
    case welcome

    static func resolve(isLoading: Bool, isSignedIn: Bool, continuedAsGuest: Bool, allowsGuests: Bool) -> AppEntry {
        if isLoading { return .launch }
        if isSignedIn || (continuedAsGuest && allowsGuests) { return .main }
        return .welcome
    }
}

struct RootView: View {
    /// When true, the welcome screen offers "Continue as a guest" so people can browse
    /// without an account. Set to false to require signing in or signing up first.
    static let allowsGuestBrowsing = true

    let dependencies: AppDependencies
    @State private var auth: AuthViewModel
    @State private var inbox: InboxViewModel
    @State private var continuedAsGuest = false

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _auth = State(initialValue: AuthViewModel(
            service: dependencies.authService,
            isCloudBacked: dependencies.isCloudBacked
        ))
        _inbox = State(initialValue: InboxViewModel(chat: dependencies.chatRepository))
    }

    var body: some View {
        @Bindable var auth = auth

        Group {
            switch AppEntry.resolve(
                isLoading: auth.session == .loading,
                isSignedIn: auth.isSignedIn,
                continuedAsGuest: continuedAsGuest,
                allowsGuests: Self.allowsGuestBrowsing
            ) {
            case .launch:
                // Restoring a saved session takes a moment; don't flash the welcome screen.
                LaunchView()
            case .main:
                // One branch for signed-in people and guests, so signing in from the sheet keeps
                // the screen (and the action the person was in the middle of) in place.
                mainTabs
            case .welcome:
                WelcomeView(allowsGuest: Self.allowsGuestBrowsing) { continuedAsGuest = true }
            }
        }
        // Signing out sends people back to the welcome screen, not to a stale guest session.
        .onChange(of: auth.isSignedIn) { _, signedIn in
            if signedIn { continuedAsGuest = false }
        }
        .environment(auth)
        .environment(inbox)
        // The inbox follows the signed-in account; it empties on sign-out and when switching
        // accounts, so one person's conversations are never shown to the next.
        .task(id: "\(auth.user?.uid ?? "signed-out")#\(inbox.reloadToken)") {
            await inbox.run(userID: auth.user?.uid)
        }
        // Follows sign-in/out for the life of the app (restores a saved session at launch).
        .task { await auth.start() }
        .sheet(isPresented: $auth.isPresentingAuth, onDismiss: { auth.runPendingAction() }) {
            AuthFlowView()
                .environment(auth)
        }
    }

    private var mainTabs: some View {
        TabView {
            BrowseView(dependencies: dependencies)
                .tabItem { Label("Browse", systemImage: "square.grid.2x2") }

            MyListingsView(dependencies: dependencies)
                .tabItem { Label("My Listings", systemImage: "tray.full") }

            InboxView(dependencies: dependencies)
                .tabItem { Label("Messages", systemImage: "bubble.left.and.bubble.right") }
                .badge(inbox.unreadCount)

            AccountView(listingRepository: dependencies.listingRepository)
                .tabItem { Label("Account", systemImage: "person.crop.circle") }
        }
    }
}

#Preview {
    RootView(dependencies: .preview())
}
