//
//  RootView.swift
//  neighbourly
//
//  App composition root: hands dependencies to feature screens.
//

import SwiftUI

struct RootView: View {
    let dependencies: AppDependencies

    var body: some View {
        TabView {
            BrowseView(dependencies: dependencies)
                .tabItem { Label("Browse", systemImage: "square.grid.2x2") }

            MyListingsView(dependencies: dependencies)
                .tabItem { Label("My Listings", systemImage: "tray.full") }
        }
    }
}

#Preview {
    RootView(dependencies: .preview())
}
