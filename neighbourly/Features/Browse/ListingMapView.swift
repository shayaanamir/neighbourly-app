//
//  ListingMapView.swift
//  neighbourly
//
//  MapKit view of the current Browse results. Listings without coordinates
//  are left off the map (and counted in a banner); the list stays usable
//  whether or not location permission is granted.
//

import CoreLocation
import MapKit
import SwiftUI
import UIKit

nonisolated extension Listing {
    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// A listing paired with its (known) coordinate, so map content needs no optionals.
private struct MapPin: Identifiable {
    let listing: Listing
    let coordinate: CLLocationCoordinate2D
    var id: UUID { listing.id }
}

struct ListingMapView: View {
    let listings: [Listing]
    let photoStore: PhotoStore
    let locationService: LocationService
    let onShowList: () -> Void

    @State private var position: MapCameraPosition = .automatic
    @State private var selectedID: UUID?
    @Environment(\.openURL) private var openURL

    private var pins: [MapPin] {
        listings.compactMap { listing in
            listing.coordinate.map { MapPin(listing: listing, coordinate: $0) }
        }
    }

    private var selectedListing: Listing? {
        pins.first { $0.id == selectedID }?.listing
    }

    var body: some View {
        if pins.isEmpty {
            ContentUnavailableView {
                Label("No listings on the map", systemImage: "mappin.slash")
            } description: {
                Text("None of these listings has a location. They're all still in the list.")
            } actions: {
                Button("Show list", action: onShowList)
            }
        } else {
            map
        }
    }

    private var map: some View {
        Map(position: $position, selection: $selectedID) {
            ForEach(pins) { pin in
                Marker(pin.listing.title, systemImage: pin.listing.category.systemImage, coordinate: pin.coordinate)
                    .tint(pin.listing.mode.tint)
                    .tag(pin.id)
            }
            UserAnnotation()
        }
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .overlay(alignment: .topLeading) { hiddenCountBanner }
        .overlay(alignment: .topTrailing) { locationButton }
        .overlay(alignment: .bottom) { selectionPreview }
        .animation(.snappy, value: selectedID)
        .onChange(of: pins.map { $0.id }) {
            // Results changed (search/filter): drop a stale selection and refit.
            if selectedListing == nil { selectedID = nil }
            position = .automatic
        }
        .onChange(of: locationService.state) { _, state in
            guard case let .located(latitude, longitude) = state else { return }
            withAnimation {
                position = .region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                    latitudinalMeters: 5_000,
                    longitudinalMeters: 5_000
                ))
            }
        }
        .alert("Location access is off", isPresented: isShowing(.denied)) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                locationService.dismissMessage()
            }
            Button("Not now", role: .cancel) { locationService.dismissMessage() }
        } message: {
            Text("You can still browse every listing. To centre the map on you, allow location access in Settings.")
        }
        .alert("Location unavailable", isPresented: isShowing(.unavailable)) {
            Button("OK", role: .cancel) { locationService.dismissMessage() }
        } message: {
            Text("Your location couldn't be found right now. In the Simulator, pick one under Features › Location.")
        }
    }

    // MARK: - Overlays

    @ViewBuilder
    private var hiddenCountBanner: some View {
        let hidden = listings.count - pins.count
        if hidden > 0 {
            Text(hidden == 1 ? "1 listing has no location" : "\(hidden) listings have no location")
                .font(Theme.Typography.caption)
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.vertical, Theme.Spacing.s)
                .background(.regularMaterial, in: Capsule())
                .padding(Theme.Spacing.m)
        }
    }

    private var locationButton: some View {
        Button {
            locationService.requestCurrentLocation()
        } label: {
            Group {
                if locationService.state == .requesting {
                    ProgressView()
                } else {
                    Image(systemName: "location")
                }
            }
            .frame(width: 44, height: 44)
            .background(.regularMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.Colors.accent)
        .padding(Theme.Spacing.m)
        .padding(.top, 44) // clear the compass
        .accessibilityLabel("Use my location")
        .accessibilityHint("Centres the map near you. Asks for permission the first time.")
    }

    @ViewBuilder
    private var selectionPreview: some View {
        if let listing = selectedListing {
            NavigationLink(value: listing) {
                ListingCard(listing: listing, photoStore: photoStore)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens listing details")
                .overlay(alignment: .topTrailing) {
                    Button {
                        selectedID = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Theme.Colors.secondaryText)
                            .padding(Theme.Spacing.s)
                    }
                    .accessibilityLabel("Close preview")
                }
                .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
                .padding(Theme.Spacing.l)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func isShowing(_ state: LocationService.State) -> Binding<Bool> {
        Binding(
            get: { locationService.state == state },
            set: { if !$0 { locationService.dismissMessage() } }
        )
    }
}

#Preview {
    let dependencies = AppDependencies.preview()
    ListingMapView(
        listings: SampleListings.make(),
        photoStore: dependencies.photoStore,
        locationService: dependencies.locationService,
        onShowList: {}
    )
}
