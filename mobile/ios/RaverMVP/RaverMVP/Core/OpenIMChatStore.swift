import Foundation
import Combine
import OSLog

struct ChatMessageHistoryPage {
    var messages: [ChatMessage]
    var isEnd: Bool
}

protocol OpenIMChatConversationDataSource {
    func fetchConversations(type: ConversationType) async throws -> [Conversation]
    func markConversationRead(conversationID: String) async throws
}

protocol OpenIMChatMessageDataSource: OpenIMChatConversationDataSource {
    func fetchMessages(conversationID: String, startClientMsgID: String?, count: Int) async throws -> ChatMessageHistoryPage
    func fetchMessages(conversationID: String) async throws -> [ChatMessage]
    func sendMessage(conversationID: String, content: String) async throws -> ChatMessage
    func sendImageMessage(conversationID: String, fileURL: URL) async throws -> ChatMessage
    func sendVideoMessage(conversationID: String, fileURL: URL) async throws -> ChatMessage
    func sendImageMessage(conversationID: String, fileURL: URL, onProgress: ((Int) -> Void)?) async throws -> ChatMessage
    func sendVideoMessage(conversationID: String, fileURL: URL, onProgress: ((Int) -> Void)?) async throws -> ChatMessage
}

extension OpenIMChatMessageDataSource {
    func fetchMessages(conversationID: String, startClientMsgID: String?, count: Int) async throws -> ChatMessageHistoryPage {
        _ = startClientMsgID
        _ = count
        let messages = try await fetchMessages(conversationID: conversationID)
        return ChatMessageHistoryPage(messages: messages, isEnd: true)
    }

    func sendImageMessage(conversationID: String, fileURL: URL, onProgress: ((Int) -> Void)?) async throws -> ChatMessage {
        _ = onProgress
        return try await sendImageMessage(conversationID: conversationID, fileURL: fileURL)
    }

    func sendVideoMessage(conversationID: String, fileURL: URL, onProgress: ((Int) -> Void)?) async throws -> ChatMessage {
        _ = onProgress
        return try await sendVideoMessage(conversationID: conversationID, fileURL: fileURL)
    }
}

@MainActor
final class OpenIMChatStore: ObservableObject {
    private struct MessagePaginationState {
        var oldestClientMsgID: String?
        var reachedBeginning: Bool = true
        var isLoadingOlder: Bool = false
    }

