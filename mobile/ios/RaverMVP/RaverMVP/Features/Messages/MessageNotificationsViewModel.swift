import Foundation

@MainActor
final class MessageNotificationsViewModel: ObservableObject {
    @Published var notifications: [AppNotification] = []
    @Published var unreadCounts = NotificationUnreadCount(total: 0, follows: 0, likes: 0, comments: 0, squadInvites: 0)
    @Published var isLoading = false
    @Published var error: String?

    private let repository: MessagesRepository

    init(repository: MessagesRepository) {
        self.repository = repository
    }

    func load() async {
        if isLoading { return }
        isLoading = true
        defer { isLoading = false }

        do {
            async let inbox = repository.fetchNotifications(limit: 50)
            async let unread = repository.fetchNotificationUnreadCount()
            let inboxResult = try await inbox
            let unreadResult = try await unread

            notifications = inboxResult.items
            unreadCounts = unreadResult
            unreadCounts.total = unreadCounts.follows + unreadCounts.likes + unreadCounts.comments
            error = nil
        } catch {
            self.error = error.userFacingMessage
        }
    }

    func markRead(_ item: AppNotification) async {
        guard let index = notifications.firstIndex(where: { $0.id == item.id }) else { return }
        guard notifications[index].isRead == false else { return }

        notifications[index].isRead = true
        decrementUnread(for: item.type)

        do {
            try await repository.markNotificationRead(notificationID: item.id)
            error = nil
        } catch {
            notifications[index].isRead = false
            incrementUnread(for: item.type)
            self.error = error.userFacingMessage
        }
    }

    func unreadCount(for type: AppNotificationType) -> Int {
        switch type {
        case .follow:
            return unreadCounts.follows
        case .like:
            return unreadCounts.likes
        case .comment:
            return unreadCounts.comments
        case .squadInvite:
            return unreadCounts.squadInvites
        }
    }

    func items(for type: AppNotificationType) -> [AppNotification] {
        notifications
            .filter { $0.type == type }
            .sorted(by: { $0.createdAt > $1.createdAt })
    }

    private func decrementUnread(for type: AppNotificationType) {
        switch type {
        case .follow:
            unreadCounts.follows = max(0, unreadCounts.follows - 1)
        case .like:
            unreadCounts.likes = max(0, unreadCounts.likes - 1)
        case .comment:
            unreadCounts.comments = max(0, unreadCounts.comments - 1)
        case .squadInvite:
            unreadCounts.squadInvites = max(0, unreadCounts.squadInvites - 1)
        }
        unreadCounts.total = max(0, unreadCounts.total - 1)
    }

    private func incrementUnread(for type: AppNotificationType) {
        switch type {
        case .follow:
            unreadCounts.follows += 1
        case .like:
            unreadCounts.likes += 1
        case .comment:
            unreadCounts.comments += 1
        case .squadInvite:
            unreadCounts.squadInvites += 1
        }
        unreadCounts.total += 1
    }
}
