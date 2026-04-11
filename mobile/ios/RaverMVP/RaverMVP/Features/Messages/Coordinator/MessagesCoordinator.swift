import SwiftUI

enum MessagesRoute: Hashable {
    case alertCategory(MessageAlertCategory)
}

enum MessagesModalRoute: Hashable {
    case squadProfile(String)
}

private struct MessagesPushKey: EnvironmentKey {
    static let defaultValue: (MessagesRoute) -> Void = { _ in }
}

extension EnvironmentValues {
    var messagesPush: (MessagesRoute) -> Void {
        get { self[MessagesPushKey.self] }
        set { self[MessagesPushKey.self] = newValue }
    }
}

private struct MessagesPresentKey: EnvironmentKey {
    static let defaultValue: (MessagesModalRoute) -> Void = { _ in }
}

extension EnvironmentValues {
    var messagesPresent: (MessagesModalRoute) -> Void {
        get { self[MessagesPresentKey.self] }
        set { self[MessagesPresentKey.self] = newValue }
    }
}

struct MessagesCoordinatorView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var chatViewModel: MessagesViewModel
    @StateObject private var alertViewModel: MessageNotificationsViewModel

    init(repository: MessagesRepository) {
        _chatViewModel = StateObject(wrappedValue: MessagesViewModel(repository: repository))
        _alertViewModel = StateObject(wrappedValue: MessageNotificationsViewModel(repository: repository))
    }

    var body: some View {
        MessagesHomeView(
            chatViewModel: chatViewModel,
            alertViewModel: alertViewModel,
            onUnreadStateChanged: requestUnreadRefresh
        )
        .background(RaverTheme.background)
    }

    private func requestUnreadRefresh() {
        Task {
            await appState.refreshUnreadMessages()
        }
    }
}
