//
//  AccountView.swift
//  neighbourly
//
//  Account tab: who you're signed in as, sign out, and account deletion.
//

import SwiftUI

struct AccountView: View {
    /// Used to remove the person's shared listings when they delete their account.
    let listingRepository: any ListingRepository

    @Environment(AuthViewModel.self) private var auth

    @State private var showSignOutConfirmation = false
    @State private var showDeleteAlert = false
    @State private var deletePassword = ""

    var body: some View {
        NavigationStack {
            Group {
                switch auth.session {
                case .loading:
                    ProgressView()
                case .signedOut:
                    SignInPromptView(
                        title: "You're browsing as a guest",
                        message: "Create an account to post listings and message sellers.",
                        systemImage: "person.crop.circle"
                    )
                case .signedIn(let user):
                    accountList(for: user)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.Colors.groupedBackground)
            .navigationTitle("Account")
        }
    }

    private func accountList(for user: AppUser) -> some View {
        List {
            Section {
                HStack(spacing: Theme.Spacing.m) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Theme.Colors.accent)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(verbatim: user.displayName)
                            .font(Theme.Typography.headline)
                        if let email = user.email {
                            Text(verbatim: email)
                                .font(Theme.Typography.subheadline)
                                .foregroundStyle(Theme.Colors.secondaryText)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
            } footer: {
                Text("Your display name is shown to people you chat with. Your email is only visible to you.")
            }
            .listRowBackground(Theme.Colors.cardBackground)

            if !auth.isCloudBacked {
                Section { DemoModeNotice() }
                .listRowBackground(Theme.Colors.cardBackground)
            }

            if let message = auth.errorMessage {
                Section { FormErrorText(message: message) }
                .listRowBackground(Theme.Colors.cardBackground)
            }

            Section {
                Button("Sign Out", systemImage: "rectangle.portrait.and.arrow.right") {
                    showSignOutConfirmation = true
                }
                Button("Delete Account", systemImage: "trash", role: .destructive) {
                    deletePassword = ""
                    auth.clearError()
                    showDeleteAlert = true
                }
            }
            .listRowBackground(Theme.Colors.cardBackground)
        }
        .warmForm()
        .confirmationDialog("Sign out of Neighbourly?", isPresented: $showSignOutConfirmation, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) { auth.signOut() }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Delete your account?", isPresented: $showDeleteAlert) {
            SecureField("Password", text: $deletePassword)
            Button("Delete Account", role: .destructive) {
                let password = deletePassword
                deletePassword = ""
                let userID = auth.user?.uid
                Task {
                    _ = await auth.deleteAccount(password: password) {
                        if let userID {
                            try await listingRepository.deleteAllListings(ownedBy: userID)
                        }
                    }
                }
            }
            Button("Cancel", role: .cancel) { deletePassword = "" }
        } message: {
            Text("This permanently deletes your account, profile, and the listings you posted. Messages you sent may remain visible to the people you wrote to. Enter your password to confirm. This can't be undone.")
        }
    }
}

#Preview("Signed in") {
    let service = MockAuthService()
    service.seedAccount(name: "Asha", email: "asha@example.com", password: "password1", signedIn: true)
    let auth = AuthViewModel(service: service, isCloudBacked: false)
    return AccountView(listingRepository: InMemoryListingRepository())
        .environment(auth)
        .task { await auth.start() }
}

#Preview("Guest") {
    let auth = AuthViewModel(service: MockAuthService())
    return AccountView(listingRepository: InMemoryListingRepository())
        .environment(auth)
        .task { await auth.start() }
}