    static let shared = OpenIMChatStore()
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.raver.mvp",
        category: "OpenIMChatStore"
    )

    @Published private(set) var conversations: [Conversation] = []
    @Published private(set) var unreadTotal = 0
    @Published private(set) var messagesByConversationID: [String: [ChatMessage]] = [:]
    @Published private(set) var latestInputStatusByConversationID: [String: OpenIMInputStatusEvent] = [:]

    private let session = OpenIMSession.shared
    private let conversationSnapshotStore = ConversationSnapshotStore()
    private var cancellables = Set<AnyCancellable>()
    private var hydratedSnapshotUserID: String?
    private var messagePaginationByConversationID: [String: MessagePaginationState] = [:]
    private var messageSearchIndex = ChatMessageSearchIndex()
    private var pendingMessageFocusByConversationID: [String: String] = [:]

    private init() {
        bindOpenIMSession()
    }

    func reset() {
        conversations = []
        unreadTotal = 0
        messagesByConversationID = [:]
        latestInputStatusByConversationID = [:]
        messagePaginationByConversationID = [:]
        messageSearchIndex.reset()
        pendingMessageFocusByConversationID = [:]
        hydratedSnapshotUserID = nil
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

    func messages(for conversation: Conversation) -> [ChatMessage] {
        let keys = resolvedConversationKeys(conversation: conversation, fallbackID: conversation.id)
        let merged = keys.flatMap { messagesByConversationID[$0] ?? [] }
        let normalized = Self.normalizedMessagesForPresentation(merged)
        let rawCount = Self.deduplicatedAndSortedMessages(merged).count
        if normalized.count != rawCount {
            debug(
                "messages normalized conversation=\(conversation.id) keys=\(keys.joined(separator: ",")) raw=\(rawCount) normalized=\(normalized.count) tail={\(normalized.last.map { debugMessageSummary($0) } ?? "-")}"
            )
        }
        return normalized
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

    func loadMessages(for conversation: Conversation, using dataSource: OpenIMChatMessageDataSource) async throws {
        let page = try await dataSource.fetchMessages(
            conversationID: conversation.id,
            startClientMsgID: nil,
            count: 50
        )
        let existing = messages(for: conversation)
        let merged = Self.deduplicatedAndSortedMessages(existing + page.messages)
        replaceMessages(merged, for: conversation)

        var pagination = paginationState(for: conversation)
        pagination.oldestClientMsgID = merged.first?.id
        pagination.reachedBeginning = page.isEnd || page.messages.isEmpty
        updatePaginationState(pagination, for: conversation)
        debug("load messages initial conversation=\(conversation.id) fetched=\(page.messages.count) merged=\(merged.count) reachedBeginning=\(pagination.reachedBeginning)")
    }

    @discardableResult
    func loadOlderMessages(
        for conversation: Conversation,
        count: Int = 30,
        using dataSource: OpenIMChatMessageDataSource
    ) async throws -> Int {
        var pagination = paginationState(for: conversation)
        if pagination.isLoadingOlder || pagination.reachedBeginning {
            return 0
        }

        pagination.isLoadingOlder = true
        updatePaginationState(pagination, for: conversation)
        defer {
            var latest = paginationState(for: conversation)
            latest.isLoadingOlder = false
            updatePaginationState(latest, for: conversation)
        }

        let anchor = pagination.oldestClientMsgID
        let page = try await dataSource.fetchMessages(
            conversationID: conversation.id,
            startClientMsgID: anchor,
            count: max(1, count)
        )
        let before = messages(for: conversation)
        let merged = Self.deduplicatedAndSortedMessages(before + page.messages)
        replaceMessages(merged, for: conversation)

        let inserted = max(0, merged.count - before.count)
        pagination = paginationState(for: conversation)
        pagination.oldestClientMsgID = merged.first?.id
        pagination.reachedBeginning = page.isEnd || page.messages.isEmpty || inserted == 0
        updatePaginationState(pagination, for: conversation)

        debug("load older conversation=\(conversation.id) anchor=\(anchor ?? "-") fetched=\(page.messages.count) inserted=\(inserted) reachedBeginning=\(pagination.reachedBeginning)")
        return inserted
    }

    func hasOlderMessages(for conversation: Conversation) -> Bool {
        !paginationState(for: conversation).reachedBeginning
    }

    func isLoadingOlderMessages(for conversation: Conversation) -> Bool {
        paginationState(for: conversation).isLoadingOlder
    }

    func sendMessage(conversation: Conversation, content: String, using dataSource: OpenIMChatMessageDataSource) async throws -> ChatMessage {
        let localMessageID = "local-\(UUID().uuidString)"
        let localMessage = ChatMessage(
            id: localMessageID,
            conversationID: conversation.id,
            sender: localOutgoingSender(for: conversation),
            content: content,
            createdAt: Date(),
            isMine: true,
            kind: .text,
            deliveryStatus: .sending
        )
        debug(
            "send start localID=\(localMessageID) conversation=\(conversation.id) openIMConversation=\(conversation.openIMConversationID ?? "-") payload={\(debugMessageSummary(localMessage))}"
        )
        mergeMessage(localMessage, preferredConversation: conversation)

        do {
            var sent = try await dataSource.sendMessage(conversationID: conversation.id, content: content)
            sent.deliveryStatus = .sent
            sent.deliveryError = nil
            debug(
                "send success localID=\(localMessageID) conversation=\(conversation.id) payload={\(debugMessageSummary(sent))}"
            )
            replaceMessage(localMessageID: localMessageID, with: sent, preferredConversation: conversation)
            return sent
        } catch {
            debug(
                "send failure localID=\(localMessageID) conversation=\(conversation.id) error=\(debugSnippet(error.userFacingMessage))"
            )
            updateMessageState(
                messageID: localMessageID,
                in: conversation,
                status: .failed,
                error: error.userFacingMessage
            )
            throw error
        }
    }

    func sendImageMessage(
        conversation: Conversation,
        fileURL: URL,
        onProgress: ((Double) -> Void)? = nil,
        using dataSource: OpenIMChatMessageDataSource
    ) async throws -> ChatMessage {
        onProgress?(0)
        let localMessageID = "local-\(UUID().uuidString)"
        let localMessage = ChatMessage(
            id: localMessageID,
            conversationID: conversation.id,
            sender: localOutgoingSender(for: conversation),
            content: L("[图片]", "[Image]"),
            createdAt: Date(),
            isMine: true,
            kind: .image,
            media: ChatMessageMediaPayload(mediaURL: fileURL.absoluteString, thumbnailURL: fileURL.absoluteString),
            deliveryStatus: .sending
        )
        mergeMessage(localMessage, preferredConversation: conversation)

        do {
            var sent = try await dataSource.sendImageMessage(
                conversationID: conversation.id,
                fileURL: fileURL,
                onProgress: { value in
                    let clamped = min(100, max(0, value))
                    onProgress?(Double(clamped) / 100.0)
                }
            )
            sent.deliveryStatus = .sent
            sent.deliveryError = nil
            replaceMessage(localMessageID: localMessageID, with: sent, preferredConversation: conversation)
            onProgress?(1)
            return sent
        } catch {
            onProgress?(0)
            updateMessageState(
                messageID: localMessageID,
                in: conversation,
                status: .failed,
                error: error.userFacingMessage
            )
            throw error
        }
    }

    func sendVideoMessage(
        conversation: Conversation,
        fileURL: URL,
        onProgress: ((Double) -> Void)? = nil,
        using dataSource: OpenIMChatMessageDataSource
    ) async throws -> ChatMessage {
        onProgress?(0)
        let localMessageID = "local-\(UUID().uuidString)"
        let localMessage = ChatMessage(
            id: localMessageID,
            conversationID: conversation.id,
            sender: localOutgoingSender(for: conversation),
            content: L("[视频]", "[Video]"),
            createdAt: Date(),
            isMine: true,
            kind: .video,
            media: ChatMessageMediaPayload(mediaURL: fileURL.absoluteString),
            deliveryStatus: .sending
        )
        mergeMessage(localMessage, preferredConversation: conversation)

        do {
            var sent = try await dataSource.sendVideoMessage(
                conversationID: conversation.id,
                fileURL: fileURL,
                onProgress: { value in
                    let clamped = min(100, max(0, value))
                    onProgress?(Double(clamped) / 100.0)
                }
            )
            sent.deliveryStatus = .sent
            sent.deliveryError = nil
            replaceMessage(localMessageID: localMessageID, with: sent, preferredConversation: conversation)
            onProgress?(1)
            return sent
        } catch {
            onProgress?(0)
            updateMessageState(
                messageID: localMessageID,
                in: conversation,
                status: .failed,
                error: error.userFacingMessage
            )
            throw error
        }
    }

    func resendFailedMessage(
        messageID: String,
        conversation: Conversation,
        using dataSource: OpenIMChatMessageDataSource
    ) async throws -> ChatMessage {
        guard let failedMessage = messages(for: conversation).first(where: { $0.id == messageID }) else {
            throw ServiceError.message("Message not found")
        }
        guard failedMessage.deliveryStatus == .failed else {
            throw ServiceError.message("Message is not failed")
        }
        updateMessageState(messageID: messageID, in: conversation, status: .sending, error: nil)
        debug(
            "resend start localID=\(messageID) conversation=\(conversation.id) payload={\(debugMessageSummary(failedMessage))}"
        )
        do {
            let sentBase: ChatMessage
            switch failedMessage.kind {
            case .text:
                sentBase = try await dataSource.sendMessage(conversationID: conversation.id, content: failedMessage.content)
            case .image:
                guard let mediaURL = localFileURL(forResendFrom: failedMessage.media?.mediaURL ?? failedMessage.media?.thumbnailURL) else {
                    throw ServiceError.message("Image source file is not available for resend")
                }
                sentBase = try await dataSource.sendImageMessage(conversationID: conversation.id, fileURL: mediaURL)
            case .video:
                guard let mediaURL = localFileURL(forResendFrom: failedMessage.media?.mediaURL) else {
                    throw ServiceError.message("Video source file is not available for resend")
                }
                sentBase = try await dataSource.sendVideoMessage(conversationID: conversation.id, fileURL: mediaURL)
            default:
                throw ServiceError.message("Resend is not supported for this message type yet")
            }

            var sent = sentBase
            sent.deliveryStatus = .sent
            sent.deliveryError = nil
            debug(
                "resend success localID=\(messageID) conversation=\(conversation.id) payload={\(debugMessageSummary(sent))}"
            )
            replaceMessage(localMessageID: messageID, with: sent, preferredConversation: conversation)
            return sent
        } catch {
            debug(
                "resend failure localID=\(messageID) conversation=\(conversation.id) error=\(debugSnippet(error.userFacingMessage))"
            )
            updateMessageState(
                messageID: messageID,
                in: conversation,
                status: .failed,
                error: error.userFacingMessage
            )
            throw error
        }
    }

    private func localFileURL(forResendFrom rawValue: String?) -> URL? {
        guard let raw = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }

        if raw.hasPrefix("file://"), let url = URL(string: raw), FileManager.default.fileExists(atPath: url.path) {
            return url
        }

        if raw.hasPrefix("/"), FileManager.default.fileExists(atPath: raw) {
            return URL(fileURLWithPath: raw)
        }

        return nil
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
        storeMessages([], for: keys)
        for key in keys {
            pendingMessageFocusByConversationID.removeValue(forKey: key)
        }
        clearSearchIndex(forKeys: keys)
        clearPaginationState(for: conversation)

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
        clearStoredMessages(for: keys)
        for key in keys {
            latestInputStatusByConversationID.removeValue(forKey: key)
            pendingMessageFocusByConversationID.removeValue(forKey: key)
        }
        clearSearchIndex(forKeys: keys)
        clearPaginationState(for: conversation)

        conversations.removeAll(where: { matchesConversation($0, conversation: conversation) })
        unreadTotal = conversations.reduce(0) { $0 + max(0, $1.unreadCount) }
    }

    private func bindOpenIMSession() {
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
                        self?.debug("typing event received conversation=\(message.conversationID) user=\(message.sender.id)")
                        return
                    }
                    self?.debug("realtime message received id=\(message.id) conversation=\(message.conversationID)")
                    self?.mergeMessage(message, preferredConversation: nil)
                }
            }
            .store(in: &cancellables)

        session.conversationPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] changed in
                Task { @MainActor in
                    self?.debug("realtime conversations changed count=\(changed.count)")
                    self?.mergeConversations(changed)
                }
            }
            .store(in: &cancellables)

        session.totalUnreadPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] count in
                Task { @MainActor in
                    self?.debug("realtime total unread changed count=\(count)")
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
        conversations = Self.sortConversations(items)
        unreadTotal = items.reduce(0) { $0 + max(0, $1.unreadCount) }
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

    private func replaceMessages(_ messages: [ChatMessage], for conversation: Conversation) {
        let sorted = Self.sortMessages(messages)
        let keys = resolvedConversationKeys(conversation: conversation, fallbackID: conversation.id)
        storeMessages(sorted, for: keys)
        updateSearchIndex(messages: sorted, keys: keys)
    }

    private func mergeMessage(_ message: ChatMessage, preferredConversation: Conversation?) {
        let matchedConversation = preferredConversation ?? conversations.first {
            matchesConversation($0, id: message.conversationID)
        }
        let primaryKey = matchedConversation?.id ?? message.conversationID
        debug(
            "merge start primaryKey=\(primaryKey) preferred=\(preferredConversation?.id ?? "-") payload={\(debugMessageSummary(message))}"
        )

        var existing = messagesByConversationID[primaryKey] ?? []
        if message.conversationID != primaryKey {
            existing.append(contentsOf: messagesByConversationID[message.conversationID] ?? [])
        }
        if let openIMConversationID = matchedConversation?.openIMConversationID,
           openIMConversationID != primaryKey,
           openIMConversationID != message.conversationID {
            existing.append(contentsOf: messagesByConversationID[openIMConversationID] ?? [])
        }
        existing = Self.deduplicatedAndSortedMessages(existing)

        if let existingIndex = existing.firstIndex(where: { $0.id == message.id }) {
            let mergedMessage = Self.preferredDuplicateMessage(
                existing: existing[existingIndex],
                incoming: message
            )
            if existing[existingIndex] != mergedMessage {
                existing[existingIndex] = mergedMessage
                existing = Self.deduplicatedAndSortedMessages(existing)
                var keys = [primaryKey, message.conversationID]
                if let openIMConversationID = matchedConversation?.openIMConversationID {
                    keys.append(openIMConversationID)
                }
                storeMessages(existing, for: keys.uniqued())
                updateSearchIndex(messages: existing, keys: keys.uniqued())
                debug("merge duplicate-update key=\(primaryKey) payload={\(debugMessageSummary(mergedMessage))}")
            } else {
                debug("merge duplicate-skip key=\(primaryKey) payload={\(debugMessageSummary(message))}")
            }
            return
        }

        if let placeholderIndex = Self.staleOutgoingPlaceholderIndex(for: message, in: existing) {
            let placeholderID = existing[placeholderIndex].id
            existing[placeholderIndex] = Self.preferredDuplicateMessage(
                existing: existing[placeholderIndex],
                incoming: message
            )
            existing = Self.deduplicatedAndSortedMessages(existing)

            var keys = [primaryKey, message.conversationID]
            if let openIMConversationID = matchedConversation?.openIMConversationID {
                keys.append(openIMConversationID)
            }
            let normalizedKeys = keys.uniqued()
            storeMessages(existing, for: normalizedKeys)
            updateSearchIndex(messages: existing, keys: normalizedKeys)
            updateConversationPreview(from: message, conversationID: primaryKey)
            debug(
                "merge placeholder-collapse key=\(primaryKey) incoming={\(debugMessageSummary(message))} placeholderID=\(placeholderID)"
            )
            return
        }

        existing.append(message)
        existing = Self.deduplicatedAndSortedMessages(existing)

        var keys = [primaryKey, message.conversationID]
        if let openIMConversationID = matchedConversation?.openIMConversationID {
            keys.append(openIMConversationID)
        }
        storeMessages(existing, for: keys.uniqued())
        mergeMessageIntoSearchIndex(message, keys: keys.uniqued())

        updateConversationPreview(from: message, conversationID: primaryKey)
        debug("merge insert key=\(primaryKey) total=\(existing.count) payload={\(debugMessageSummary(message))}")
    }

    private func updateConversationPreview(from message: ChatMessage, conversationID: String) {
        guard let index = conversations.firstIndex(where: { matchesConversation($0, id: conversationID) }) else {
            return
        }

        conversations[index].lastMessage = message.content
        conversations[index].lastMessageSenderID = message.sender.displayName
        conversations[index].updatedAt = message.createdAt
        if !message.isMine {
            conversations[index].unreadCount = max(0, conversations[index].unreadCount) + 1
        }
        replaceConversations(conversations)
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

    private static func sortMessages(_ items: [ChatMessage]) -> [ChatMessage] {
        items.sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.id < rhs.id
        }
    }

    private static func deduplicatedAndSortedMessages(_ items: [ChatMessage]) -> [ChatMessage] {
        var seen = Set<String>()
        var deduplicated: [ChatMessage] = []
        for item in sortMessages(items) where !seen.contains(item.id) {
            seen.insert(item.id)
            deduplicated.append(item)
        }
        return deduplicated
    }

    private static func normalizedMessagesForPresentation(_ items: [ChatMessage]) -> [ChatMessage] {
        let deduplicated = deduplicatedAndSortedMessages(items)
        return collapseOutgoingPlaceholdersForPresentation(in: deduplicated)
    }

    private static func collapseOutgoingPlaceholdersForPresentation(
        in items: [ChatMessage]
    ) -> [ChatMessage] {
        guard items.count > 1 else { return items }

        let sorted = sortMessages(items)
        var removedIndices = Set<Int>()

        for index in sorted.indices {
            let candidate = sorted[index]
            guard candidate.isMine else { continue }
            guard candidate.deliveryStatus == .sending else { continue }
            guard candidate.id.hasPrefix("local-") else { continue }

            guard preferredOutgoingCounterpartIndex(
                for: candidate,
                in: sorted,
                excluding: removedIndices
            ) != nil else {
                continue
            }
            removedIndices.insert(index)
        }

        guard !removedIndices.isEmpty else { return sorted }
        return sorted.enumerated().compactMap { entry in
            removedIndices.contains(entry.offset) ? nil : entry.element
        }
    }

    private static func preferredOutgoingCounterpartIndex(
        for placeholder: ChatMessage,
        in messages: [ChatMessage],
        excluding removedIndices: Set<Int>
    ) -> Int? {
        let maxTimeDelta: TimeInterval
        switch placeholder.kind {
        case .text:
            maxTimeDelta = 45
        case .image, .video, .voice, .file:
            maxTimeDelta = 180
        default:
            maxTimeDelta = 60
        }

        return messages.enumerated()
            .compactMap { index, message -> (Int, Int, TimeInterval)? in
                guard !removedIndices.contains(index) else { return nil }
                guard message.id != placeholder.id else { return nil }
                guard message.isMine else { return nil }
                guard message.kind == placeholder.kind else { return nil }
                guard message.content == placeholder.content else { return nil }

                let delta = abs(message.createdAt.timeIntervalSince(placeholder.createdAt))
                guard delta <= maxTimeDelta else { return nil }

                let priority: Int
                switch message.deliveryStatus {
                case .sent:
                    priority = 0
                case .failed:
                    priority = 1
                case .sending:
                    guard !message.id.hasPrefix("local-") else { return nil }
                    priority = 2
                }

                return (index, priority, delta)
            }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 {
                    return lhs.1 < rhs.1
                }
                if lhs.2 != rhs.2 {
                    return lhs.2 < rhs.2
                }
                return messages[lhs.0].createdAt >= messages[rhs.0].createdAt
            }
            .first?
            .0
    }

    private static func preferredDuplicateMessage(existing: ChatMessage, incoming: ChatMessage) -> ChatMessage {
        var resolved = incoming
        resolved.deliveryStatus = resolvedDeliveryStatus(existing: existing, incoming: incoming)
        if resolved.deliveryStatus == .failed {
            resolved.deliveryError = incoming.deliveryError ?? existing.deliveryError
        } else {
            resolved.deliveryError = nil
        }
        return resolved
    }

    private static func resolvedDeliveryStatus(
        existing: ChatMessage,
        incoming: ChatMessage
    ) -> ChatMessageDeliveryStatus {
        if existing.deliveryStatus == .sent || incoming.deliveryStatus == .sent {
            return .sent
        }
        if existing.deliveryStatus == .failed || incoming.deliveryStatus == .failed {
            return .failed
        }
        return .sending
    }

    private static func staleOutgoingPlaceholderIndex(
        for incoming: ChatMessage,
        in messages: [ChatMessage]
    ) -> Int? {
        guard incoming.isMine else { return nil }

        let maxTimeDelta: TimeInterval
        switch incoming.kind {
        case .text:
            maxTimeDelta = 45
        case .image, .video, .voice, .file:
            maxTimeDelta = 180
        default:
            maxTimeDelta = 60
        }

        let candidates = messages.enumerated().compactMap { index, message -> (Int, TimeInterval)? in
            guard message.isMine else { return nil }
            guard message.deliveryStatus == .sending else { return nil }
            guard message.id.hasPrefix("local-") else { return nil }
            guard message.kind == incoming.kind else { return nil }
            guard message.content == incoming.content else { return nil }

            let delta = abs(message.createdAt.timeIntervalSince(incoming.createdAt))
            guard delta <= maxTimeDelta else { return nil }
            return (index, delta)
        }

        return candidates
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 {
                    return lhs.1 < rhs.1
                }
                return messages[lhs.0].createdAt > messages[rhs.0].createdAt
            }
            .first?
            .0
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

    private func localOutgoingSender(for conversation: Conversation) -> UserSummary {
        if let mine = messages(for: conversation).last(where: { $0.isMine })?.sender {
            return mine
        }
        let userID = session.currentBusinessUserIDSnapshot() ?? "me"
        return UserSummary(
            id: userID,
            username: userID,
            displayName: L("我", "Me"),
            avatarURL: nil,
            isFollowing: false
        )
    }

    private func replaceMessage(localMessageID: String, with message: ChatMessage, preferredConversation: Conversation) {
        let keys = resolvedConversationKeys(conversation: preferredConversation, fallbackID: message.conversationID)
        guard !keys.isEmpty else {
            debug(
                "replace fallback-merge localID=\(localMessageID) conversation=\(preferredConversation.id) payload={\(debugMessageSummary(message))}"
            )
            mergeMessage(message, preferredConversation: preferredConversation)
            return
        }

        let mergedExisting = keys.flatMap { messagesByConversationID[$0] ?? [] }
        var normalized = Self.deduplicatedAndSortedMessages(mergedExisting)
        let countBeforeRemoval = normalized.count
        normalized.removeAll(where: { $0.id == localMessageID })
        let removedLocalPlaceholder = normalized.count != countBeforeRemoval
        let branch: String
        if let existingIndex = normalized.firstIndex(where: { $0.id == message.id }) {
            normalized[existingIndex] = Self.preferredDuplicateMessage(
                existing: normalized[existingIndex],
                incoming: message
            )
            branch = "exact-id-update"
        } else if let placeholderIndex = Self.staleOutgoingPlaceholderIndex(for: message, in: normalized) {
            let placeholderID = normalized[placeholderIndex].id
            normalized[placeholderIndex] = Self.preferredDuplicateMessage(
                existing: normalized[placeholderIndex],
                incoming: message
            )
            branch = "placeholder-collapse(\(placeholderID))"
        } else {
            normalized.append(message)
            branch = "append"
        }
        normalized = Self.deduplicatedAndSortedMessages(normalized)

        storeMessages(normalized, for: keys)
        updateSearchIndex(messages: normalized, keys: keys)
        updateConversationPreview(from: message, conversationID: preferredConversation.id)
        debug(
            "replace done localID=\(localMessageID) conversation=\(preferredConversation.id) branch=\(branch) removedLocal=\(removedLocalPlaceholder ? 1 : 0) total=\(normalized.count) payload={\(debugMessageSummary(message))}"
        )
    }

    private func updateMessageState(
        messageID: String,
        in conversation: Conversation,
        status: ChatMessageDeliveryStatus,
        error: String?
    ) {
        let keys = resolvedConversationKeys(conversation: conversation, fallbackID: conversation.id)
        guard !keys.isEmpty else { return }

        let mergedExisting = keys.flatMap { messagesByConversationID[$0] ?? [] }
        var normalized = Self.deduplicatedAndSortedMessages(mergedExisting)
        guard let index = normalized.firstIndex(where: { $0.id == messageID }) else { return }
        normalized[index].deliveryStatus = status
        normalized[index].deliveryError = error

        storeMessages(normalized, for: keys)
        debug(
            "update state messageID=\(messageID) conversation=\(conversation.id) status=\(status.rawValue) error=\(debugSnippet(error))"
        )
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
        print("[OpenIMChatStore] \(message)")
        OpenIMProbeLogger.log("[OpenIMChatStore] \(message)")
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

    private func updateSearchIndex(messages: [ChatMessage], keys: [String]) {
        let normalized = Self.deduplicatedAndSortedMessages(messages)
        for key in keys where !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            messageSearchIndex.replaceMessages(normalized, conversationID: key)
        }
    }

    private func storeMessages(_ messages: [ChatMessage], for keys: [String]) {
        let normalizedKeys = keys
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .uniqued()
        guard !normalizedKeys.isEmpty else { return }

        var updated = messagesByConversationID
        for key in normalizedKeys {
            updated[key] = messages
        }
        messagesByConversationID = updated
    }

    private func clearStoredMessages(for keys: [String]) {
        let normalizedKeys = keys
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .uniqued()
        guard !normalizedKeys.isEmpty else { return }

        var updated = messagesByConversationID
        for key in normalizedKeys {
            updated.removeValue(forKey: key)
        }
        messagesByConversationID = updated
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

    private func paginationState(for conversation: Conversation) -> MessagePaginationState {
        messagePaginationByConversationID[paginationKey(for: conversation)] ?? MessagePaginationState()
    }

    private func updatePaginationState(_ state: MessagePaginationState, for conversation: Conversation) {
        messagePaginationByConversationID[paginationKey(for: conversation)] = state
    }

    private func clearPaginationState(for conversation: Conversation) {
        for key in resolvedConversationKeys(conversation: conversation, fallbackID: conversation.id) {
            messagePaginationByConversationID.removeValue(forKey: key)
        }
    }

    private func paginationKey(for conversation: Conversation) -> String {
        if !conversation.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return conversation.id
        }
        return conversation.openIMConversationID ?? conversation.id
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
