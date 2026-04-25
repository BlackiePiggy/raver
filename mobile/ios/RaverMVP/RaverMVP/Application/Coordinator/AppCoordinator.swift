import SwiftUI

private enum AppFlow {
    case authenticated
    case unauthenticated
}

struct AppCoordinatorView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            RaverTheme.background.ignoresSafeArea()

            if appState.isAuthBootstrapping {
                ProgressView()
                    .tint(.white.opacity(0.9))
                    .accessibilityIdentifier("app.loading")
            } else {
                switch currentFlow {
                case .authenticated:
                    MainTabCoordinatorView()
                        .id("main-tabs-\(appState.preferredLanguage.rawValue)")
                        .accessibilityIdentifier("app.authenticatedRoot")
                case .unauthenticated:
                    LoginView()
                        .accessibilityIdentifier("app.loginRoot")
                }
            }
        }
        .environment(\.locale, Locale(identifier: appState.preferredLanguage.localeIdentifier))
        .alert(L("提示", "Notice"), isPresented: Binding(
            get: { appState.errorMessage != nil },
            set: { newValue in
                if !newValue { appState.errorMessage = nil }
            }
        )) {
            Button(LL("知道了"), role: .cancel) {}
        } message: {
            Text(appState.errorMessage ?? "")
        }
    }

    private var currentFlow: AppFlow {
        appState.isLoggedIn ? .authenticated : .unauthenticated
    }
}
