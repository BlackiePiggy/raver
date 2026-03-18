import SwiftUI

@main
struct RaverMVPApp: App {
    @StateObject private var appState = AppState(service: AppEnvironment.makeService())

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            RaverTheme.background.ignoresSafeArea()

            if appState.isLoggedIn {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .alert("提示", isPresented: Binding(
            get: { appState.errorMessage != nil },
            set: { newValue in
                if !newValue { appState.errorMessage = nil }
            }
        )) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(appState.errorMessage ?? "")
        }
    }
}
