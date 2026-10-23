//
//  Theme.swift
//  neighbourly
//
//  The app's look: a warm, cozy palette (cream paper, terracotta, honey, sage, espresso
//  brown) with matching Dark Mode colors, soft rounded type, and generous corners.
//  Every screen takes its colors, fonts, and radii from here, so the whole look can be
//  changed in this one file. Fonts are Dynamic Type text styles, so they scale with the
//  user's text size.
//

import SwiftUI
import UIKit

// MARK: - Palette

/// The raw colors. Each is one dynamic color that switches between its light and dark value
/// with the system appearance. Contrast notes assume the usual pairings:
/// text on background/card, and `onAccent` on `accent`.
nonisolated enum Palette {
    /// A color with separate light-mode and dark-mode values, given as 0xRRGGBB.
    static func dynamic(light: UInt32, dark: UInt32, lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) -> UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark, alpha: darkAlpha)
                : UIColor(hex: light, alpha: lightAlpha)
        }
    }

    // Surfaces
    static let background = dynamic(light: 0xFBF4EA, dark: 0x1E1611)        // cream / dark roast
    static let groupedBackground = dynamic(light: 0xF3E7D6, dark: 0x271D16) // oat / mocha
    static let card = dynamic(light: 0xFFFBF5, dark: 0x33261D)              // warm white / cocoa
    static let separator = dynamic(light: 0xE6D5BF, dark: 0x4A3A2E)

    // Text (primary on cream is about 12:1; secondary is at least 4.5:1 on every surface)
    static let primaryText = dynamic(light: 0x3A2A20, dark: 0xF5E9DB)       // espresso / latte foam
    static let secondaryText = dynamic(light: 0x705B4C, dark: 0xC4AF9D)

    // Brand
    static let accent = dynamic(light: 0xB8502B, dark: 0xE8895F)            // terracotta / warm clay
    static let onAccent = dynamic(light: 0xFFF8F0, dark: 0x2B1A10)          // text on accent

    // Listing modes
    static let sell = dynamic(light: 0xB8502B, dark: 0xE8895F)              // terracotta
    static let exchange = dynamic(light: 0x8F5E12, dark: 0xE2A94A)          // honey
    static let donate = dynamic(light: 0x4F7A4A, dark: 0x8FBF88)            // sage

    // Feedback
    static let danger = dynamic(light: 0xB3392B, dark: 0xFF9C8A)
    static let warning = dynamic(light: 0x8F5E12, dark: 0xE2A94A)

    /// Soft shadow under cards: warm brown in light mode, deeper in dark mode.
    static let shadow = dynamic(light: 0x6B4423, dark: 0x000000, lightAlpha: 0.14, darkAlpha: 0.45)
}

private nonisolated extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

// MARK: - Tokens

enum Theme {
    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    /// Generous, soft corners.
    enum Radius {
        static let s: CGFloat = 10
        static let m: CGFloat = 16
        static let l: CGFloat = 22
    }

    enum Colors {
        static let accent = Color(uiColor: Palette.accent)
        static let onAccent = Color(uiColor: Palette.onAccent)
        static let background = Color(uiColor: Palette.background)
        static let groupedBackground = Color(uiColor: Palette.groupedBackground)
        static let cardBackground = Color(uiColor: Palette.card)
        static let primaryText = Color(uiColor: Palette.primaryText)
        static let secondaryText = Color(uiColor: Palette.secondaryText)
        static let separator = Color(uiColor: Palette.separator)
        static let danger = Color(uiColor: Palette.danger)
        static let warning = Color(uiColor: Palette.warning)
        static let shadow = Color(uiColor: Palette.shadow)

        // Listing mode tints (sell / exchange / donate).
        static let sell = Color(uiColor: Palette.sell)
        static let exchange = Color(uiColor: Palette.exchange)
        static let donate = Color(uiColor: Palette.donate)
    }

    /// Soft rounded type. Text styles keep Dynamic Type working.
    enum Typography {
        static let largeTitle = Font.system(.largeTitle, design: .rounded).weight(.bold)
        static let title = Font.system(.title2, design: .rounded).weight(.semibold)
        static let headline = Font.system(.headline, design: .rounded)
        static let body = Font.system(.body, design: .rounded)
        static let subheadline = Font.system(.subheadline, design: .rounded)
        static let caption = Font.system(.caption, design: .rounded)
        static let price = Font.system(.headline, design: .rounded).monospacedDigit()
    }

