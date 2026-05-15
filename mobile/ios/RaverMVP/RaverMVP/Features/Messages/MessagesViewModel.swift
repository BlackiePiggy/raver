import Foundation
import Combine
import SwiftUI

protocol ConversationRepository: IMChatConversationDataSource {
    func startDirectConversation(identifier: String) async throws -> Conversation
}

protocol MessageNotificationRepository {
    func fetchNotifications(limit: Int) async throws -> NotificationInbox
    func fetchNotificationUnreadCount() async throws -> NotificationUnreadCount
    func markNotificationRead(notificationID: String) async throws
    func markNotificationsRead(type: AppNotificationType) async throws
    func fetchContentReviewSummary() async throws -> ContentReviewSummary
    func fetchContentReviewNotifications(limit: Int) async throws -> [ContentReviewNotificationItem]
    func markContentReviewNotificationRead(notificationID: String) async throws
    func fetchFollowedEventsSummary() async throws -> FollowedEventsSummary
    func fetchFollowedEventNotifications(limit: Int) async throws -> [FollowedEventNotificationItem]
    func markFollowedEventNotificationRead(notificationID: String) async throws
    func fetchFollowedDJsSummary() async throws -> FollowedDJsSummary
    func fetchFollowedDJNotifications(limit: Int) async throws -> [FollowedDJNotificationItem]
    func markFollowedDJNotificationRead(notificationID: String) async throws
    func fetchFollowedBrandsSummary() async throws -> FollowedBrandsSummary
    func fetchFollowedBrandNotifications(limit: Int) async throws -> [FollowedBrandNotificationItem]
    func markFollowedBrandNotificationRead(notificationID: String) async throws
}

struct ConversationRepositoryAdapter: ConversationRepository {
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

    func setConversationPinned(conversationID: String, pinned: Bool) async throws {
        try await service.setConversationPinned(conversationID: conversationID, pinned: pinned)
    }

    func markConversationUnread(conversationID: String, unread: Bool) async throws {
        try await service.markConversationUnread(conversationID: conversationID, unread: unread)
    }

    func hideConversation(conversationID: String) async throws {
        try await service.hideConversation(conversationID: conversationID)
    }

    func startDirectConversation(identifier: String) async throws -> Conversation {
        try await service.startDirectConversation(identifier: identifier)
    }
}

struct MessageNotificationRepositoryAdapter: MessageNotificationRepository {
    private let service: SocialService

    init(service: SocialService) {
        self.service = service
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

    func markNotificationsRead(type: AppNotificationType) async throws {
        try await service.markNotificationsRead(type: type)
    }

    func fetchContentReviewSummary() async throws -> ContentReviewSummary {
        try await service.fetchContentReviewSummary()
    }

    func fetchContentReviewNotifications(limit: Int) async throws -> [ContentReviewNotificationItem] {
        try await service.fetchContentReviewNotifications(limit: limit)
    }

    func markContentReviewNotificationRead(notificationID: String) async throws {
        try await service.markContentReviewNotificationRead(notificationID: notificationID)
    }

    func fetchFollowedEventsSummary() async throws -> FollowedEventsSummary {
        try await service.fetchFollowedEventsSummary()
    }

    func fetchFollowedEventNotifications(limit: Int) async throws -> [FollowedEventNotificationItem] {
        try await service.fetchFollowedEventNotifications(limit: limit)
    }

    func markFollowedEventNotificationRead(notificationID: String) async throws {
        try await service.markFollowedEventNotificationRead(notificationID: notificationID)
    }

    func fetchFollowedDJsSummary() async throws -> FollowedDJsSummary {
        try await service.fetchFollowedDJsSummary()
    }

    func fetchFollowedDJNotifications(limit: Int) async throws -> [FollowedDJNotificationItem] {
        try await service.fetchFollowedDJNotifications(limit: limit)
    }

    func markFollowedDJNotificationRead(notificationID: String) async throws {
        try await service.markFollowedDJNotificationRead(notificationID: notificationID)
    }

    func fetchFollowedBrandsSummary() async throws -> FollowedBrandsSummary {
        try await service.fetchFollowedBrandsSummary()
    }

    func fetchFollowedBrandNotifications(limit: Int) async throws -> [FollowedBrandNotificationItem] {
        try await service.fetchFollowedBrandNotifications(limit: limit)
    }

    func markFollowedBrandNotificationRead(notificationID: String) async throws {
        try await service.markFollowedBrandNotificationRead(notificationID: notificationID)
    }
}

@MainActor
final class MessagesViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var unreadTotal = 0
    @Published private(set) var phase: LoadPhase = .idle
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var bannerMessage: String?
    @Published var error: String?
    @Published var isEditingConversations = false
    @Published var selectedConversationIDs: Set<String> = []
    @Published var followedEventsSummary: FollowedEventsSummary = .empty
    @Published var followedDJsSummary: FollowedDJsSummary = .empty
    @Published var followedBrandsSummary: FollowedBrandsSummary = .empty
    @Published var contentReviewSummary: ContentReviewSummary = .empty

    private let conversationRepository: ConversationRepository
    private let notificationRepository: MessageNotificationRepository
    private let chatStore = IMChatStore.shared
    private var cancellables = Set<AnyCancellable>()

    init(
        conversationRepository: ConversationRepository,
        notificationRepository: MessageNotificationRepository
    ) {
        self.conversationRepository = conversationRepository
        self.notificationRepository = notificationRepository
        bindChatStore()
    }

