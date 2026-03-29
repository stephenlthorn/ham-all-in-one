import Foundation
import CoreLocation
import Combine

@MainActor
final class LocationService: NSObject, ObservableObject {
    static let shared = LocationService()

    @Published private(set) var currentLocation: CLLocation?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var currentGrid: String?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = manager.authorizationStatus
        requestIfNeeded()
    }

    func requestIfNeeded() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }

    func requestAlwaysAuthorization() {
        manager.requestAlwaysAuthorization()
    }

    var currentLatLon: (lat: Double, lon: Double)? {
        guard let loc = currentLocation else { return nil }
        return (loc.coordinate.latitude, loc.coordinate.longitude)
    }

    func distanceTo(_ coordinate: CLLocationCoordinate2D) -> Double? {
        guard let loc = currentLocation else { return nil }
        let dest = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return loc.distance(from: dest) / 1609.34 // miles
    }

    func bearingTo(_ coordinate: CLLocationCoordinate2D) -> Double? {
        currentLocation?.bearing(to: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
    }

    func formattedBearing(_ bearing: Double) -> String {
        let directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                          "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int((bearing + 11.25) / 22.5) % 16
        return directions[index]
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.currentLocation = location
            if let lat = Optional(location.coordinate.latitude),
               let lon = Optional(location.coordinate.longitude) {
                self.currentGrid = Maidenhead.encode(lat: lat, lon: lon)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error)")
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
                manager.requestLocation()
            }
        }
    }
}
