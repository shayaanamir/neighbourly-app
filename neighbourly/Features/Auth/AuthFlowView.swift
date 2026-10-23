//
//  AuthFlowView.swift
//  neighbourly
//
//  The sheet shown when a guest taps something that needs an account.
//  Root screen is Sign In, with links to Create Account and Forgot Password.
//

import SwiftUI

struct AuthFlowView: View {
    @Environment(AuthViewModel.self) private var auth

    enum Route: Hashable {
        case signIn
        case signUp
        case forgotPassword(prefillEmail: String)
    }

    /// The screen for a route; shared with the welcome screen, which pushes the same ones.
    @ViewBuilder
    static func destination(for route: Route) -> some View {
        switch route {
        case .signIn:
            SignInView()
        case .signUp:
            SignUpView()
        case .forgotPassword(let email):
            ForgotPasswordView(email: email)
        }
    }

    var body: some View {
        NavigationStack {
            SignInView()
                .navigationDestination(for: Route.self) { route in
                    Self.destination(for: route)
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { auth.isPresentingAuth = false }
                    }
                }
        }
        .onAppear { auth.clearError() }
    }
}

/// Inline error line used by all the auth forms.
struct FormErrorText: View {
    let message: String?

    var body: some View {
        if let message {
            Label(message, systemImage: "exclamationmark.circle")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.danger)
                .accessibilityLabel("Error: \(message)")
        }
    }
}

/// Full-width primary button that shows a spinner while the action runs.
struct AuthSubmitButton: View {
    let title: String
    let isWorking: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Spacer()
                if isWorking {
                    ProgressView()
                        .tint(Theme.Colors.onAccent)
                } else {
                    Text(title).fontWeight(.semibold)
                }
                Spacer()
            }
        }
        .buttonStyle(.warmProminent)
        .disabled(isWorking)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }
}
