//
//  ListingLocationTests.swift
//  neighbourlyTests
//
//  "Use my current location" on the Create Listing form: rounding for privacy, the area
//  suggestion, failures, and saving the coordinates. Core Location itself isn't touched.
//

import Foundation
import Testing
@testable import neighbourly

// MARK: - Coordinates and errors

struct CoordinateTests {
    @Test func roundsToTwoDecimalsForSharing() {
        let rounded = Coordinate(latitude: 19.07654, longitude: 72.89876).roundedForSharing()
        #expect(rounded == Coordinate(latitude: 19.08, longitude: 72.9))
    }

    @Test func roundsNegativeCoordinates() {
        let rounded = Coordinate(latitude: -33.8688, longitude: 151.2093).roundedForSharing()
        #expect(rounded == Coordinate(latitude: -33.87, longitude: 151.21))
    }

    @Test func alreadyRoundedValuesDontMove() {
        let coordinate = Coordinate(latitude: 19.08, longitude: 72.9)
        #expect(coordinate.roundedForSharing() == coordinate)
    }

    @Test func roundedPositionIsWithinAboutAKilometre() {
        let exact = Coordinate(latitude: 19.07654, longitude: 72.89876)
        let rounded = exact.roundedForSharing()
        // 0.005 degrees of latitude is roughly 550 m, so rounding never moves it more than that.
        #expect(abs(rounded.latitude - exact.latitude) <= 0.005 + 1e-9)
        #expect(abs(rounded.longitude - exact.longitude) <= 0.005 + 1e-9)
    }

    @Test func everyLocationErrorHasADistinctMessage() {
        let errors: [LocationError] = [.denied, .unavailable, .busy]
        let messages = errors.map { $0.errorDescription ?? "" }
        let allNonEmpty = messages.allSatisfy { !$0.isEmpty }
        #expect(allNonEmpty)
        #expect(Set(messages).count == errors.count)
    }
}

// MARK: - Form behaviour

/// A stand-in for the device's location, with a configurable answer and delay.
@MainActor
private final class StubLocation: LocationProviding {
    var result: Result<Coordinate, LocationError>
    var name: String?
    var delay: Duration
    private(set) var requests = 0

    init(result: Result<Coordinate, LocationError>, name: String? = nil, delay: Duration = .zero) {
        self.result = result
        self.name = name
        self.delay = delay
    }

    func currentCoordinate() async throws -> Coordinate {
        requests += 1
        if delay > .zero { try await Task.sleep(for: delay) }
        return try result.get()
    }

    func placeName(for coordinate: Coordinate) async -> String? { name }
}

@MainActor
final class ListingLocationFormTests {
    private let directory = URL.temporaryDirectory.appending(path: "LocationForm-\(UUID().uuidString)", directoryHint: .isDirectory)
    private lazy var photoStore = PhotoStore(directory: directory)

    private let powai = Coordinate(latitude: 19.11761, longitude: 72.90604)

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    private func makeViewModel(
        location: (any LocationProviding)?,
        editing original: Listing? = nil,
        repository: any ListingRepository = InMemoryListingRepository(listings: [])
    ) -> CreateListingViewModel {
        CreateListingViewModel(
            repository: repository, photoStore: photoStore, visionAssist: VisionAssistService(),
            editing: original, sellerID: "uid-1", location: location
        )
    }

    private func waitUntil(_ condition: () -> Bool) async -> Bool {
        for _ in 0..<2_000 {
            if condition() { return true }
            await Task.yield()
        }
        return condition()
    }

    // MARK: Availability

    @Test func buttonIsHiddenWithoutALocationSource() async {
        let viewModel = makeViewModel(location: nil)
        #expect(!viewModel.canUseLocation)

        await viewModel.useCurrentLocation()
        #expect(!viewModel.hasLocation)
        #expect(viewModel.locationStatus == .idle)
    }

    @Test func newFormsStartWithoutALocation() {
        let viewModel = makeViewModel(location: StubLocation(result: .success(powai)))
        #expect(viewModel.canUseLocation)
        #expect(!viewModel.hasLocation)
        #expect(!viewModel.isDirty)
    }

    // MARK: Getting a position

    @Test func successStoresTheRoundedPosition() async {
        let viewModel = makeViewModel(location: StubLocation(result: .success(powai)))
        await viewModel.useCurrentLocation()

        #expect(viewModel.hasLocation)
        #expect(viewModel.latitude == 19.12)
        #expect(viewModel.longitude == 72.91)
        #expect(viewModel.locationStatus == .idle)
        #expect(viewModel.isDirty, "adding a location counts as an unsaved change")
    }

    @Test func theExactPositionIsNeverKept() async {
        let viewModel = makeViewModel(location: StubLocation(result: .success(powai)))
        await viewModel.useCurrentLocation()
        #expect(viewModel.latitude != powai.latitude)
        #expect(viewModel.longitude != powai.longitude)
    }

    @Test func deniedAccessShowsAReasonAndKeepsTheForm() async {
        let viewModel = makeViewModel(location: StubLocation(result: .failure(.denied)))
        viewModel.title = "Chair"
        await viewModel.useCurrentLocation()

        #expect(viewModel.locationStatus == .failed(.denied))
        #expect(!viewModel.hasLocation)
        #expect(viewModel.title == "Chair", "the rest of the form is untouched")
    }

    @Test func noFixShowsAReason() async {
        let viewModel = makeViewModel(location: StubLocation(result: .failure(.unavailable)))
        await viewModel.useCurrentLocation()
        #expect(viewModel.locationStatus == .failed(.unavailable))
        #expect(!viewModel.hasLocation)
    }

