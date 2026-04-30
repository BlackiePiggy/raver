import Foundation
import Combine

@MainActor
final class RaverChatController: ObservableObject {
    private enum Pagination {
        static let initialPageCount = 50
        static let olderPageCount = 30
        static let maxSearchBackfillPageLoads = 12
    }

    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var latestInputStatus: IMInputStatusEvent?
    @Published private(set) var isInitialLoading = false
    @Published private(set) var isLoadingOlder = false
    @Published private(set) var hasCompletedInitialLoad = false
    @Published private(set) var canLoadOlderMessages = false
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var replyDraftMessage: ChatMessage?
    @Published private(set) var playingVoiceMessageID: String?

    private let dataProvider: RaverChatDataProvider
    private let tencentIMSession = TencentIMSession.shared
    private var cancellables = Set<AnyCancellable>()
    private var oldestLoadedMessageID: String?

    init(dataProvider: RaverChatDataProvider) {
        self.dataProvider = dataProvider
    }

    func start() {
        bindRealtimeIfNeeded()
        Task { @MainActor [weak self] in
            await self?.loadTencentMessages(force: false)
        }
    }

    func updateContext(conversation: Conversation, service: SocialService) {
        dataProvider.updateContext(conversation: conversation, service: service)
        resetTencentState()
        start()
    }

    func loadOlderMessagesIfNeeded() async {
        guard hasCompletedInitialLoad else { return }
        guard !isInitialLoading, !isLoadingOlder else { return }
        guard canLoadOlderMessages else { return }

        isLoadingOlder = true
        lastErrorMessage = nil
        defer {
            isLoadingOlder = false
        }

        do {
            let page = try await dataProvider.currentService.fetchMessages(
                conversationID: dataProvider.currentConversation.id,
                startClientMsgID: oldestLoadedMessageID,
                count: Pagination.olderPageCount
            )
            prependOlderMessages(sortTencentMessages(page.messages))
            canLoadOlderMessages = !page.isEnd
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.userFacingMessage
        }
    }

    func currentMessagesSnapshot() -> [ChatMessage] {
        messages
    }

    @discardableResult
    func sendTextMessage(_ text: String) async throws -> ChatMessage {
        let replyContext = replyDraftMessage
        let transportText = buildTransportText(text: text, replyDraft: replyContext)
        let sent = try await dataProvider.currentService.sendMessage(
            conversationID: dataProvider.currentConversation.id,
            content: transportText
        )
        let decorated = decorateMessageMetadata(sent, originalText: text, replyDraft: replyContext)
        replyDraftMessage = nil
        applySentMessage(decorated)
        return decorated
    }

    @discardableResult
    func sendImageMessage(
        fileURL: URL,
        onProgress: ((Double) -> Void)? = nil
    ) async throws -> ChatMessage {
        let sent = try await dataProvider.currentService.sendImageMessage(
            conversationID: dataProvider.currentConversation.id,
            fileURL: fileURL
        )
        onProgress?(1)
        applySentMessage(sent)
        return sent
    }

    @discardableResult
    func sendVideoMessage(
        fileURL: URL,
        onProgress: ((Double) -> Void)? = nil
    ) async throws -> ChatMessage {
        let sent = try await dataProvider.currentService.sendVideoMessage(
            conversationID: dataProvider.currentConversation.id,
            fileURL: fileURL
        )
        onProgress?(1)
        applySentMessage(sent)
        return sent
    }

    @discardableResult
    func sendVoiceMessage(fileURL: URL) async throws -> ChatMessage {
        let sent = try await dataProvider.currentService.sendVoiceMessage(
            conversationID: dataProvider.currentConversation.id,
            fileURL: fileURL
        )
        applySentMessage(sent)
        return sent
    }

    @discardableResult
    func sendFileMessage(fileURL: URL) async throws -> ChatMessage {
        let sent = try await dataProvider.currentService.sendFileMessage(
            conversationID: dataProvider.currentConversation.id,
            fileURL: fileURL
        )
        applySentMessage(sent)
        return sent
    }

