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

    static func consumePendingSystemNotificationUserInfo() -> [AnyHashable: Any]? {
        pendingNotificationLock.lock()
        defer { pendingNotificationLock.unlock() }
        let payload = pendingSystemNotificationUserInfo
        pendingSystemNotificationUserInfo = nil
        return payload
    }

    private static func cachePendingSystemNotificationUserInfo(_ userInfo: [AnyHashable: Any]) {
        pendingNotificationLock.lock()
        pendingSystemNotificationUserInfo = userInfo
        pendingNotificationLock.unlock()
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
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
        NotificationCenter.default.post(name: .raverDidRegisterPushToken, object: token)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        _ = application
        #if DEBUG
        print("[Push] APNs register failed:", error.localizedDescription)
        #endif
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        _ = center
        _ = notification
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        _ = center
        let payload = response.notification.request.content.userInfo
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
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                    guard granted else { return }
                    DispatchQueue.main.async {
                        application.registerForRemoteNotifications()
                    }
                }
            case .denied:
                break
            @unknown default:
                break
            }
        }
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
