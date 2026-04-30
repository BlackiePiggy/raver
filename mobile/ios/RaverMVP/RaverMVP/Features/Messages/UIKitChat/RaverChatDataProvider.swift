import Foundation

@MainActor
final class RaverChatDataProvider {
    private let chatStore: IMChatStore
    private var conversation: Conversation
    private var service: SocialService

    init(
        conversation: Conversation,
        service: SocialService,
        chatStore: IMChatStore? = nil
    ) {
        self.conversation = conversation
        self.service = service
        self.chatStore = chatStore ?? .shared
    }

    var currentConversation: Conversation {
        conversation
    }

    var currentService: SocialService {
        service
    }

    func updateContext(conversation: Conversation, service: SocialService) {
        self.conversation = conversation
        self.service = service
    }

    func searchMessages(
        query: String,
        limit: Int = 30
    ) async throws -> [ChatMessageSearchResult] {
        return try await chatStore.searchMessages(
            query: query,
            conversationID: conversation.id,
            limit: limit
        )
    }
}
