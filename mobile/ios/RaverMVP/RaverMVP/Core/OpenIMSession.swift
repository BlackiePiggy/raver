import Foundation
import Combine
import OSLog
import AVFoundation
import UniformTypeIdentifiers
import UIKit

#if canImport(OpenIMSDK)
import OpenIMSDK
#endif

enum OpenIMConnectionState: Equatable {
    case idle
    case disabled
    case unavailable
    case initializing
    case connecting
    case connected(userID: String)
    case tokenExpired
    case kickedOffline
    case failed(String)

    var isConnected: Bool {
        if case .connected = self {
            return true
        }
        return false
    }
}

struct OpenIMInputStatusEvent: Equatable {
    let conversationID: String
    let userID: String
    let platformIDs: [Int]
    let receivedAt: Date
}

struct OpenIMMessageHistoryPage {
    let messages: [ChatMessage]
    let isEnd: Bool
}

#if canImport(OpenIMSDK)
struct OpenIMRawMessagePage {
    let messages: [OIMMessageInfo]
    let isEnd: Bool
}
#endif

@MainActor
final class OpenIMSession {
    static let shared = OpenIMSession()
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.raver.mvp",
        category: "OpenIMSession"
    )

    var onStateChange: ((OpenIMConnectionState) -> Void)?
    private let messageSubject = PassthroughSubject<ChatMessage, Never>()
    #if canImport(OpenIMSDK)
    private let rawMessageSubject = PassthroughSubject<OIMMessageInfo, Never>()
    #endif
    private let conversationSubject = PassthroughSubject<[Conversation], Never>()
    private let totalUnreadSubject = PassthroughSubject<Int, Never>()
    private let inputStatusSubject = PassthroughSubject<OpenIMInputStatusEvent, Never>()

    // Compatibility outlet retained while store/service layers still expect `ChatMessage`.
    // New chat flows should subscribe to `rawMessagePublisher` instead.
    var messagePublisher: AnyPublisher<ChatMessage, Never> {
        messageSubject.eraseToAnyPublisher()
    }

    #if canImport(OpenIMSDK)
    // Primary message stream for demo-style chat flows.
    var rawMessagePublisher: AnyPublisher<OIMMessageInfo, Never> {
        rawMessageSubject.eraseToAnyPublisher()
    }
    #endif

    var conversationPublisher: AnyPublisher<[Conversation], Never> {
        conversationSubject.eraseToAnyPublisher()
    }

    var totalUnreadPublisher: AnyPublisher<Int, Never> {
        totalUnreadSubject.eraseToAnyPublisher()
    }

    var inputStatusPublisher: AnyPublisher<OpenIMInputStatusEvent, Never> {
        inputStatusSubject.eraseToAnyPublisher()
    }

    private(set) var state: OpenIMConnectionState = .idle {
        didSet {
            onStateChange?(state)
        }
    }

    private var currentBootstrap: OpenIMBootstrap?
    private var hasInitializedSDK = false
    private var hasRegisteredRealtimeListeners = false
    private var currentLoginUserID: String?
    private var currentToken: String?
    private var loginTask: Task<Void, Error>?
    private var loginAttemptSequence: Int = 0

    private init() {}

    private func setStateIfNeeded(_ nextState: OpenIMConnectionState) {
        if state != nextState {
            state = nextState
        }
    }

    func connectionStateSnapshot() -> OpenIMConnectionState {
        state
    }

    func currentBusinessUserIDSnapshot() -> String? {
        #if canImport(OpenIMSDK)
        decodeRaverID(fromOpenIMID: currentLoginUserID, expectedPrefix: "u")
            ?? currentLoginUserID
        #else
        currentLoginUserID
        #endif
    }

    var isSDKAvailable: Bool {
        #if canImport(OpenIMSDK)
        return true
        #else
        return false
        #endif
    }

    /// Recover runtime connection state when app returns foreground.
    /// This avoids unnecessary re-login when SDK is already logging/logged.
    func recoverSessionAfterAppBecameActive() async -> Bool {
        #if canImport(OpenIMSDK)
        guard hasInitializedSDK else { return false }

        let snapshot = sdkLoginStatusSnapshot()
        let expectedUserID = currentBootstrap?.userID ?? currentLoginUserID

        switch snapshot.status {
        case .logged:
            guard let sdkUserID = snapshot.userID else { return false }
            if let expectedUserID, sdkUserID != expectedUserID {
                debug("recover-on-active mismatch sdkUser=\(sdkUserID) expected=\(expectedUserID)")
                return false
            }

            currentLoginUserID = sdkUserID
            registerRealtimeListenersIfNeeded(force: true)
            setStateIfNeeded(.connected(userID: sdkUserID))
            debug("recover-on-active promoted sdk logged user=\(sdkUserID)")
            return true

        case .logging:
            setStateIfNeeded(.connecting)
            debug("recover-on-active sdk logging, keep connecting")
            return true

        case .logout:
            debug("recover-on-active sdk logout")
            return false

        @unknown default:
            return false
        }
        #else
        return false
        #endif
    }

    func reset() {
        #if canImport(OpenIMSDK)
        if hasInitializedSDK {
            OIMManager.manager.unInitSDK()
        }
        #endif

        hasInitializedSDK = false
        hasRegisteredRealtimeListeners = false
        currentBootstrap = nil
        currentLoginUserID = nil
        currentToken = nil
        loginTask?.cancel()
        loginTask = nil
        state = .idle
    }

    func sync(with bootstrap: OpenIMBootstrap?) async {
        guard let bootstrap else {
            reset()
            return
        }

        guard bootstrap.enabled, let token = bootstrap.token, !token.isEmpty else {
            if hasInitializedSDK {
                reset()
            }
            currentBootstrap = bootstrap
            state = .disabled
            return
        }

        #if canImport(OpenIMSDK)
        do {
            try initializeIfNeeded(with: bootstrap)
            try await loginIfNeeded(with: bootstrap, token: token)
        } catch {
            state = .failed(error.localizedDescription)
        }
        #else
        state = .unavailable
        #endif
    }

    func fetchConversations(type: ConversationType) async throws -> [Conversation]? {
        #if canImport(OpenIMSDK)
        await waitForConnectionIfNeeded()
        guard hasInitializedSDK, state.isConnected else {
            debug("fetchConversations skipped: initialized=\(hasInitializedSDK) state=\(state)")
            return nil
        }

        let allConversations = try await getAllConversations()
        return allConversations.compactMap { toConversation($0, expectedType: type) }
        #else
        return nil
        #endif
    }

    func markConversationRead(conversationID: String) async throws -> Bool {
        #if canImport(OpenIMSDK)
        await waitForConnectionIfNeeded()
        guard hasInitializedSDK, state.isConnected else {
            debug("markConversationRead skipped: initialized=\(hasInitializedSDK) state=\(state) conversationID=\(conversationID)")
            return false
        }

        guard let openIMConversationID = try await resolveOpenIMConversationID(for: conversationID) else {
            debug("markConversationRead missing OpenIM conversationID for businessID=\(conversationID)")
            return false
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            OIMManager.manager.markConversationMessage(
                asRead: openIMConversationID,
                onSuccess: { _ in
                    continuation.resume()
                },
                onFailure: { code, message in
                    let resolved = (message ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    let text = resolved.isEmpty ? "OpenIM mark read failed (\(code))" : resolved
                    continuation.resume(throwing: ServiceError.message(text))
                }
            )
        }
        return true
        #else
        return false
        #endif
    }

    // MARK: - ChatMessage Compatibility API

    // Legacy compatibility wrapper around the raw history pipeline.
    // New demo-style chat flows should prefer `fetchRawMessagesPage(...)`.
    func fetchMessages(conversationID: String) async throws -> [ChatMessage]? {
        let page = try await fetchMessagesPage(
            conversationID: conversationID,
            startClientMsgID: nil,
            count: 50
        )
        return page?.messages
    }

    // Legacy compatibility wrapper around the raw history pipeline.
    // Kept so compatibility services can continue returning `ChatMessage`.
    func fetchMessagesPage(
        conversationID: String,
        startClientMsgID: String?,
        count: Int
    ) async throws -> OpenIMMessageHistoryPage? {
        #if canImport(OpenIMSDK)
        guard let page = try await fetchRawMessagesPage(
            conversationID: conversationID,
            startClientMsgID: startClientMsgID,
            count: count
        ) else {
            return nil
        }

        let openIMConversationID = try await resolveOpenIMConversationID(for: conversationID) ?? conversationID
        let mapped = page.messages.map { chatMessageSnapshot(from: $0, conversationID: openIMConversationID) }
        return OpenIMMessageHistoryPage(messages: mapped, isEnd: page.isEnd)
        #else
        return nil
        #endif
    }

    #if canImport(OpenIMSDK)
    // MARK: - Raw Message API

    func fetchRawMessages(conversationID: String) async throws -> [OIMMessageInfo]? {
        let page = try await fetchRawMessagesPage(
            conversationID: conversationID,
            startClientMsgID: nil,
            count: 50
        )
        return page?.messages
    }

    func fetchRawMessagesPage(
        conversationID: String,
        startClientMsgID: String?,
        count: Int
    ) async throws -> OpenIMRawMessagePage? {
        await waitForConnectionIfNeeded()
        guard hasInitializedSDK, state.isConnected else {
            debug("fetchRawMessages skipped: initialized=\(hasInitializedSDK) state=\(state) conversationID=\(conversationID)")
            return nil
        }

        guard let openIMConversationID = try await resolveOpenIMConversationID(for: conversationID) else {
            debug("fetchRawMessages missing OpenIM conversationID for businessID=\(conversationID)")
            return nil
        }

        let options = OIMGetAdvancedHistoryMessageListParam()
        options.conversationID = openIMConversationID
        options.viewType = .history
        options.count = max(1, count)
        if let startClientMsgID = normalizedText(startClientMsgID) {
            options.startClientMsgID = startClientMsgID
        }

        let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<OIMGetAdvancedHistoryMessageListInfo, Error>) in
            OIMManager.manager.getAdvancedHistoryMessageList(
                options,
                onSuccess: { info in
                    if let info {
                        continuation.resume(returning: info)
                    } else {
                        continuation.resume(returning: OIMGetAdvancedHistoryMessageListInfo())
                    }
                },
                onFailure: { code, message in
                    let resolved = (message ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    let text = resolved.isEmpty ? "OpenIM fetch raw messages failed (\(code))" : resolved
                    continuation.resume(throwing: ServiceError.message(text))
                }
            )
        }

        let sorted = result.messageList.sorted { lhs, rhs in
            let lhsTime = Int(lhs.sendTime > 0 ? lhs.sendTime : lhs.createTime)
            let rhsTime = Int(rhs.sendTime > 0 ? rhs.sendTime : rhs.createTime)
            if lhsTime != rhsTime {
                return lhsTime < rhsTime
            }
            return (normalizedText(lhs.clientMsgID) ?? "") < (normalizedText(rhs.clientMsgID) ?? "")
        }
        return OpenIMRawMessagePage(messages: sorted, isEnd: result.isEnd)
    }
    #endif

    // Legacy compatibility wrapper around raw create/send/replace flow.
    // New demo-style chat flows should create/send raw messages directly.
    func sendTextMessage(conversationID: String, content: String) async throws -> ChatMessage? {
        #if canImport(OpenIMSDK)
        let prepared = createRawTextMessage(content: content)
        guard let sent = try await sendPreparedRawMessage(
            prepared,
            conversationID: conversationID,
            failurePrefix: "OpenIM send text message failed"
        ) else {
            return nil
        }
        let openIMConversationID = try await resolveOpenIMConversationID(for: conversationID) ?? conversationID
        return chatMessageSnapshot(from: sent, conversationID: openIMConversationID)
        #else
        return nil
        #endif
    }

    #if canImport(OpenIMSDK)
    func createRawTextMessage(content: String) -> OIMMessageInfo {
        let message = OIMMessageInfo.createTextMessage(content)
        message.status = .sending
        return message
    }

    func createRawImageMessage(fileURL: URL) throws -> OIMMessageInfo {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw ServiceError.message(L("图片文件不存在", "Image file not found"))
        }

        let message = OIMMessageInfo.createImageMessage(fromFullPath: fileURL.path)
        message.status = .sending
        return message
    }

    func createRawVideoMessage(fileURL: URL) throws -> OIMMessageInfo {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw ServiceError.message(L("视频文件不存在", "Video file not found"))
        }

        let duration = resolvedVideoDurationSeconds(fileURL: fileURL)
        let snapshotURL = try createVideoSnapshotFile(videoURL: fileURL)
        let mimeType = resolvedMimeType(for: fileURL, fallback: "video/mp4")
        let message = OIMMessageInfo.createVideoMessage(
            fromFullPath: fileURL.path,
            videoType: mimeType,
            duration: duration,
            snapshotPath: snapshotURL.path
        )
        message.status = .sending
        return message
    }

    func sendPreparedRawMessage(
        _ message: OIMMessageInfo,
        conversationID: String,
        failurePrefix: String,
        onProgress: ((Int) -> Void)? = nil
    ) async throws -> OIMMessageInfo? {
        guard let target = try await resolveSendTarget(for: conversationID, actionName: "sendPreparedRawMessage") else {
            return nil
        }
        return try await sendPreparedMessage(
            message,
            to: target,
            failurePrefix: failurePrefix,
            onProgress: onProgress
        )
    }
    #endif

    // Legacy compatibility wrapper around raw create/send/replace flow.
    // New demo-style chat flows should create/send raw messages directly.
    func sendImageMessage(
        conversationID: String,
        fileURL: URL,
        onProgress: ((Int) -> Void)? = nil
    ) async throws -> ChatMessage? {
        #if canImport(OpenIMSDK)
        let prepared = try createRawImageMessage(fileURL: fileURL)
        guard let sent = try await sendPreparedRawMessage(
            prepared,
            conversationID: conversationID,
            failurePrefix: "OpenIM send image message failed",
            onProgress: onProgress
        ) else {
            return nil
        }
        let openIMConversationID = try await resolveOpenIMConversationID(for: conversationID) ?? conversationID
        return chatMessageSnapshot(from: sent, conversationID: openIMConversationID)
        #else
        return nil
        #endif
    }

    // Legacy compatibility wrapper around raw create/send/replace flow.
    // New demo-style chat flows should create/send raw messages directly.
    func sendVideoMessage(
        conversationID: String,
        fileURL: URL,
        onProgress: ((Int) -> Void)? = nil
    ) async throws -> ChatMessage? {
        #if canImport(OpenIMSDK)
        let prepared = try createRawVideoMessage(fileURL: fileURL)
        guard let sent = try await sendPreparedRawMessage(
            prepared,
            conversationID: conversationID,
            failurePrefix: "OpenIM send video message failed",
            onProgress: onProgress
        ) else {
            return nil
        }
        let openIMConversationID = try await resolveOpenIMConversationID(for: conversationID) ?? conversationID
        return chatMessageSnapshot(from: sent, conversationID: openIMConversationID)
        #else
        return nil
        #endif
    }

    func sendTypingStatus(conversationID: String, msgTip: String = "yes") async throws -> Bool {
        #if canImport(OpenIMSDK)
        await waitForConnectionIfNeeded()
        guard hasInitializedSDK, state.isConnected else {
            debug("sendTypingStatus skipped: initialized=\(hasInitializedSDK) state=\(state) conversationID=\(conversationID)")
            return false
        }

        guard let openIMConversationID = try await resolveOpenIMConversationID(for: conversationID) else {
            debug("sendTypingStatus missing OpenIM conversationID for businessID=\(conversationID)")
            return false
        }

        let conversation = try await getConversation(byConversationID: openIMConversationID)
        guard let recvID = normalizedText(conversation.userID), normalizedText(conversation.groupID) == nil else {
            return false
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            OIMManager.manager.typingStatusUpdate(
                recvID,
                msgTip: msgTip,
                onSuccess: { _ in
                    continuation.resume()
                },
                onFailure: { code, message in
                    let resolved = (message ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    let text = resolved.isEmpty ? "OpenIM typing status failed (\(code))" : resolved
                    continuation.resume(throwing: ServiceError.message(text))
                }
            )
        }
        return true
        #else
        return false
        #endif
    }

    func fetchTotalUnreadCount() async throws -> Int? {
        #if canImport(OpenIMSDK)
        await waitForConnectionIfNeeded()
        guard hasInitializedSDK, state.isConnected else {
            debug("fetchTotalUnreadCount skipped: initialized=\(hasInitializedSDK) state=\(state)")
            return nil
        }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int, Error>) in
            OIMManager.manager.getTotalUnreadMsgCountWith(
                onSuccess: { count in
                    continuation.resume(returning: max(0, count))
                },
                onFailure: { code, message in
                    let resolved = (message ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    let text = resolved.isEmpty ? "OpenIM unread count failed (\(code))" : resolved
                    continuation.resume(throwing: ServiceError.message(text))
                }
            )
        }
        #else
        return nil
        #endif
    }

    func setConversationMuted(conversationID: String, muted: Bool) async throws -> Bool {
        #if canImport(OpenIMSDK)
        await waitForConnectionIfNeeded()
        guard hasInitializedSDK, state.isConnected else {
            debug("setConversationMuted skipped: initialized=\(hasInitializedSDK) state=\(state) conversationID=\(conversationID)")
            return false
        }

        guard let openIMConversationID = try await resolveOpenIMConversationID(for: conversationID) else {
            debug("setConversationMuted missing OpenIM conversationID for businessID=\(conversationID)")
            return false
        }

        let status: OIMReceiveMessageOpt = muted ? .notNotify : .receive
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            OIMManager.manager.setConversationRecvMessageOpt(
                openIMConversationID,
                status: status,
                onSuccess: { _ in
                    continuation.resume()
                },
                onFailure: { code, message in
                    let resolved = (message ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    let text = resolved.isEmpty ? "OpenIM mute conversation failed (\(code))" : resolved
                    continuation.resume(throwing: ServiceError.message(text))
                }
            )
        }
        return true
        #else
        return false
        #endif
    }

    func clearConversationHistory(conversationID: String) async throws -> Bool {
        #if canImport(OpenIMSDK)
        await waitForConnectionIfNeeded()
        guard hasInitializedSDK, state.isConnected else {
            debug("clearConversationHistory skipped: initialized=\(hasInitializedSDK) state=\(state) conversationID=\(conversationID)")
            return false
        }

        guard let openIMConversationID = try await resolveOpenIMConversationID(for: conversationID) else {
            debug("clearConversationHistory missing OpenIM conversationID for businessID=\(conversationID)")
            return false
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            OIMManager.manager.clearConversationAndDeleteAllMsg(
                openIMConversationID,
                onSuccess: { _ in
                    continuation.resume()
                },
                onFailure: { code, message in
                    let resolved = (message ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    let text = resolved.isEmpty ? "OpenIM clear conversation failed (\(code))" : resolved
                    continuation.resume(throwing: ServiceError.message(text))
                }
            )
        }
        return true
        #else
        return false
        #endif
    }

    #if canImport(OpenIMSDK)
    private struct OpenIMSendTarget {
        let openIMConversationID: String
        let recvID: String?
        let groupID: String?
    }

    private func resolveSendTarget(for conversationID: String, actionName: String) async throws -> OpenIMSendTarget? {
        await waitForConnectionIfNeeded()
        guard hasInitializedSDK, state.isConnected else {
            debug("\(actionName) skipped: initialized=\(hasInitializedSDK) state=\(state) conversationID=\(conversationID)")
            return nil
        }

        guard let openIMConversationID = try await resolveOpenIMConversationID(for: conversationID) else {
            debug("\(actionName) missing OpenIM conversationID for businessID=\(conversationID)")
            return nil
        }

        let conversation = try await getConversation(byConversationID: openIMConversationID)
        let recvID = normalizedText(conversation.userID)
        let groupID = normalizedText(conversation.groupID)
        if recvID == nil, groupID == nil {
            throw ServiceError.message("OpenIM send message failed: target is empty")
        }

        return OpenIMSendTarget(openIMConversationID: openIMConversationID, recvID: recvID, groupID: groupID)
    }

    private func sendPreparedMessage(
        _ message: OIMMessageInfo,
        to target: OpenIMSendTarget,
        failurePrefix: String,
        onProgress: ((Int) -> Void)? = nil
    ) async throws -> OIMMessageInfo {
        debug(
            "sendPreparedMessage start openIMConversation=\(target.openIMConversationID) clientMsgID=\(normalizedText(message.clientMsgID) ?? "-") recvID=\(target.recvID ?? "-") groupID=\(target.groupID ?? "-") content=\(debugSnippet(previewText(from: message)))"
        )
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<OIMMessageInfo, Error>) in
            OIMManager.manager.sendMessage(
                message,
                recvID: target.recvID,
                groupID: target.groupID,
                isOnlineOnly: false,
                offlinePushInfo: nil,
                onSuccess: { sentMessage in
                    if let sentMessage {
                        self.debug(
                            "sendPreparedMessage success openIMConversation=\(target.openIMConversationID) requestClientMsgID=\(self.normalizedText(message.clientMsgID) ?? "-") responseClientMsgID=\(self.normalizedText(sentMessage.clientMsgID) ?? "-") serverMsgID=\(self.normalizedText(sentMessage.serverMsgID) ?? "-") status=\(Int(sentMessage.status.rawValue)) sendTime=\(sentMessage.sendTime)"
                        )
                        continuation.resume(returning: sentMessage)
                    } else {
                        self.debug(
                            "sendPreparedMessage success openIMConversation=\(target.openIMConversationID) requestClientMsgID=\(self.normalizedText(message.clientMsgID) ?? "-") response=nil fallback=request"
                        )
                        continuation.resume(returning: message)
                    }
                },
                onProgress: { progress in
                    onProgress?(max(0, min(100, progress)))
                },
                onFailure: { code, failureMessage in
                    let resolved = (failureMessage ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    let text = resolved.isEmpty ? "\(failurePrefix) (\(code))" : resolved
                    self.debug(
                        "sendPreparedMessage failure openIMConversation=\(target.openIMConversationID) requestClientMsgID=\(self.normalizedText(message.clientMsgID) ?? "-") code=\(code) text=\(text)"
                    )
                    continuation.resume(throwing: ServiceError.message(text))
                }
            )
        }
    }

    private func resolvedMimeType(for fileURL: URL, fallback: String) -> String {
        let ext = fileURL.pathExtension.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let type = UTType(filenameExtension: ext),
           let mimeType = type.preferredMIMEType,
           !mimeType.isEmpty {
            return mimeType
        }
        return fallback
    }

    private func resolvedVideoDurationSeconds(fileURL: URL) -> Int {
        let asset = AVURLAsset(url: fileURL)
        let seconds = CMTimeGetSeconds(asset.duration)
        guard seconds.isFinite, seconds > 0 else {
            return 1
        }
        return max(1, Int(ceil(seconds)))
    }

    private func createVideoSnapshotFile(videoURL: URL) throws -> URL {
        let asset = AVURLAsset(url: videoURL)
        let durationSeconds = CMTimeGetSeconds(asset.duration)
        let seekSeconds: Double
        if durationSeconds.isFinite, durationSeconds > 0 {
            seekSeconds = min(0.8, max(0, durationSeconds / 3))
        } else {
            seekSeconds = 0
        }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let frame = try generator.copyCGImage(
            at: CMTime(seconds: seekSeconds, preferredTimescale: 600),
            actualTime: nil
        )
        let image = UIImage(cgImage: frame)
        guard let imageData = image.jpegData(compressionQuality: 0.78) else {
            throw ServiceError.message(L("生成视频封面失败", "Failed to generate video snapshot"))
        }

        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("openim-video-snapshots", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let snapshotURL = folder.appendingPathComponent("snapshot-\(UUID().uuidString).jpg")
        try imageData.write(to: snapshotURL, options: .atomic)
        return snapshotURL
    }

    private func waitForConnectionIfNeeded(timeoutMs: UInt64 = 5000) async {
        guard hasInitializedSDK else { return }
        switch state {
        case .connecting, .initializing:
            break
        default:
            return
        }

        let stepNs: UInt64 = 150_000_000
        var waitedNs: UInt64 = 0

        while waitedNs < timeoutMs * 1_000_000 {
            if state.isConnected { return }
            switch state {
            case .failed, .disabled, .unavailable, .tokenExpired, .kickedOffline:
                return
            case .idle, .initializing, .connecting, .connected:
                break
            }
            try? await Task.sleep(nanoseconds: stepNs)
            waitedNs += stepNs
        }
    }

    private func getAllConversations() async throws -> [OIMConversationInfo] {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[OIMConversationInfo], Error>) in
            OIMManager.manager.getAllConversationListWith(
                onSuccess: { list in
                    continuation.resume(returning: list ?? [])
                },
                onFailure: { code, message in
                    let resolved = (message ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    let text = resolved.isEmpty ? "OpenIM fetch conversations failed (\(code))" : resolved
                    continuation.resume(throwing: ServiceError.message(text))
                }
            )
        }
    }

    private func getConversation(byConversationID conversationID: String) async throws -> OIMConversationInfo {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<OIMConversationInfo, Error>) in
            OIMManager.manager.getMultipleConversation(
                [conversationID],
                onSuccess: { list in
                    if let conversation = list?.first {
                        continuation.resume(returning: conversation)
                    } else {
                        continuation.resume(throwing: ServiceError.message("OpenIM conversation not found"))
                    }
                },
                onFailure: { code, message in
                    let resolved = (message ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    let text = resolved.isEmpty ? "OpenIM fetch conversation failed (\(code))" : resolved
                    continuation.resume(throwing: ServiceError.message(text))
                }
            )
        }
    }

    private func toConversation(_ item: OIMConversationInfo, expectedType: ConversationType) -> Conversation? {
        guard let mappedType = mapConversationType(item.conversationType),
              mappedType == expectedType else {
            return nil
        }

        let openIMConversationID = normalizedText(item.conversationID)
            ?? normalizedText(item.userID)
            ?? normalizedText(item.groupID)
            ?? UUID().uuidString
        let businessConversationID = resolveBusinessConversationID(item: item, mappedType: mappedType) ?? openIMConversationID
        let title = resolveConversationTitle(item: item, mappedType: mappedType)
        let lastMessage = previewText(from: item.latestMsg)
        let lastMessageSenderID = normalizedText(item.latestMsg?.senderNickname)
            ?? decodeRaverID(fromOpenIMID: normalizedText(item.latestMsg?.sendID), expectedPrefix: "u")
            ?? normalizedText(item.latestMsg?.sendID)
        let unreadCount = max(0, item.unreadCount)
        let updatedAt = dateFromOpenIMTimestamp(item.latestMsgSendTime)
        let peer = makePeer(item: item, mappedType: mappedType)

        return Conversation(
            id: businessConversationID,
            type: mappedType,
            title: title,
            avatarURL: normalizedText(item.faceURL),
            openIMConversationID: openIMConversationID,
            lastMessage: lastMessage,
            lastMessageSenderID: lastMessageSenderID,
            unreadCount: unreadCount,
            updatedAt: updatedAt,
            peer: peer
        )
    }

    private func resolveBusinessConversationID(item: OIMConversationInfo, mappedType: ConversationType) -> String? {
        switch mappedType {
        case .direct:
            return decodeRaverID(fromOpenIMID: normalizedText(item.userID), expectedPrefix: "u")
                ?? normalizedText(item.userID)
        case .group:
            return decodeRaverID(fromOpenIMID: normalizedText(item.groupID), expectedPrefix: "g")
                ?? normalizedText(item.groupID)
        }
    }

    private func mapConversationType(_ type: OIMConversationType) -> ConversationType? {
        switch Int(type.rawValue) {
        case 1:
            return .direct
        case 2, 3:
            return .group
        default:
            return nil
        }
    }

    private func resolveConversationTitle(item: OIMConversationInfo, mappedType: ConversationType) -> String {
        if let showName = normalizedText(item.showName) {
            return showName
        }

        switch mappedType {
        case .direct:
            return decodeRaverID(fromOpenIMID: normalizedText(item.userID), expectedPrefix: "u")
                ?? normalizedText(item.userID)
                ?? L("私信", "Direct")
        case .group:
            return normalizedText(item.groupID) ?? L("小队", "Squad")
        }
    }

    private func makePeer(item: OIMConversationInfo, mappedType: ConversationType) -> UserSummary? {
        guard mappedType == .direct,
              let userID = normalizedText(item.userID) else {
            return nil
        }

        let resolvedUserID = decodeRaverID(fromOpenIMID: userID, expectedPrefix: "u") ?? userID
        return UserSummary(
            id: resolvedUserID,
            username: resolvedUserID,
            displayName: normalizedText(item.showName) ?? resolvedUserID,
            avatarURL: normalizedText(item.faceURL),
            isFollowing: false
        )
    }

    private func toChatMessage(_ message: OIMMessageInfo, conversationID: String) -> ChatMessage {
        let senderID = decodeRaverID(fromOpenIMID: normalizedText(message.sendID), expectedPrefix: "u")
            ?? normalizedText(message.sendID)
            ?? "unknown_sender"
        let senderName = normalizedText(message.senderNickname) ?? senderID

        let sender = UserSummary(
            id: senderID,
            username: senderID,
            displayName: senderName,
            avatarURL: normalizedText(message.senderFaceUrl),
            isFollowing: false
        )

        return ChatMessage(
            id: normalizedText(message.clientMsgID)
                ?? normalizedText(message.serverMsgID)
                ?? UUID().uuidString,
            conversationID: conversationID,
            sender: sender,
            content: previewText(from: message),
            createdAt: dateFromOpenIMTimestamp(Int(message.sendTime > 0 ? message.sendTime : message.createTime)),
            isMine: message.isSelf(),
            kind: messageKind(from: message),
            media: messageMediaPayload(from: message),
            deliveryStatus: messageDeliveryStatus(from: message)
        )
    }

    private func messageKind(from message: OIMMessageInfo) -> ChatMessageKind {
        if normalizedText(message.textElem?.content) != nil || normalizedText(message.advancedTextElem?.text) != nil {
            return .text
        }
        if message.typingElem != nil {
            return .typing
        }
        if message.pictureElem != nil {
            return .image
        }
        if message.videoElem != nil {
            return .video
        }
        if message.soundElem != nil {
            return .voice
        }
        if message.fileElem != nil {
            return .file
        }
        if message.faceElem != nil {
            return .emoji
        }
        if message.locationElem != nil {
            return .location
        }
        if message.cardElem != nil {
            return .card
        }
        if message.notificationElem != nil {
            return .system
        }
        if message.customElem != nil {
            return .custom
        }
        return .unknown
    }

    private func messageDeliveryStatus(from message: OIMMessageInfo) -> ChatMessageDeliveryStatus {
        if message.status == .sendFailure {
            return .failed
        }

        if message.isSelf() {
            return .sent
        }

        switch message.status {
        case .sending:
            return .sending
        default:
            return .sent
        }
    }

    private func messageMediaPayload(from message: OIMMessageInfo) -> ChatMessageMediaPayload? {
        if let picture = message.pictureElem {
            let mediaURL = resolvedMediaURL(remote: picture.sourcePicture?.url, localPath: picture.sourcePath)
                ?? resolvedMediaURL(remote: picture.bigPicture?.url, localPath: picture.sourcePath)
                ?? resolvedMediaURL(remote: picture.snapshotPicture?.url, localPath: picture.sourcePath)
            let thumbnailURL = resolvedMediaURL(remote: picture.snapshotPicture?.url, localPath: picture.sourcePath)
                ?? mediaURL

            return ChatMessageMediaPayload(
                mediaURL: mediaURL,
                thumbnailURL: thumbnailURL,
                width: resolvedDimension(primary: picture.sourcePicture?.width, fallback: picture.snapshotPicture?.width),
                height: resolvedDimension(primary: picture.sourcePicture?.height, fallback: picture.snapshotPicture?.height)
            )
        }

        if let video = message.videoElem {
            return ChatMessageMediaPayload(
                mediaURL: resolvedMediaURL(remote: video.videoUrl, localPath: video.videoPath),
                thumbnailURL: resolvedMediaURL(remote: video.snapshotUrl, localPath: video.snapshotPath),
                width: video.snapshotWidth > 0 ? Double(video.snapshotWidth) : nil,
                height: video.snapshotHeight > 0 ? Double(video.snapshotHeight) : nil,
                durationSeconds: video.duration > 0 ? video.duration : nil,
                fileSizeBytes: video.videoSize > 0 ? video.videoSize : nil
            )
        }

        if let sound = message.soundElem {
            return ChatMessageMediaPayload(
                mediaURL: resolvedMediaURL(remote: sound.sourceUrl, localPath: sound.soundPath),
                durationSeconds: sound.duration > 0 ? sound.duration : nil,
                fileSizeBytes: sound.dataSize > 0 ? sound.dataSize : nil
            )
        }

        if let file = message.fileElem {
            return ChatMessageMediaPayload(
                mediaURL: resolvedMediaURL(remote: file.sourceUrl, localPath: file.filePath),
                fileName: normalizedText(file.fileName),
                fileSizeBytes: file.fileSize > 0 ? file.fileSize : nil
            )
        }

        return nil
    }

    private func resolvedDimension(primary: CGFloat?, fallback: CGFloat?) -> Double? {
        if let primary, primary > 0 {
            return Double(primary)
        }
        if let fallback, fallback > 0 {
            return Double(fallback)
        }
        return nil
    }

    private func resolvedMediaURL(remote: String?, localPath: String?) -> String? {
        if let remote = normalizedText(remote) {
            return remote
        }

        guard let localPath = normalizedText(localPath) else {
            return nil
        }

        if localPath.hasPrefix("file://") {
            return localPath
        }

        if localPath.hasPrefix("/") {
            return URL(fileURLWithPath: localPath).absoluteString
        }

        return localPath
    }

    private func previewText(from message: OIMMessageInfo?) -> String {
        guard let message else {
            return L("暂无消息", "No messages yet")
        }

        if let text = normalizedText(message.textElem?.content) {
            return text
        }

        if let advancedText = normalizedText(message.advancedTextElem?.text) {
            return advancedText
        }

        if let typingText = normalizedText(message.typingElem?.msgTips) {
            return typingText
        }

        if message.pictureElem != nil {
            return L("[图片]", "[Image]")
        }
        if message.videoElem != nil {
            return L("[视频]", "[Video]")
        }
        if message.soundElem != nil {
            return L("[语音]", "[Voice]")
        }
        if message.fileElem != nil {
            return L("[文件]", "[File]")
        }
        if message.cardElem != nil {
            return L("[名片]", "[Card]")
        }
        if message.locationElem != nil {
            return L("[位置]", "[Location]")
        }
        if message.quoteElem != nil {
            return L("[引用消息]", "[Quote]")
        }
        if message.faceElem != nil {
            return L("[表情]", "[Emoji]")
        }
        if message.notificationElem != nil {
            return systemNotificationPreviewText(from: message)
        }
        if message.customElem != nil {
            return L("[自定义消息]", "[Custom Message]")
        }

        if let content = normalizedText(message.content) {
            return content
        }

        return L("[消息]", "[Message]")
    }

    private func systemNotificationPreviewText(from message: OIMMessageInfo) -> String {
        let notification = message.notificationElem
        let actorName = normalizedText(notification?.opUser?.nickname)
            ?? normalizedText(message.senderNickname)
            ?? L("系统", "System")
        let groupName = normalizedText(notification?.group?.groupName)
        let kickedName = normalizedText(notification?.kickedUserList?.first?.nickname)
        let invitedName = normalizedText(notification?.invitedUserList?.first?.nickname)
        let entrantName = normalizedText(notification?.entrantUser?.nickname)
        let quitName = normalizedText(notification?.quitUser?.nickname)

        switch message.contentType {
        case .groupCreated:
            if let groupName {
                return L("已创建群聊：\(groupName)", "Created group: \(groupName)")
            }
            return L("已创建群聊", "Created group")
        case .memberQuit:
            if let quitName {
                return L("\(quitName) 已退出群聊", "\(quitName) left the group")
            }
            return L("有成员退出群聊", "A member left the group")
        case .memberKicked:
            if let kickedName {
                return L("\(kickedName) 已被移出群聊", "\(kickedName) was removed from the group")
            }
            return L("有成员被移出群聊", "A member was removed from the group")
        case .memberInvited:
            if let invitedName {
                return L("\(invitedName) 已加入群聊", "\(invitedName) joined the group")
            }
            return L("有成员被邀请加入群聊", "A member was invited to the group")
        case .memberEnter:
            if let entrantName {
                return L("\(entrantName) 已加入群聊", "\(entrantName) joined the group")
            }
            return L("有成员加入群聊", "A member joined the group")
        case .dismissGroup:
            if let groupName {
                return L("群聊已解散：\(groupName)", "Group dismissed: \(groupName)")
            }
            return L("群聊已解散", "Group dismissed")
        case .groupAnnouncement:
            return L("群公告已更新", "Group announcement updated")
        case .groupSetNameNotification:
            if let groupName {
                return L("群名称已更新为 \(groupName)", "Group renamed to \(groupName)")
            }
            return L("群名称已更新", "Group name updated")
        default:
            if let detail = normalizedText(notification?.detail) {
                return detail
            }
            if actorName == L("系统", "System") {
                return L("[系统消息]", "[System Message]")
            }
            return L("\(actorName) 更新了群系统消息", "\(actorName) updated a group system message")
        }
    }

    private func dateFromOpenIMTimestamp(_ timestamp: Int) -> Date {
        guard timestamp > 0 else {
            return Date(timeIntervalSince1970: 0)
        }

        // OpenIM timestamp fields are millisecond-level in most APIs.
        let seconds = timestamp > 100_000_000_000 ? Double(timestamp) / 1000 : Double(timestamp)
        return Date(timeIntervalSince1970: seconds)
    }

    private func normalizedText(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private func resolveOpenIMConversationID(for conversationID: String) async throws -> String? {
        let normalizedID = conversationID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedID.isEmpty else {
            return nil
        }

        let allConversations = try await getAllConversations()

        if allConversations.contains(where: { normalizedText($0.conversationID) == normalizedID }) {
            return normalizedID
        }

        for item in allConversations {
            guard let mappedType = mapConversationType(item.conversationType),
                  let businessID = resolveBusinessConversationID(item: item, mappedType: mappedType),
                  businessID == normalizedID,
                  let openIMConversationID = normalizedText(item.conversationID) else {
                continue
            }
            return openIMConversationID
        }

        return nil
    }

    private func decodeRaverID(fromOpenIMID openIMID: String?, expectedPrefix: String) -> String? {
        guard let source = normalizedText(openIMID),
              source.hasPrefix("\(expectedPrefix)_") else {
            return nil
        }

        let compact = String(source.dropFirst(2))
        guard compact.count == 32, compact.unicodeScalars.allSatisfy({ Self.hexCharacters.contains($0) }) else {
            return nil
        }

        return "\(compact.prefix(8))-\(compact.dropFirst(8).prefix(4))-\(compact.dropFirst(12).prefix(4))-\(compact.dropFirst(16).prefix(4))-\(compact.dropFirst(20).prefix(12))"
    }

    private static let hexCharacters = CharacterSet(charactersIn: "0123456789abcdef")

    private func initializeIfNeeded(with bootstrap: OpenIMBootstrap) throws {
        if hasInitializedSDK,
           currentBootstrap?.apiURL == bootstrap.apiURL,
           currentBootstrap?.wsURL == bootstrap.wsURL {
            return
        }

        if hasInitializedSDK {
            OIMManager.manager.unInitSDK()
            hasInitializedSDK = false
            hasRegisteredRealtimeListeners = false
        }

        setStateIfNeeded(.initializing)

        let config = OIMInitConfig()
        config.platform = bootstrap.platformID == 9 ? .iPad : .iPhone
        config.apiAddr = bootstrap.apiURL
        config.wsAddr = bootstrap.wsURL
        config.dataDir = openIMDataDirectory()
        config.logLevel = 6
        config.compression = false
        config.isLogStandardOutput = true
        config.systemType = "iOS-Raver"

        let initialized = OIMManager.manager.initSDK(
            with: config,
            onConnecting: { [weak self] in
                Task { @MainActor in
                    guard let self else { return }
                    if case .connected = self.state {
                        return
                    }
                    self.setStateIfNeeded(.connecting)
                }
            },
            onConnectFailure: { [weak self] _code, message in
                let resolved = (message ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                Task { @MainActor in
                    self?.setStateIfNeeded(.failed(resolved.isEmpty ? "OpenIM connect failure" : resolved))
                }
            },
            onConnectSuccess: { [weak self] in
                Task { @MainActor in
                    guard let self, let userID = self.currentLoginUserID else { return }
                    self.registerRealtimeListenersIfNeeded(force: true)
                    self.setStateIfNeeded(.connected(userID: userID))
                }
            },
            onKickedOffline: { [weak self] in
                Task { @MainActor in
                    self?.setStateIfNeeded(.kickedOffline)
                }
            },
            onUserTokenExpired: { [weak self] in
                Task { @MainActor in
                    self?.setStateIfNeeded(.tokenExpired)
                }
            },
            onUserTokenInvalid: { [weak self] message in
                let resolved = (message ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                Task { @MainActor in
                    self?.setStateIfNeeded(.failed(resolved.isEmpty ? "OpenIM token invalid" : resolved))
                }
            }
        )

        guard initialized else {
            throw ServiceError.message("OpenIM SDK 初始化失败")
        }

        hasInitializedSDK = true
        registerRealtimeListenersIfNeeded()
    }

    private func registerRealtimeListenersIfNeeded(force: Bool = false) {
        guard force || !hasRegisteredRealtimeListeners else { return }
        hasRegisteredRealtimeListeners = true
        debug(force ? "re-registered realtime listeners" : "registered realtime listeners")

        OIMManager.callbacker.setAdvancedMsgListenerWithOnRecvMessageRevoked(
            { _ in },
            onRecvC2CReadReceipt: { _ in },
            onRecvGroupReadReceipt: { _ in },
            onRecvNewMessage: { [weak self] message in
                Task { @MainActor in
                    self?.debug(
                        "onRecvNewMessage sessionType=\(Int(message?.sessionType.rawValue ?? 0)) sendID=\(message?.sendID ?? "-") recvID=\(message?.recvID ?? "-") groupID=\(message?.groupID ?? "-") clientMsgID=\(message?.clientMsgID ?? "-")"
                    )
                    self?.publishIncomingMessage(message)
                }
            }
        )

        OIMManager.callbacker.setConversationListenerWithOnSyncServerStart(
            { _ in },
            onSyncServerFinish: { _ in },
            onSyncServerFailed: { _ in },
            onSyncServerProgress: { _ in },
            onConversationChanged: { [weak self] conversations in
                Task { @MainActor in
                    self?.debug("onConversationChanged count=\(conversations?.count ?? 0)")
                    self?.publishConversationChanges(conversations)
                }
            },
            onNewConversation: { [weak self] conversations in
                Task { @MainActor in
                    self?.debug("onNewConversation count=\(conversations?.count ?? 0)")
                    self?.publishConversationChanges(conversations)
                }
            },
            onTotalUnreadMessageCountChanged: { [weak self] count in
                Task { @MainActor in
                    self?.debug("onTotalUnreadMessageCountChanged count=\(count)")
                    self?.totalUnreadSubject.send(max(0, count))
                }
            }
        )
        debug("conversation input-status callback disabled for current SDK; typing handled via message events")
    }

    private func publishIncomingMessage(_ message: OIMMessageInfo?) {
        guard let message,
              let conversationID = businessConversationID(for: message) else {
            debug(
                "drop incoming message: missing conversation mapping sessionType=\(Int(message?.sessionType.rawValue ?? 0)) sendID=\(message?.sendID ?? "-") recvID=\(message?.recvID ?? "-") groupID=\(message?.groupID ?? "-")"
            )
            return
        }
        debug(
            "publishIncomingMessage businessConversation=\(conversationID) clientMsgID=\(normalizedText(message.clientMsgID) ?? "-") serverMsgID=\(normalizedText(message.serverMsgID) ?? "-") self=\(message.isSelf() ? 1 : 0) status=\(Int(message.status.rawValue)) sendID=\(normalizedText(message.sendID) ?? "-") recvID=\(normalizedText(message.recvID) ?? "-") groupID=\(normalizedText(message.groupID) ?? "-") content=\(debugSnippet(previewText(from: message)))"
        )
        #if canImport(OpenIMSDK)
        rawMessageSubject.send(message)
        #endif
        messageSubject.send(toChatMessage(message, conversationID: conversationID))
    }

    #if canImport(OpenIMSDK)
    func businessConversationIDSnapshot(for message: OIMMessageInfo) -> String? {
        businessConversationID(for: message)
    }

    func chatMessageSnapshot(from message: OIMMessageInfo, conversationID: String) -> ChatMessage {
        toChatMessage(message, conversationID: conversationID)
    }
    #endif

    private func debugMessageSummary(_ message: ChatMessage) -> String {
        "id=\(message.id) conversation=\(message.conversationID) mine=\(message.isMine ? 1 : 0) status=\(message.deliveryStatus.rawValue) createdAt=\(Int(message.createdAt.timeIntervalSince1970 * 1000)) content=\(debugSnippet(message.content))"
    }

    private func debugSnippet(_ text: String?, limit: Int = 32) -> String {
        let normalized = (text ?? "")
            .replacingOccurrences(of: "\n", with: "\\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return "-" }
        return normalized.count > limit ? "\(normalized.prefix(limit))..." : normalized
    }

    private func publishConversationChanges(_ items: [OIMConversationInfo]?) {
        let conversations = (items ?? []).compactMap { item -> Conversation? in
            guard let type = mapConversationType(item.conversationType) else {
                return nil
            }
            return toConversation(item, expectedType: type)
        }
        guard !conversations.isEmpty else { return }
        conversationSubject.send(conversations)
    }

    private func publishInputStatusChanged(_ data: OIMInputStatusChangedData?) {
        guard let data,
              let conversationID = normalizedText(data.conversationID),
              let userIDRaw = normalizedText(data.userID) else {
            return
        }

        let userID = decodeRaverID(fromOpenIMID: userIDRaw, expectedPrefix: "u") ?? userIDRaw
        let event = OpenIMInputStatusEvent(
            conversationID: conversationID,
            userID: userID,
            platformIDs: data.platformIDs.map(\.intValue),
            receivedAt: Date()
        )
        debug("onConversationUserInputStatusChanged conversation=\(event.conversationID) user=\(event.userID)")
        inputStatusSubject.send(event)
    }

    private func businessConversationID(for message: OIMMessageInfo) -> String? {
        if let groupID = normalizedText(message.groupID) {
            return decodeRaverID(fromOpenIMID: groupID, expectedPrefix: "g") ?? groupID
        }

        let peerOpenIMID = message.isSelf() ? normalizedText(message.recvID) : normalizedText(message.sendID)
        if let peerOpenIMID {
            return decodeRaverID(fromOpenIMID: peerOpenIMID, expectedPrefix: "u") ?? peerOpenIMID
        }

        if let sendID = normalizedText(message.sendID) {
            return decodeRaverID(fromOpenIMID: sendID, expectedPrefix: "u") ?? sendID
        }

        if let recvID = normalizedText(message.recvID) {
            return decodeRaverID(fromOpenIMID: recvID, expectedPrefix: "u") ?? recvID
        }

        return nil
    }

    private func debug(_ message: String) {
        #if DEBUG
        Self.logger.debug("[OpenIMSession] \(message, privacy: .public)")
        print("[OpenIMSession] \(message)")
        OpenIMProbeLogger.log("[OpenIMSession] \(message)")
        #endif
    }

    private func loginIfNeeded(with bootstrap: OpenIMBootstrap, token: String) async throws {
        let targetUserID = bootstrap.userID

        if currentLoginUserID == bootstrap.userID, state.isConnected {
            currentBootstrap = bootstrap
            currentToken = token
            return
        }

        if let loginTask {
            try await loginTask.value
            if currentLoginUserID == bootstrap.userID, state.isConnected {
                currentBootstrap = bootstrap
                currentToken = token
                return
            }
        }

        var sdkSnapshot = sdkLoginStatusSnapshot()
        if sdkSnapshot.status == .logging {
            sdkSnapshot = await waitForSDKLoginStatusStabilized(targetUserID: targetUserID, timeoutMs: 2600)
        }
        debug(
            "login precheck targetUser=\(targetUserID) state=\(String(describing: state)) sdkStatus=\(sdkLoginStatusDescription(sdkSnapshot.status)) sdkUser=\(sdkSnapshot.userID ?? "-")"
        )

        if sdkSnapshot.status == .logged, sdkSnapshot.userID == targetUserID {
            currentBootstrap = bootstrap
            currentLoginUserID = targetUserID
            currentToken = token
            registerRealtimeListenersIfNeeded(force: true)
            setStateIfNeeded(.connected(userID: targetUserID))
            debug("login bypassed: sdk already logged with same user")
            return
        }

        if sdkSnapshot.status == .logging {
            // SDK is recovering its own session; avoid duplicated login(10102).
            currentBootstrap = bootstrap
            currentToken = token
            if currentLoginUserID == nil {
                currentLoginUserID = targetUserID
            }
            setStateIfNeeded(.connecting)
            debug("login skipped: sdk is logging for targetUser=\(targetUserID)")
            return
        }

        if sdkSnapshot.status == .logged,
           let sdkUser = sdkSnapshot.userID,
           sdkUser != targetUserID {
            debug("login precheck found stale sdk user=\(sdkUser), target=\(targetUserID), performing sdk logout")
            try await logoutSDK(reason: "switch-user")
        }

        setStateIfNeeded(.connecting)
        loginAttemptSequence += 1
        let attempt = loginAttemptSequence

        let task = Task { @MainActor in
            do {
                debug("login start attempt=\(attempt) targetUser=\(targetUserID)")
                try await performSDKLogin(userID: targetUserID, token: token)
                currentBootstrap = bootstrap
                currentLoginUserID = targetUserID
                currentToken = token
                registerRealtimeListenersIfNeeded(force: true)
                setStateIfNeeded(.connected(userID: targetUserID))
                debug("login success attempt=\(attempt) targetUser=\(targetUserID)")
            } catch let failure as OpenIMLoginFailure {
                if failure.code == 10102 {
                    let repeatedSnapshot = sdkLoginStatusSnapshot()
                    debug(
                        "login repeated attempt=\(attempt) code=10102 sdkStatus=\(sdkLoginStatusDescription(repeatedSnapshot.status)) sdkUser=\(repeatedSnapshot.userID ?? "-")"
                    )

                    if repeatedSnapshot.status == .logged, repeatedSnapshot.userID == targetUserID {
                        currentBootstrap = bootstrap
                        currentLoginUserID = targetUserID
                        currentToken = token
                        registerRealtimeListenersIfNeeded(force: true)
                        setStateIfNeeded(.connected(userID: targetUserID))
                        debug("login repeated resolved as already connected attempt=\(attempt)")
                        return
                    }

                    if repeatedSnapshot.status == .logged,
                       let sdkUser = repeatedSnapshot.userID,
                       sdkUser != targetUserID {
                        debug("login repeated mismatch sdkUser=\(sdkUser) targetUser=\(targetUserID), retry after logout")
                        try await logoutSDK(reason: "repeat-login-mismatch")
                        try await performSDKLogin(userID: targetUserID, token: token)
                        currentBootstrap = bootstrap
                        currentLoginUserID = targetUserID
                        currentToken = token
                        registerRealtimeListenersIfNeeded(force: true)
                        setStateIfNeeded(.connected(userID: targetUserID))
                        debug("login retry success attempt=\(attempt) targetUser=\(targetUserID)")
                        return
                    }

                    if repeatedSnapshot.status == .logging {
                        currentBootstrap = bootstrap
                        currentToken = token
                        if currentLoginUserID == nil {
                            currentLoginUserID = targetUserID
                        }
                        setStateIfNeeded(.connecting)
                        debug("login repeated treated as in-flight sdk logging attempt=\(attempt)")
                        return
                    }
                }
                throw ServiceError.message(failure.message)
            } catch {
                throw error
            }
        }

        loginTask = task
        do {
            try await task.value
        } catch {
            loginTask = nil
            throw error
        }
        loginTask = nil
    }

    private struct OpenIMLoginFailure: Error {
        let code: Int
        let message: String
    }

    private func performSDKLogin(userID: String, token: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            OIMManager.manager.login(
                userID,
                token: token,
                onSuccess: { _ in
                    continuation.resume()
                },
                onFailure: { code, message in
                    let resolved = (message ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    let text = resolved.isEmpty ? "OpenIM login failed (\(code))" : resolved
                    continuation.resume(throwing: OpenIMLoginFailure(code: code, message: text))
                }
            )
        }
    }

    private func logoutSDK(reason: String) async throws {
        debug("sdk logout start reason=\(reason)")
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            OIMManager.manager.logoutWith(
                onSuccess: { _ in
                    continuation.resume()
                },
                onFailure: { code, message in
                    let resolved = (message ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    let text = resolved.isEmpty ? "OpenIM logout failed (\(code))" : resolved
                    continuation.resume(throwing: ServiceError.message(text))
                }
            )
        }
        debug("sdk logout success reason=\(reason)")
    }

    private func sdkLoginStatusSnapshot() -> (status: OIMLoginStatus, userID: String?) {
        let status = OIMManager.manager.getLoginStatus()
        let userID = normalizedText(OIMManager.manager.getLoginUserID())
        return (status: status, userID: userID)
    }

    private func sdkLoginStatusDescription(_ status: OIMLoginStatus) -> String {
        switch status {
        case .logout:
            return "logout"
        case .logging:
            return "logging"
        case .logged:
            return "logged"
        @unknown default:
            return "unknown(\(status.rawValue))"
        }
    }

    private func waitForSDKLoginStatusStabilized(
        targetUserID: String,
        timeoutMs: UInt64
    ) async -> (status: OIMLoginStatus, userID: String?) {
        let stepNs: UInt64 = 200_000_000
        var waitedNs: UInt64 = 0

        while waitedNs < timeoutMs * 1_000_000 {
            let snapshot = sdkLoginStatusSnapshot()
            if snapshot.status != .logging {
                return snapshot
            }

            // If current in-memory state already points to target user and SDK is still logging,
            // keep waiting a short while for internal reconnection to settle.
            if currentLoginUserID == targetUserID {
                debug("sdk status logging, waiting... targetUser=\(targetUserID) waitedMs=\(waitedNs / 1_000_000)")
            }
            try? await Task.sleep(nanoseconds: stepNs)
            waitedNs += stepNs
        }

        return sdkLoginStatusSnapshot()
    }

    private func openIMDataDirectory() -> String {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let directory = root.appendingPathComponent("OpenIM", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        return directory.path
    }
    #endif
}

#if canImport(OpenIMSDK)
extension OpenIMSession: OpenIMRawChatService {}
#endif
