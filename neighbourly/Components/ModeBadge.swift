//
//  ModeBadge.swift
//  neighbourly
//

import SwiftUI

/// Small tinted capsule showing Sell / Exchange / Donate.
struct ModeBadge: View {
    let mode: ListingMode

    var body: some View {
        Label(mode.displayName, systemImage: mode.systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(mode.tint)
            .padding(.horizontal, Theme.Spacing.s)
            .padding(.vertical, Theme.Spacing.xs / 2)
            .background(mode.tint.opacity(0.15), in: Capsule())
    }
}

#Preview {
    HStack {
        ForEach(ListingMode.allCases) { ModeBadge(mode: $0) }
    }
}
