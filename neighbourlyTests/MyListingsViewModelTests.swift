//
//  MyListingsViewModelTests.swift
//  neighbourlyTests
//

import Foundation
import Testing
@testable import neighbourly

@MainActor
struct MyListingsViewModelTests {
    private func ownListing(_ title: String) -> Listing {
        Listing(title: title, category: .books, mode: .donate, condition: .good, sellerName: "Me")
    }

    private func makeViewModel(own: [Listing]) -> MyListingsViewModel {
        let repository = InMemoryListingRepository(listings: SampleListings.make() + own)
        return MyListingsViewModel(repository: repository)
    }

    @Test func onlyListingsCreatedOnThisDeviceAreShown() async {
        let viewModel = makeViewModel(own: [ownListing("Mine")])
        await viewModel.load()

        let titles = viewModel.listings.map { $0.title }
        #expect(viewModel.hasLoaded)
        #expect(titles == ["Mine"])
    }

    @Test func emptyWhenNothingHasBeenCreated() async {
        let viewModel = makeViewModel(own: [])
        await viewModel.load()
        #expect(viewModel.hasLoaded)
        #expect(viewModel.listings.isEmpty)
    }

    @Test func deleteRemovesTheListing() async {
        let keep = ownListing("Keep")
        let remove = ownListing("Remove")
        let viewModel = makeViewModel(own: [keep, remove])
        await viewModel.load()

        let removed = await viewModel.delete(remove)
        #expect(removed)
        #expect(viewModel.listings.map { $0.title } == ["Keep"])

        await viewModel.load()
        #expect(viewModel.listings.map { $0.title } == ["Keep"])
    }

    @Test func resetReplacesOwnListingsWithSamples() async {
        let viewModel = makeViewModel(own: [ownListing("Mine")])
        await viewModel.load()
        #expect(viewModel.listings.count == 1)

        let didReset = await viewModel.resetSampleData()
        #expect(didReset)
        #expect(viewModel.listings.isEmpty)
    }
}
