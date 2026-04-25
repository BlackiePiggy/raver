import Foundation

@MainActor
final class NotificationsViewModel: ObservableObject {
    @Published var notifications: [AppNotification] = []
    @Published var unreadCount = 0
    @Published var isLoading = false
    @Published var error: String?

    private let service: SocialService

    init(service: SocialService) {
        self.service = service
    }

    func load() async {
        if isLoading { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let inbox = try await service.fetchNotifications(limit: 30)
            notifications = inbox.items
            unreadCount = inbox.unreadCount
            publishCommunityUnreadDidChange()
            error = nil
        } catch {
            self.error = error.userFacingMessage
        }
    }

    func markRead(_ item: AppNotification) async {
        guard let index = notifications.firstIndex(where: { $0.id == item.id }) else { return }
        guard notifications[index].isRead == false else { return }

        notifications[index].isRead = true
        unreadCount = max(0, unreadCount - 1)
        publishCommunityUnreadDidChange()

        do {
            try await service.markNotificationRead(notificationID: item.id)
            error = nil
        } catch {
            notifications[index].isRead = false
            unreadCount += 1
            publishCommunityUnreadDidChange()
            self.error = error.userFacingMessage
        }
    }

    private func publishCommunityUnreadDidChange() {
        NotificationCenter.default.post(
            name: .raverCommunityUnreadDidChange,
            object: nil,
            userInfo: ["total": unreadCount]
        )
    }
}
