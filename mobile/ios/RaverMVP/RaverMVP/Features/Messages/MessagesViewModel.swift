import Foundation
import Combine
import SwiftUI

protocol MessagesRepository: IMChatConversationDataSource {
    func fetchNotifications(limit: Int) async throws -> NotificationInbox
    func fetchNotificationUnreadCount() async throws -> NotificationUnreadCount
    func markNotificationRead(notificationID: String) async throws
    func markNotificationsRead(type: AppNotificationType) async throws
    func fetchFollowedEventsSummary() async throws -> FollowedEventsSummary
    func fetchFollowedEventNotifications(limit: Int) async throws -> [FollowedEventNotificationItem]
    func markFollowedEventNotificationRead(notificationID: String) async throws
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

    func setConversationPinned(conversationID: String, pinned: Bool) async throws {
        try await service.setConversationPinned(conversationID: conversationID, pinned: pinned)
    }

    func markConversationUnread(conversationID: String, unread: Bool) async throws {
        try await service.markConversationUnread(conversationID: conversationID, unread: unread)
    }

    func hideConversation(conversationID: String) async throws {
        try await service.hideConversation(conversationID: conversationID)
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

    func fetchFollowedEventsSummary() async throws -> FollowedEventsSummary {
        try await service.fetchFollowedEventsSummary()
    }

    func fetchFollowedEventNotifications(limit: Int) async throws -> [FollowedEventNotificationItem] {
        try await service.fetchFollowedEventNotifications(limit: limit)
    }

    func markFollowedEventNotificationRead(notificationID: String) async throws {
        try await service.markFollowedEventNotificationRead(notificationID: notificationID)
    }
}

@MainActor
final class MessagesViewModel: ObservableObject {
    struct GlobalSearchSection: Identifiable, Hashable {
        let conversation: Conversation
        let results: [ChatMessageSearchResult]

        var id: String { conversation.id }
    }

    @Published var conversations: [Conversation] = []
    @Published var unreadTotal = 0
    @Published private(set) var phase: LoadPhase = .idle
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var bannerMessage: String?
    @Published var error: String?
    @Published var globalSearchSections: [GlobalSearchSection] = []
    @Published var isGlobalSearching = false
    @Published var globalSearchError: String?
    @Published var isEditingConversations = false
    @Published var selectedConversationIDs: Set<String> = []
    @Published var followedEventsSummary: FollowedEventsSummary = .empty

    private let repository: MessagesRepository
    private let chatStore = IMChatStore.shared
    private var cancellables = Set<AnyCancellable>()

    init(repository: MessagesRepository) {
        self.repository = repository
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
            try await chatStore.loadConversations(using: repository)
            followedEventsSummary = (try? await repository.fetchFollowedEventsSummary()) ?? .empty
            phase = conversations.isEmpty ? .empty : .success
            bannerMessage = nil
            self.error = nil
        } catch {
            let message = error.userFacingMessage ?? L("消息加载失败，请稍后重试", "Failed to load messages. Please try again later.")
            if hadContent {
                bannerMessage = message
                phase = .success
            } else {
                phase = .failure(message: message)
            }
        }
    }

    func refreshFollowedEventsSummary() async {
        followedEventsSummary = (try? await repository.fetchFollowedEventsSummary()) ?? .empty
    }

    func markConversationRead(conversationID: String) async {
        do {
            try await chatStore.markConversationRead(conversationID: conversationID, using: repository)
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
                using: repository
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
                using: repository
            )
            error = nil
        } catch {
            self.error = error.userFacingMessage
        }
    }

    func hideConversation(conversationID: String) async {
        do {
            try await chatStore.hideConversation(conversationID: conversationID, using: repository)
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

    func searchGlobally(query: String, limit: Int = 120) async {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else {
            globalSearchSections = []
            globalSearchError = nil
            isGlobalSearching = false
            IMProbeLogger.log("[GlobalSearch] cleared-empty-query")
            return
        }

        isGlobalSearching = true
        IMProbeLogger.log(
            "[GlobalSearch] submit query=\(normalizedQuery) limit=\(max(1, limit))"
        )
        defer { isGlobalSearching = false }

        do {
            let hits = try await chatStore.searchMessages(
                query: normalizedQuery,
                conversationID: nil,
                limit: max(1, limit)
            )
            globalSearchSections = buildGlobalSearchSections(from: hits)
            globalSearchError = nil
            error = nil
            IMProbeLogger.log(
                "[GlobalSearch] result query=\(normalizedQuery) sectionCount=\(globalSearchSections.count) hitCount=\(hits.count)"
            )
        } catch {
            globalSearchSections = []
            globalSearchError = error.userFacingMessage
            IMProbeLogger.log(
                "[GlobalSearch] failed query=\(normalizedQuery) error=\(error.localizedDescription)"
            )
        }
    }

    func clearGlobalSearchState() {
        globalSearchSections = []
        globalSearchError = nil
        isGlobalSearching = false
        IMProbeLogger.log("[GlobalSearch] state-cleared")
    }

    private func buildGlobalSearchSections(from hits: [ChatMessageSearchResult]) -> [GlobalSearchSection] {
        guard !hits.isEmpty else { return [] }

        var conversationByKey: [String: Conversation] = [:]
        for conversation in conversations {
            conversationByKey[conversation.id] = conversation
        }

        var groupedHits: [String: [ChatMessageSearchResult]] = [:]
        var groupedConversation: [String: Conversation] = [:]

        for hit in hits {
            let resolvedConversation = conversationByKey[hit.conversationID]
                ?? fallbackConversation(for: hit.conversationID)
            groupedHits[resolvedConversation.id, default: []].append(hit)
            groupedConversation[resolvedConversation.id] = resolvedConversation
        }

        let sections = groupedHits.compactMap { key, values -> GlobalSearchSection? in
            guard let conversation = groupedConversation[key] else { return nil }
            let sortedValues = values.sorted { lhs, rhs in
                if lhs.matchScore != rhs.matchScore {
                    return lhs.matchScore > rhs.matchScore
                }
                if lhs.message.createdAt != rhs.message.createdAt {
                    return lhs.message.createdAt > rhs.message.createdAt
                }
                return lhs.message.id > rhs.message.id
            }
            return GlobalSearchSection(conversation: conversation, results: sortedValues)
        }

        return sections.sorted { lhs, rhs in
            let lhsDate = lhs.results.first?.message.createdAt ?? .distantPast
            let rhsDate = rhs.results.first?.message.createdAt ?? .distantPast
            if lhsDate != rhsDate {
                return lhsDate > rhsDate
            }
            return lhs.conversation.updatedAt > rhs.conversation.updatedAt
        }
    }

    private func fallbackConversation(for conversationID: String) -> Conversation {
        Conversation(
            id: conversationID,
            type: .direct,
            title: L("未知会话", "Unknown Conversation"),
            avatarURL: nil,
            sdkConversationID: nil,
            lastMessage: "",
            lastMessageSenderID: nil,
            unreadCount: 0,
            updatedAt: .distantPast,
            peer: nil
        )
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
