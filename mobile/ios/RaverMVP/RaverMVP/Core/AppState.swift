import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var session: Session?
    @Published var errorMessage: String?
    @Published var unreadMessagesCount: Int = 0

    let service: SocialService
    private var cancellables: Set<AnyCancellable> = []

    init(service: SocialService) {
        self.service = service

        NotificationCenter.default.publisher(for: .raverSessionExpired)
            .sink { [weak self] _ in
                guard let self else { return }
                self.session = nil
                self.unreadMessagesCount = 0
                self.errorMessage = "登录状态已失效，请重新登录"
            }
            .store(in: &cancellables)
    }

    var isLoggedIn: Bool {
        session != nil
    }

    func login(username: String, password: String) async {
        do {
            session = try await service.login(username: username, password: password)
            await refreshUnreadMessages()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func register(username: String, email: String, password: String, displayName: String) async {
        do {
            session = try await service.register(
                username: username,
                email: email,
                password: password,
                displayName: displayName
            )
            await refreshUnreadMessages()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func logout() {
        Task {
            await service.logout()
        }
        session = nil
        unreadMessagesCount = 0
    }

    func refreshUnreadMessages() async {
        guard session != nil else {
            unreadMessagesCount = 0
            return
        }

        do {
            async let directConversations = service.fetchConversations(type: .direct)
            async let groupConversations = service.fetchConversations(type: .group)
            async let notificationsUnread = service.fetchNotificationUnreadCount()
            let merged = try await directConversations + groupConversations
            let chatsUnread = merged.reduce(0) { $0 + max(0, $1.unreadCount) }
            let socialUnread = try await notificationsUnread
            unreadMessagesCount = chatsUnread + max(0, socialUnread.follows + socialUnread.likes + socialUnread.comments)
        } catch {
            // Keep current count when refresh fails.
        }
    }
}

extension Notification.Name {
    static let raverSessionExpired = Notification.Name("raver.session.expired")
}
