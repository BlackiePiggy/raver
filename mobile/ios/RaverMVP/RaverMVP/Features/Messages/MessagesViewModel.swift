import Foundation
import Combine

@MainActor
final class MessagesViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var unreadTotal = 0
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
            async let directConversations = service.fetchConversations(type: .direct)
            async let groupConversations = service.fetchConversations(type: .group)
            let merged = try await directConversations + groupConversations
            conversations = Self.sortConversations(merged)
            unreadTotal = merged.reduce(0) { $0 + max(0, $1.unreadCount) }
            self.error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func markConversationRead(conversationID: String) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        guard conversations[index].unreadCount > 0 else { return }
        conversations[index].unreadCount = 0
        conversations = Self.sortConversations(conversations)
        unreadTotal = conversations.reduce(0) { $0 + max(0, $1.unreadCount) }
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
