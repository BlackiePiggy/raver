import Foundation

protocol ChatMessageRepository: AnyObject {
    func fetchMessages(conversationID: String) async throws -> [ChatMessage]
    func fetchMessages(
        conversationID: String,
        startClientMsgID: String?,
        count: Int
    ) async throws -> ChatMessageHistoryPage
    func sendMessage(
        conversationID: String,
        content: String,
        mentionedUserIDs: [String]
    ) async throws -> ChatMessage
    func sendImageMessage(conversationID: String, fileURL: URL) async throws -> ChatMessage
    func sendVideoMessage(conversationID: String, fileURL: URL) async throws -> ChatMessage
    func sendVoiceMessage(conversationID: String, fileURL: URL) async throws -> ChatMessage
    func sendFileMessage(conversationID: String, fileURL: URL) async throws -> ChatMessage
    func sendEventCardMessage(conversationID: String, payload: EventShareCardPayload) async throws -> ChatMessage
    func sendSetCardMessage(conversationID: String, payload: SetShareCardPayload) async throws -> ChatMessage
    func sendBrandCardMessage(conversationID: String, payload: BrandShareCardPayload) async throws -> ChatMessage
    func sendLabelCardMessage(conversationID: String, payload: LabelShareCardPayload) async throws -> ChatMessage
    func sendNewsCardMessage(conversationID: String, payload: NewsShareCardPayload) async throws -> ChatMessage
    func sendRankingBoardCardMessage(conversationID: String, payload: RankingBoardShareCardPayload) async throws -> ChatMessage
    func sendMyCheckinsCardMessage(conversationID: String, payload: MyCheckinsShareCardPayload) async throws -> ChatMessage
    func sendEventRouteCardMessage(conversationID: String, payload: EventRouteShareCardPayload) async throws -> ChatMessage
    func sendTypingStatus(conversationID: String, isTyping: Bool) async throws
    func markConversationRead(conversationID: String) async throws
    func revokeMessage(conversationID: String, messageID: String) async throws -> String
    func deleteMessage(conversationID: String, messageID: String) async throws
}

final class ChatMessageRepositoryAdapter: ChatMessageRepository {
    private let service: SocialService

    init(service: SocialService) {
        self.service = service
    }

    func fetchMessages(conversationID: String) async throws -> [ChatMessage] {
        try await service.fetchMessages(conversationID: conversationID)
    }

    func fetchMessages(
        conversationID: String,
        startClientMsgID: String?,
        count: Int
    ) async throws -> ChatMessageHistoryPage {
        try await service.fetchMessages(
            conversationID: conversationID,
            startClientMsgID: startClientMsgID,
            count: count
        )
    }

    func sendMessage(
        conversationID: String,
        content: String,
        mentionedUserIDs: [String]
    ) async throws -> ChatMessage {
        try await service.sendMessage(
            conversationID: conversationID,
            content: content,
            mentionedUserIDs: mentionedUserIDs
        )
    }

    func sendImageMessage(conversationID: String, fileURL: URL) async throws -> ChatMessage {
        try await service.sendImageMessage(conversationID: conversationID, fileURL: fileURL)
    }

    func sendVideoMessage(conversationID: String, fileURL: URL) async throws -> ChatMessage {
        try await service.sendVideoMessage(conversationID: conversationID, fileURL: fileURL)
    }

    func sendVoiceMessage(conversationID: String, fileURL: URL) async throws -> ChatMessage {
        try await service.sendVoiceMessage(conversationID: conversationID, fileURL: fileURL)
    }

    func sendFileMessage(conversationID: String, fileURL: URL) async throws -> ChatMessage {
        try await service.sendFileMessage(conversationID: conversationID, fileURL: fileURL)
    }

    func sendEventCardMessage(conversationID: String, payload: EventShareCardPayload) async throws -> ChatMessage {
        try await service.sendEventCardMessage(conversationID: conversationID, payload: payload)
    }

    func sendSetCardMessage(conversationID: String, payload: SetShareCardPayload) async throws -> ChatMessage {
        try await service.sendSetCardMessage(conversationID: conversationID, payload: payload)
    }

    func sendBrandCardMessage(conversationID: String, payload: BrandShareCardPayload) async throws -> ChatMessage {
        try await service.sendBrandCardMessage(conversationID: conversationID, payload: payload)
    }

    func sendLabelCardMessage(conversationID: String, payload: LabelShareCardPayload) async throws -> ChatMessage {
        try await service.sendLabelCardMessage(conversationID: conversationID, payload: payload)
    }

    func sendNewsCardMessage(conversationID: String, payload: NewsShareCardPayload) async throws -> ChatMessage {
        try await service.sendNewsCardMessage(conversationID: conversationID, payload: payload)
    }

    func sendRankingBoardCardMessage(
        conversationID: String,
        payload: RankingBoardShareCardPayload
    ) async throws -> ChatMessage {
        try await service.sendRankingBoardCardMessage(conversationID: conversationID, payload: payload)
    }

    func sendMyCheckinsCardMessage(conversationID: String, payload: MyCheckinsShareCardPayload) async throws -> ChatMessage {
        try await service.sendMyCheckinsCardMessage(conversationID: conversationID, payload: payload)
    }

    func sendEventRouteCardMessage(conversationID: String, payload: EventRouteShareCardPayload) async throws -> ChatMessage {
        try await service.sendEventRouteCardMessage(conversationID: conversationID, payload: payload)
    }

    func sendTypingStatus(conversationID: String, isTyping: Bool) async throws {
        try await service.sendTypingStatus(conversationID: conversationID, isTyping: isTyping)
    }

    func markConversationRead(conversationID: String) async throws {
        try await service.markConversationRead(conversationID: conversationID)
    }

    func revokeMessage(conversationID: String, messageID: String) async throws -> String {
        try await service.revokeMessage(conversationID: conversationID, messageID: messageID)
    }

    func deleteMessage(conversationID: String, messageID: String) async throws {
        try await service.deleteMessage(conversationID: conversationID, messageID: messageID)
    }
}

@MainActor
final class RaverChatDataProvider {
    private let chatStore: IMChatStore
    private var conversation: Conversation
    private var repository: ChatMessageRepository

    init(
        conversation: Conversation,
        repository: ChatMessageRepository,
        chatStore: IMChatStore? = nil
    ) {
        self.conversation = conversation
        self.repository = repository
        self.chatStore = chatStore ?? .shared
    }

    var currentConversation: Conversation {
        conversation
    }

    var currentRepository: ChatMessageRepository {
        repository
    }

    func updateContext(conversation: Conversation, repository: ChatMessageRepository) {
        self.conversation = conversation
        self.repository = repository
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
