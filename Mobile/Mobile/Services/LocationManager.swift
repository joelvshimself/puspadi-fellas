import CoreLocation
import Foundation

/// CLLocationCoordinate2D doesn't conform to Equatable on this SDK, which
/// SwiftUI's `.onChange` needs — this thin wrapper is just that.
struct Coordinate: Equatable {
    let latitude: Double
    let longitude: Double

    var clLocation: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// Wraps CLLocationManager so the map can center on wherever the user
/// actually is instead of a hardcoded demo coordinate — this is what makes
/// search/discover work anywhere in the world, not just San Francisco.
/// MKLocalSearch itself has no geographic restriction; it only ever searches
/// near whatever region it's given.
@MainActor
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var currentCoordinate: Coordinate?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus

    private let manager = CLLocationManager()

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestLocation() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
                manager.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        Task { @MainActor in
            currentCoordinate = Coordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Denied, no signal (common in Simulator without a simulated
        // location set), etc. — the map just keeps its current/default
        // region rather than crashing.
    }
}
