//
//  WelcomeView.swift
//  neighbourly
//
//  The first screen when nobody is signed in: the app's name in script, a warm
//  illustration, and the choice to create an account or sign in. Browsing as a guest
//  is a quiet option underneath (see `RootView.allowsGuestBrowsing`).
//

import SwiftUI

struct WelcomeView: View {
    let allowsGuest: Bool
    let onContinueAsGuest: () -> Void

    @Environment(AuthViewModel.self) private var auth

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: Theme.Spacing.xl) {
                        Spacer(minLength: Theme.Spacing.l)
                        hero
                        titleBlock
                        Spacer(minLength: Theme.Spacing.l)
                        actions
                        if !auth.isCloudBacked {
                            DemoModeNotice()
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.vertical, Theme.Spacing.xl)
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .background(
                LinearGradient(
                    colors: [Theme.Colors.background, Theme.Colors.groupedBackground],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: AuthFlowView.Route.self) { route in
                AuthFlowView.destination(for: route)
            }
        }
        .onAppear { auth.clearError() }
    }

    // MARK: - Pieces

    private var titleBlock: some View {
        VStack(spacing: Theme.Spacing.s) {
            Text("Neighbourly")
                .font(Theme.Typography.script(64, relativeTo: .largeTitle))
                .foregroundStyle(Theme.Colors.accent)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)

            Text("Give everyday things a second life, right in your neighbourhood.")
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
    }

    private var actions: some View {
        VStack(spacing: Theme.Spacing.m) {
            NavigationLink(value: AuthFlowView.Route.signUp) {
                Text("Create an account")
            }
            .buttonStyle(.warmProminent)

            NavigationLink(value: AuthFlowView.Route.signIn) {
                Text("I already have an account")
            }
            .buttonStyle(.warmOutline)

            if allowsGuest {
                Button("Just looking? Continue as a guest", action: onContinueAsGuest)
                    .font(Theme.Typography.subheadline)
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .padding(.top, Theme.Spacing.s)
            }
        }
    }

    /// A house surrounded by the three ways to pass something on. Decorative only.
    private var hero: some View {
        ZStack {
            Circle()
                .fill(Theme.Colors.accent.opacity(0.12))
                .frame(width: 224, height: 224)
            Circle()
                .fill(Theme.Colors.cardBackground)
                .frame(width: 148, height: 148)
                .shadow(color: Theme.Colors.shadow, radius: 10, y: 4)
            Image(systemName: "house.fill")
                .font(.system(size: 62))
                .foregroundStyle(Theme.Colors.accent)

            badge("gift.fill", tint: Theme.Colors.donate)
                .offset(x: 84, y: -66)
            badge("arrow.left.arrow.right", tint: Theme.Colors.exchange)
                .offset(x: -92, y: -34)
            badge("tag.fill", tint: Theme.Colors.sell)
                .offset(x: 62, y: 80)
        }
        .frame(height: 240)
        .accessibilityHidden(true)
    }

    private func badge(_ systemImage: String, tint: Color) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 52, height: 52)
            .background(Theme.Colors.cardBackground, in: Circle())
            .shadow(color: Theme.Colors.shadow, radius: 6, y: 3)
    }
}

/// Shown for a moment at launch while the saved session (if any) is restored, so a
/// signed-in person never sees the welcome screen flash by.
struct LaunchView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.l) {
            Text("Neighbourly")
                .font(Theme.Typography.script(64, relativeTo: .largeTitle))
                .foregroundStyle(Theme.Colors.accent)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            ProgressView()
                .tint(Theme.Colors.accent)
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.background.ignoresSafeArea())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Neighbourly, loading")
    }
}

#Preview("Welcome") {
    WelcomeView(allowsGuest: true, onContinueAsGuest: {})
        .environment(AuthViewModel(service: MockAuthService(), isCloudBacked: false))
}

#Preview("Launch") {
    LaunchView()
}
