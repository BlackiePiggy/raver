import Foundation
import Combine

@MainActor
final class RaverChatController: ObservableObject {
    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var latestInputStatus: OpenIMInputStatusEvent?
    @Published private(set) var isInitialLoading = false
    @Published private(set) var isLoadingOlder = false
    @Published private(set) var hasCompletedInitialLoad = false
    @Published private(set) var canLoadOlderMessages = false
    @Published private(set) var lastErrorMessage: String?

    private let dataProvider: RaverChatDataProvider
    private let openIMController: RaverOpenIMChatController
    private var cancellables = Set<AnyCancellable>()
    private var hasBoundState = false

    init(dataProvider: RaverChatDataProvider) {
        self.dataProvider = dataProvider
        self.openIMController = RaverOpenIMChatController(
            conversation: dataProvider.currentConversation,
            service: dataProvider.currentService,
            session: .shared
        )
    }

    func start() {
        bindStateIfNeeded()
        openIMController.start()
    }

    func updateContext(conversation: Conversation, service: SocialService) {
        dataProvider.updateContext(conversation: conversation, service: service)
        openIMController.updateContext(conversation: conversation, service: service)
        bindStateIfNeeded()
    }

    func loadOlderMessagesIfNeeded() async {
        await openIMController.loadOlderMessagesIfNeeded()
    }

    func currentMessagesSnapshot() -> [ChatMessage] {
        openIMController.renderedMessages
    }

    @discardableResult
    func sendTextMessage(_ text: String) async throws -> ChatMessage {
        try await openIMController.sendTextMessage(text)
    }

    @discardableResult
    func sendImageMessage(
        fileURL: URL,
        onProgress: ((Double) -> Void)? = nil
    ) async throws -> ChatMessage {
        try await openIMController.sendImageMessage(
            fileURL: fileURL,
            onProgress: onProgress
        )
    }

    @discardableResult
    func sendVideoMessage(
        fileURL: URL,
        onProgress: ((Double) -> Void)? = nil
    ) async throws -> ChatMessage {
        try await openIMController.sendVideoMessage(
            fileURL: fileURL,
            onProgress: onProgress
        )
    }

    @discardableResult
    func resendFailedMessage(messageID: String) async throws -> ChatMessage {
        try await openIMController.resendFailedMessage(messageID: messageID)
    }

    func handleComposerInputChanged(_ text: String) {
        openIMController.handleComposerInputChanged(text)
    }

    func searchMessages(
        query: String,
        limit: Int = 30,
        remoteDataSource: ChatMessageSearchRemoteDataSource? = nil
    ) async throws -> [ChatMessageSearchResult] {
        try await dataProvider.searchMessages(
            query: query,
            limit: limit,
            remoteDataSource: remoteDataSource
        )
    }

    private func bindStateIfNeeded() {
        guard !hasBoundState else { return }
        hasBoundState = true

        openIMController.$renderedMessages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.messages = $0 }
            .store(in: &cancellables)

        openIMController.$latestInputStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.latestInputStatus = $0 }
            .store(in: &cancellables)

        openIMController.$isInitialLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.isInitialLoading = $0 }
            .store(in: &cancellables)

        openIMController.$isLoadingOlder
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.isLoadingOlder = $0 }
            .store(in: &cancellables)

        openIMController.$hasCompletedInitialLoad
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.hasCompletedInitialLoad = $0 }
            .store(in: &cancellables)

        openIMController.$canLoadOlderMessages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.canLoadOlderMessages = $0 }
            .store(in: &cancellables)

        openIMController.$lastErrorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.lastErrorMessage = $0 }
            .store(in: &cancellables)
    }
}

#if canImport(OpenIMSDK)
import OpenIMSDK

private struct OpenIMChatItem: Equatable {
    let messageID: String
    let rawMessage: OIMMessageInfo
    let renderedMessage: ChatMessage
}

