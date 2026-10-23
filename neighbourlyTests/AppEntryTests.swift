//
//  AppEntryTests.swift
//  neighbourlyTests
//

import Testing
@testable import neighbourly

struct AppEntryTests {
    private func resolve(
        loading: Bool = false, signedIn: Bool = false, guest: Bool = false, allowsGuests: Bool = true
    ) -> AppEntry {
        AppEntry.resolve(isLoading: loading, isSignedIn: signedIn, continuedAsGuest: guest, allowsGuests: allowsGuests)
    }

    @Test func launchShowsTheLoadingScreenWhileTheSessionIsRestored() {
        #expect(resolve(loading: true) == .launch)
        #expect(resolve(loading: true, signedIn: true) == .launch)
        #expect(resolve(loading: true, guest: true) == .launch)
    }

    @Test func signedOutPeopleStartOnTheWelcomeScreen() {
        #expect(resolve() == .welcome)
    }

    @Test func signedInPeopleGoStraightToTheApp() {
        #expect(resolve(signedIn: true) == .main)
    }

    @Test func guestsGetTheAppOnlyAfterChoosingToBrowse() {
        #expect(resolve(guest: false) == .welcome)
        #expect(resolve(guest: true) == .main)
    }

    @Test func guestBrowsingCanBeSwitchedOff() {
        #expect(resolve(guest: true, allowsGuests: false) == .welcome)
        #expect(resolve(signedIn: true, allowsGuests: false) == .main)
    }

    @Test func signingOutReturnsToTheWelcomeScreen() {
        // The root clears "continued as guest" when someone signs in, so after signing
        // out (signedIn false, guest false) the welcome screen comes back.
        #expect(resolve(signedIn: true) == .main)
        #expect(resolve(signedIn: false, guest: false) == .welcome)
    }
}
