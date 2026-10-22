//
//  MyListingsViewModelTests.swift
//  neighbourlyTests
//

import Foundation
import Testing
@testable import neighbourly

@MainActor
struct MyListingsViewModelTests {
    private func listing(_ title: String, seller: String?) -> Listing {
        Listing(
            title: title, category: .books, mode: .donate, condition: .good,
            sellerID: seller, sellerName: "Someone"
        )
    }

    private func makeViewModel(listings: [Listing]) -> MyListingsViewModel {
        let repository = InMemoryListingRepository(listings: SampleListings.make() + listings)
        return MyListingsViewModel(repository: repository)
    }

    @Test func onlyThisAccountsListingsAreShown() async {
        let viewModel = makeViewModel(listings: [
            listing("Mine", seller: "me"),
            listing("Theirs", seller: "someone-else"),
            listing("Legacy, no owner", seller: nil),
        ])
        await viewModel.load(for: "me")

        let titles = viewModel.listings.map { $0.title }
        #expect(viewModel.hasLoaded)
        #expect(titles == ["Mine"])
    }

    @Test func signedOutShowsNothing() async {
        let viewModel = makeViewModel(listings: [listing("Mine", seller: "me")])
        await viewModel.load(for: nil)
        #expect(viewModel.hasLoaded)
        #expect(viewModel.listings.isEmpty)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func emptyWhenNothingHasBeenPosted() async {
        let viewModel = makeViewModel(listings: [])
        await viewModel.load(for: "me")
        #expect(viewModel.hasLoaded)
        #expect(viewModel.listings.isEmpty)
    }

    @Test func switchingAccountsChangesTheList() async {
        let viewModel = makeViewModel(listings: [
            listing("Alice's", seller: "alice"),
            listing("Bob's", seller: "bob"),
        ])
        await viewModel.load(for: "alice")
        #expect(viewModel.listings.map { $0.title } == ["Alice's"])

        await viewModel.load(for: "bob")
        #expect(viewModel.listings.map { $0.title } == ["Bob's"])
    }

    @Test func deleteRemovesTheListing() async {
        let keep = listing("Keep", seller: "me")
        let remove = listing("Remove", seller: "me")
        let viewModel = makeViewModel(listings: [keep, remove])
        await viewModel.load(for: "me")

        let removed = await viewModel.delete(remove)
        #expect(removed)
        #expect(viewModel.listings.map { $0.title } == ["Keep"])

        await viewModel.load(for: "me")
        #expect(viewModel.listings.map { $0.title } == ["Keep"])
    }

    @Test func resetRestoresSamplesAndReloads() async {
        let viewModel = makeViewModel(listings: [listing("Mine", seller: "me")])
        await viewModel.load(for: "me")
        #expect(viewModel.listings.count == 1)

        // The in-memory store resets everything; the composite store only resets samples.
        let didReset = await viewModel.resetSampleData(for: "me")
        #expect(didReset)
        #expect(viewModel.listings.isEmpty)
    }
}
