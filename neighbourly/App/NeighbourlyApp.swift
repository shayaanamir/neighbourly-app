//
//  NeighbourlyApp.swift
//  neighbourly
//

import SwiftUI

@main
struct NeighbourlyApp: App {
    private let dependencies = AppDependencies.live()

    init() {
        Theme.applyAppearance()
    }

    var body: some Scene {
        WindowGroup {
            RootView(dependencies: dependencies)
                .tint(Theme.Colors.accent)
                .fontDesign(.rounded)
                .foregroundStyle(Theme.Colors.primaryText)
        }
    }
}
