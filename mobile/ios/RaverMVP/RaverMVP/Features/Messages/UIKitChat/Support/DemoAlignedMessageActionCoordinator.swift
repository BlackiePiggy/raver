import Foundation
import SwiftUI
import UIKit
import AVFAudio

@MainActor
final class DemoAlignedMessageActionCoordinator: NSObject, @preconcurrency AVAudioPlayerDelegate {
    private let chatController: RaverChatController
    private weak var presenter: UIViewController?
    private let chatContextProvider: DemoAlignedChatContextProvider
    private let failureFeedbackActions: DemoAlignedFailureFeedbackActions
    private var voicePlayer: AVAudioPlayer?
    private var currentVoiceMessageID: String?
    private var pendingResendMessageIDs = Set<String>()
    private var interruptionObserver: NSObjectProtocol?
    private var appBackgroundObserver: NSObjectProtocol?

    init(
        chatController: RaverChatController,
        presenter: UIViewController,
        chatContextProvider: DemoAlignedChatContextProvider,
        failureFeedbackActions: DemoAlignedFailureFeedbackActions
    ) {
        self.chatController = chatController
        self.presenter = presenter
        self.chatContextProvider = chatContextProvider
        self.failureFeedbackActions = failureFeedbackActions
        super.init()
        configureObservers()
    }

    deinit {
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
        if let appBackgroundObserver {
            NotificationCenter.default.removeObserver(appBackgroundObserver)
        }
    }

    func handleMessageTapped(_ message: ChatMessage) async {
        if message.isMine, message.deliveryStatus == .failed {
            await resendMessage(messageID: message.id)
            return
        }

        if message.kind == .image || message.kind == .video {
            presentMediaPreviewIfNeeded(message)
            return
        }
        if message.kind == .voice {
            await playVoiceMessageIfNeeded(message)
            return
        }

        chatController.toggleReplyDraft(for: message.id)
    }

    func stopVoicePlaybackIfNeeded() {
        stopVoicePlayback()
    }

    private func resendMessage(messageID: String) async {
        if pendingResendMessageIDs.contains(messageID) {
            failureFeedbackActions.show(
                message: L("正在重发，请稍候", "Resending... Please wait."),
                reason: "resend_in_progress"
            )
            return
        }

        pendingResendMessageIDs.insert(messageID)
        defer {
            pendingResendMessageIDs.remove(messageID)
        }

        failureFeedbackActions.show(
            message: L("正在重发消息...", "Resending message..."),
            reason: "resend_started"
        )
        do {
            _ = try await chatController.resendFailedMessage(messageID: messageID)
        } catch {
            DemoAlignedChatLogger.resendFailed(
                conversationID: chatContextProvider.conversationID,
                messageID: messageID,
                error: error
            )
            failureFeedbackActions.showSendFailureHint()
        }
    }

    private func presentMediaPreviewIfNeeded(_ message: ChatMessage) {
        guard let rawURL = RaverChatMediaResolver.playbackRawURL(for: message), !rawURL.isEmpty else { return }
        guard let presenter else { return }

        let viewer = FullscreenMediaViewer(
            items: [FullscreenMediaItem(rawURL: rawURL, index: 0)],
            initialIndex: 0
        )
        let host = UIHostingController(rootView: viewer)
        host.modalPresentationStyle = .fullScreen
        presenter.present(host, animated: true)
    }

    private func playVoiceMessageIfNeeded(_ message: ChatMessage) async {
        if currentVoiceMessageID == message.id, let player = voicePlayer, player.isPlaying {
            stopVoicePlayback()
            return
        }

        do {
            let mediaURL = try await resolveVoicePlaybackURL(for: message)
            try startVoicePlayback(url: mediaURL, messageID: message.id)
        } catch {
            DemoAlignedChatLogger.resendFailed(
                conversationID: chatContextProvider.conversationID,
                messageID: message.id,
                error: error
            )
            failureFeedbackActions.showSendFailureHint()
        }
    }

    private func resolveVoicePlaybackURL(for message: ChatMessage) async throws -> URL {
        guard let rawURL = RaverChatMediaResolver.playbackRawURL(for: message),
              let resolved = RaverChatMediaResolver.resolvedURL(from: rawURL) else {
            throw ServiceError.message(L("语音地址无效", "Invalid voice URL"))
        }
        if resolved.isFileURL {
            ChatMediaTempFileStore.noteAccess(for: resolved)
            return resolved
        }

        let (data, _) = try await URLSession.shared.data(from: resolved)
        let ext = resolved.pathExtension.isEmpty ? "m4a" : resolved.pathExtension
        return try ChatMediaTempFileStore.writeData(
            data,
            fileExtension: ext,
            prefix: "voice-play",
            kind: .voice
        )
    }

    private func startVoicePlayback(url: URL, messageID: String) throws {
        stopVoicePlayback()
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true, options: [])

        let player = try AVAudioPlayer(contentsOf: url)
        player.delegate = self
        player.prepareToPlay()
        player.play()

        voicePlayer = player
        currentVoiceMessageID = messageID
        chatController.setPlayingVoiceMessageID(messageID)
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        _ = player
        _ = flag
        stopVoicePlayback()
        Task { @MainActor [weak self] in
            self?.chatController.setPlayingVoiceMessageID(nil)
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: (any Error)?) {
        _ = player
        _ = error
        stopVoicePlayback()
        Task { @MainActor [weak self] in
            self?.chatController.setPlayingVoiceMessageID(nil)
            self?.failureFeedbackActions.showSendFailureHint()
        }
    }

    private func configureObservers() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.stopVoicePlayback()
        }
        appBackgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.stopVoicePlayback()
        }
    }

    private func stopVoicePlayback() {
        voicePlayer?.stop()
        voicePlayer = nil
        currentVoiceMessageID = nil
        chatController.setPlayingVoiceMessageID(nil)
    }
}
