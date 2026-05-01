import Foundation

@MainActor
final class NotificationsViewModel: ObservableObject {
    @Published var notifications: [AppNotification] = []
    @Published var unreadCount = 0
    @Published private(set) var phase: LoadPhase = .idle
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var bannerMessage: String?
    @Published var error: String?

    private let service: SocialService

    init(service: SocialService) {
        self.service = service
    }

    func load() async {
        if isLoading { return }
        isLoading = true
        let hadContent = !notifications.isEmpty
        if hadContent {
            isRefreshing = true
        } else {
            phase = .initialLoading
        }
        defer { isLoading = false }
        defer { isRefreshing = false }

        do {
            let inbox = try await service.fetchNotifications(limit: 30)
            notifications = inbox.items
            unreadCount = inbox.unreadCount
            publishCommunityUnreadDidChange()
            phase = notifications.isEmpty ? .empty : .success
            bannerMessage = nil
            error = nil
        } catch {
            let message = error.userFacingMessage ?? L("通知加载失败，请稍后重试", "Failed to load notifications. Please try again later.")
            if hadContent {
                bannerMessage = message
                phase = .success
            } else {
                phase = .failure(message: message)
            }
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
            bannerMessage = nil
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
