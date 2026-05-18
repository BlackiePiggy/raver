import CoreLocation
import Foundation

@MainActor
final class AppLocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var cityName: String?
    @Published private(set) var regionName: String?
    @Published private(set) var countryName: String?
    @Published private(set) var isResolving = false

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var displayCityName: String {
        cityName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        ?? LT("定位", "Locate", "位置")
    }

    var compactCityName: String {
        let city = displayCityName
        guard city.count > 2 else { return city }
        return String(city.prefix(2))
    }

    var displayLocationText: String {
        [countryName, regionName, cityName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty }
            .reduce(into: [String]()) { result, item in
                if result.last != item {
                    result.append(item)
                }
            }
            .joined(separator: " · ")
            .nilIfEmpty
        ?? LT("尚未获取定位", "Location not available yet", "位置情報はまだありません")
    }

    func requestOnAppEntryIfNeeded() {
        authorizationStatus = manager.authorizationStatus
        switch authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            break
        @unknown default:
            break
        }
    }

    func refreshCurrentLocation() {
        authorizationStatus = manager.authorizationStatus
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            requestOnAppEntryIfNeeded()
            return
        }
        manager.requestLocation()
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
                manager.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            await resolve(location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            isResolving = false
        }
        print("App location error: \(error.userFacingMessage ?? "")")
    }

    private func resolve(_ location: CLLocation) async {
        isResolving = true
        defer { isResolving = false }
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else { return }
            cityName = (placemark.locality ?? placemark.subAdministrativeArea ?? placemark.administrativeArea)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nilIfEmpty
            regionName = placemark.administrativeArea?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nilIfEmpty
            countryName = placemark.country?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nilIfEmpty
        } catch {
            print("App reverse geocode error: \(error.userFacingMessage ?? "")")
        }
    }
}
