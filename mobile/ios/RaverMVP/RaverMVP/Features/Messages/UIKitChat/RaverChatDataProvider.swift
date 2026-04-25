import Foundation

@MainActor
final class RaverChatDataProvider {
    private let chatStore: OpenIMChatStore
    private var conversation: Conversation
    private var service: SocialService

    init(
        conversation: Conversation,
        service: SocialService,
        chatStore: OpenIMChatStore? = nil
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
        limit: Int = 30,
        remoteDataSource: ChatMessageSearchRemoteDataSource? = nil
    ) async throws -> [ChatMessageSearchResult] {
        try await chatStore.searchMessages(
            query: query,
            conversationID: conversation.id,
            limit: limit,
            remoteDataSource: remoteDataSource
        )
    }
}
