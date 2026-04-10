import Foundation
import Combine

protocol MessagesRepository {
    func fetchConversations(type: ConversationType) async throws -> [Conversation]
    func markConversationRead(conversationID: String) async throws
    func fetchNotifications(limit: Int) async throws -> NotificationInbox
    func fetchNotificationUnreadCount() async throws -> NotificationUnreadCount
    func markNotificationRead(notificationID: String) async throws
}

struct MessagesRepositoryAdapter: MessagesRepository {
    private let service: SocialService

    init(service: SocialService) {
        self.service = service
    }

    func fetchConversations(type: ConversationType) async throws -> [Conversation] {
        try await service.fetchConversations(type: type)
    }

    func markConversationRead(conversationID: String) async throws {
        try await service.markConversationRead(conversationID: conversationID)
    }

    func fetchNotifications(limit: Int) async throws -> NotificationInbox {
        try await service.fetchNotifications(limit: limit)
    }

    func fetchNotificationUnreadCount() async throws -> NotificationUnreadCount {
        try await service.fetchNotificationUnreadCount()
    }

    func markNotificationRead(notificationID: String) async throws {
        try await service.markNotificationRead(notificationID: notificationID)
    }
}

@MainActor
final class MessagesViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var unreadTotal = 0
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
            async let directConversations = repository.fetchConversations(type: .direct)
            async let groupConversations = repository.fetchConversations(type: .group)
            let merged = try await directConversations + groupConversations
            conversations = Self.sortConversations(merged)
            unreadTotal = merged.reduce(0) { $0 + max(0, $1.unreadCount) }
            self.error = nil
        } catch {
            self.error = error.userFacingMessage
        }
    }

    func markConversationRead(conversationID: String) async {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        let previousUnread = conversations[index].unreadCount
        guard previousUnread > 0 else { return }

        conversations[index].unreadCount = 0
        conversations = Self.sortConversations(conversations)
        unreadTotal = conversations.reduce(0) { $0 + max(0, $1.unreadCount) }

        do {
            try await repository.markConversationRead(conversationID: conversationID)
            error = nil
        } catch {
            if let restoreIndex = conversations.firstIndex(where: { $0.id == conversationID }) {
                conversations[restoreIndex].unreadCount = previousUnread
            }
            conversations = Self.sortConversations(conversations)
            unreadTotal = conversations.reduce(0) { $0 + max(0, $1.unreadCount) }
            self.error = error.userFacingMessage
        }
    }

    private static func sortConversations(_ items: [Conversation]) -> [Conversation] {
        items.sorted { lhs, rhs in
            let lhsUnread = lhs.unreadCount > 0
            let rhsUnread = rhs.unreadCount > 0
            if lhsUnread != rhsUnread {
                return lhsUnread && !rhsUnread
            }
            if lhs.updatedAt != rhs.updatedAt {
                return lhs.updatedAt > rhs.updatedAt
            }
            return lhs.id < rhs.id
        }
    }
}
