//
//  LocationService.swift
//  neighbourly
//
//  Small Core Location wrapper. Permission is requested only when the user
//  taps "Use my location"; browsing never depends on it.
//

import CoreLocation
import Observation

@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    enum State: Equatable {
        case idle
        case requesting
        case located(latitude: Double, longitude: Double)
        case denied
        case unavailable
    }

    private(set) var state: State = .idle

    @ObservationIgnored private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// Call only from a user action: may show the system permission prompt.
    func requestCurrentLocation() {
        switch manager.authorizationStatus {
        case .notDetermined:
            state = .requesting
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            state = .denied
        default:
            state = .requesting
            manager.requestLocation()
        }
    }

    /// Clears a denied/unavailable message after the user has seen it.
    func dismissMessage() {
        if state == .denied || state == .unavailable {
            state = .idle
        }
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
            self.state = .located(latitude: latitude, longitude: longitude)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        Task { @MainActor in
            guard self.state == .requesting else { return }
            self.state = .unavailable
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
            state = .denied
        default:
            break
        }
    }
}
