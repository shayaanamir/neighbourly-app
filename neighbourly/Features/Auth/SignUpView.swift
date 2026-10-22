//
//  SignUpView.swift
//  neighbourly
//

import SwiftUI

struct SignUpView: View {
    @Environment(AuthViewModel.self) private var auth

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmation = ""
    @State private var attempted = false

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    TextField("Display name", text: $name)
                        .textContentType(.name)
                    FormErrorText(message: attempted ? AuthValidation.displayName(name) : nil)
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    FormErrorText(message: attempted ? AuthValidation.email(email) : nil)
                }
            } header: {
                Text("About you")
            } footer: {
                Text("Your display name is shown to people you chat with. Your email stays private.")
            }

            Section {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    SecureField("Password", text: $password)
                        .textContentType(.newPassword)
                    FormErrorText(message: attempted ? AuthValidation.newPassword(password) : nil)
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    SecureField("Confirm password", text: $confirmation)
                        .textContentType(.newPassword)
                    FormErrorText(message: attempted ? AuthValidation.confirmation(confirmation, matches: password) : nil)
                }
            } header: {
                Text("Password")
            } footer: {
                Text("At least \(AuthValidation.minPasswordLength) characters.")
            }

            if let message = auth.errorMessage, attempted, isFormValid {
                Section { FormErrorText(message: message) }
            }

            Section {
                AuthSubmitButton(title: "Create Account", isWorking: auth.isWorking) {
                    attempted = true
                    guard isFormValid else { return }
                    Task {
                        _ = await auth.signUp(name: name, email: email, password: password, confirmation: confirmation)
                    }
                }
            }
        }
        .navigationTitle("Create Account")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { auth.clearError() }
    }

    private var isFormValid: Bool {
        AuthValidation.displayName(name) == nil
            && AuthValidation.email(email) == nil
            && AuthValidation.newPassword(password) == nil
            && AuthValidation.confirmation(confirmation, matches: password) == nil
    }
}

#Preview {
    NavigationStack {
        SignUpView()
    }
    .environment(AuthViewModel(service: MockAuthService()))
}