@MainActor
private enum OpenIMMessageRenderMapper {
    static func map(
        _ message: OIMMessageInfo,
        conversation: Conversation,
        rawChatService: OpenIMRawChatService
    ) -> OpenIMChatItem {
        let openIMConversationID = conversation.openIMConversationID ?? conversation.id
        let rendered = rawChatService.chatMessageSnapshot(from: message, conversationID: openIMConversationID)
        return OpenIMChatItem(
            messageID: rendered.id,
            rawMessage: message,
            renderedMessage: rendered
        )
    }
}

@MainActor
final class RaverOpenIMChatController: ObservableObject {
    @Published private(set) var rawMessages: [OIMMessageInfo] = []
    @Published private(set) var renderedMessages: [ChatMessage] = []
    @Published private(set) var latestInputStatus: OpenIMInputStatusEvent?
    @Published private(set) var isInitialLoading = false
    @Published private(set) var isLoadingOlder = false
    @Published private(set) var hasCompletedInitialLoad = false
    @Published private(set) var canLoadOlderMessages = false
    @Published private(set) var lastErrorMessage: String?

    private let session: OpenIMSession
    private var conversation: Conversation
    private var service: SocialService
    private var cancellables = Set<AnyCancellable>()
    private var hasBoundRealtime = false
    private var lastOlderLoadAt: Date = .distantPast
    private let olderLoadThrottleSeconds: TimeInterval = 0.45
    private let typingStatusExpireSeconds: TimeInterval = 4
    private let typingSendThrottleSeconds: TimeInterval = 2
    private let readMarkThrottleSeconds: TimeInterval = 0.75
    private var oldestClientMsgID: String?
    private var reachedBeginning = false
    private var renderedItems: [OpenIMChatItem] = []
    private var latestInputStatusClearTask: Task<Void, Never>?
    private var lastTypingStatusSentAt: Date = .distantPast
    private var lastReadMarkAt: Date = .distantPast
    private let chatStore = OpenIMChatStore.shared
    private var hasRegisteredActiveConversation = false

    init(
        conversation: Conversation,
        service: SocialService,
        session: OpenIMSession
    ) {
        self.conversation = conversation
        self.service = service
        self.session = session
    }

    deinit {
        Task { @MainActor [conversation, chatStore, hasRegisteredActiveConversation] in
            guard hasRegisteredActiveConversation else { return }
            chatStore.deactivateConversation(conversation)
        }
    }

    private var rawChatService: OpenIMRawChatService {
        (service as? OpenIMRawChatService) ?? session
    }

    func start() {
        ensureActiveConversationRegistration()
        bindRealtimeIfNeeded()
        Task { @MainActor [weak self] in
            await self?.loadInitialMessagesIfNeeded()
        }
    }

    func updateContext(conversation: Conversation, service: SocialService) {
        releaseActiveConversationRegistration()
        self.conversation = conversation
        self.service = service
        resetState()
        start()
    }

    func loadOlderMessagesIfNeeded() async {
        guard hasCompletedInitialLoad else { return }
        guard !isInitialLoading, !isLoadingOlder else { return }
        guard !rawMessages.isEmpty else { return }
        guard canLoadOlderMessages else { return }
        guard Date().timeIntervalSince(lastOlderLoadAt) >= olderLoadThrottleSeconds else { return }

        lastOlderLoadAt = Date()
        isLoadingOlder = true
        defer { isLoadingOlder = false }

        do {
            guard let page = try await rawChatService.fetchRawMessagesPage(
                conversationID: conversation.id,
                startClientMsgID: oldestClientMsgID,
                count: 30
            ) else {
                canLoadOlderMessages = false
                return
            }

            rawMessages = deduplicatedAndSorted(page.messages + rawMessages)
            oldestClientMsgID = normalizedClientMsgID(for: rawMessages.first)
            reachedBeginning = page.isEnd || page.messages.isEmpty
            canLoadOlderMessages = !reachedBeginning
            rebuildRenderedMessages()
        } catch {
            if !error.isUserInitiatedCancellation {
                lastErrorMessage = error.userFacingMessage
            }
        }
    }

