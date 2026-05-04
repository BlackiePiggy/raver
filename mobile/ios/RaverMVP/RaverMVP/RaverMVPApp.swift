import SwiftUI
import UIKit
import UserNotifications

@main
struct RaverMVPApp: App {
    @UIApplicationDelegateAdaptor(RaverAppDelegate.self) private var appDelegate
    @StateObject private var appContainer: AppContainer
    @StateObject private var appState: AppState

    init() {
        ImageCacheBootstrap.configureIfNeeded()
        Self.applyUITestSessionResetIfNeeded()

        let socialService = AppEnvironment.makeService()
        let webService = AppEnvironment.makeWebService()
        _appContainer = StateObject(
            wrappedValue: AppContainer(
                socialService: socialService,
                webService: webService
            )
        )
        _appState = StateObject(wrappedValue: AppState(service: socialService))
    }

    var body: some Scene {
        WindowGroup {
            AppCoordinatorView()
                .environmentObject(appContainer)
                .environmentObject(appState)
                .preferredColorScheme(appState.preferredAppearance.preferredColorScheme)
        }
    }

    private static func applyUITestSessionResetIfNeeded() {
        let raw = ProcessInfo.processInfo.environment["RAVER_UI_TEST_RESET_SESSION"]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let enabled = raw == "1" || raw == "true" || raw == "yes" || raw == "on"
        guard enabled else { return }
        SessionTokenStore.shared.clear()
    }
}

private extension AppAppearance {
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

final class RaverAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private static var pendingSystemNotificationUserInfo: [AnyHashable: Any]?
    private static let pendingNotificationLock = NSLock()
    private static func pushRouteLog(_ message: String) {
        PushRouteTrace.log("SystemPushBootstrap", message)
    }

    static func consumePendingSystemNotificationUserInfo() -> [AnyHashable: Any]? {
        pendingNotificationLock.lock()
        defer { pendingNotificationLock.unlock() }
        let payload = pendingSystemNotificationUserInfo
        pendingSystemNotificationUserInfo = nil
        pushRouteLog("consume pending payload keys=\(summarizePayloadKeys(payload))")
        return payload
    }

    private static func cachePendingSystemNotificationUserInfo(_ userInfo: [AnyHashable: Any]) {
        pendingNotificationLock.lock()
        pendingSystemNotificationUserInfo = userInfo
        pendingNotificationLock.unlock()
        pushRouteLog("cache pending payload keys=\(summarizePayloadKeys(userInfo))")
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if let logPath = PushRouteTrace.currentLogFilePath {
            Self.pushRouteLog("log file path=\(logPath)")
        }
        Self.pushRouteLog("didFinishLaunching launchOptionsRemote=\((launchOptions?[.remoteNotification] as? [AnyHashable: Any]).map { Self.summarizePayloadKeys($0) } ?? "nil")")
        if let payload = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            Self.cachePendingSystemNotificationUserInfo(payload)
            NotificationCenter.default.post(
                name: .raverDidOpenSystemNotification,
                object: nil,
                userInfo: payload
            )
        }
        configureRemoteNotifications(application)
        return true
    }

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        _ = application
        _ = window
        return AppOrientationLock.shared.currentMask
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        _ = application
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        Self.pushRouteLog("didRegisterForRemoteNotifications tokenLength=\(token.count)")
        NotificationCenter.default.post(name: .raverDidRegisterPushToken, object: token)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        _ = application
        Self.pushRouteLog("didFailToRegisterForRemoteNotifications error=\(error.localizedDescription)")
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        _ = center
        Self.pushRouteLog("willPresent payload keys=\(Self.summarizePayloadKeys(notification.request.content.userInfo))")
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        _ = center
        let payload = response.notification.request.content.userInfo
        Self.pushRouteLog("didReceive response action=\(response.actionIdentifier) payload keys=\(Self.summarizePayloadKeys(payload))")
        Self.cachePendingSystemNotificationUserInfo(payload)
        NotificationCenter.default.post(
            name: .raverDidOpenSystemNotification,
            object: nil,
            userInfo: payload
        )
        completionHandler()
    }

    private func configureRemoteNotifications(_ application: UIApplication) {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        center.getNotificationSettings { settings in
            Self.pushRouteLog("configureRemoteNotifications authStatus=\(settings.authorizationStatus.rawValue)")
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                DispatchQueue.main.async {
                    Self.pushRouteLog("registerForRemoteNotifications authorized")
                    application.registerForRemoteNotifications()
                }
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                    Self.pushRouteLog("requestAuthorization result granted=\(granted)")
                    guard granted else { return }
                    DispatchQueue.main.async {
                        Self.pushRouteLog("registerForRemoteNotifications after prompt")
                        application.registerForRemoteNotifications()
                    }
                }
            case .denied:
                Self.pushRouteLog("notifications denied")
                break
            @unknown default:
                Self.pushRouteLog("notifications unknown auth status=\(settings.authorizationStatus.rawValue)")
                break
            }
        }
    }

    private static func summarizePayloadKeys(_ payload: [AnyHashable: Any]?) -> String {
        guard let payload else { return "nil" }
        let keys = payload.keys.compactMap { $0 as? String }.sorted()
        let apsKeys = (payload["aps"] as? [String: Any])?.keys.sorted() ?? []
        let metadataKeys = (payload["metadata"] as? [String: Any])?.keys.sorted() ?? []
        return "keys=\(keys) apsKeys=\(apsKeys) metadataKeys=\(metadataKeys)"
    }
}

@MainActor
final class AppOrientationLock {
    static let shared = AppOrientationLock()

    private(set) var currentMask: UIInterfaceOrientationMask = .portrait
    private var landscapeRequestCount = 0
    private var landscapeOnlyRequestCount = 0

    private init() {}

    func allowLandscape() {
        landscapeRequestCount += 1
        updateOrientationMask()
    }

    func lockPortrait(force: Bool) {
        landscapeRequestCount = max(0, landscapeRequestCount - 1)
        updateOrientationMask()
        if force, landscapeRequestCount == 0, landscapeOnlyRequestCount == 0 {
            forcePortraitRotation()
        }
    }

    func lockLandscapeOnly(forceRotate: Bool) {
        landscapeOnlyRequestCount += 1
        updateOrientationMask()
        if forceRotate {
            forceLandscapeRotation()
        }
    }

    func unlockLandscapeOnly(forcePortrait: Bool) {
        landscapeOnlyRequestCount = max(0, landscapeOnlyRequestCount - 1)
        updateOrientationMask()
        if forcePortrait, landscapeRequestCount == 0, landscapeOnlyRequestCount == 0 {
            forcePortraitRotation()
        }
    }

    private func updateOrientationMask() {
        if landscapeOnlyRequestCount > 0 {
            currentMask = .landscape
        } else if landscapeRequestCount > 0 {
            currentMask = .allButUpsideDown
        } else {
            currentMask = .portrait
        }
        refreshSupportedOrientations()
    }

    private func refreshSupportedOrientations() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
    }

    private func forcePortraitRotation() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        if #available(iOS 16.0, *) {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
            scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
        UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
    }

    private func forceLandscapeRotation() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        if #available(iOS 16.0, *) {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
            scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
        UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
    }
}

extension Notification.Name {
    static let raverDidRegisterPushToken = Notification.Name("raver.push.didRegisterToken")
    static let raverDidOpenSystemNotification = Notification.Name("raver.push.didOpenNotification")
}
