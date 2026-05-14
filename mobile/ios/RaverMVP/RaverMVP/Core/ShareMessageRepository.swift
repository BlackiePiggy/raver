import Foundation

protocol ShareMessageRepository {
    func fetchConversations(type: ConversationType) async throws -> [Conversation]
    func sendMessage(conversationID: String, content: String) async throws -> ChatMessage
    func sendPostCardMessage(conversationID: String, payload: PostShareCardPayload) async throws -> ChatMessage
    func sendCircleIDCardMessage(conversationID: String, payload: CircleIDShareCardPayload) async throws -> ChatMessage
    func sendEventCardMessage(conversationID: String, payload: EventShareCardPayload) async throws -> ChatMessage
    func sendDJCardMessage(conversationID: String, payload: DJShareCardPayload) async throws -> ChatMessage
    func sendSetCardMessage(conversationID: String, payload: SetShareCardPayload) async throws -> ChatMessage
    func sendBrandCardMessage(conversationID: String, payload: BrandShareCardPayload) async throws -> ChatMessage
    func sendLabelCardMessage(conversationID: String, payload: LabelShareCardPayload) async throws -> ChatMessage
    func sendNewsCardMessage(conversationID: String, payload: NewsShareCardPayload) async throws -> ChatMessage
    func sendRankingBoardCardMessage(conversationID: String, payload: RankingBoardShareCardPayload) async throws -> ChatMessage
    func sendMyCheckinsCardMessage(conversationID: String, payload: MyCheckinsShareCardPayload) async throws -> ChatMessage
    func sendRatingEventCardMessage(conversationID: String, payload: RatingEventShareCardPayload) async throws -> ChatMessage
    func sendRatingUnitCardMessage(conversationID: String, payload: RatingUnitShareCardPayload) async throws -> ChatMessage
    func sendEventRouteCardMessage(conversationID: String, payload: EventRouteShareCardPayload) async throws -> ChatMessage
}

struct ShareMessageRepositoryAdapter: ShareMessageRepository {
    private let service: SocialService

    init(service: SocialService) {
        self.service = service
    }

    func fetchConversations(type: ConversationType) async throws -> [Conversation] {
        try await service.fetchConversations(type: type)
    }

    func sendMessage(conversationID: String, content: String) async throws -> ChatMessage {
        try await service.sendMessage(conversationID: conversationID, content: content)
    }

    func sendPostCardMessage(conversationID: String, payload: PostShareCardPayload) async throws -> ChatMessage {
        try await service.sendPostCardMessage(conversationID: conversationID, payload: payload)
    }

    func sendCircleIDCardMessage(
        conversationID: String,
        payload: CircleIDShareCardPayload
    ) async throws -> ChatMessage {
        try await service.sendCircleIDCardMessage(conversationID: conversationID, payload: payload)
    }

    func sendEventCardMessage(conversationID: String, payload: EventShareCardPayload) async throws -> ChatMessage {
        try await service.sendEventCardMessage(conversationID: conversationID, payload: payload)
    }

    func sendDJCardMessage(conversationID: String, payload: DJShareCardPayload) async throws -> ChatMessage {
        try await service.sendDJCardMessage(conversationID: conversationID, payload: payload)
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

    func sendMyCheckinsCardMessage(
        conversationID: String,
        payload: MyCheckinsShareCardPayload
    ) async throws -> ChatMessage {
        try await service.sendMyCheckinsCardMessage(conversationID: conversationID, payload: payload)
    }

    func sendRatingEventCardMessage(
        conversationID: String,
        payload: RatingEventShareCardPayload
    ) async throws -> ChatMessage {
        try await service.sendRatingEventCardMessage(conversationID: conversationID, payload: payload)
    }

    func sendRatingUnitCardMessage(
        conversationID: String,
        payload: RatingUnitShareCardPayload
    ) async throws -> ChatMessage {
        try await service.sendRatingUnitCardMessage(conversationID: conversationID, payload: payload)
    }

    func sendEventRouteCardMessage(conversationID: String, payload: EventRouteShareCardPayload) async throws -> ChatMessage {
        try await service.sendEventRouteCardMessage(conversationID: conversationID, payload: payload)
    }
}
