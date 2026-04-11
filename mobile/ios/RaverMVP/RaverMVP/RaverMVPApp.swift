import SwiftUI
import UIKit

@main
struct RaverMVPApp: App {
    @UIApplicationDelegateAdaptor(RaverAppDelegate.self) private var appDelegate
    @StateObject private var appContainer: AppContainer
    @StateObject private var appState: AppState

    init() {
        ImageCacheBootstrap.configureIfNeeded()

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
                .preferredColorScheme(.dark)
        }
    }
}

final class RaverAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        AppOrientationLock.shared.currentMask
    }
}

@MainActor
final class AppOrientationLock {
    static let shared = AppOrientationLock()

    private(set) var currentMask: UIInterfaceOrientationMask = .portrait
    private var landscapeRequestCount = 0

    private init() {}

    func allowLandscape() {
        landscapeRequestCount += 1
        currentMask = .allButUpsideDown
        refreshSupportedOrientations()
    }

    func lockPortrait(force: Bool) {
        landscapeRequestCount = max(0, landscapeRequestCount - 1)
        guard landscapeRequestCount == 0 else { return }
        currentMask = .portrait
        refreshSupportedOrientations()
        if force {
            forcePortraitRotation()
        }
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
}
