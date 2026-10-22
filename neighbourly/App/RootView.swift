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

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _auth = State(initialValue: AuthViewModel(
            service: dependencies.authService,
            isCloudBacked: dependencies.isCloudBacked
        ))
    }

    var body: some View {
        @Bindable var auth = auth

        TabView {
            BrowseView(dependencies: dependencies)
                .tabItem { Label("Browse", systemImage: "square.grid.2x2") }

            MyListingsView(dependencies: dependencies)
                .tabItem { Label("My Listings", systemImage: "tray.full") }

            AccountView()
                .tabItem { Label("Account", systemImage: "person.crop.circle") }
        }
        .environment(auth)
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
