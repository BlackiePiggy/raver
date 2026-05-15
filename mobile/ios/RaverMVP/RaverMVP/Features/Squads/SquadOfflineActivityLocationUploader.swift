import CoreLocation
import Foundation

private enum SquadOfflineCoordinateTransform {
    private static let a = 6378245.0
    private static let ee = 0.00669342162296594323

    static func wgs84ToGcj02IfNeeded(_ coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        guard isInsideChina(coordinate) else {
            return coordinate
        }

        var dLat = transformLat(
            x: coordinate.longitude - 105.0,
            y: coordinate.latitude - 35.0
        )
        var dLng = transformLng(
            x: coordinate.longitude - 105.0,
            y: coordinate.latitude - 35.0
        )
        let radLat = coordinate.latitude / 180.0 * .pi
        var magic = sin(radLat)
        magic = 1 - ee * magic * magic
        let sqrtMagic = sqrt(magic)
        dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * .pi)
        dLng = (dLng * 180.0) / (a / sqrtMagic * cos(radLat) * .pi)

        return CLLocationCoordinate2D(
            latitude: coordinate.latitude + dLat,
            longitude: coordinate.longitude + dLng
        )
    }

    private static func isInsideChina(_ coordinate: CLLocationCoordinate2D) -> Bool {
        coordinate.longitude >= 72.004
            && coordinate.longitude <= 137.8347
            && coordinate.latitude >= 0.8293
            && coordinate.latitude <= 55.8271
    }

    private static func transformLat(x: Double, y: Double) -> Double {
        var result = -100.0
            + 2.0 * x
            + 3.0 * y
            + 0.2 * y * y
            + 0.1 * x * y
            + 0.2 * sqrt(abs(x))
        result += (20.0 * sin(6.0 * x * .pi) + 20.0 * sin(2.0 * x * .pi)) * 2.0 / 3.0
        result += (20.0 * sin(y * .pi) + 40.0 * sin(y / 3.0 * .pi)) * 2.0 / 3.0
        result += (160.0 * sin(y / 12.0 * .pi) + 320.0 * sin(y * .pi / 30.0)) * 2.0 / 3.0
        return result
    }

    private static func transformLng(x: Double, y: Double) -> Double {
        var result = 300.0
            + x
            + 2.0 * y
            + 0.1 * x * x
            + 0.1 * x * y
            + 0.1 * sqrt(abs(x))
        result += (20.0 * sin(6.0 * x * .pi) + 20.0 * sin(2.0 * x * .pi)) * 2.0 / 3.0
        result += (20.0 * sin(x * .pi) + 40.0 * sin(x / 3.0 * .pi)) * 2.0 / 3.0
        result += (150.0 * sin(x / 12.0 * .pi) + 300.0 * sin(x / 30.0 * .pi)) * 2.0 / 3.0
        return result
    }
}

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
        guard hasLocationAuthorization else { return }
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
        guard !isUploading else { return false }
        isUploading = true
        defer { isUploading = false }

        if !hasLocationAuthorization {
            if authorizationStatus == .notDetermined {
                manager.requestWhenInUseAuthorization()
            }
            errorMessage = LT("定位权限未开启，请在系统设置中允许定位后重试", "Location permission is disabled. Please enable it in Settings and try again.", "位置情報の権限が無効です。設定で許可してからもう一度お試しください。")
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
        guard !isUploading else { return false }
        isUploading = true
        defer { isUploading = false }

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
            errorMessage = LT("还没有获取到定位，请稍后再试", "Location is not ready yet. Try again shortly.", "位置情報はまだ取得できていません。少し待ってから再試行してください。")
            return false
        }
        guard isFreshEnough(location) else {
            errorMessage = LT("定位结果已过期，请稍后重试", "Location is stale. Try again shortly.", "位置情報が古くなっています。少し待ってから再試行してください。")
            return false
        }
        if #available(iOS 14.0, *), manager.accuracyAuthorization == .reducedAccuracy {
            errorMessage = LT("当前为大概位置，请在系统定位权限中开启精确位置", "Precise Location is off. Enable Precise Location in system settings.", "現在はおおよその位置です。システム設定で正確な位置情報を有効にしてください。")
            return false
        }
        let uploadCoordinate = SquadOfflineCoordinateTransform.wgs84ToGcj02IfNeeded(location.coordinate)
        do {
            try await repository.uploadSquadOfflineActivityLocation(
                squadID: squadID,
                activityID: activityID,
                input: SquadOfflineLocationUploadInput(
                    latitude: uploadCoordinate.latitude,
                    longitude: uploadCoordinate.longitude,
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
