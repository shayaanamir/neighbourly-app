//
//  RootView.swift
//  neighbourly
//
//  App composition root. Dependencies (repository, services) will be
//  created here and injected into feature screens in later phases.
//

import SwiftUI

struct RootView: View {
    var body: some View {
        BrowseView()
    }
}

#Preview {
    RootView()
}
