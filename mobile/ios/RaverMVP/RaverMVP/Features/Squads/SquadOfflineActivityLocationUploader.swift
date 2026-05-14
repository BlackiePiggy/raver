import CoreLocation
import Foundation

@MainActor
final class SquadOfflineActivityLocationUploader: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var lastLocation: CLLocation?
    @Published private(set) var lastUploadAt: Date?
    @Published private(set) var isUploading = false
    @Published private(set) var errorMessage: String?

    private let manager = CLLocationManager()
    private var uploadTask: Task<Void, Never>?
    private var pendingLocationRequest: CheckedContinuation<CLLocation?, Never>?
    private var pendingBestLocation: CLLocation?
    private var pendingRequestStartedAt: Date?

    private let preferredHorizontalAccuracy: CLLocationAccuracy = 20
    private let maxAcceptedLocationAge: TimeInterval = 30

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10
        manager.activityType = .fitness
    }

    deinit {
        uploadTask?.cancel()
        manager.stopUpdatingLocation()
    }

    func start(
        repository: LocationSyncRepository,
        squadID: String,
        activityID: String,
        intervalSeconds: Int
    ) {
        if authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        manager.startUpdatingLocation()
        uploadTask?.cancel()
        uploadTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.uploadFreshLocation(
                    repository: repository,
                    squadID: squadID,
                    activityID: activityID
                )
                let seconds = max(60, intervalSeconds)
                try? await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
            }
        }
    }

    func stop() {
        uploadTask?.cancel()
        uploadTask = nil
        manager.stopUpdatingLocation()
    }

    func uploadNow(repository: LocationSyncRepository, squadID: String, activityID: String) async -> Bool {
        if !hasLocationAuthorization {
            if authorizationStatus == .notDetermined {
                manager.requestWhenInUseAuthorization()
            }
            errorMessage = L("定位权限未开启，请在系统设置中允许定位后重试", "Location permission is disabled. Please enable it in Settings and try again.")
            return false
        }
        let location = await requestFreshLocation(allowsCachedLocation: false)
        return await uploadLocation(location, repository: repository, squadID: squadID, activityID: activityID)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = bestLocation(from: locations + [lastLocation].compactMap { $0 }) {
            lastLocation = location
        }
        let requestScopedLocations = locations.filter { location in
            guard let pendingRequestStartedAt else { return true }
            return location.timestamp >= pendingRequestStartedAt.addingTimeInterval(-5)
        }
        if let location = bestLocation(from: requestScopedLocations) {
            pendingBestLocation = bestLocation(from: [pendingBestLocation, location].compactMap { $0 })
            guard isFreshEnough(location), isPreciseEnough(location) else { return }
            pendingLocationRequest?.resume(returning: location)
            pendingLocationRequest = nil
            pendingBestLocation = nil
            pendingRequestStartedAt = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = error.localizedDescription
        pendingLocationRequest?.resume(returning: nil)
        pendingLocationRequest = nil
        pendingBestLocation = nil
        pendingRequestStartedAt = nil
    }

    @discardableResult
    private func uploadFreshLocation(
        repository: LocationSyncRepository,
        squadID: String,
        activityID: String
    ) async -> Bool {
        let location = await requestFreshLocation(allowsCachedLocation: true)
        return await uploadLocation(location, repository: repository, squadID: squadID, activityID: activityID)
    }

    @discardableResult
    private func uploadLocation(
        _ location: CLLocation?,
        repository: LocationSyncRepository,
        squadID: String,
        activityID: String
    ) async -> Bool {
        guard let location else {
            errorMessage = L("还没有获取到定位，请稍后再试", "Location is not ready yet. Try again shortly.")
            return false
        }
        guard isFreshEnough(location) else {
            errorMessage = L("定位结果已过期，请稍后重试", "Location is stale. Try again shortly.")
            return false
        }
        if #available(iOS 14.0, *), manager.accuracyAuthorization == .reducedAccuracy {
            errorMessage = L("当前为大概位置，请在系统定位权限中开启精确位置", "Precise Location is off. Enable Precise Location in system settings.")
            return false
        }
        isUploading = true
        defer { isUploading = false }
        do {
            try await repository.uploadSquadOfflineActivityLocation(
                squadID: squadID,
                activityID: activityID,
                input: SquadOfflineLocationUploadInput(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    accuracy: location.horizontalAccuracy >= 0 ? location.horizontalAccuracy : nil,
                    altitude: location.verticalAccuracy >= 0 ? location.altitude : nil,
                    speed: location.speed >= 0 ? location.speed : nil,
                    heading: location.course >= 0 ? location.course : nil,
                    capturedAt: location.timestamp
                )
            )
            lastUploadAt = Date()
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.userFacingMessage ?? error.localizedDescription
            return false
        }
    }

    private func requestFreshLocation(allowsCachedLocation: Bool) async -> CLLocation? {
        if authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        guard hasLocationAuthorization else { return nil }
        if allowsCachedLocation, let lastLocation, isFreshEnough(lastLocation), isPreciseEnough(lastLocation) {
            return lastLocation
        }
        let requestStartedAt = Date()
        return await withCheckedContinuation { continuation in
            pendingLocationRequest?.resume(returning: nil)
            pendingBestLocation = nil
            pendingRequestStartedAt = requestStartedAt
            pendingLocationRequest = continuation
            manager.desiredAccuracy = kCLLocationAccuracyBest
            manager.startUpdatingLocation()
            manager.requestLocation()
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 12_000_000_000)
                guard let self, let pending = self.pendingLocationRequest else { return }
                self.pendingLocationRequest = nil
                let fallbackCandidates = [self.pendingBestLocation, self.lastLocation]
                    .compactMap { $0 }
                    .filter { self.isFreshEnough($0) }
                let fallback = self.bestLocation(from: fallbackCandidates)
                self.pendingBestLocation = nil
                self.pendingRequestStartedAt = nil
                pending.resume(returning: fallback.flatMap { self.isFreshEnough($0) ? $0 : nil })
            }
        }
    }

    private func bestLocation(from locations: [CLLocation]) -> CLLocation? {
        locations
            .filter { $0.horizontalAccuracy >= 0 }
            .sorted {
                if abs($0.horizontalAccuracy - $1.horizontalAccuracy) > 1 {
                    return $0.horizontalAccuracy < $1.horizontalAccuracy
                }
                return $0.timestamp > $1.timestamp
            }
            .first
    }

    private func isFreshEnough(_ location: CLLocation) -> Bool {
        abs(location.timestamp.timeIntervalSinceNow) <= maxAcceptedLocationAge
    }

    private func isPreciseEnough(_ location: CLLocation) -> Bool {
        location.horizontalAccuracy >= 0 && location.horizontalAccuracy <= preferredHorizontalAccuracy
    }

    private var hasLocationAuthorization: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }
}