    @discardableResult
    func resendFailedMessage(messageID: String) async throws -> ChatMessage {
        guard let message = messages.first(where: { $0.id == messageID }) else {
            throw ServiceError.message(L("未找到待重发消息", "Failed message not found"))
        }
        guard message.deliveryStatus == .failed else {
            throw ServiceError.message(L("该消息当前不可重发", "This message cannot be resent now"))
        }

        switch message.kind {
        case .text:
            let text = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                throw ServiceError.message(L("文本内容为空，无法重发", "Empty text message cannot be resent"))
            }
            let resent = try await dataProvider.currentService.sendMessage(
                conversationID: dataProvider.currentConversation.id,
                content: text
            )
            let decorated = decorateMessageMetadata(
                resent,
                originalText: text,
                replyDraft: repliedMessage(for: message)
            )
            replaceLocalFailedMessage(messageID: messageID, with: decorated)
            return decorated
        case .image:
            let resent = try await dataProvider.currentService.sendImageMessage(
                conversationID: dataProvider.currentConversation.id,
                fileURL: try localMediaFileURL(from: message)
            )
            replaceLocalFailedMessage(messageID: messageID, with: resent)
            return resent
        case .video:
            let resent = try await dataProvider.currentService.sendVideoMessage(
                conversationID: dataProvider.currentConversation.id,
                fileURL: try localMediaFileURL(from: message)
            )
            replaceLocalFailedMessage(messageID: messageID, with: resent)
            return resent
        case .voice:
            let resent = try await dataProvider.currentService.sendVoiceMessage(
                conversationID: dataProvider.currentConversation.id,
                fileURL: try localMediaFileURL(from: message)
            )
            replaceLocalFailedMessage(messageID: messageID, with: resent)
            return resent
        case .file:
            let resent = try await dataProvider.currentService.sendFileMessage(
                conversationID: dataProvider.currentConversation.id,
                fileURL: try localMediaFileURL(from: message)
            )
            replaceLocalFailedMessage(messageID: messageID, with: resent)
            return resent
        default:
            throw ServiceError.message(
                L("当前消息类型暂不支持重发", "Resend is not supported for this message type")
            )
        }
    }

    func handleComposerInputChanged(_ text: String) {
        _ = text
    }

    func toggleReplyDraft(for messageID: String) {
        guard let target = messages.first(where: { $0.id == messageID }) else { return }
        if replyDraftMessage?.id == target.id {
            replyDraftMessage = nil
            return
        }
        replyDraftMessage = target
    }

    func clearReplyDraft() {
        replyDraftMessage = nil
    }

    func setPlayingVoiceMessageID(_ messageID: String?) {
        playingVoiceMessageID = messageID
    }

    func removeLocalFailedMessage(_ messageID: String) {
        guard let index = messages.firstIndex(where: { $0.id == messageID }) else { return }
        guard messages[index].isMine, messages[index].deliveryStatus == .failed else { return }
        messages.remove(at: index)
        if replyDraftMessage?.id == messageID {
            replyDraftMessage = nil
        }
    }

    func revokeMessage(_ messageID: String) async throws {
        guard let index = messages.firstIndex(where: { $0.id == messageID }) else {
            throw ServiceError.message(L("未找到待撤回消息", "Message to revoke was not found"))
        }

        let message = messages[index]
        guard message.isMine else {
            throw ServiceError.message(L("只能撤回自己发送的消息", "Only your own messages can be revoked"))
        }
        guard message.deliveryStatus == .sent else {
            throw ServiceError.message(L("消息尚未发送完成，暂不可撤回", "This message cannot be revoked yet"))
        }

        let displayText = try await dataProvider.currentService.revokeMessage(
            conversationID: dataProvider.currentConversation.id,
            messageID: messageID
        )
        replaceMessageWithRevokedSystemNotice(messageID: messageID, displayText: displayText)
    }

    func deleteMessage(_ messageID: String) async throws {
        guard let index = messages.firstIndex(where: { $0.id == messageID }) else {
            throw ServiceError.message(L("未找到待删除消息", "Message to delete was not found"))
        }

        let message = messages[index]
        if message.deliveryStatus == .failed, message.isMine {
            removeLocalFailedMessage(messageID)
            return
        }

        try await dataProvider.currentService.deleteMessage(
            conversationID: dataProvider.currentConversation.id,
            messageID: messageID
        )
        messages.remove(at: index)
        if replyDraftMessage?.id == messageID {
            replyDraftMessage = nil
        }
    }

    func searchMessages(
        query: String,
        limit: Int = 30
    ) async throws -> [ChatMessageSearchResult] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return [] }

        if !hasCompletedInitialLoad {
            await loadTencentMessages(force: false)
        }

        var results = try await dataProvider.searchMessages(
            query: query,
            limit: limit
        )