    /// Navigation bars, tab bar, and segmented controls are UIKit under the hood, so their
    /// warm colors and rounded titles are set once here at launch.
    @MainActor
    static func applyAppearance() {
        let navigation = UINavigationBarAppearance()
        navigation.configureWithOpaqueBackground()
        navigation.backgroundColor = Palette.background
        navigation.shadowColor = Palette.separator
        navigation.titleTextAttributes = [
            .foregroundColor: Palette.primaryText,
            .font: roundedFont(size: 17, weight: .semibold),
        ]
        navigation.largeTitleTextAttributes = [
            .foregroundColor: Palette.primaryText,
            .font: roundedFont(size: 34, weight: .bold),
        ]
        UINavigationBar.appearance().standardAppearance = navigation
        UINavigationBar.appearance().scrollEdgeAppearance = navigation
        UINavigationBar.appearance().compactAppearance = navigation

        let tabBar = UITabBarAppearance()
        tabBar.configureWithOpaqueBackground()
        tabBar.backgroundColor = Palette.background
        tabBar.shadowColor = Palette.separator
        for item in [tabBar.stackedLayoutAppearance, tabBar.inlineLayoutAppearance, tabBar.compactInlineLayoutAppearance] {
            item.normal.iconColor = Palette.secondaryText
            item.normal.titleTextAttributes = [.foregroundColor: Palette.secondaryText]
            item.selected.iconColor = Palette.accent
            item.selected.titleTextAttributes = [.foregroundColor: Palette.accent]
        }
        UITabBar.appearance().standardAppearance = tabBar
        UITabBar.appearance().scrollEdgeAppearance = tabBar

        let segmented = UISegmentedControl.appearance()
        segmented.backgroundColor = Palette.separator.withAlphaComponent(0.55)
        segmented.selectedSegmentTintColor = Palette.accent
        segmented.setTitleTextAttributes(
            [.foregroundColor: Palette.onAccent, .font: roundedFont(size: 14, weight: .semibold)],
            for: .selected
        )
        segmented.setTitleTextAttributes(
            [.foregroundColor: Palette.primaryText, .font: roundedFont(size: 14, weight: .medium)],
            for: .normal
        )
    }

    private static func roundedFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }
}

// MARK: - Containers

/// Soft rounded card with a gentle warm shadow, used by listing cards and detail sections.
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Theme.Spacing.m)
            .background(
                Theme.Colors.cardBackground,
                in: RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous)
                    .strokeBorder(Theme.Colors.separator.opacity(0.6), lineWidth: 0.5)
            }
            .shadow(color: Theme.Colors.shadow, radius: 8, x: 0, y: 3)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }

    /// Cream-colored backdrop for screens made of cards and custom layouts.
    func warmScreen() -> some View {
        background(Theme.Colors.groupedBackground.ignoresSafeArea())
    }

    /// For `Form` and `List` screens: replaces the system's cool grey with the warm backdrop.
    /// Add `.listRowBackground(Theme.Colors.cardBackground)` to its sections for warm rows.
    func warmForm() -> some View {
        scrollContentBackground(.hidden)
            .background(Theme.Colors.groupedBackground.ignoresSafeArea())
    }
}

// MARK: - Buttons

/// Terracotta pill button for the main action on a screen.
struct WarmProminentButtonStyle: ButtonStyle {
    var fullWidth = true

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.headline)
            .foregroundStyle(Theme.Colors.onAccent)
            .padding(.vertical, Theme.Spacing.m)
            .padding(.horizontal, Theme.Spacing.xl)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(
                Theme.Colors.accent.opacity(isEnabled ? 1 : 0.4),
                in: RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous)
            )
            .shadow(color: Theme.Colors.shadow, radius: configuration.isPressed ? 2 : 6, x: 0, y: configuration.isPressed ? 1 : 3)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

/// Small tinted button for secondary actions inside a card or form.
struct WarmSoftButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.subheadline.weight(.semibold))
            .foregroundStyle(Theme.Colors.accent.opacity(isEnabled ? 1 : 0.5))
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.s)
            .background(Theme.Colors.accent.opacity(configuration.isPressed ? 0.22 : 0.13), in: Capsule())
    }
}

extension ButtonStyle where Self == WarmProminentButtonStyle {
    /// Full-width main action.
    static var warmProminent: WarmProminentButtonStyle { WarmProminentButtonStyle() }
    /// Main action that is only as wide as its label.
    static var warmCompact: WarmProminentButtonStyle { WarmProminentButtonStyle(fullWidth: false) }
}

extension ButtonStyle where Self == WarmSoftButtonStyle {
    static var warmSoft: WarmSoftButtonStyle { WarmSoftButtonStyle() }
}
