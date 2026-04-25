import Foundation

@MainActor
final class DemoAlignedMessageFlowCoordinator {
    private let chatController: RaverChatController
    private let messageApplyCoordinator: DemoAlignedMessageApplyCoordinator
    private let viewportScrollCoordinator: DemoAlignedMessageViewportScrollCoordinator
    private let viewportCoordinator: DemoAlignedViewportCoordinator
    private let onSendFailureHint: () -> Void

    private var messages: [ChatMessage] = []

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
    }

    func loadOlderMessagesIfNeeded() async {
        guard chatController.hasCompletedInitialLoad else { return }
        guard !chatController.isInitialLoading, !chatController.isLoadingOlder else { return }
        guard !messages.isEmpty else { return }
        guard chatController.canLoadOlderMessages else { return }

        OpenIMProbeLogger.log("[DemoAlignedMessageFlow] load-older start")
        let anchor = viewportScrollCoordinator.capturePaginationAnchor()
        await chatController.loadOlderMessagesIfNeeded()
        applyMessagesFromController(forceScrollToBottom: false)
        viewportScrollCoordinator.restorePaginationAnchor(anchor)
        OpenIMProbeLogger.log("[DemoAlignedMessageFlow] load-older end")
    }

    func applyMessagesFromController(forceScrollToBottom: Bool = false) {
        let next = chatController.messages
        let previousMessages = messages
        OpenIMProbeLogger.log(
            "[DemoAlignedMessageFlow] apply-start previousCount=\(previousMessages.count) nextCount=\(next.count) previousTail={\(debugMessageSummary(previousMessages.last))} nextTail={\(debugMessageSummary(next.last))}"
        )
        messages = next

        let outcome = messageApplyCoordinator.apply(
            currentMessages: previousMessages,
            nextMessages: next,
            forceScrollToBottom: forceScrollToBottom,
            isLoadingOlder: chatController.isLoadingOlder,
            hasCompletedInitialLoad: chatController.hasCompletedInitialLoad
        )

        if outcome.shouldAutoScroll {
            OpenIMProbeLogger.log(
                "[DemoAlignedMessageFlow] apply outcome auto-scroll=1 nearBottom=\(outcome.isNearBottomAfterApply ? 1 : 0)"
            )
            viewportScrollCoordinator.scrollToBottom(animated: chatController.hasCompletedInitialLoad)
            viewportCoordinator.clearPendingMessages()
        } else if outcome.pendingMessagesDelta > 0 {
            OpenIMProbeLogger.log(
                "[DemoAlignedMessageFlow] apply outcome auto-scroll=0 pendingDelta=\(outcome.pendingMessagesDelta)"
            )
            viewportCoordinator.accumulatePendingMessages(by: outcome.pendingMessagesDelta)
        }

        viewportCoordinator.updateJumpToBottomUI(isNearBottom: outcome.isNearBottomAfterApply, animated: true)

        if outcome.hasNewFailedOutgoingMessage {
            OpenIMProbeLogger.log("[DemoAlignedMessageFlow] apply outcome failure-hint=1")
            onSendFailureHint()
        }

        OpenIMProbeLogger.log(
            "[DemoAlignedMessageFlow] apply-end renderedTail={\(debugMessageSummary(messages.last))}"
        )
    }

    private func debugMessageSummary(_ message: ChatMessage?) -> String {
        guard let message else { return "-" }
        let text = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let snippet = text.isEmpty ? "-" : (text.count > 24 ? "\(text.prefix(24))..." : text)
        return "id=\(message.id) mine=\(message.isMine ? 1 : 0) status=\(message.deliveryStatus.rawValue) content=\(snippet)"
    }
}
