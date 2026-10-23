//
//  LocationService.swift
//  neighbourly
//
//  Small Core Location wrapper. Permission is requested only when the user
//  taps "Use my location" (on the map, or when creating a listing); browsing never
//  depends on it.
//

import CoreLocation
import Observation

/// A latitude/longitude pair.
nonisolated struct Coordinate: Equatable, Sendable {
    var latitude: Double
    var longitude: Double

    /// Listings are public, so a seller's exact position is never shared: coordinates are
    /// rounded to two decimal places, about 1 km, enough for "near Powai" but not a doorstep.
    func roundedForSharing() -> Coordinate {
        Coordinate(
            latitude: (latitude * 100).rounded() / 100,
            longitude: (longitude * 100).rounded() / 100
        )
    }
}

nonisolated enum LocationError: LocalizedError, Equatable, Sendable {
    case denied
    case unavailable
    /// A location request is already running.
    case busy

    var errorDescription: String? {
        switch self {
        case .denied: "Location access is off for Neighbourly."
        case .unavailable: "Your location couldn't be found right now. You can type your area instead."
        case .busy: "Still finding your location…"
        }
    }
}

/// Where the current location comes from. The form depends on this, not on Core Location,
/// so tests can substitute a stand-in.
@MainActor
protocol LocationProviding {
    /// The device's current position. May show the system permission prompt, so call it only
    /// in response to a tap. Throws `LocationError` if access is denied or no fix is found.
    func currentCoordinate() async throws -> Coordinate

    /// A neighbourhood or town name for the position, if one can be looked up.
    func placeName(for coordinate: Coordinate) async -> String?
}

extension LocationProviding {
    func placeName(for coordinate: Coordinate) async -> String? { nil }
}

@Observable
final class LocationService: NSObject, CLLocationManagerDelegate, LocationProviding {
    enum State: Equatable {
        case idle
        case requesting
        case located(latitude: Double, longitude: Double)
        case denied
        case unavailable
    }

    private(set) var state: State = .idle

    @ObservationIgnored private let manager = CLLocationManager()
    /// Someone waiting in `currentCoordinate()` for the next result.
    @ObservationIgnored private var waiter: CheckedContinuation<Coordinate, any Error>?
    @ObservationIgnored private var timeout: Task<Void, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// Call only from a user action: may show the system permission prompt.
    func requestCurrentLocation() {
        switch manager.authorizationStatus {
        case .notDetermined:
            setState(.requesting)
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            setState(.denied)
        default:
            setState(.requesting)
            manager.requestLocation()
        }
    }

    // MARK: LocationProviding

    func currentCoordinate() async throws -> Coordinate {
        guard waiter == nil else { throw LocationError.busy }
        return try await withCheckedThrowingContinuation { continuation in
            waiter = continuation
            // requestLocation can occasionally never answer; don't leave the form spinning.
            timeout = Task { [weak self] in
                try? await Task.sleep(for: .seconds(20))
                guard !Task.isCancelled else { return }
                self?.setState(.unavailable)
            }
            requestCurrentLocation()
        }
    }

    func placeName(for coordinate: Coordinate) async -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first else { return nil }
        return placemark.subLocality ?? placemark.locality
    }

    /// Clears a denied/unavailable message after the user has seen it.
    func dismissMessage() {
        if state == .denied || state == .unavailable {
            setState(.idle)
        }
    }

    /// Every state change goes through here so a waiting `currentCoordinate()` call is
    /// answered exactly once.
    private func setState(_ newState: State) {
        state = newState
        switch newState {
        case .located(let latitude, let longitude):
            finishWaiting(.success(Coordinate(latitude: latitude, longitude: longitude)))
        case .denied:
            finishWaiting(.failure(LocationError.denied))
        case .unavailable:
            finishWaiting(.failure(LocationError.unavailable))
        case .idle, .requesting:
            break
        }
    }

    private func finishWaiting(_ result: Result<Coordinate, any Error>) {
        timeout?.cancel()
        timeout = nil
        guard let waiter else { return }
        self.waiter = nil
        waiter.resume(with: result)
    }

    // MARK: - CLLocationManagerDelegate
    // Delegate calls arrive on the main thread; hop explicitly to keep the compiler happy.

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in self.authorizationChanged(to: status) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        let latitude = coordinate.latitude
        let longitude = coordinate.longitude
        Task { @MainActor in
            guard self.state == .requesting else { return }
            self.setState(.located(latitude: latitude, longitude: longitude))
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        Task { @MainActor in
            guard self.state == .requesting else { return }
            self.setState(.unavailable)
        }
    }

    private func authorizationChanged(to status: CLAuthorizationStatus) {
        // Core Location also reports the initial status at startup; only react
        // while a user-initiated request is in flight.
        guard state == .requesting else { return }
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            setState(.denied)
        default:
            break
        }
    }
}
