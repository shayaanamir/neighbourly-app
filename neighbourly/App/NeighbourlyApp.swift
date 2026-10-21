//
//  NeighbourlyApp.swift
//  neighbourly
//

import SwiftUI

@main
struct NeighbourlyApp: App {
    private let dependencies = AppDependencies.live()

    var body: some Scene {
        WindowGroup {
            RootView(dependencies: dependencies)
        }
    }
}