    @discardableResult
    func sendTextMessage(_ text: String) async throws -> ChatMessage {
        let message = rawChatService.createRawTextMessage(content: text)
        return try await sendPreparedMessage(
            message,
            failurePrefix: "OpenIM send text message failed"
        )
    }

    @discardableResult
    func sendImageMessage(
        fileURL: URL,
        onProgress: ((Double) -> Void)? = nil
    ) async throws -> ChatMessage {
        let message = try rawChatService.createRawImageMessage(fileURL: fileURL)
        return try await sendPreparedMessage(
            message,
            failurePrefix: "OpenIM send image message failed",
            onProgress: onProgress
        )
    }

    @discardableResult
    func sendVideoMessage(
        fileURL: URL,
        onProgress: ((Double) -> Void)? = nil
    ) async throws -> ChatMessage {
        let message = try rawChatService.createRawVideoMessage(fileURL: fileURL)
        return try await sendPreparedMessage(
            message,
            failurePrefix: "OpenIM send video message failed",
            onProgress: onProgress
        )
    }

    @discardableResult
    func resendFailedMessage(messageID: String) async throws -> ChatMessage {
        guard let failedMessage = rawMessages.first(where: {
            normalizedClientMsgID(for: $0) == messageID
        }) else {
            throw ServiceError.message("Message not found")
        }

        guard failedMessage.status == .sendFailure else {
            throw ServiceError.message("Message is not failed")
        }

        failedMessage.status = .sending
        return try await sendPreparedMessage(
            failedMessage,
            failurePrefix: "OpenIM resend message failed"
        )
    }

