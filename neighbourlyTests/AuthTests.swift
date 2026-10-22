//
//  AuthTests.swift
//  neighbourlyTests
//

import Foundation
import Testing
@testable import neighbourly

// MARK: - Validation

struct AuthValidationTests {
    @Test(arguments: ["a@b.co", "first.last@mail.example.org", "  me@example.com  "])
    func validEmailsPass(email: String) {
        #expect(AuthValidation.email(email) == nil)
    }

    @Test(arguments: ["", "   ", "plain", "a@b", "@b.co", "a b@c.com"])
    func invalidEmailsFail(email: String) {
        #expect(AuthValidation.email(email) != nil)
    }

    @Test func newPasswordNeedsEightCharacters() {
        #expect(AuthValidation.newPassword("") != nil)
        #expect(AuthValidation.newPassword("1234567") != nil)
        #expect(AuthValidation.newPassword("12345678") == nil)
        #expect(AuthValidation.newPassword(String(repeating: "a", count: AuthValidation.maxPasswordLength)) == nil)
        #expect(AuthValidation.newPassword(String(repeating: "a", count: AuthValidation.maxPasswordLength + 1)) != nil)
    }

    @Test func existingPasswordOnlyNeedsToBeNonEmpty() {
        #expect(AuthValidation.existingPassword("") != nil)
        #expect(AuthValidation.existingPassword("x") == nil)
    }

    @Test func confirmationMustMatch() {
        #expect(AuthValidation.confirmation("", matches: "password1") != nil)
        #expect(AuthValidation.confirmation("password2", matches: "password1") != nil)
        #expect(AuthValidation.confirmation("password1", matches: "password1") == nil)
    }

    @Test func displayNameLengthLimits() {
        #expect(AuthValidation.displayName("") != nil)
        #expect(AuthValidation.displayName(" A ") != nil)
        #expect(AuthValidation.displayName("Al") == nil)
        #expect(AuthValidation.displayName(String(repeating: "a", count: 40)) == nil)
        #expect(AuthValidation.displayName(String(repeating: "a", count: 41)) != nil)
    }

    @Test func everyFailureHasAFriendlyMessage() {
        let failures: [AuthFailure] = [
            .invalidEmail, .weakPassword, .emailAlreadyInUse, .wrongCredentials, .network,
            .tooManyAttempts, .requiresRecentLogin, .userDisabled, .notSignedIn, .unknown,
        ]
        let messages = failures.map { $0.errorDescription ?? "" }
        let allNonEmpty = messages.allSatisfy { !$0.isEmpty }
        #expect(allNonEmpty)
        #expect(Set(messages).count == failures.count, "each failure should read differently")
    }
}

// MARK: - Mock service

@MainActor
struct MockAuthServiceTests {
    @Test func signUpCreatesAndSignsInTheUser() async throws {
        let service = MockAuthService()
        let user = try await service.signUp(name: "Asha", email: "Asha@Example.com", password: "password1")
        #expect(user.displayName == "Asha")
        #expect(user.email == "asha@example.com")
    }

    @Test func duplicateEmailIsRejectedIgnoringCase() async throws {
        let service = MockAuthService()
        _ = try await service.signUp(name: "Asha", email: "asha@example.com", password: "password1")
        await #expect(throws: AuthFailure.emailAlreadyInUse) {
            try await service.signUp(name: "Other", email: "ASHA@example.com", password: "password2")
        }
    }

    @Test func signInChecksThePassword() async throws {
        let service = MockAuthService()
        service.seedAccount(name: "Asha", email: "asha@example.com", password: "password1")

        await #expect(throws: AuthFailure.wrongCredentials) {
            try await service.signIn(email: "asha@example.com", password: "nope")
        }
        await #expect(throws: AuthFailure.wrongCredentials) {
            try await service.signIn(email: "nobody@example.com", password: "password1")
        }
        let user = try await service.signIn(email: " Asha@example.com ", password: "password1")
        #expect(user.displayName == "Asha")
    }

    @Test func authStateStreamReportsChanges() async throws {
        let service = MockAuthService()
        service.seedAccount(name: "Asha", email: "asha@example.com", password: "password1")

        var iterator = service.authStateChanges().makeAsyncIterator()
        let initial = await iterator.next()
        #expect(initial == .some(nil), "starts signed out")

        _ = try await service.signIn(email: "asha@example.com", password: "password1")
        let signedIn = await iterator.next()
        let signedInUser: AppUser? = signedIn ?? nil
        #expect(signedInUser?.displayName == "Asha")
        #expect(signedInUser?.email == "asha@example.com")

        try service.signOut()
        let signedOut = await iterator.next()
        #expect(signedOut == .some(nil))
    }

    @Test func deleteAccountNeedsTheRightPasswordAndRemovesTheAccount() async throws {
        let service = MockAuthService()
        service.seedAccount(name: "Asha", email: "asha@example.com", password: "password1", signedIn: true)

        await #expect(throws: AuthFailure.wrongCredentials) {
            try await service.deleteAccount(password: "wrong")
        }
        try await service.deleteAccount(password: "password1")
        await #expect(throws: AuthFailure.wrongCredentials) {
            try await service.signIn(email: "asha@example.com", password: "password1")
        }
    }

    @Test func passwordResetSucceedsEvenForUnknownEmails() async throws {
        let service = MockAuthService()
        try await service.sendPasswordReset(email: "nobody@example.com")
        #expect(service.passwordResetRequests == ["nobody@example.com"])
    }
}

