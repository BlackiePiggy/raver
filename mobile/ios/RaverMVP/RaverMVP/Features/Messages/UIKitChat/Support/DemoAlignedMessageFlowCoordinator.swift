import Foundation

@MainActor
final class DemoAlignedMessageFlowCoordinator {
    private let chatController: RaverChatController
    private let messageApplyCoordinator: DemoAlignedMessageApplyCoordinator
    private let viewportScrollCoordinator: DemoAlignedMessageViewportScrollCoordinator
    private let viewportCoordinator: DemoAlignedViewportCoordinator
    private let onSendFailureHint: () -> Void

    private var messages: [ChatMessage] = []
    private var pendingPaginationAnchor: RaverChatScrollCoordinator.PaginationAnchor?

    init(
        chatController: RaverChatController,
        messageApplyCoordinator: DemoAlignedMessageApplyCoordinator,
        viewportScrollCoordinator: DemoAlignedMessageViewportScrollCoordinator,
        viewportCoordinator: DemoAlignedViewportCoordinator,
        onSendFailureHint: @escaping () -> Void
    ) {
        self.chatController = chatController
        self.messageApplyCoordinator = messageApplyCoordinator
        self.viewportScrollCoordinator = viewportScrollCoordinator
        self.viewportCoordinator = viewportCoordinator
        self.onSendFailureHint = onSendFailureHint
    }

    var hasMessages: Bool {
        !messages.isEmpty
    }

    func reset() {
        messages.removeAll(keepingCapacity: true)
        pendingPaginationAnchor = nil
    }

    func loadOlderMessagesIfNeeded() async {
        guard chatController.hasCompletedInitialLoad else { return }
        guard !chatController.isInitialLoading, !chatController.isLoadingOlder else { return }
        guard !messages.isEmpty else { return }
        guard chatController.canLoadOlderMessages else { return }

        let previousCount = messages.count
        pendingPaginationAnchor = viewportScrollCoordinator.capturePaginationAnchor()
        await chatController.loadOlderMessagesIfNeeded()

        if pendingPaginationAnchor != nil {
            let currentMessages = chatController.currentMessagesSnapshot()
            let didPrependMessages = currentMessages.count > previousCount

            if didPrependMessages {
                applyMessages(currentMessages, forceScrollToBottom: false)
            } else {
                pendingPaginationAnchor = nil
            }
        }
    }

    func applyMessagesFromController(forceScrollToBottom: Bool = false) {
        let next = chatController.currentMessagesSnapshot()
        applyMessages(next, forceScrollToBottom: forceScrollToBottom)
    }

    private func applyMessages(_ next: [ChatMessage], forceScrollToBottom: Bool) {
        let previousMessages = messages
        messages = next

        let outcome = messageApplyCoordinator.apply(
            currentMessages: previousMessages,
            nextMessages: next,
            playingVoiceMessageID: chatController.playingVoiceMessageID,
            forceScrollToBottom: forceScrollToBottom,
            isLoadingOlder: chatController.isLoadingOlder,
            hasCompletedInitialLoad: chatController.hasCompletedInitialLoad
        )

        let didPrependOlderMessages =
            pendingPaginationAnchor != nil &&
            next.count > previousMessages.count

        if didPrependOlderMessages {
            viewportScrollCoordinator.restorePaginationAnchor(pendingPaginationAnchor)
            pendingPaginationAnchor = nil
        }

        if outcome.shouldAutoScroll {
            // Demo-style chat should stay pinned to bottom without a visible bounce when
            // a tall incoming/outgoing media bubble changes content height.
            viewportScrollCoordinator.scrollToBottom(animated: false)
            viewportCoordinator.clearPendingMessages()
        } else if outcome.pendingMessagesDelta > 0 {
            viewportCoordinator.accumulatePendingMessages(by: outcome.pendingMessagesDelta)
        }

        viewportCoordinator.updateJumpToBottomUI(isNearBottom: outcome.isNearBottomAfterApply, animated: true)

        if outcome.hasNewFailedOutgoingMessage {
            onSendFailureHint()
        }
    }
}
