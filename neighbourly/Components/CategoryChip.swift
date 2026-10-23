//
//  CategoryChip.swift
//  neighbourly
//

import SwiftUI

/// Toggleable filter chip used in Browse's filter bar.
struct CategoryChip: View {
    let title: String
    var systemImage: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let systemImage {
                    Label(title, systemImage: systemImage)
                } else {
                    Text(title)
                }
            }
            .font(Theme.Typography.subheadline)
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.s)
            .foregroundStyle(isSelected ? Theme.Colors.onAccent : Theme.Colors.primaryText)
            .background(
                isSelected ? Theme.Colors.accent : Theme.Colors.cardBackground,
                in: Capsule()
            )
            .overlay {
                Capsule().strokeBorder(isSelected ? Color.clear : Theme.Colors.separator)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(isSelected ? "Removes this filter" : "Filters listings")
    }
}

#Preview {
    HStack {
        CategoryChip(title: "Books", systemImage: "book", isSelected: true) {}
        CategoryChip(title: "Sell", isSelected: false) {}
    }
    .padding()
}