// MARK: - View model

@MainActor
struct AuthViewModelTests {
    private func makeViewModel(
        signedInAs name: String? = nil
    ) -> (AuthViewModel, MockAuthService) {
        let service = MockAuthService()
        service.seedAccount(name: "Existing", email: "existing@example.com", password: "password1")
        if let name {
            service.seedAccount(name: name, email: "\(name.lowercased())@example.com", password: "password1", signedIn: true)
        }
        return (AuthViewModel(service: service), service)
    }

    /// Runs `start()` until the session leaves `.loading`, then stops it.
    private func startAndSettle(_ viewModel: AuthViewModel) async {
        let task = Task { await viewModel.start() }
        var attempts = 0
        while viewModel.session == .loading && attempts < 500 {
            await Task.yield()
            attempts += 1
        }
        task.cancel()
    }

    // MARK: Session

    @Test func startsInLoadingThenReportsSignedOut() async {
        let (viewModel, _) = makeViewModel()
        #expect(viewModel.session == .loading)
        await startAndSettle(viewModel)
        #expect(viewModel.session == .signedOut)
        #expect(!viewModel.isSignedIn)
    }

    @Test func restoresAnExistingSession() async {
        let (viewModel, _) = makeViewModel(signedInAs: "Asha")
        await startAndSettle(viewModel)
        #expect(viewModel.isSignedIn)
        #expect(viewModel.user?.displayName == "Asha")
    }

    // MARK: Sign in

    @Test func signInSucceeds() async {
        let (viewModel, _) = makeViewModel()
        let ok = await viewModel.signIn(email: "existing@example.com", password: "password1")
        #expect(ok)
        #expect(viewModel.user?.displayName == "Existing")
        #expect(viewModel.errorMessage == nil)
    }

    @Test func wrongPasswordShowsAFriendlyError() async {
        let (viewModel, _) = makeViewModel()
        let ok = await viewModel.signIn(email: "existing@example.com", password: "nope")
        #expect(!ok)
        #expect(!viewModel.isSignedIn)
        #expect(viewModel.errorMessage == AuthFailure.wrongCredentials.errorDescription)
    }

    @Test func invalidInputNeverReachesTheService() async {
        let (viewModel, service) = makeViewModel()
        service.failNextCall = .network // would surface if the service were called

        let ok = await viewModel.signIn(email: "not-an-email", password: "password1")
        #expect(!ok)
        #expect(viewModel.errorMessage == AuthValidation.email("not-an-email"))
        #expect(service.failNextCall == .network, "service was not called")
    }

    @Test func networkFailureIsReported() async {
        let (viewModel, service) = makeViewModel()
        service.failNextCall = .network
        let ok = await viewModel.signIn(email: "existing@example.com", password: "password1")
        #expect(!ok)
        #expect(viewModel.errorMessage == AuthFailure.network.errorDescription)
    }

    // MARK: Sign up

    @Test func signUpSignsTheNewUserIn() async {
        let (viewModel, _) = makeViewModel()
        let ok = await viewModel.signUp(
            name: "  Bob  ", email: "bob@example.com", password: "password1", confirmation: "password1"
        )
        #expect(ok)
        #expect(viewModel.user?.displayName == "Bob")
        #expect(viewModel.user?.email == "bob@example.com")
    }

    @Test func signUpRejectsMismatchedPasswords() async {
        let (viewModel, _) = makeViewModel()
        let ok = await viewModel.signUp(
            name: "Bob", email: "bob@example.com", password: "password1", confirmation: "password2"
        )
        #expect(!ok)
        #expect(!viewModel.isSignedIn)
        #expect(viewModel.errorMessage == AuthValidation.confirmation("password2", matches: "password1"))
    }

