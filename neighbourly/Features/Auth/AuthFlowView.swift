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
        case signUp
        case forgotPassword(prefillEmail: String)
    }

    var body: some View {
        NavigationStack {
            SignInView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .signUp:
                        SignUpView()
                    case .forgotPassword(let email):
                        ForgotPasswordView(email: email)
                    }
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
