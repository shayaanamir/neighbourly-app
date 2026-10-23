//
//  ForgotPasswordView.swift
//  neighbourly
//

import SwiftUI

struct ForgotPasswordView: View {
    @Environment(AuthViewModel.self) private var auth

    @State private var email: String
    @State private var attempted = false
    @State private var didSend = false

    init(email: String = "") {
        _email = State(initialValue: email)
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    FormErrorText(message: attempted ? AuthValidation.email(email) : nil)
                }
            } footer: {
                Text("We'll email you a link to choose a new password.")
            }
            .listRowBackground(Theme.Colors.cardBackground)

            if didSend {
                Section {
                    // Same wording whether or not the address has an account.
                    Label(
                        "If an account exists for that email, a reset link is on its way. Check your spam folder too.",
                        systemImage: "checkmark.circle"
                    )
                    .font(Theme.Typography.subheadline)
                    .foregroundStyle(Theme.Colors.donate)
                }
                .listRowBackground(Theme.Colors.cardBackground)
            } else if let message = auth.errorMessage, attempted, AuthValidation.email(email) == nil {
                Section { FormErrorText(message: message) }
                .listRowBackground(Theme.Colors.cardBackground)
            }

            Section {
                AuthSubmitButton(title: didSend ? "Send Again" : "Send Reset Link", isWorking: auth.isWorking) {
                    attempted = true
                    guard AuthValidation.email(email) == nil else { return }
                    Task { didSend = await auth.sendPasswordReset(email: email) }
                }
            }
        }
        .warmForm()
        .navigationTitle("Reset Password")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { auth.clearError() }
    }
}

#Preview {
    NavigationStack {
        ForgotPasswordView()
    }
    .environment(AuthViewModel(service: MockAuthService()))
}