    @Test func signUpRejectsShortPasswords() async {
        let (viewModel, _) = makeViewModel()
        let ok = await viewModel.signUp(name: "Bob", email: "bob@example.com", password: "short", confirmation: "short")
        #expect(!ok)
        #expect(viewModel.errorMessage == AuthValidation.newPassword("short"))
    }

    @Test func signUpWithTakenEmailShowsAnError() async {
        let (viewModel, _) = makeViewModel()
        let ok = await viewModel.signUp(
            name: "Copy", email: "existing@example.com", password: "password1", confirmation: "password1"
        )
        #expect(!ok)
        #expect(viewModel.errorMessage == AuthFailure.emailAlreadyInUse.errorDescription)
    }

    // MARK: Sign out, delete, reset

    @Test func signOutReturnsToSignedOut() async {
        let (viewModel, _) = makeViewModel()
        _ = await viewModel.signIn(email: "existing@example.com", password: "password1")
        viewModel.signOut()
        #expect(viewModel.session == .signedOut)
        #expect(viewModel.user == nil)
    }

    @Test func deleteAccountSignsOut() async {
        let (viewModel, _) = makeViewModel()
        _ = await viewModel.signIn(email: "existing@example.com", password: "password1")

        let wrong = await viewModel.deleteAccount(password: "nope")
        #expect(!wrong)
        #expect(viewModel.isSignedIn)

        let ok = await viewModel.deleteAccount(password: "password1")
        #expect(ok)
        #expect(viewModel.session == .signedOut)
    }

    @Test func passwordResetValidatesTheEmail() async {
        let (viewModel, service) = makeViewModel()
        let bad = await viewModel.sendPasswordReset(email: "nope")
        #expect(!bad)
        #expect(service.passwordResetRequests.isEmpty)

        let good = await viewModel.sendPasswordReset(email: "existing@example.com")
        #expect(good)
        #expect(service.passwordResetRequests == ["existing@example.com"])
    }

    // MARK: Gating

    @Test func requireSignInRunsTheActionImmediatelyWhenSignedIn() async {
        let (viewModel, _) = makeViewModel()
        _ = await viewModel.signIn(email: "existing@example.com", password: "password1")

        var ran = false
        viewModel.requireSignIn { ran = true }
        #expect(ran)
        #expect(!viewModel.isPresentingAuth)
    }

    @Test func requireSignInPresentsTheSheetForGuests() {
        let (viewModel, _) = makeViewModel()
        var ran = false
        viewModel.requireSignIn { ran = true }
        #expect(!ran)
        #expect(viewModel.isPresentingAuth)
    }

    @Test func pendingActionRunsAfterSigningIn() async {
        let (viewModel, _) = makeViewModel()
        var ran = false
        viewModel.requireSignIn { ran = true }

        _ = await viewModel.signIn(email: "existing@example.com", password: "password1")
        #expect(!viewModel.isPresentingAuth, "the sheet closes on sign-in")
        viewModel.runPendingAction() // what the sheet's onDismiss does
        #expect(ran)

        ran = false
        viewModel.runPendingAction()
        #expect(!ran, "the action only runs once")
    }

    @Test func cancellingTheSheetDropsThePendingAction() async {
        let (viewModel, _) = makeViewModel()
        var ran = false
        viewModel.requireSignIn { ran = true }
        viewModel.isPresentingAuth = false
        viewModel.runPendingAction()
        #expect(!ran)

        // Signing in later must not resurrect the old action.
        _ = await viewModel.signIn(email: "existing@example.com", password: "password1")
        viewModel.runPendingAction()
        #expect(!ran)
    }
}

// MARK: - Create Listing picks up the account's name

@MainActor
struct SellerNameDefaultTests {
    @Test func formDefaultsToTheAccountDisplayName() {
        let viewModel = CreateListingViewModel(
            repository: InMemoryListingRepository(listings: []),
            photoStore: PhotoStore(directory: URL.temporaryDirectory.appending(path: "SellerName-\(UUID().uuidString)")),
            visionAssist: VisionAssistService(),
            defaultSellerName: "Asha"
        )
        #expect(viewModel.sellerName == "Asha")
        #expect(!viewModel.isDirty, "an untouched form shouldn't count as edited")
    }

    @Test func formFallsBackToMeWithoutAnAccountName() {
        let viewModel = CreateListingViewModel(
            repository: InMemoryListingRepository(listings: []),
            photoStore: PhotoStore(directory: URL.temporaryDirectory.appending(path: "SellerName-\(UUID().uuidString)")),
            visionAssist: VisionAssistService()
        )
        #expect(viewModel.sellerName == CreateListingViewModel.defaultSellerName)
    }
}
