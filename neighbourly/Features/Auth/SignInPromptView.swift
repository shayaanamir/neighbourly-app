//
//  SignInPromptView.swift
//  neighbourly
//
//  Placeholder for screens that need an account when nobody is signed in.
//

import SwiftUI

struct SignInPromptView: View {
    let title: String
    let message: String
    var systemImage = "person.crop.circle.badge.questionmark"

    @Environment(AuthViewModel.self) private var auth

    var body: some View {
        if auth.session == .loading {
            ProgressView()
        } else {
            ContentUnavailableView {
                Label(title, systemImage: systemImage)
            } description: {
                Text(message)
            } actions: {
                Button("Sign In or Create Account") { auth.requireSignIn() }
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

#Preview {
    SignInPromptView(title: "Sign in to see your listings", message: "Your listings live in your account.")
        .environment(AuthViewModel(service: MockAuthService()))
}
