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