    func handleComposerInputChanged(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard Date().timeIntervalSince(lastTypingStatusSentAt) >= typingSendThrottleSeconds else {
            return
        }

        lastTypingStatusSentAt = Date()
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                _ = try await self.session.sendTypingStatus(conversationID: self.conversation.id)
            } catch {
                // Typing status is best-effort and should stay silent on failure.
            }
        }
    }

    private func bindRealtimeIfNeeded() {
        guard !hasBoundRealtime else { return }
        hasBoundRealtime = true

        rawChatService.rawMessagePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                guard let self else { return }
                guard self.matchesCurrentConversation(message) else { return }
                self.appendOrReplace(message)
            }
            .store(in: &cancellables)

        session.inputStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.consumeInputStatus(event)
            }
            .store(in: &cancellables)
    }

    private func loadInitialMessagesIfNeeded() async {
        guard !hasCompletedInitialLoad else { return }
        guard !isInitialLoading else { return }
        isInitialLoading = true
        defer { isInitialLoading = false }

        do {
            if let page = try await rawChatService.fetchRawMessagesPage(
                conversationID: conversation.id,
                startClientMsgID: nil,
                count: 50
            ) {
                rawMessages = deduplicatedAndSorted(page.messages)
                oldestClientMsgID = normalizedClientMsgID(for: rawMessages.first)
                reachedBeginning = page.isEnd || page.messages.isEmpty
                canLoadOlderMessages = !reachedBeginning
                rebuildRenderedMessages()
            } else {
                canLoadOlderMessages = false
            }

            await markConversationReadBestEffort(force: true)
        } catch {
            if !error.isUserInitiatedCancellation {
                lastErrorMessage = error.userFacingMessage
            }
        }

        hasCompletedInitialLoad = true
    }

    private func matchesCurrentConversation(_ message: OIMMessageInfo) -> Bool {
        guard let businessConversationID = rawChatService.businessConversationIDSnapshot(for: message) else {
            return false
        }
        return businessConversationID == conversation.id
            || businessConversationID == conversation.openIMConversationID
    }

    private func appendOrReplace(_ message: OIMMessageInfo) {
        let clientMsgID = normalizedClientMsgID(for: message)
        if let existingIndex = rawMessages.firstIndex(where: { normalizedClientMsgID(for: $0) == clientMsgID }) {
            rawMessages[existingIndex] = message
        } else {
            rawMessages.append(message)
        }
        if message.typingElem == nil {
            latestInputStatus = nil
            latestInputStatusClearTask?.cancel()
        }
        rawMessages = deduplicatedAndSorted(rawMessages)
        rebuildRenderedMessages()
        if !message.isSelf(), message.typingElem == nil {
            Task { @MainActor [weak self] in
                await self?.markConversationReadBestEffort()
            }
        }
    }

    private func consumeInputStatus(_ event: OpenIMInputStatusEvent) {
        guard matchesCurrentConversation(rawConversationID: event.conversationID) else { return }
        if let currentUserID = session.currentBusinessUserIDSnapshot(), currentUserID == event.userID {
            return
        }

        latestInputStatus = event
        latestInputStatusClearTask?.cancel()
        latestInputStatusClearTask = Task { [weak self] in
            let delay = UInt64((self?.typingStatusExpireSeconds ?? 4) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self else { return }
                if self.latestInputStatus == event {
                    self.latestInputStatus = nil
                }
            }
        }
    }

    private func sendPreparedMessage(
        _ message: OIMMessageInfo,
        failurePrefix: String,
        onProgress: ((Double) -> Void)? = nil
    ) async throws -> ChatMessage {
        appendOrReplace(message)
        onProgress?(0)

        do {
            let sent = try await rawChatService.sendPreparedRawMessage(
                message,
                conversationID: conversation.id,
                failurePrefix: failurePrefix,
                onProgress: { value in
                    onProgress?(min(1, max(0, Double(value) / 100.0)))
                }
            )
            if let sent {
                appendOrReplace(sent)
            }
            onProgress?(1)
            return renderedMessageSnapshot(from: sent ?? message)
        } catch {
            onProgress?(0)
            message.status = .sendFailure
            appendOrReplace(message)
            if !error.isUserInitiatedCancellation {
                lastErrorMessage = error.userFacingMessage
            }
            throw error
        }
    }

    private func normalizedClientMsgID(for message: OIMMessageInfo?) -> String? {
        guard let message else { return nil }
        let raw = (message.clientMsgID ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !raw.isEmpty {
            return raw
        }
        let fallback = (message.serverMsgID ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return fallback.isEmpty ? nil : fallback
    }

    private func matchesCurrentConversation(rawConversationID: String) -> Bool {
        rawConversationID == conversation.id || rawConversationID == conversation.openIMConversationID
    }

    private func rebuildRenderedMessages() {
        renderedItems = rawMessages.map {
            OpenIMMessageRenderMapper.map(
                $0,
                conversation: conversation,
                rawChatService: rawChatService
            )
        }
        renderedMessages = renderedItems.map(\.renderedMessage)
    }

    private func renderedMessageSnapshot(from message: OIMMessageInfo) -> ChatMessage {
        let messageID = normalizedClientMsgID(for: message)
        if let messageID,
           let rendered = renderedItems.first(where: { $0.messageID == messageID })?.renderedMessage {
            return rendered
        }
        return OpenIMMessageRenderMapper.map(
            message,
            conversation: conversation,
            rawChatService: rawChatService
        ).renderedMessage
    }

    private func deduplicatedAndSorted(_ messages: [OIMMessageInfo]) -> [OIMMessageInfo] {
        let sorted = messages.sorted(by: Self.messageSort(lhs:rhs:))
        var seen = Set<String>()
        var result: [OIMMessageInfo] = []
        for message in sorted {
            let key = normalizedClientMsgID(for: message) ?? UUID().uuidString
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(message)
        }
        return result
    }

    private static func messageSort(lhs: OIMMessageInfo, rhs: OIMMessageInfo) -> Bool {
        let lhsTime = Int(lhs.sendTime > 0 ? lhs.sendTime : lhs.createTime)
        let rhsTime = Int(rhs.sendTime > 0 ? rhs.sendTime : rhs.createTime)
        if lhsTime != rhsTime {
            return lhsTime < rhsTime
        }
        return (lhs.clientMsgID ?? "") < (rhs.clientMsgID ?? "")
    }

    private func resetState() {
        rawMessages = []
        renderedItems = []
        renderedMessages = []
        latestInputStatus = nil
        isInitialLoading = false
        isLoadingOlder = false
        hasCompletedInitialLoad = false
        canLoadOlderMessages = false
        lastErrorMessage = nil
        lastOlderLoadAt = .distantPast
        oldestClientMsgID = nil
        reachedBeginning = false
        latestInputStatusClearTask?.cancel()
        latestInputStatusClearTask = nil
        lastTypingStatusSentAt = .distantPast
        lastReadMarkAt = .distantPast
    }

    private func ensureActiveConversationRegistration() {
        guard !hasRegisteredActiveConversation else { return }
        chatStore.activateConversation(conversation)
        hasRegisteredActiveConversation = true
    }

    private func releaseActiveConversationRegistration() {
        guard hasRegisteredActiveConversation else { return }
        chatStore.deactivateConversation(conversation)
        hasRegisteredActiveConversation = false
    }

    private func markConversationReadBestEffort(force: Bool = false) async {
        guard force || Date().timeIntervalSince(lastReadMarkAt) >= readMarkThrottleSeconds else {
            #if DEBUG
            print("[RaverOpenIMChatController] mark read throttled conversation=\(conversation.id)")
            #endif
            return
        }

        lastReadMarkAt = Date()
        do {
            _ = try await rawChatService.markConversationRead(conversationID: conversation.id)
            #if DEBUG
            print("[RaverOpenIMChatController] mark read success conversation=\(conversation.id) force=\(force ? 1 : 0)")
            #endif
        } catch {
            if !error.isUserInitiatedCancellation {
                #if DEBUG
                print("[RaverOpenIMChatController] mark read failed conversation=\(conversation.id) error=\(error.localizedDescription)")
                #endif
                // Read sync is best-effort for the open conversation; keep failures silent.
            }
        }
    }
}
#else
@MainActor
final class RaverOpenIMChatController: ObservableObject {
    @Published private(set) var rawMessages: [Any] = []
    @Published private(set) var renderedMessages: [ChatMessage] = []
    @Published private(set) var latestInputStatus: OpenIMInputStatusEvent?
    @Published private(set) var isInitialLoading = false
    @Published private(set) var isLoadingOlder = false
    @Published private(set) var hasCompletedInitialLoad = false
    @Published private(set) var canLoadOlderMessages = false
    @Published private(set) var lastErrorMessage: String?

    private var conversation: Conversation
    private var service: SocialService

    init(
        conversation: Conversation,
        service: SocialService,
        session: OpenIMSession
    ) {
        self.conversation = conversation
        self.service = service
    }

    func start() {}

    func updateContext(conversation: Conversation, service: SocialService) {
        self.conversation = conversation
        self.service = service
        renderedMessages = []
        latestInputStatus = nil
        isInitialLoading = false
        isLoadingOlder = false
        hasCompletedInitialLoad = false
        canLoadOlderMessages = false
        lastErrorMessage = "OpenIMSDK unavailable"
    }

    func loadOlderMessagesIfNeeded() async {}

    @discardableResult
    func sendTextMessage(_ text: String) async throws -> ChatMessage {
        throw ServiceError.message("OpenIMSDK unavailable")
    }

    @discardableResult
    func sendImageMessage(
        fileURL: URL,
        onProgress: ((Double) -> Void)? = nil
    ) async throws -> ChatMessage {
        throw ServiceError.message("OpenIMSDK unavailable")
    }

    @discardableResult
    func sendVideoMessage(
        fileURL: URL,
        onProgress: ((Double) -> Void)? = nil
    ) async throws -> ChatMessage {
        throw ServiceError.message("OpenIMSDK unavailable")
    }

    @discardableResult
    func resendFailedMessage(messageID: String) async throws -> ChatMessage {
        throw ServiceError.message("OpenIMSDK unavailable")
    }

    func handleComposerInputChanged(_ text: String) {}
}
#endif
