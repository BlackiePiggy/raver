import SwiftUI
import Foundation

struct AppCoordinatorView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            RaverTheme.background.ignoresSafeArea()

            MainTabCoordinatorView()
                .id("main-tabs-\(appState.preferredLanguage.rawValue)")
                .accessibilityIdentifier("app.mainRoot")
        }
        .environment(\.locale, Locale(identifier: appState.preferredLanguage.localeIdentifier))
        .onOpenURL { url in
            handleIncomingURL(url)
        }
        .alert(LT("提示", "Notice", "お知らせ"), isPresented: Binding(
            get: { appState.errorMessage != nil },
            set: { newValue in
                if !newValue { appState.errorMessage = nil }
            }
        )) {
            Button(LT("知道了", "Got it", "OK"), role: .cancel) {}
        } message: {
            Text(appState.errorMessage ?? "")
        }
    }

    private func handleIncomingURL(_ url: URL) {
        recordShareAppOpenIfNeeded(url)

        Task {
            let router = UniversalLinkRouter(service: AppEnvironment.makeShareLinkService())
            let resolved = await router.resolve(url) ?? url.absoluteString
            let deeplink = resolved.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !deeplink.isEmpty else { return }
            await MainActor.run {
                appState.systemDeepLinkEvent = SystemDeepLinkEvent(
                    deeplink: deeplink,
                    source: "open-url"
                )
            }
        }
    }

    private func recordShareAppOpenIfNeeded(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "shareCode" })?.value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !code.isEmpty else {
            return
        }

        Task.detached {
            try? await AppEnvironment.makeShareLinkService().recordEvent(
                code: code,
                eventType: "app_open",
                channel: "universal_link",
                anonymousId: nil,
                metadata: [
                    "source": "open-url",
                    "incomingURL": url.absoluteString
                ]
            )
        }
    }
}
