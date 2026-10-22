//
//  RootView.swift
//  neighbourly
//
//  App composition root: hands dependencies to feature screens.
//

import SwiftUI

struct RootView: View {
    let dependencies: AppDependencies
    @State private var auth: AuthViewModel
    @State private var inbox: InboxViewModel

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
        .environment(auth)
        .environment(inbox)
        // The inbox follows the signed-in account; it empties on sign-out and when switching
        // accounts, so one person's conversations are never shown to the next.
        .task(id: auth.user?.uid) { await inbox.run(userID: auth.user?.uid) }
        // Follows sign-in/out for the life of the app (restores a saved session at launch).
        .task { await auth.start() }
        .sheet(isPresented: $auth.isPresentingAuth, onDismiss: { auth.runPendingAction() }) {
            AuthFlowView()
                .environment(auth)
        }
    }
}

#Preview {
    RootView(dependencies: .preview())
}
