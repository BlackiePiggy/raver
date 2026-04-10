import SwiftUI

enum MessagesRoute: Hashable {
    case conversation(Conversation)
    case userProfile(String)
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
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var appState: AppState
    @StateObject private var chatViewModel: MessagesViewModel
    @StateObject private var alertViewModel: MessageNotificationsViewModel
    @State private var navPath: [MessagesRoute] = []
    @State private var presentedModal: MessagesModalRoute?

    init(repository: MessagesRepository) {
        _chatViewModel = StateObject(wrappedValue: MessagesViewModel(repository: repository))
        _alertViewModel = StateObject(wrappedValue: MessageNotificationsViewModel(repository: repository))
    }

    var body: some View {
        NavigationStack(path: $navPath) {
            MessagesHomeView(
                chatViewModel: chatViewModel,
                alertViewModel: alertViewModel,
                onUnreadStateChanged: requestUnreadRefresh
            )
                .navigationDestination(for: MessagesRoute.self) { route in
                    routeDestination(for: route)
                }
        }
        .environment(\.messagesPush) { route in
            navPath.append(route)
        }
        .environment(\.messagesPresent) { route in
            presentedModal = route
        }
        .navigationDestination(item: $presentedModal) { route in
            modalDestination(for: route)
        }
        .background(RaverTheme.background)
    }

    @ViewBuilder
    private func routeDestination(for route: MessagesRoute) -> some View {
        switch route {
        case let .conversation(conversation):
            ChatView(conversation: conversation, service: appContainer.socialService)
        case let .userProfile(userID):
            UserProfileView(userID: userID)
        case let .alertCategory(category):
            MessageAlertDetailView(
                category: category,
                viewModel: alertViewModel
            ) {
                requestUnreadRefresh()
            }
        }
    }

    @ViewBuilder
    private func modalDestination(for route: MessagesModalRoute) -> some View {
        switch route {
        case let .squadProfile(squadID):
            SquadProfileView(
                squadID: squadID,
                service: appContainer.socialService
            )
        }
    }

    private func requestUnreadRefresh() {
        Task {
            await appState.refreshUnreadMessages()
        }
    }
}
