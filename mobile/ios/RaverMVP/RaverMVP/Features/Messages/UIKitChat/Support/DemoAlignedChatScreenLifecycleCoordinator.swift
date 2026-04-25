import Foundation

@MainActor
final class DemoAlignedChatScreenLifecycleCoordinator {
    private let chatController: RaverChatController
    private let updateTitle: (String) -> Void
    private let updateCollectionConversationType: (Conversation) -> Void
    private let forceScrollOnNextApply: () -> Void
    private let resetPagination: () -> Void
    private let resetViewport: () -> Void
    private let resetMessageFlowState: () -> Void
    private let resetSendFailureHint: () -> Void
    private let refreshSendButtonState: () -> Void
    private let updateRouteContext: (
        Conversation,
        SocialService,
        ((AppRoute) -> Void)?,
        (() -> Void)?
    ) -> Void
    private var hasPerformedInitialStableScroll = false

    init(
        chatController: RaverChatController,
        updateTitle: @escaping (String) -> Void,
        updateCollectionConversationType: @escaping (Conversation) -> Void,
        forceScrollOnNextApply: @escaping () -> Void,
        resetPagination: @escaping () -> Void,
        resetViewport: @escaping () -> Void,
        resetMessageFlowState: @escaping () -> Void,
        resetSendFailureHint: @escaping () -> Void,
        refreshSendButtonState: @escaping () -> Void,
        updateRouteContext: @escaping (
            Conversation,
            SocialService,
            ((AppRoute) -> Void)?,
            (() -> Void)?
        ) -> Void
    ) {
        self.chatController = chatController
        self.updateTitle = updateTitle
        self.updateCollectionConversationType = updateCollectionConversationType
        self.forceScrollOnNextApply = forceScrollOnNextApply
        self.resetPagination = resetPagination
        self.resetViewport = resetViewport
        self.resetMessageFlowState = resetMessageFlowState
        self.resetSendFailureHint = resetSendFailureHint
        self.refreshSendButtonState = refreshSendButtonState
        self.updateRouteContext = updateRouteContext
    }

    func start() {
        chatController.start()
    }

    func handleViewDidAppear(hasMessages: Bool) -> Bool {
        guard !hasPerformedInitialStableScroll else { return false }
        hasPerformedInitialStableScroll = true
        return hasMessages
    }

    func updateConversation(
        currentConversation: Conversation,
        nextConversation: Conversation,
        service: SocialService,
        onNavigate: ((AppRoute) -> Void)?,
        onLeaveConversation: (() -> Void)?
    ) -> Conversation {
        updateTitle(nextConversation.title)

        guard currentConversation.id != nextConversation.id else {
            return nextConversation
        }

        updateCollectionConversationType(nextConversation)
        forceScrollOnNextApply()
        resetPagination()
        resetViewport()
        resetMessageFlowState()
        hasPerformedInitialStableScroll = false
        resetSendFailureHint()
        refreshSendButtonState()
        updateRouteContext(nextConversation, service, onNavigate, onLeaveConversation)
        chatController.updateContext(conversation: nextConversation, service: service)
        return nextConversation
    }
}