#if DEBUG
        print(
            "[IMSearchProbe] conversation-search-initial conversation=\(dataProvider.currentConversation.id) query=\(normalizedQuery) hits=\(results.count) canLoadOlder=\(canLoadOlderMessages)"
        )
#endif

        guard results.count < limit, canLoadOlderMessages else {
            return results
        }

        var remainingLoads = Pagination.maxSearchBackfillPageLoads
        var previousMessageCount = messages.count
        var previousOldestMessageID = oldestLoadedMessageID

        while results.count < limit, canLoadOlderMessages, remainingLoads > 0 {
            await loadOlderMessagesIfNeeded()
            remainingLoads -= 1

            results = try await dataProvider.searchMessages(
                query: normalizedQuery,
                limit: limit
            )

#if DEBUG
            print(
                "[IMSearchProbe] conversation-search-backfill conversation=\(dataProvider.currentConversation.id) query=\(normalizedQuery) hits=\(results.count) remainingLoads=\(remainingLoads) messages=\(messages.count)"
            )
#endif

            let currentMessageCount = messages.count
            let currentOldestMessageID = oldestLoadedMessageID
            if currentMessageCount == previousMessageCount, currentOldestMessageID == previousOldestMessageID {
                break
            }
            previousMessageCount = currentMessageCount
            previousOldestMessageID = currentOldestMessageID
        }

        return results
    }

    func revealMessage(messageID: String, maxOlderPageLoads: Int = 6) async -> Bool {
        if messages.contains(where: { $0.id == messageID }) {
            return true
        }

        guard maxOlderPageLoads > 0 else { return false }

        var remainingLoads = maxOlderPageLoads
        var previousCount = messages.count
        var previousOldestMessageID = oldestLoadedMessageID

        while canLoadOlderMessages, remainingLoads > 0 {
            await loadOlderMessagesIfNeeded()
            if messages.contains(where: { $0.id == messageID }) {
                return true
            }

            remainingLoads -= 1
            let currentCount = messages.count
            let currentOldestMessageID = oldestLoadedMessageID
            if currentCount == previousCount, currentOldestMessageID == previousOldestMessageID {
                break
            }
            previousCount = currentCount
            previousOldestMessageID = currentOldestMessageID
        }

        return messages.contains(where: { $0.id == messageID })
    }

    private func loadTencentMessages(force: Bool) async {
        guard force || !hasCompletedInitialLoad else { return }
        guard !isInitialLoading else { return }

        isInitialLoading = true
        lastErrorMessage = nil
        defer {
            isInitialLoading = false
        }

        do {
            let page = try await dataProvider.currentService.fetchMessages(
                conversationID: dataProvider.currentConversation.id,
                startClientMsgID: nil,
                count: Pagination.initialPageCount
            )
            messages = sortTencentMessages(page.messages)
            oldestLoadedMessageID = messages.first?.id
            latestInputStatus = nil
            hasCompletedInitialLoad = true
            canLoadOlderMessages = !page.isEnd
            lastErrorMessage = nil
            IMChatStore.shared.replaceSearchIndexMessages(messages, for: dataProvider.currentConversation)
#if DEBUG
            print(
                "[IMSearchProbe] initial-load conversation=\(dataProvider.currentConversation.id) fetched=\(messages.count)"
            )
#endif
        } catch {
            hasCompletedInitialLoad = false
            lastErrorMessage = error.userFacingMessage
        }
    }

    private func sortTencentMessages(_ items: [ChatMessage]) -> [ChatMessage] {
        items.map(normalizeInboundMessageMetadata).sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.id < rhs.id
        }
    }

    private func resetTencentState() {
        messages = []
        latestInputStatus = nil
        isInitialLoading = false
        isLoadingOlder = false
        hasCompletedInitialLoad = false
        canLoadOlderMessages = false
        lastErrorMessage = nil
        replyDraftMessage = nil
        playingVoiceMessageID = nil
        oldestLoadedMessageID = nil
    }

    private func bindRealtimeIfNeeded() {
        guard cancellables.isEmpty else { return }

        tencentIMSession.messagePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                guard let self else { return }
                guard self.isMessageInCurrentConversation(message) else { return }
                self.applyIncomingRealtimeMessage(message)
            }
            .store(in: &cancellables)

        tencentIMSession.c2cReadReceiptPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] events in
                self?.applyC2CReadReceiptEvents(events)
            }
            .store(in: &cancellables)

        tencentIMSession.messageRevocationPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.applyRevocationEvent(event)
            }
            .store(in: &cancellables)
    }

    private func isMessageInCurrentConversation(_ message: ChatMessage) -> Bool {
        let currentConversation = dataProvider.currentConversation
        if message.conversationID == currentConversation.id {
            return true
        }
        if let sdkConversationID = currentConversation.sdkConversationID,
           message.conversationID == sdkConversationID {
            return true
        }
        return false
    }

    private func applyIncomingRealtimeMessage(_ message: ChatMessage) {
        guard message.kind != .typing else {
            latestInputStatus = IMInputStatusEvent(
                conversationID: message.conversationID,
                userID: message.sender.id,
                platformIDs: [],
                receivedAt: Date()
            )
            return
        }

        let normalizedMessage = normalizeInboundMessageMetadata(message)
        var next = messages
        if let existingIndex = next.firstIndex(where: { $0.id == normalizedMessage.id }) {
            next[existingIndex] = normalizedMessage
        } else {
            next.append(normalizedMessage)
        }
        messages = sortTencentMessages(next)
        IMChatStore.shared.mergeSearchIndexMessages([normalizedMessage], for: dataProvider.currentConversation)
        hasCompletedInitialLoad = true
        lastErrorMessage = nil
    }

    private func applySentMessage(_ message: ChatMessage) {
        guard isMessageInCurrentConversation(message) else { return }
        applyIncomingRealtimeMessage(normalizeInboundMessageMetadata(message))
    }

    private func applyC2CReadReceiptEvents(_ events: [TencentC2CReadReceiptEvent]) {
        guard !messages.isEmpty else { return }
        let currentConversationID = dataProvider.currentConversation.id
        let filtered = events.filter { $0.conversationID == currentConversationID }
        guard !filtered.isEmpty else { return }

        var next = messages
        var changed = false

        for event in filtered {
            if let messageID = event.messageID {
                if let index = next.firstIndex(where: { $0.id == messageID && $0.isMine }) {
                    if next[index].peerRead != event.peerRead {
                        next[index].peerRead = event.peerRead
                        changed = true
                    }
                }
                continue
            }

            // Conversation-level read receipt: mark my already-sent messages as read up to the read timestamp.
            if let readAt = event.readAt {
                for index in next.indices where next[index].isMine && next[index].createdAt <= readAt {
                    if next[index].peerRead != true {
                        next[index].peerRead = true
                        changed = true
                    }
                }
            } else {
                for index in next.indices where next[index].isMine {
                    if next[index].peerRead != event.peerRead {
                        next[index].peerRead = event.peerRead
                        changed = true
                    }
                }
            }
        }

        if changed {
            messages = sortTencentMessages(next)
        }
    }

    private func normalizeInboundMessageMetadata(_ message: ChatMessage) -> ChatMessage {
        guard message.kind == .text else { return message }
        let parsed = parseReplyEnvelope(from: message.content)
        var normalized = message
        if let parsed {
            normalized.content = parsed.body
            normalized.replyPreview = parsed.replyPreview
            if normalized.replyToMessageID == nil {
                normalized.replyToMessageID = parsed.replyToMessageID
            }
        }
        if normalized.mentionedUserIDs.isEmpty {
            normalized.mentionedUserIDs = parseMentionedUserIDs(from: normalized.content)
        }
        return normalized
    }

    private func decorateMessageMetadata(
        _ sent: ChatMessage,
        originalText: String,
        replyDraft: ChatMessage?
    ) -> ChatMessage {
        var next = sent
        next.content = originalText
        if let replyDraft {
            next.replyToMessageID = replyDraft.id
            next.replyPreview = replyPreviewText(for: replyDraft, includeSender: true)
        }
        next.mentionedUserIDs = parseMentionedUserIDs(from: originalText)
        return next
    }

    private func buildTransportText(text: String, replyDraft: ChatMessage?) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let replyDraft else { return trimmed }
        let senderName = displayName(for: replyDraft.sender, isMine: replyDraft.isMine)
        let preview = replyPreviewText(for: replyDraft, includeSender: false)
        return "[reply:\(sanitizeReplyEnvelopeField(replyDraft.id))|\(sanitizeReplyEnvelopeField(senderName))|\(sanitizeReplyEnvelopeField(preview))]\n\(trimmed)"
    }

    private func parseReplyEnvelope(from text: String) -> (replyToMessageID: String?, replyPreview: String, body: String)? {
        guard text.hasPrefix("[reply:") else { return nil }
        guard let closeIndex = text.firstIndex(of: "]") else { return nil }
        let payloadStart = text.index(text.startIndex, offsetBy: 7)
        let payload = String(text[payloadStart..<closeIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = payload.split(separator: "|", omittingEmptySubsequences: false)
        guard parts.count >= 3 else { return nil }
        let idPart = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
        let senderPart = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
        let previewPart = parts.dropFirst(2).joined(separator: "|")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !idPart.isEmpty, !previewPart.isEmpty else { return nil }
        let preview = senderPart.isEmpty ? previewPart : "\(senderPart): \(previewPart)"
        var body = String(text[text.index(after: closeIndex)...])
        if body.hasPrefix("\n") {
            body.removeFirst()
        }
        return (replyToMessageID: idPart, replyPreview: preview, body: body)
    }

    private func replyPreviewText(for message: ChatMessage, includeSender: Bool) -> String {
        let base = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let body: String
        if !base.isEmpty {
            body = String(base.prefix(40))
        } else {
            switch message.kind {
            case .image:
                body = L("[图片]", "[Image]")
            case .video:
                body = L("[视频]", "[Video]")
            case .voice:
                body = L("[语音]", "[Voice]")
            case .file:
                if let fileName = message.media?.fileName?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !fileName.isEmpty {
                    body = "[\(fileName)]"
                } else {
                    body = L("[文件]", "[File]")
                }
            default:
                body = L("[消息]", "[Message]")
            }
        }

        guard includeSender else { return body }
        let sender = displayName(for: message.sender, isMine: message.isMine)
        return "\(sender): \(body)"
    }

    private func displayName(for sender: UserSummary, isMine: Bool) -> String {
        if isMine {
            return L("我", "Me")
        }
        let shown = sender.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !shown.isEmpty { return shown }
        let username = sender.username.trimmingCharacters(in: .whitespacesAndNewlines)
        return username.isEmpty ? L("用户", "User") : username
    }

    private func sanitizeReplyEnvelopeField(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "|", with: "/")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func localMediaFileURL(from message: ChatMessage) throws -> URL {
        guard let raw = message.media?.mediaURL?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            throw ServiceError.message(L("本地媒体文件不存在，无法重发", "Local media file is missing"))
        }

        let url: URL
        if raw.hasPrefix("file://"), let parsed = URL(string: raw) {
            url = parsed
        } else if raw.hasPrefix("/") {
            url = URL(fileURLWithPath: raw)
        } else if let parsed = URL(string: raw), parsed.isFileURL {
            url = parsed
        } else {
            throw ServiceError.message(
                L("该媒体消息缺少本地文件，仅云端地址不可直接重发", "Remote-only media cannot be resent directly")
            )
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ServiceError.message(L("本地媒体文件已失效，请重新发送", "Local media file no longer exists"))
        }
        return url
    }

    private func parseMentionedUserIDs(from text: String) -> [String] {
        let pattern = #"(?:^|\s)@([A-Za-z0-9_\-\.]{2,64})"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, options: [], range: nsRange)
        var result: [String] = []
        for match in matches {
            guard match.numberOfRanges >= 2,
                  let range = Range(match.range(at: 1), in: text) else {
                continue
            }
            let value = String(text[range])
            if !result.contains(value) {
                result.append(value)
            }
        }
        return result
    }

    private func replaceLocalFailedMessage(messageID: String, with message: ChatMessage) {
        guard isMessageInCurrentConversation(message) else { return }
        var next = messages
        if let existingIndex = next.firstIndex(where: { $0.id == messageID }) {
            next.remove(at: existingIndex)
        }
        if let duplicateIndex = next.firstIndex(where: { $0.id == message.id }) {
            next[duplicateIndex] = normalizeInboundMessageMetadata(message)
        } else {
            next.append(normalizeInboundMessageMetadata(message))
        }
        messages = sortTencentMessages(next)
        if replyDraftMessage?.id == messageID {
            replyDraftMessage = nil
        }
        hasCompletedInitialLoad = true
        lastErrorMessage = nil
    }

    private func applyRevocationEvent(_ event: TencentMessageRevocationEvent) {
        guard isMessageInCurrentConversationID(event.conversationID) else { return }
        replaceMessageWithRevokedSystemNotice(messageID: event.messageID, displayText: event.displayText)
    }

    private func replaceMessageWithRevokedSystemNotice(messageID: String, displayText: String) {
        guard let index = messages.firstIndex(where: { $0.id == messageID }) else { return }
        var revoked = messages[index]
        revoked.kind = .system
        revoked.content = displayText
        revoked.media = nil
        revoked.deliveryStatus = .sent
        revoked.deliveryError = nil
        revoked.replyToMessageID = nil
        revoked.replyPreview = nil
        revoked.mentionedUserIDs = []
        revoked.peerRead = nil
        revoked.readReceiptReadCount = nil
        revoked.readReceiptUnreadCount = nil
        messages[index] = revoked
        if replyDraftMessage?.id == messageID {
            replyDraftMessage = nil
        }
        messages = sortTencentMessages(messages)
    }

    private func isMessageInCurrentConversationID(_ conversationID: String) -> Bool {
        let currentConversation = dataProvider.currentConversation
        if currentConversation.id == conversationID {
            return true
        }
        if let sdkConversationID = currentConversation.sdkConversationID, sdkConversationID == conversationID {
            return true
        }
        return false
    }

    private func prependOlderMessages(_ olderMessages: [ChatMessage]) {
        guard !olderMessages.isEmpty else { return }

        var mergedByID: [String: ChatMessage] = [:]
        mergedByID.reserveCapacity(messages.count + olderMessages.count)
        for message in messages {
            mergedByID[message.id] = message
        }
        for message in olderMessages {
            mergedByID[message.id] = message
        }

        messages = sortTencentMessages(Array(mergedByID.values))
        oldestLoadedMessageID = messages.first?.id
        hasCompletedInitialLoad = true
        IMChatStore.shared.mergeSearchIndexMessages(olderMessages, for: dataProvider.currentConversation)
#if DEBUG
        print(
            "[IMSearchProbe] prepend-older conversation=\(dataProvider.currentConversation.id) older=\(olderMessages.count) merged=\(messages.count)"
        )
#endif
    }

    private func repliedMessage(for message: ChatMessage) -> ChatMessage? {
        guard let replyToMessageID = message.replyToMessageID else { return nil }
        return messages.first(where: { $0.id == replyToMessageID })
    }
}
