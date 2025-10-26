import Foundation
import CoreLocation
import Combine

/// Advanced location manager with real-time tracking, geocoding, and distance calculations
class LocationManager: NSObject, ObservableObject {

    // MARK: - Published Properties
    @Published var userLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isAuthorized: Bool = false
    @Published var locationError: String?
    @Published var heading: CLHeading?
    @Published var currentAddress: String?

    // MARK: - Private Properties
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()

    // MARK: - Configuration
    var desiredAccuracy: CLLocationAccuracy = kCLLocationAccuracyBest
    var distanceFilter: CLLocationDistance = 10 // meters

    // MARK: - Initialization
    override init() {
        super.init()
        setupLocationManager()
        checkAuthorizationStatus()
    }

    // MARK: - Setup
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = desiredAccuracy
        locationManager.distanceFilter = distanceFilter
        locationManager.activityType = .automotiveNavigation
        locationManager.pausesLocationUpdatesAutomatically = true
        locationManager.allowsBackgroundLocationUpdates = false
    }

    // MARK: - Authorization
    func requestAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }

    private func checkAuthorizationStatus() {
        authorizationStatus = locationManager.authorizationStatus
        updateAuthorizationState()
    }

    private func updateAuthorizationState() {
        isAuthorized = authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways

        if isAuthorized {
            startUpdatingLocation()
        } else {
            stopUpdatingLocation()
        }
    }

    // MARK: - Location Updates
    func startUpdatingLocation() {
        guard isAuthorized else {
            locationError = "Autorizzazione posizione non concessa"
            return
        }

        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
    }

    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
    }

    // MARK: - One-time Location
    func requestLocation() {
        guard isAuthorized else {
            locationError = "Autorizzazione posizione non concessa"
            return
        }

        locationManager.requestLocation()
    }

    // MARK: - Distance Calculations
    func distance(to coordinate: CLLocationCoordinate2D) -> CLLocationDistance? {
        guard let userLocation = userLocation else { return nil }

        let destination = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return userLocation.distance(from: destination)
    }

    func formattedDistance(to coordinate: CLLocationCoordinate2D) -> String? {
        guard let distance = distance(to: coordinate) else { return nil }

        if distance < 1_000 {
            return String(format: "%.0f m", distance)
        } else {
            let km = distance / 1_000
            return String(format: "%.1f km", km)
        }
    }

    // MARK: - Geocoding
    func reverseGeocode(location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self else { return }

            if let error = error {
                print("Reverse geocoding error: \(error.localizedDescription)")
                return
            }

            if let placemark = placemarks?.first {
                self.currentAddress = self.formatAddress(from: placemark)
            }
        }
    }

    private func formatAddress(from placemark: CLPlacemark) -> String {
        var components: [String] = []

        if let street = placemark.thoroughfare {
            components.append(street)
        }

        if let number = placemark.subThoroughfare {
            components.append(number)
        }

        if let city = placemark.locality {
            components.append(city)
        }

        return components.joined(separator: ", ")
    }

    // MARK: - Bearing
    func bearing(to coordinate: CLLocationCoordinate2D) -> Double? {
        guard let userLocation = userLocation else { return nil }

        let lat1 = userLocation.coordinate.latitude.toRadians()
        let lon1 = userLocation.coordinate.longitude.toRadians()
        let lat2 = coordinate.latitude.toRadians()
        let lon2 = coordinate.longitude.toRadians()

        let dLon = lon2 - lon1

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let bearing = atan2(y, x).toDegrees()

        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        userLocation = location
        locationError = nil

        // Reverse geocode to get address
        reverseGeocode(location: location)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationError = error.localizedDescription
        print("Location error: \(error.localizedDescription)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        updateAuthorizationState()
    }
}

// MARK: - Helper Extensions
private extension Double {
    func toRadians() -> Double {
        return self * .pi / 180
    }

    func toDegrees() -> Double {
        return self * 180 / .pi
    }
}