    @Test func retryingAfterAFailureWorks() async {
        let stub = StubLocation(result: .failure(.unavailable))
        let viewModel = makeViewModel(location: stub)
        await viewModel.useCurrentLocation()
        #expect(viewModel.locationStatus == .failed(.unavailable))

        stub.result = .success(powai)
        await viewModel.useCurrentLocation()
        #expect(viewModel.locationStatus == .idle)
        #expect(viewModel.hasLocation)
    }

    @Test func tappingTwiceWhileLocatingAsksOnlyOnce() async {
        let stub = StubLocation(result: .success(powai), delay: .milliseconds(150))
        let viewModel = makeViewModel(location: stub)

        let first = Task { await viewModel.useCurrentLocation() }
        let started = await waitUntil { viewModel.isLocating }
        #expect(started)

        await viewModel.useCurrentLocation() // ignored: one is already running
        await first.value
        #expect(stub.requests == 1)
        #expect(viewModel.hasLocation)
    }

    // MARK: Area name

    @Test func emptyAreaIsSuggestedFromThePlaceName() async {
        let viewModel = makeViewModel(location: StubLocation(result: .success(powai), name: "Powai"))
        await viewModel.useCurrentLocation()

        #expect(viewModel.areaName == "Powai")
        #expect(viewModel.areaFilledFromLocation)
    }

    @Test func aTypedAreaIsNeverOverwritten() async {
        let viewModel = makeViewModel(location: StubLocation(result: .success(powai), name: "Powai"))
        viewModel.areaName = "Hiranandani Gardens"
        await viewModel.useCurrentLocation()

        #expect(viewModel.areaName == "Hiranandani Gardens")
        #expect(!viewModel.areaFilledFromLocation)
    }

    @Test func editingTheSuggestedAreaMakesItTheirs() async {
        let viewModel = makeViewModel(location: StubLocation(result: .success(powai), name: "Powai"))
        await viewModel.useCurrentLocation()
        #expect(viewModel.areaFilledFromLocation)

        viewModel.areaName = "Powai Lake side"
        #expect(!viewModel.areaFilledFromLocation)
    }

    @Test func missingPlaceNameLeavesTheAreaEmpty() async {
        let viewModel = makeViewModel(location: StubLocation(result: .success(powai), name: nil))
        await viewModel.useCurrentLocation()

        #expect(viewModel.hasLocation)
        #expect(viewModel.areaName.isEmpty)
        #expect(!viewModel.areaFilledFromLocation)
    }

    // MARK: Removing and saving

    @Test func removingTheLocationClearsEverything() async {
        let viewModel = makeViewModel(location: StubLocation(result: .success(powai), name: "Powai"))
        await viewModel.useCurrentLocation()

        viewModel.clearLocation()
        #expect(!viewModel.hasLocation)
        #expect(viewModel.latitude == nil)
        #expect(viewModel.longitude == nil)
        #expect(!viewModel.areaFilledFromLocation)
    }

    @Test func savedListingCarriesTheRoundedCoordinates() async throws {
        let repository = InMemoryListingRepository(listings: [])
        let viewModel = makeViewModel(location: StubLocation(result: .success(powai), name: "Powai"), repository: repository)
        viewModel.title = "Study table"
        viewModel.mode = .donate
        await viewModel.useCurrentLocation()

        let saved = try #require(await viewModel.save())
        #expect(saved.latitude == 19.12)
        #expect(saved.longitude == 72.91)
        #expect(saved.hasCoordinates)
        #expect(saved.areaName == "Powai")
        #expect(saved.isValid)

        let stored = try await repository.fetchListings()
        #expect(stored == [saved])
    }

    @Test func listingsWithoutALocationStillSave() async throws {
        let viewModel = makeViewModel(location: StubLocation(result: .success(powai)))
        viewModel.title = "Study table"
        viewModel.mode = .donate

        let saved = try #require(await viewModel.save())
        #expect(!saved.hasCoordinates)
    }

    // MARK: Editing

    private func existingListing() -> Listing {
        Listing(
            title: "Chair", category: .furniture, mode: .donate, condition: .good,
            latitude: 19.08, longitude: 72.9, areaName: "Vidyavihar",
            sellerID: "uid-1", sellerName: "Asha"
        )
    }

    @Test func editingStartsWithTheListingsLocationAndNoChanges() {
        let viewModel = makeViewModel(location: StubLocation(result: .success(powai)), editing: existingListing())
        #expect(viewModel.hasLocation)
        #expect(viewModel.latitude == 19.08)
        #expect(viewModel.longitude == 72.9)
        #expect(!viewModel.isDirty)
    }

    @Test func editingCanMoveTheLocation() async throws {
        let viewModel = makeViewModel(location: StubLocation(result: .success(powai)), editing: existingListing())
        await viewModel.useCurrentLocation()

        let saved = try #require(await viewModel.save())
        #expect(saved.latitude == 19.12)
        #expect(saved.longitude == 72.91)
    }

    @Test func editingCanRemoveTheLocation() async throws {
        let viewModel = makeViewModel(location: StubLocation(result: .success(powai)), editing: existingListing())
        viewModel.clearLocation()
        #expect(viewModel.isDirty)

        let saved = try #require(await viewModel.save())
        #expect(!saved.hasCoordinates)
        #expect(saved.latitude == nil)
    }

    @Test func existingAreaIsNotOverwrittenWhenUpdatingTheLocation() async {
        let viewModel = makeViewModel(location: StubLocation(result: .success(powai), name: "Powai"), editing: existingListing())
        await viewModel.useCurrentLocation()
        #expect(viewModel.areaName == "Vidyavihar")
    }
}
