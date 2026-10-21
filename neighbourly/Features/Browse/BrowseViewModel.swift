//
//  BrowseViewModel.swift
//  neighbourly
//

import Foundation
import Observation

@Observable
final class BrowseViewModel {
    enum DisplayMode: String, CaseIterable, Identifiable {
        case list
        case map

        var id: String { rawValue }

        var title: String {
            switch self {
            case .list: "List"
            case .map: "Map"
            }
        }
    }

    private(set) var listings: [Listing] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var errorMessage: String?

    var filters = ListingFilters()
    var displayMode: DisplayMode = .list

    @ObservationIgnored private let repository: any ListingRepository

    init(repository: any ListingRepository) {
        self.repository = repository
    }

    /// Listings matching the current search and filters.
    var results: [Listing] {
        filters.apply(to: listings)
    }

    func load() async {
        isLoading = true
        defer {
            isLoading = false
            hasLoaded = true
        }
        do {
            listings = try await repository.fetchListings()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resetSampleData() async {
        do {
            try await repository.resetToSampleData()
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        await load()
    }

    func clearFilters() {
        filters.clear()
    }

    func toggle(_ category: ListingCategory) {
        filters.category = filters.category == category ? nil : category
    }

    func toggle(_ mode: ListingMode) {
        filters.mode = filters.mode == mode ? nil : mode
    }
}
