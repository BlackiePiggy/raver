import Foundation

protocol NotificationRepository {
    func fetchNotifications(limit: Int) async throws -> NotificationInbox
    func markNotificationRead(notificationID: String) async throws
}

struct NotificationRepositoryAdapter: NotificationRepository {
    let service: SocialService

    func fetchNotifications(limit: Int) async throws -> NotificationInbox {
        try await service.fetchNotifications(limit: limit)
    }

    func markNotificationRead(notificationID: String) async throws {
        try await service.markNotificationRead(notificationID: notificationID)
    }
}

#if DEBUG
final class MockNotificationRepository: NotificationRepository {
    private var inbox: NotificationInbox
    private(set) var markedReadIDs: [String] = []

    init(inbox: NotificationInbox = .phase3Preview) {
        self.inbox = inbox
    }

    func fetchNotifications(limit: Int) async throws -> NotificationInbox {
        let normalizedLimit = max(1, limit)
        return NotificationInbox(
            unreadCount: inbox.items.filter { !$0.isRead }.count,
            items: Array(inbox.items.prefix(normalizedLimit))
        )
    }

    func markNotificationRead(notificationID: String) async throws {
        markedReadIDs.append(notificationID)
        guard let index = inbox.items.firstIndex(where: { $0.id == notificationID }) else { return }
        inbox.items[index].isRead = true
        inbox.unreadCount = inbox.items.filter { !$0.isRead }.count
    }
}

private extension NotificationInbox {
    static var phase3Preview: NotificationInbox {
        let actor = UserSummary(
            id: "u_phase3_preview",
            username: "phase3",
            displayName: "Phase 3 Preview",
            avatarURL: nil,
            isFollowing: true
        )
        return NotificationInbox(
            unreadCount: 2,
            items: [
                AppNotification(
                    id: "n_phase3_follow",
                    type: .follow,
                    createdAt: Date().addingTimeInterval(-240),
                    isRead: false,
                    actor: actor,
                    text: "\(actor.displayName) 关注了你",
                    target: AppNotificationTarget(type: "user", id: actor.id, title: actor.displayName)
                ),
                AppNotification(
                    id: "n_phase3_comment",
                    type: .comment,
                    createdAt: Date().addingTimeInterval(-980),
                    isRead: false,
                    actor: actor,
                    text: "\(actor.displayName) 评论了你的动态",
                    target: AppNotificationTarget(type: "post", id: "p_phase3", title: "Phase 3 repository seam")
                )
            ]
        )
    }
}
#endif
