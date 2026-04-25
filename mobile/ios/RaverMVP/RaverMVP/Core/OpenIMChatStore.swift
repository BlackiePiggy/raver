import Foundation
import Combine
import OSLog
#if canImport(OpenIMSDK)
import OpenIMSDK
#endif

struct ChatMessageHistoryPage {
    var messages: [ChatMessage]
    var isEnd: Bool
}

protocol OpenIMChatConversationDataSource {
    func fetchConversations(type: ConversationType) async throws -> [Conversation]
    func markConversationRead(conversationID: String) async throws
}

@MainActor
final class OpenIMChatStore: ObservableObject {
    static let shared = OpenIMChatStore()
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.raver.mvp",
        category: "OpenIMChatStore"
    )

    @Published private(set) var conversations: [Conversation] = []
    @Published private(set) var unreadTotal = 0
    @Published private(set) var latestInputStatusByConversationID: [String: OpenIMInputStatusEvent] = [:]

    private let session = OpenIMSession.shared
    private let conversationSnapshotStore = ConversationSnapshotStore()
    private var cancellables = Set<AnyCancellable>()
    private var hydratedSnapshotUserID: String?
    private var messageSearchIndex = ChatMessageSearchIndex()
    private var pendingMessageFocusByConversationID: [String: String] = [:]
    private var activeConversationReferenceCounts: [String: Int] = [:]

    private init() {
        bindOpenIMSession()
    }

    func reset() {
        conversations = []
        unreadTotal = 0
        latestInputStatusByConversationID = [:]
        messageSearchIndex.reset()
        pendingMessageFocusByConversationID = [:]
        activeConversationReferenceCounts = [:]
        hydratedSnapshotUserID = nil
    }

    func activateConversation(_ conversation: Conversation) {
        let keys = resolvedConversationKeys(conversation: conversation, fallbackID: conversation.id)
        guard !keys.isEmpty else { return }
        for key in keys {
            activeConversationReferenceCounts[key, default: 0] += 1
        }
        zeroUnreadIfNeeded(for: keys)
        debug("active conversation registered keys=\(keys.joined(separator: ","))")
    }

    func deactivateConversation(_ conversation: Conversation) {
        let keys = resolvedConversationKeys(conversation: conversation, fallbackID: conversation.id)
        guard !keys.isEmpty else { return }
        for key in keys {
            let next = max(0, (activeConversationReferenceCounts[key] ?? 0) - 1)
            if next == 0 {
                activeConversationReferenceCounts.removeValue(forKey: key)
            } else {
                activeConversationReferenceCounts[key] = next
            }
        }
        debug("active conversation released keys=\(keys.joined(separator: ","))")
    }

    func setPendingMessageFocus(messageID: String, conversationID: String) {
        let normalizedMessageID = messageID.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedConversationID = conversationID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedMessageID.isEmpty, !normalizedConversationID.isEmpty else { return }
        pendingMessageFocusByConversationID[normalizedConversationID] = normalizedMessageID
        debug("pending focus set conversation=\(normalizedConversationID) message=\(normalizedMessageID)")
    }

    func consumePendingMessageFocus(for conversation: Conversation) -> String? {
        let keys = resolvedConversationKeys(conversation: conversation, fallbackID: conversation.id)
        guard !keys.isEmpty else { return nil }

        for key in keys {
            guard let messageID = pendingMessageFocusByConversationID[key] else { continue }
            for alias in keys {
                pendingMessageFocusByConversationID.removeValue(forKey: alias)
            }
            debug("pending focus consumed conversation=\(conversation.id) message=\(messageID)")
            return messageID
        }
        return nil
    }

    func latestInputStatus(for conversation: Conversation) -> OpenIMInputStatusEvent? {
        if let openIMConversationID = conversation.openIMConversationID,
           let value = latestInputStatusByConversationID[openIMConversationID] {
            return value
        }
        return latestInputStatusByConversationID[conversation.id]
    }

    func pruneExpiredInputStatus() {
        cleanupExpiredInputStatus()
    }

    func searchMessages(
        query: String,
        conversationID: String? = nil,
        limit: Int = 30,
        remoteDataSource: ChatMessageSearchRemoteDataSource? = nil
    ) async throws -> [ChatMessageSearchResult] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return [] }
        guard limit > 0 else { return [] }

        let localHits = messageSearchIndex.search(
            query: normalizedQuery,
            conversationID: conversationID,
            limit: limit
        )
        var results = localHits.map {
            ChatMessageSearchResult(
                message: $0.message,
                conversationID: $0.conversationID,
                source: .localIndex,
                matchScore: $0.score
            )
        }

        guard results.count < limit, let remoteDataSource else {
            debug(
                "search messages local-only query=\(normalizedQuery) conversation=\(conversationID ?? "all") hits=\(results.count)"
            )
            return results
        }

        let remaining = limit - results.count
        let remoteMessages = try await remoteDataSource.searchMessages(
            query: normalizedQuery,
            conversationID: conversationID,
            limit: remaining
        )

        var seenMessageIDs = Set(results.map { $0.message.id })
        for message in remoteMessages where !seenMessageIDs.contains(message.id) {
            seenMessageIDs.insert(message.id)
            let resultConversationID = conversationID ?? message.conversationID
            results.append(
                ChatMessageSearchResult(
                    message: message,
                    conversationID: resultConversationID,
                    source: .remoteFallback,
                    matchScore: 0
                )
            )

            let keys = resolvedConversationKeys(rawConversationID: resultConversationID)
            if keys.isEmpty {
                mergeMessageIntoSearchIndex(message, keys: [resultConversationID])
            } else {
                mergeMessageIntoSearchIndex(message, keys: keys)
            }
        }

        debug(
            "search messages local=\(localHits.count) remote=\(remoteMessages.count) total=\(results.count) query=\(normalizedQuery) conversation=\(conversationID ?? "all")"
        )
        return Array(results.prefix(limit))
    }

    func loadConversations(using dataSource: OpenIMChatConversationDataSource) async throws {
        restoreConversationSnapshotIfNeeded()
        async let directConversations = dataSource.fetchConversations(type: .direct)
        async let groupConversations = dataSource.fetchConversations(type: .group)
        replaceConversations(try await directConversations + groupConversations)
    }

    func markConversationRead(conversationID: String, using dataSource: OpenIMChatConversationDataSource) async throws {
        let previous = conversations
        if let index = conversations.firstIndex(where: { matchesConversation($0, id: conversationID) }) {
            conversations[index].unreadCount = 0
            conversations = Self.sortConversations(conversations)
            unreadTotal = conversations.reduce(0) { $0 + max(0, $1.unreadCount) }
        }

        do {
            try await dataSource.markConversationRead(conversationID: conversationID)
        } catch {
            conversations = previous
            unreadTotal = conversations.reduce(0) { $0 + max(0, $1.unreadCount) }
            throw error
        }
    }

    func clearMessages(for conversation: Conversation) {
        let keys = resolvedConversationKeys(conversation: conversation, fallbackID: conversation.id)
        for key in keys {
            pendingMessageFocusByConversationID.removeValue(forKey: key)
        }
        clearSearchIndex(forKeys: keys)

        if let index = conversations.firstIndex(where: { matchesConversation($0, conversation: conversation) }) {
            conversations[index].lastMessage = L("暂无消息", "No messages yet")
            conversations[index].lastMessageSenderID = nil
            conversations[index].unreadCount = 0
            conversations = Self.sortConversations(conversations)
            unreadTotal = conversations.reduce(0) { $0 + max(0, $1.unreadCount) }
        }
    }

    func removeConversation(conversationID: String) {
        guard let conversation = conversations.first(where: { matchesConversation($0, id: conversationID) }) else {
            return
        }

        let keys = resolvedConversationKeys(conversation: conversation, fallbackID: conversationID)
        for key in keys {
            latestInputStatusByConversationID.removeValue(forKey: key)
            pendingMessageFocusByConversationID.removeValue(forKey: key)
        }
        clearSearchIndex(forKeys: keys)

        conversations.removeAll(where: { matchesConversation($0, conversation: conversation) })
        unreadTotal = conversations.reduce(0) { $0 + max(0, $1.unreadCount) }
    }

    private func bindOpenIMSession() {
        #if canImport(OpenIMSDK)
        session.rawMessagePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] rawMessage in
                Task { @MainActor in
                    guard let self,
                          let message = self.legacyChatMessage(from: rawMessage) else { return }
                    if message.kind == .typing {
                        guard !message.isMine else { return }
                        self.mergeInputStatus(
                            OpenIMInputStatusEvent(
                                conversationID: message.conversationID,
                                userID: message.sender.id,
                                platformIDs: [],
                                receivedAt: Date()
                            )
                        )
                        return
                    }
                    self.indexRealtimeMessageForCompatibility(message, preferredConversation: nil)
                }
            }
            .store(in: &cancellables)
        #else
        session.messagePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                Task { @MainActor in
                    if message.kind == .typing {
                        guard !message.isMine else { return }
                        self?.mergeInputStatus(
                            OpenIMInputStatusEvent(
                                conversationID: message.conversationID,
                                userID: message.sender.id,
                                platformIDs: [],
                                receivedAt: Date()
                            )
                        )
                        return
                    }
                    self?.indexRealtimeMessageForCompatibility(message, preferredConversation: nil)
                }
            }
            .store(in: &cancellables)
        #endif

        session.conversationPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] changed in
                Task { @MainActor in
                    self?.mergeConversations(changed)
                }
            }
            .store(in: &cancellables)

        session.totalUnreadPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] count in
                Task { @MainActor in
                    self?.unreadTotal = max(0, count)
                }
            }
            .store(in: &cancellables)

        session.inputStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                Task { @MainActor in
                    self?.mergeInputStatus(event)
                }
            }
            .store(in: &cancellables)
    }

    private func replaceConversations(_ items: [Conversation]) {
        var normalized = items
        normalizeActiveConversationUnreadCounts(in: &normalized)
        conversations = Self.sortConversations(normalized)
        unreadTotal = normalized.reduce(0) { $0 + max(0, $1.unreadCount) }
        persistConversationSnapshotIfPossible()
    }

    private func mergeConversations(_ changed: [Conversation]) {
        guard !changed.isEmpty else { return }

        var merged = conversations
        for conversation in changed {
            if let index = merged.firstIndex(where: { matchesConversation($0, conversation: conversation) }) {
                merged[index] = conversation
            } else {
                merged.append(conversation)
            }
        }
        replaceConversations(merged)
    }

    // Temporary compatibility adapter that keeps search + conversation preview in sync
    // while controller-owned raw message state replaces the old store-owned message flow.
    private func indexRealtimeMessageForCompatibility(_ message: ChatMessage, preferredConversation: Conversation?) {
        let matchedConversation = preferredConversation ?? conversations.first {
            matchesConversation($0, id: message.conversationID)
        }
        let primaryKey = matchedConversation?.id ?? message.conversationID

        var keys = [primaryKey, message.conversationID]
        if let openIMConversationID = matchedConversation?.openIMConversationID {
            keys.append(openIMConversationID)
        }
        mergeMessageIntoSearchIndex(message, keys: keys.uniqued())

        updateConversationPreviewForCompatibility(from: message, conversationID: primaryKey)
    }

    private func updateConversationPreviewForCompatibility(from message: ChatMessage, conversationID: String) {
        guard let index = conversations.firstIndex(where: { matchesConversation($0, id: conversationID) }) else {
            return
        }

        let suppressUnreadIncrement = isConversationActive(conversationID)
        conversations[index].lastMessage = message.content
        conversations[index].lastMessageSenderID = message.sender.displayName
        conversations[index].updatedAt = message.createdAt
        if !message.isMine && !suppressUnreadIncrement {
            conversations[index].unreadCount = max(0, conversations[index].unreadCount) + 1
        }
        debug(
            "compat preview updated conversation=\(conversationID) suppressUnread=\(suppressUnreadIncrement ? 1 : 0) unread=\(conversations[index].unreadCount) payload={\(debugMessageSummary(message))}"
        )
        replaceConversations(conversations)
    }

    private func isConversationActive(_ conversationID: String) -> Bool {
        activeConversationReferenceCounts[conversationID, default: 0] > 0
    }

    private func zeroUnreadIfNeeded(for keys: [String]) {
        var didChange = false
        var changedKeys: [String] = []
        for index in conversations.indices {
            guard keys.contains(where: { matchesConversation(conversations[index], id: $0) }) else { continue }
            if conversations[index].unreadCount != 0 {
                changedKeys.append(conversations[index].id)
                conversations[index].unreadCount = 0
                didChange = true
            }
        }
        guard didChange else { return }
        debug("active conversation zeroed unread conversations=\(changedKeys.joined(separator: ","))")
        replaceConversations(conversations)
    }

    private func normalizeActiveConversationUnreadCounts(in items: inout [Conversation]) {
        guard !activeConversationReferenceCounts.isEmpty else { return }
        for index in items.indices {
            if isConversationActive(items[index].id)
                || (items[index].openIMConversationID.map(isConversationActive) ?? false) {
                if items[index].unreadCount != 0 {
                    debug("normalize active unread conversation=\(items[index].id) previousUnread=\(items[index].unreadCount)")
                }
                items[index].unreadCount = 0
            }
        }
    }

    private func matchesConversation(_ lhs: Conversation, conversation rhs: Conversation) -> Bool {
        lhs.id == rhs.id
            || lhs.openIMConversationID == rhs.openIMConversationID
            || lhs.id == rhs.openIMConversationID
            || lhs.openIMConversationID == rhs.id
    }

    private func matchesConversation(_ conversation: Conversation, id: String) -> Bool {
        conversation.id == id || conversation.openIMConversationID == id
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

    private func mergeInputStatus(_ event: OpenIMInputStatusEvent) {
        let keys = resolvedConversationKeys(rawConversationID: event.conversationID)
        guard !keys.isEmpty else { return }
        for key in keys {
            latestInputStatusByConversationID[key] = event
        }
        cleanupExpiredInputStatus()
        debug("input status merged conversation=\(event.conversationID) user=\(event.userID)")
    }

    private func cleanupExpiredInputStatus(expireAfter: TimeInterval = 4) {
        let now = Date()
        latestInputStatusByConversationID = latestInputStatusByConversationID.filter {
            now.timeIntervalSince($0.value.receivedAt) <= expireAfter
        }
    }

    private func resolvedConversationKeys(conversation: Conversation, fallbackID: String) -> [String] {
        resolvedConversationKeys(rawConversationID: conversation.openIMConversationID ?? fallbackID)
            .unioned(with: [conversation.id, conversation.openIMConversationID].compactMap { $0 })
    }

    private func resolvedConversationKeys(rawConversationID: String) -> [String] {
        let matched = conversations.first {
            $0.id == rawConversationID || $0.openIMConversationID == rawConversationID
        }
        return resolvedConversationKeys(conversation: matched, fallbackID: rawConversationID)
    }

    private func resolvedConversationKeys(conversation: Conversation?, fallbackID: String) -> [String] {
        [conversation?.id, conversation?.openIMConversationID, fallbackID]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .uniqued()
    }

    private func debug(_ message: String) {
        #if DEBUG
        Self.logger.debug("[OpenIMChatStore] \(message, privacy: .public)")
        #endif
    }

    private func debugMessageSummary(_ message: ChatMessage) -> String {
        "id=\(message.id) conversation=\(message.conversationID) mine=\(message.isMine ? 1 : 0) kind=\(message.kind.rawValue) status=\(message.deliveryStatus.rawValue) createdAt=\(Int(message.createdAt.timeIntervalSince1970 * 1000)) content=\(debugSnippet(message.content))"
    }

    private func debugSnippet(_ text: String?, limit: Int = 32) -> String {
        let normalized = (text ?? "")
            .replacingOccurrences(of: "\n", with: "\\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return "-" }
        return normalized.count > limit ? "\(normalized.prefix(limit))..." : normalized
    }

    private func mergeMessageIntoSearchIndex(_ message: ChatMessage, keys: [String]) {
        for key in keys where !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            messageSearchIndex.mergeMessage(message, conversationID: key)
        }
    }

    private func clearSearchIndex(forKeys keys: [String]) {
        for key in keys where !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            messageSearchIndex.clearConversation(key)
        }
    }

    #if canImport(OpenIMSDK)
    // Temporary compatibility bridge so store-owned search/input-status paths can
    // keep consuming raw realtime messages without reviving the old message source of truth.
    private func legacyChatMessage(from rawMessage: OIMMessageInfo) -> ChatMessage? {
        guard let businessConversationID = session.businessConversationIDSnapshot(for: rawMessage) else {
            return nil
        }
        return session.chatMessageSnapshot(from: rawMessage, conversationID: businessConversationID)
    }
    #endif

    private func restoreConversationSnapshotIfNeeded() {
        guard conversations.isEmpty else { return }
        guard let userID = currentSnapshotUserID() else { return }
        guard hydratedSnapshotUserID != userID else { return }
        hydratedSnapshotUserID = userID

        guard let snapshot = conversationSnapshotStore.loadConversations(for: userID), !snapshot.isEmpty else {
            debug("conversation snapshot miss user=\(userID)")
            return
        }
        conversations = Self.sortConversations(snapshot)
        unreadTotal = snapshot.reduce(0) { $0 + max(0, $1.unreadCount) }
        debug("conversation snapshot restored user=\(userID) count=\(snapshot.count)")
    }

    private func persistConversationSnapshotIfPossible() {
        guard let userID = currentSnapshotUserID() else { return }
        hydratedSnapshotUserID = userID
        conversationSnapshotStore.saveConversations(conversations, for: userID)
    }

    private func currentSnapshotUserID() -> String? {
        guard let userID = session.currentBusinessUserIDSnapshot()?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !userID.isEmpty else {
            return nil
        }
        return userID
    }

}

private extension Array where Element == String {
    func uniqued() -> [String] {
        var seen = Set<String>()
        var values: [String] = []
        for value in self where !seen.contains(value) {
            seen.insert(value)
            values.append(value)
        }
        return values
    }

    func unioned(with rhs: [String]) -> [String] {
        (self + rhs).uniqued()
    }
}

private struct ConversationSnapshotStore {
    private let defaults: UserDefaults
    private let storageKeyPrefix = "raver.openim.conversation.snapshot."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadConversations(for userID: String) -> [Conversation]? {
        guard let data = defaults.data(forKey: storageKey(for: userID)),
              let conversations = try? JSONDecoder.raver.decode([Conversation].self, from: data) else {
            return nil
        }
        return conversations
    }

    func saveConversations(_ conversations: [Conversation], for userID: String) {
        guard let data = try? JSONEncoder.raver.encode(conversations) else { return }
        defaults.set(data, forKey: storageKey(for: userID))
    }

    private func storageKey(for userID: String) -> String {
        storageKeyPrefix + userID
    }
}
