//
//  Theme.swift
//  neighbourly
//
//  Shared design tokens. Colors are system/semantic colors so Light and
//  Dark Mode both work without extra assets; fonts are Dynamic Type styles.
//

import SwiftUI
import UIKit

enum Theme {
    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
    }

    enum Colors {
        static let accent = Color.accentColor
        static let background = Color(uiColor: .systemBackground)
        static let groupedBackground = Color(uiColor: .systemGroupedBackground)
        static let cardBackground = Color(uiColor: .secondarySystemGroupedBackground)
        static let primaryText = Color.primary
        static let secondaryText = Color.secondary
        static let separator = Color(uiColor: .separator)

        // Listing mode tints (sell / exchange / donate).
        static let sell = Color.indigo
        static let exchange = Color.orange
        static let donate = Color.green
    }

    enum Typography {
        static let largeTitle = Font.largeTitle.weight(.bold)
        static let title = Font.title2.weight(.semibold)
        static let headline = Font.headline
        static let body = Font.body
        static let subheadline = Font.subheadline
        static let caption = Font.caption
        static let price = Font.headline.monospacedDigit()
    }
}

/// Rounded card container used by listing cards and detail sections.
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Theme.Spacing.m)
            .background(Theme.Colors.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.m))
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}
