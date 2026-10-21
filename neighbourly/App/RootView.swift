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
        BrowseView(repository: dependencies.listingRepository)
    }
}

#Preview {
    RootView(dependencies: .preview())
}
