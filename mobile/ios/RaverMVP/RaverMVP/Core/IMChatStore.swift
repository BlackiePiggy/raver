import Foundation
import Combine
import OSLog

struct ChatMessageHistoryPage {
    var messages: [ChatMessage]
    var isEnd: Bool
}

protocol IMChatConversationDataSource {
    func fetchConversations(type: ConversationType) async throws -> [Conversation]
    func markConversationRead(conversationID: String) async throws
    func setConversationPinned(conversationID: String, pinned: Bool) async throws
    func markConversationUnread(conversationID: String, unread: Bool) async throws
    func hideConversation(conversationID: String) async throws
}


@MainActor
final class IMChatStore: ObservableObject {
    static let shared = IMChatStore()
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.raver.mvp",
        category: "IMChatStore"
    )

    @Published private(set) var conversations: [Conversation] = []
    @Published private(set) var unreadTotal = 0
    @Published private(set) var latestInputStatusByConversationID: [String: IMInputStatusEvent] = [:]

    private let tencentSession = TencentIMSession.shared
    private let conversationSnapshotStore = ConversationSnapshotStore()
    private let directRemarkStore = DirectConversationRemarkStore()
    private var cancellables = Set<AnyCancellable>()
    private var hydratedSnapshotUserID: String?
    private var messageSearchIndex = ChatMessageSearchIndex()
    private var pendingMessageFocusByConversationID: [String: String] = [:]
    private var activeConversationReferenceCounts: [String: Int] = [:]

    private enum ConversationMergeSource {
        case staging
        case sdkRefresh
    }

    private init() {
        bindIMSession()
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

    func latestInputStatus(for conversation: Conversation) -> IMInputStatusEvent? {
        if let sdkConversationID = conversation.sdkConversationID,
           let value = latestInputStatusByConversationID[sdkConversationID] {
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
        limit: Int = 30
    ) async throws -> [ChatMessageSearchResult] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return [] }
        guard limit > 0 else { return [] }

        searchProbe("submit query=\(normalizedQuery) conversation=\(conversationID ?? "all") limit=\(limit)")
        let searchConversationIDs = resolvedSearchConversationIDs(for: conversationID)
        searchProbe("aliases=\(searchConversationIDs ?? ["<global>"])")

        let localHits = localSearchHits(
            query: normalizedQuery,
            conversationIDs: searchConversationIDs,
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
        debug(
            "search messages local-only query=\(normalizedQuery) conversation=\(conversationID ?? "all") hits=\(results.count)"
        )
        return Array(results.prefix(limit))
    }

    func loadConversations(using dataSource: IMChatConversationDataSource) async throws {
        restoreConversationSnapshotIfNeeded()
        async let directConversations = dataSource.fetchConversations(type: .direct)
        async let groupConversations = dataSource.fetchConversations(type: .group)
        replaceConversations(try await directConversations + groupConversations)
    }

    func markConversationRead(conversationID: String, using dataSource: IMChatConversationDataSource) async throws {
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

    func setConversationPinned(
        conversationID: String,
        pinned: Bool,
        using dataSource: IMChatConversationDataSource
    ) async throws {
        let previous = conversations
        if let index = conversations.firstIndex(where: { matchesConversation($0, id: conversationID) }) {
            conversations[index].isPinned = pinned
            conversations = Self.sortConversations(conversations)
        }

        do {
            try await dataSource.setConversationPinned(conversationID: conversationID, pinned: pinned)
        } catch {
            conversations = previous
            throw error
        }
    }

    func markConversationUnread(
        conversationID: String,
        unread: Bool,
        using dataSource: IMChatConversationDataSource
    ) async throws {
        let previous = conversations
        if let index = conversations.firstIndex(where: { matchesConversation($0, id: conversationID) }) {
            conversations[index].unreadCount = unread ? max(1, conversations[index].unreadCount) : 0
            conversations = Self.sortConversations(conversations)
            unreadTotal = conversations.reduce(0) { $0 + max(0, $1.unreadCount) }
        }

        do {
            try await dataSource.markConversationUnread(conversationID: conversationID, unread: unread)
        } catch {
            conversations = previous
            unreadTotal = conversations.reduce(0) { $0 + max(0, $1.unreadCount) }
            throw error
        }
    }

    func hideConversation(conversationID: String, using dataSource: IMChatConversationDataSource) async throws {
        let previous = conversations
        let target = conversations.first(where: { matchesConversation($0, id: conversationID) })
        if let target {
            removeConversation(conversationID: target.id)
        } else {
            removeConversation(conversationID: conversationID)
        }

        do {
            try await dataSource.hideConversation(conversationID: conversationID)
        } catch {
            conversations = previous
            unreadTotal = conversations.reduce(0) { $0 + max(0, $1.unreadCount) }
            throw error
        }
    }

    func updateConversationMuteState(conversationID: String, muted: Bool) {
        guard let index = conversations.firstIndex(where: { matchesConversation($0, id: conversationID) }) else {
            return
        }
        conversations[index].isMuted = muted
    }

    func updateDirectConversationDisplayName(conversationID: String, displayName: String) {
        guard let index = conversations.firstIndex(where: { matchesConversation($0, id: conversationID) }) else {
            return
        }

        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        conversations[index].title = trimmedName
        if var peer = conversations[index].peer {
            peer.displayName = trimmedName
            conversations[index].peer = peer
        }
        replaceConversations(conversations)
    }

    func directConversationRemarkOverride(conversationID: String, peerUserID: String?) -> String? {
        directRemarkStore.loadRemark(
            currentUserID: currentSnapshotUserID(),
            conversationID: conversationID,
            peerUserID: peerUserID
        )
    }

    func setDirectConversationRemarkOverride(
        conversationID: String,
        peerUserID: String?,
        displayName: String?
    ) {
        directRemarkStore.saveRemark(
            displayName,
            currentUserID: currentSnapshotUserID(),
            conversationID: conversationID,
            peerUserID: peerUserID
        )

        if let displayName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !displayName.isEmpty {
            updateDirectConversationDisplayName(conversationID: conversationID, displayName: displayName)
        } else {
            replaceConversations(conversations)
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

    func replaceSearchIndexMessages(_ messages: [ChatMessage], for conversation: Conversation) {
        let keys = resolvedConversationKeys(conversation: conversation, fallbackID: conversation.id)
        guard !keys.isEmpty else { return }
        searchProbe("index-replace conversation=\(conversation.id) keys=\(keys) count=\(messages.count)")
        for key in keys {
            messageSearchIndex.replaceMessages(messages, conversationID: key)
        }
    }

    func mergeSearchIndexMessages(_ messages: [ChatMessage], for conversation: Conversation) {
        let keys = resolvedConversationKeys(conversation: conversation, fallbackID: conversation.id)
        guard !keys.isEmpty else { return }
        searchProbe("index-merge-batch conversation=\(conversation.id) keys=\(keys) count=\(messages.count)")
        for message in messages {
            mergeMessageIntoSearchIndex(message, keys: keys)
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

    func stageConversation(_ conversation: Conversation) {
        if let index = conversations.firstIndex(where: { matchesConversation($0, conversation: conversation) }) {
            conversations[index] = mergeConversation(
                existing: conversations[index],
                incoming: conversation,
                source: .staging
            )
        } else {
            conversations.append(conversation)
        }
        conversations = Self.sortConversations(conversations)
        unreadTotal = conversations.reduce(0) { $0 + max(0, $1.unreadCount) }
    }

    private func bindIMSession() {
        tencentSession.messagePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                Task { @MainActor in
                    if message.kind == .typing {
                        guard !message.isMine else { return }
                        self?.mergeInputStatus(
                            IMInputStatusEvent(
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

        tencentSession.conversationPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] changed in
                Task { @MainActor in
                    self?.mergeConversations(changed)
                }
            }
            .store(in: &cancellables)

        tencentSession.totalUnreadPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] count in
                Task { @MainActor in
                    self?.unreadTotal = max(0, count)
                }
            }
            .store(in: &cancellables)
    }

    private func replaceConversations(_ items: [Conversation]) {
        var normalized = items
        applyDirectRemarkOverrides(to: &normalized)
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
                merged[index] = mergeConversation(
                    existing: merged[index],
                    incoming: conversation,
                    source: .sdkRefresh
                )
            } else {
                merged.append(conversation)
            }
        }
        replaceConversations(merged)
    }

    // Tencent-aligned behavior:
    // conversation list preview / unread should be driven by conversation callbacks,
    // while realtime message callbacks only feed message search indexing and typing state.
    private func indexRealtimeMessageForCompatibility(_ message: ChatMessage, preferredConversation: Conversation?) {
        let matchedConversation = preferredConversation ?? conversations.first {
            matchesConversation($0, id: message.conversationID)
        }
        let primaryKey = matchedConversation?.id ?? message.conversationID

        var keys = [primaryKey, message.conversationID]
        if let sdkConversationID = matchedConversation?.sdkConversationID {
            keys.append(sdkConversationID)
        }
        mergeMessageIntoSearchIndex(message, keys: keys.uniqued())
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
                || (items[index].sdkConversationID.map(isConversationActive) ?? false) {
                if items[index].unreadCount != 0 {
                    debug("normalize active unread conversation=\(items[index].id) previousUnread=\(items[index].unreadCount)")
                }
                items[index].unreadCount = 0
            }
        }
    }

    private func matchesConversation(_ lhs: Conversation, conversation rhs: Conversation) -> Bool {
        lhs.id == rhs.id
            || lhs.sdkConversationID == rhs.sdkConversationID
            || lhs.id == rhs.sdkConversationID
            || lhs.sdkConversationID == rhs.id
            || intersects(
                normalizedConversationIdentifiers(lhs),
                normalizedConversationIdentifiers(rhs)
            )
    }

    private func matchesConversation(_ conversation: Conversation, id: String) -> Bool {
        normalizedConversationIdentifiers(conversation).contains(normalizedIdentifier(id))
    }

    private func mergeConversation(
        existing: Conversation,
        incoming: Conversation,
        source: ConversationMergeSource
    ) -> Conversation {
        let identitySource = preferredIdentityConversation(
            existing: existing,
            incoming: incoming,
            source: source
        )
        let mergedPeer = mergePeer(existing.peer, incoming.peer)
        let mergedTitle = preferredConversationTitle(
            existing: existing,
            incoming: incoming,
            mergedPeer: mergedPeer,
            source: source
        )
        let mergedAvatarURL =
            normalizedText(identitySource.avatarURL)
            ?? normalizedText(mergedPeer?.avatarURL)
            ?? normalizedText(existing.avatarURL)
            ?? normalizedText(incoming.avatarURL)

        let preferIncomingActivity = shouldPreferIncomingActivity(
            existing: existing,
            incoming: incoming,
            source: source
        )
        let activitySource = preferIncomingActivity ? incoming : existing

        return Conversation(
            id: normalizedText(existing.id) ?? incoming.id,
            type: existing.type,
            title: mergedTitle,
            avatarURL: mergedAvatarURL,
            sdkConversationID: normalizedText(incoming.sdkConversationID) ?? existing.sdkConversationID,
            lastMessage: preferredLastMessage(
                existing: existing,
                incoming: incoming,
                preferIncoming: preferIncomingActivity
            ),
            lastMessageSenderID: preferredLastMessageSender(
                existing: existing,
                incoming: incoming,
                preferIncoming: preferIncomingActivity
            ),
            unreadCount: preferredUnreadCount(
                existing: existing,
                incoming: incoming,
                source: source
            ),
            updatedAt: max(activitySource.updatedAt, existing.updatedAt, incoming.updatedAt),
            peer: mergedPeer,
            isPinned: preferredPinnedState(existing: existing, incoming: incoming, source: source),
            isMuted: preferredMutedState(existing: existing, incoming: incoming, source: source)
        )
    }

    private func preferredIdentityConversation(
        existing: Conversation,
        incoming: Conversation,
        source: ConversationMergeSource
    ) -> Conversation {
        let existingScore = conversationIdentityScore(existing)
        let incomingScore = conversationIdentityScore(incoming)

        if incomingScore > existingScore {
            return incoming
        }
        if incomingScore < existingScore {
            return existing
        }

        switch source {
        case .staging:
            return incoming
        case .sdkRefresh:
            return existing
        }
    }

    private func shouldPreferIncomingActivity(
        existing: Conversation,
        incoming: Conversation,
        source: ConversationMergeSource
    ) -> Bool {
        switch source {
        case .staging:
            return incoming.updatedAt >= existing.updatedAt
        case .sdkRefresh:
            return true
        }
    }

    private func preferredUnreadCount(
        existing: Conversation,
        incoming: Conversation,
        source: ConversationMergeSource
    ) -> Int {
        switch source {
        case .staging:
            return max(0, max(existing.unreadCount, incoming.unreadCount))
        case .sdkRefresh:
            return max(0, incoming.unreadCount)
        }
    }

    private func preferredPinnedState(
        existing: Conversation,
        incoming: Conversation,
        source: ConversationMergeSource
    ) -> Bool {
        switch source {
        case .staging:
            return incoming.isPinned || existing.isPinned
        case .sdkRefresh:
            return incoming.isPinned
        }
    }

    private func preferredMutedState(
        existing: Conversation,
        incoming: Conversation,
        source: ConversationMergeSource
    ) -> Bool {
        switch source {
        case .staging:
            return incoming.isMuted || existing.isMuted
        case .sdkRefresh:
            return incoming.isMuted
        }
    }

    private func preferredLastMessage(
        existing: Conversation,
        incoming: Conversation,
        preferIncoming: Bool
    ) -> String {
        let existingText = normalizedText(existing.lastMessage)
        let incomingText = normalizedText(incoming.lastMessage)
        if preferIncoming {
            return incomingText ?? existingText ?? ""
        }
        return existingText ?? incomingText ?? ""
    }

    private func preferredLastMessageSender(
        existing: Conversation,
        incoming: Conversation,
        preferIncoming: Bool
    ) -> String? {
        let existingSender = normalizedText(existing.lastMessageSenderID)
        let incomingSender = normalizedText(incoming.lastMessageSenderID)
        if preferIncoming {
            return incomingSender ?? existingSender
        }
        return existingSender ?? incomingSender
    }

    private func preferredConversationTitle(
        existing: Conversation,
        incoming: Conversation,
        mergedPeer: UserSummary?,
        source: ConversationMergeSource
    ) -> String {
        let existingTitle = normalizedText(existing.title)
        let incomingTitle = normalizedText(incoming.title)
        let peerDisplayName = normalizedText(mergedPeer?.displayName)
        let peerUsername = normalizedText(mergedPeer?.username)

        let existingIsFallback = existingTitle.map { isFallbackConversationTitle($0, conversation: existing) } ?? true
        let incomingIsFallback = incomingTitle.map { isFallbackConversationTitle($0, conversation: incoming) } ?? true

        if let existingTitle, let incomingTitle {
            if existingIsFallback != incomingIsFallback {
                return existingIsFallback ? incomingTitle : existingTitle
            }
            if conversationIdentityScore(incoming) > conversationIdentityScore(existing) {
                return incomingTitle
            }
            if conversationIdentityScore(incoming) < conversationIdentityScore(existing) {
                return existingTitle
            }
            switch source {
            case .staging:
                return incomingTitle
            case .sdkRefresh:
                return existingTitle
            }
        }

        return existingTitle
            ?? incomingTitle
            ?? peerDisplayName
            ?? peerUsername
            ?? existing.id
    }

    private func mergePeer(_ existing: UserSummary?, _ incoming: UserSummary?) -> UserSummary? {
        switch (existing, incoming) {
        case let (.some(existing), .some(incoming)):
            let existingScore = userIdentityScore(existing)
            let incomingScore = userIdentityScore(incoming)
            let preferred = incomingScore >= existingScore ? incoming : existing
            let fallback = incomingScore >= existingScore ? existing : incoming
            return UserSummary(
                id: normalizedText(preferred.id) ?? fallback.id,
                username: normalizedText(preferred.username) ?? fallback.username,
                displayName: normalizedText(preferred.displayName) ?? fallback.displayName,
                avatarURL: normalizedText(preferred.avatarURL) ?? normalizedText(fallback.avatarURL),
                isFollowing: preferred.isFollowing || fallback.isFollowing
            )
        case let (.some(existing), .none):
            return existing
        case let (.none, .some(incoming)):
            return incoming
        case (.none, .none):
            return nil
        }
    }

    private func conversationIdentityScore(_ conversation: Conversation) -> Int {
        var score = 0
        if let title = normalizedText(conversation.title) {
            score += 1
            if !isFallbackConversationTitle(title, conversation: conversation) {
                score += 3
            }
        }
        if normalizedText(conversation.avatarURL) != nil {
            score += 2
        }
        if let peer = conversation.peer {
            score += userIdentityScore(peer)
        }
        return score
    }

    private func userIdentityScore(_ user: UserSummary) -> Int {
        var score = 0
        if normalizedText(user.id) != nil {
            score += 1
        }
        if let displayName = normalizedText(user.displayName),
           displayName.lowercased() != normalizedText(user.id)?.lowercased(),
           displayName.lowercased() != normalizedText(user.username)?.lowercased() {
            score += 3
        }
        if normalizedText(user.username) != nil {
            score += 1
        }
        if normalizedText(user.avatarURL) != nil {
            score += 2
        }
        return score
    }

    private func isFallbackConversationTitle(_ title: String, conversation: Conversation) -> Bool {
        let normalizedTitle = normalizedIdentifier(title)
        let fallbackValues = normalizedConversationIdentifiers(conversation)
        if fallbackValues.contains(normalizedTitle) {
            return true
        }

        let genericTitles = [
            normalizedIdentifier(L("私信", "Direct")),
            normalizedIdentifier(L("群聊", "Group chat")),
            normalizedIdentifier(L("小队", "Squad"))
        ]
        return genericTitles.contains(normalizedTitle)
    }

    private func normalizedConversationIdentifiers(_ conversation: Conversation) -> Set<String> {
        let baseValues = [
            conversation.id,
            conversation.sdkConversationID,
            conversation.peer?.id,
            conversation.peer?.username
        ]
        return Set(
            baseValues
                .compactMap { $0 }
                .map(normalizedIdentifier)
                .filter { !$0.isEmpty }
        )
    }

    private func normalizedIdentifier(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func intersects(_ lhs: Set<String>, _ rhs: Set<String>) -> Bool {
        !lhs.intersection(rhs).isEmpty
    }

    private func normalizedText(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func sortConversations(_ items: [Conversation]) -> [Conversation] {
        items.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }
            if lhs.updatedAt != rhs.updatedAt {
                return lhs.updatedAt > rhs.updatedAt
            }
            return lhs.id < rhs.id
        }
    }

    private func mergeInputStatus(_ event: IMInputStatusEvent) {
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
        resolvedConversationKeys(rawConversationID: conversation.sdkConversationID ?? fallbackID)
            .unioned(with: [conversation.id, conversation.sdkConversationID].compactMap { $0 })
    }

    private func resolvedConversationKeys(rawConversationID: String) -> [String] {
        let matched = conversations.first {
            $0.id == rawConversationID || $0.sdkConversationID == rawConversationID
        }
        return resolvedConversationKeys(conversation: matched, fallbackID: rawConversationID)
    }

    private func resolvedConversationKeys(conversation: Conversation?, fallbackID: String) -> [String] {
        [conversation?.id, conversation?.sdkConversationID, fallbackID]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .uniqued()
    }

    private func resolvedSearchConversationIDs(for conversationID: String?) -> [String]? {
        guard let conversationID else { return nil }
        let normalized = conversationID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        let aliases = resolvedConversationKeys(rawConversationID: normalized)
        return aliases.isEmpty ? [normalized] : aliases
    }

    private func localSearchHits(
        query: String,
        conversationIDs: [String]?,
        limit: Int
    ) -> [ChatMessageSearchIndex.Hit] {
        searchProbe("local-search-start query=\(query) ids=\(conversationIDs ?? ["<global>"]) limit=\(limit)")
        guard let conversationIDs, !conversationIDs.isEmpty else {
            let hits = messageSearchIndex.search(query: query, conversationID: nil, limit: limit)
            searchProbe("local-search-result count=\(hits.count)")
            return hits
        }

        var bestHitByMessageID: [String: ChatMessageSearchIndex.Hit] = [:]
        for conversationID in conversationIDs {
            searchProbe("local-search-scan id=\(conversationID)")
            let hits = messageSearchIndex.search(
                query: query,
                conversationID: conversationID,
                limit: limit
            )
            for hit in hits {
                if let existing = bestHitByMessageID[hit.message.id] {
                    if hit.score > existing.score
                        || (hit.score == existing.score && hit.message.createdAt > existing.message.createdAt) {
                        bestHitByMessageID[hit.message.id] = hit
                    }
                } else {
                    bestHitByMessageID[hit.message.id] = hit
                }
            }
        }

        let merged = bestHitByMessageID.values.sorted { lhs, rhs in
            if lhs.score != rhs.score {
                return lhs.score > rhs.score
            }
            if lhs.message.createdAt != rhs.message.createdAt {
                return lhs.message.createdAt > rhs.message.createdAt
            }
            return lhs.message.id > rhs.message.id
        }
        .prefix(limit)
        .map { $0 }
        searchProbe("local-search-result count=\(merged.count)")
        return merged
    }

    private func debug(_ message: String) {
        #if DEBUG
        Self.logger.debug("[IMChatStore] \(message, privacy: .public)")
        #endif
    }

    private func searchProbe(_ message: String) {
        #if DEBUG
        print("[IMSearchProbe] \(message)")
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
        searchProbe(
            "index-merge msg=\(message.id) kind=\(message.kind.rawValue) conv=\(message.conversationID) keys=\(keys)"
        )
        for key in keys where !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            messageSearchIndex.mergeMessage(message, conversationID: key)
        }
    }

    private func clearSearchIndex(forKeys keys: [String]) {
        for key in keys where !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            messageSearchIndex.clearConversation(key)
        }
    }

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
        let rawUserID = tencentSession.currentBusinessUserIDSnapshot()
        guard let userID = rawUserID?.trimmingCharacters(in: .whitespacesAndNewlines),
              !userID.isEmpty else {
            return nil
        }
        return userID
    }

    private func applyDirectRemarkOverrides(to items: inout [Conversation]) {
        let currentUserID = currentSnapshotUserID()
        for index in items.indices where items[index].type == .direct {
            let peerUserID = items[index].peer?.id ?? items[index].id
            guard let override = directRemarkStore.loadRemark(
                currentUserID: currentUserID,
                conversationID: items[index].id,
                peerUserID: peerUserID
            )?.trimmingCharacters(in: .whitespacesAndNewlines),
            !override.isEmpty else {
                continue
            }
            items[index].title = override
            if var peer = items[index].peer {
                peer.displayName = override
                items[index].peer = peer
            }
        }
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
    private let storageKeyPrefix = "raver.im.conversation.snapshot."

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

private struct DirectConversationRemarkStore {
    private let defaults: UserDefaults
    private let storageKeyPrefix = "raver.im.direct.remark."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadRemark(
        currentUserID: String?,
        conversationID: String,
        peerUserID: String?
    ) -> String? {
        let map = loadMap(currentUserID: currentUserID)
        for key in candidateKeys(conversationID: conversationID, peerUserID: peerUserID) {
            guard let value = map[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty else { continue }
            return value
        }
        return nil
    }

    func saveRemark(
        _ displayName: String?,
        currentUserID: String?,
        conversationID: String,
        peerUserID: String?
    ) {
        let keys = candidateKeys(conversationID: conversationID, peerUserID: peerUserID)
        guard !keys.isEmpty else { return }

        var map = loadMap(currentUserID: currentUserID)
        let trimmed = displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            for key in keys {
                map[key] = trimmed
            }
        } else {
            for key in keys {
                map.removeValue(forKey: key)
            }
        }
        persistMap(map, currentUserID: currentUserID)
    }

    private func loadMap(currentUserID: String?) -> [String: String] {
        guard let data = defaults.data(forKey: storageKey(for: currentUserID)),
              let map = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return map
    }

    private func persistMap(_ map: [String: String], currentUserID: String?) {
        if map.isEmpty {
            defaults.removeObject(forKey: storageKey(for: currentUserID))
            return
        }
        guard let data = try? JSONEncoder().encode(map) else { return }
        defaults.set(data, forKey: storageKey(for: currentUserID))
    }

    private func candidateKeys(conversationID: String, peerUserID: String?) -> [String] {
        var keys: [String] = []
        let trimmedConversationID = conversationID.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedConversationID.isEmpty {
            keys.append("conversation:\(trimmedConversationID)")
        }
        if let peerUserID {
            let normalizedPeerID = TencentIMIdentity.toTencentIMUserID(peerUserID)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !normalizedPeerID.isEmpty {
                keys.append("peer:\(normalizedPeerID)")
            }
        }
        return keys.uniqued()
    }

    private func storageKey(for currentUserID: String?) -> String {
        let userID = currentUserID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "anonymous"
        return storageKeyPrefix + userID
    }
}