    func load() async {
        if isLoading { return }
        isLoading = true
        let hadContent = !conversations.isEmpty
        if hadContent {
            isRefreshing = true
        } else {
            phase = .initialLoading
        }
        defer { isLoading = false }
        defer { isRefreshing = false }

        do {
            try await chatStore.loadConversations(using: conversationRepository)
            async let contentReviewsTask = notificationRepository.fetchContentReviewSummary()
            async let followedEventsTask = notificationRepository.fetchFollowedEventsSummary()
            async let followedDJsTask = notificationRepository.fetchFollowedDJsSummary()
            async let followedBrandsTask = notificationRepository.fetchFollowedBrandsSummary()
            contentReviewSummary = (try? await contentReviewsTask) ?? .empty
            followedEventsSummary = (try? await followedEventsTask) ?? .empty
            followedDJsSummary = (try? await followedDJsTask) ?? .empty
            followedBrandsSummary = (try? await followedBrandsTask) ?? .empty
            phase = conversations.isEmpty ? .empty : .success
            bannerMessage = nil
            self.error = nil
        } catch {
            let message = error.userFacingMessage ?? LT("消息加载失败，请稍后重试", "Failed to load messages. Please try again later.", "メッセージの読み込みに失敗しました。後でもう一度お試しください。")
            if hadContent {
                bannerMessage = message
                phase = .success
            } else {
                phase = .failure(message: message)
            }
        }
    }

    func refreshFollowedEventsSummary() async {
        followedEventsSummary = (try? await notificationRepository.fetchFollowedEventsSummary()) ?? .empty
    }

    func refreshContentReviewSummary() async {
        contentReviewSummary = (try? await notificationRepository.fetchContentReviewSummary()) ?? .empty
    }

    func refreshFollowedDJsSummary() async {
        followedDJsSummary = (try? await notificationRepository.fetchFollowedDJsSummary()) ?? .empty
    }

    func refreshFollowedBrandsSummary() async {
        followedBrandsSummary = (try? await notificationRepository.fetchFollowedBrandsSummary()) ?? .empty
    }

    func markConversationRead(conversationID: String) async {
        do {
            try await chatStore.markConversationRead(conversationID: conversationID, using: conversationRepository)
            error = nil
        } catch {
            self.error = error.userFacingMessage
        }
    }

    func setConversationPinned(conversationID: String, pinned: Bool) async {
        do {
            try await chatStore.setConversationPinned(
                conversationID: conversationID,
                pinned: pinned,
                using: conversationRepository
            )
            error = nil
        } catch {
            self.error = error.userFacingMessage
        }
    }

    func markConversationUnread(conversationID: String, unread: Bool) async {
        do {
            try await chatStore.markConversationUnread(
                conversationID: conversationID,
                unread: unread,
                using: conversationRepository
            )
            error = nil
        } catch {
            self.error = error.userFacingMessage
        }
    }

    func hideConversation(conversationID: String) async {
        do {
            try await chatStore.hideConversation(conversationID: conversationID, using: conversationRepository)
            selectedConversationIDs.remove(conversationID)
            error = nil
        } catch {
            self.error = error.userFacingMessage
        }
    }

    func toggleConversationEditing() {
        isEditingConversations.toggle()
        if !isEditingConversations {
            selectedConversationIDs.removeAll()
        }
    }

    func exitConversationEditing() {
        isEditingConversations = false
        selectedConversationIDs.removeAll()
    }

    func toggleConversationSelection(_ conversationID: String) {
        if selectedConversationIDs.contains(conversationID) {
            selectedConversationIDs.remove(conversationID)
        } else {
            selectedConversationIDs.insert(conversationID)
        }
    }

    func setConversationSelection(_ conversationID: String, selected: Bool) {
        if selected {
            selectedConversationIDs.insert(conversationID)
        } else {
            selectedConversationIDs.remove(conversationID)
        }
    }

    func isConversationSelected(_ conversationID: String) -> Bool {
        selectedConversationIDs.contains(conversationID)
    }

    func selectAllConversations() {
        selectedConversationIDs = Set(conversations.map(\.id))
    }

    func clearConversationSelection() {
        selectedConversationIDs.removeAll()
    }

    func markSelectedConversationsRead() async {
        let ids = Array(selectedConversationIDs)
        guard !ids.isEmpty else { return }
        for id in ids {
            await markConversationRead(conversationID: id)
        }
    }

    func hideSelectedConversations() async {
        let ids = Array(selectedConversationIDs)
        guard !ids.isEmpty else { return }
        for id in ids {
            await hideConversation(conversationID: id)
        }
        exitConversationEditing()
    }

    private func bindChatStore() {
        chatStore.$conversations
            .receive(on: DispatchQueue.main)
            .sink { [weak self] conversations in
                Task { @MainActor in
                    withAnimation(.snappy(duration: 0.24, extraBounce: 0.0)) {
                        self?.conversations = conversations
                    }
                    let validIDs = Set(conversations.map(\.id))
                    self?.selectedConversationIDs = self?.selectedConversationIDs.filter { validIDs.contains($0) } ?? []
                }
            }
            .store(in: &cancellables)

        chatStore.$unreadTotal
            .receive(on: DispatchQueue.main)
            .sink { [weak self] count in
                Task { @MainActor in
                    self?.unreadTotal = max(0, count)
                }
            }
            .store(in: &cancellables)
    }
}
