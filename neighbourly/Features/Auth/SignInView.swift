//
//  SignInView.swift
//  neighbourly
//

import SwiftUI

struct SignInView: View {
    @Environment(AuthViewModel.self) private var auth

    @State private var email = ""
    @State private var password = ""
    @State private var attempted = false

    var body: some View {
        Form {
            Section {
                Text("Sign in to post listings and message sellers.")
                    .foregroundStyle(Theme.Colors.secondaryText)
                if !auth.isCloudBacked { DemoModeNotice() }
            }

            Section {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    FormErrorText(message: attempted ? AuthValidation.email(email) : nil)
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                    FormErrorText(message: attempted ? AuthValidation.existingPassword(password) : nil)
                }

                NavigationLink(value: AuthFlowView.Route.forgotPassword(prefillEmail: email)) {
                    Text("Forgot password?")
                        .font(Theme.Typography.subheadline)
                }
            }

            // Server-side failures (wrong password, offline, ...).
            if let message = auth.errorMessage, attempted, isFormValid {
                Section { FormErrorText(message: message) }
            }

            Section {
                AuthSubmitButton(title: "Sign In", isWorking: auth.isWorking) {
                    attempted = true
                    guard isFormValid else { return }
                    Task { _ = await auth.signIn(email: email, password: password) }
                }
            }

            Section {
                NavigationLink(value: AuthFlowView.Route.signUp) {
                    Label("Create an account", systemImage: "person.badge.plus")
                }
            } footer: {
                Text("You can keep browsing without an account.")
            }
        }
        .navigationTitle("Sign In")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var isFormValid: Bool {
        AuthValidation.email(email) == nil && AuthValidation.existingPassword(password) == nil
    }
}

/// Shown while Firebase isn't configured, so nobody mistakes demo accounts for real ones.
struct DemoModeNotice: View {
    var body: some View {
        Label(
            "Demo mode: accounts are kept in memory only and disappear when the app closes. Set up Firebase to use real accounts.",
            systemImage: "exclamationmark.triangle"
        )
        .font(Theme.Typography.caption)
        .foregroundStyle(.orange)
    }
}

#Preview {
    NavigationStack {
        SignInView()
    }
    .environment(AuthViewModel(service: MockAuthService(), isCloudBacked: false))
}
