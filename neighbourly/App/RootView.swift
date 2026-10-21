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
        BrowseView(
            repository: dependencies.listingRepository,
            photoStore: dependencies.photoStore,
            locationService: dependencies.locationService
        )
    }
}

#Preview {
    RootView(dependencies: .preview())
}
