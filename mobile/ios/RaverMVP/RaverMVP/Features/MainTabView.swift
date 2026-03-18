import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            DiscoverHomeView()
                .tabItem {
                    Label("发现", systemImage: "safari.fill")
                }

            MessagesHomeView()
                .tabItem {
                    Label("消息", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .badge(appState.unreadMessagesCount > 0 ? Text("\(appState.unreadMessagesCount)") : nil)

            ProfileView()
                .tabItem {
                    Label("我的", systemImage: "person.crop.circle.fill")
                }
        }
        .tint(RaverTheme.accent)
        .task {
            await appState.refreshUnreadMessages()
        }
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else { return }
            Task { await appState.refreshUnreadMessages() }
        }
    }
}
