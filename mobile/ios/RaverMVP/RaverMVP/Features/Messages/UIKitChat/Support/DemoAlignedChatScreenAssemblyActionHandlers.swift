import Foundation

struct DemoAlignedChatScreenAssemblyActionHandlers {
    struct Dependencies {
        let configureLayout: () -> Void
        let configureCollectionView: () -> Void
        let configureComposer: () -> Void
        let configureJumpToBottomButton: () -> Void
        let configureOlderLoadingIndicator: () -> Void
        let configureNavigationItems: () -> Void
        let configureViewportScrollCoordinator: () -> Void
        let configureMessageApplyCoordinator: () -> Void
        let configureSendFailureHintPresenter: () -> Void
        let configureChatContextProvider: () -> Void
        let configureMessageFailureFeedbackCoordinator: () -> Void
        let configureFailureFeedbackActions: () -> Void
        let configureMediaProgressPresenter: () -> Void
        let configureTextSendCoordinator: () -> Void
        let configureMediaMessageSendCoordinator: () -> Void
        let configureMediaSendCoordinator: () -> Void
        let configureMessageActionCoordinator: () -> Void
        let configurePaginationCoordinator: () -> Void
        let configureViewportCoordinator: () -> Void
        let configureComposerActionCoordinator: () -> Void
        let configureKeyboardLifecycleCoordinator: () -> Void
        let configureMessageFlowCoordinator: () -> Void
        let configureControllerBindingCoordinator: () -> Void
        let configureChatRouteCoordinator: () -> Void
        let configureChatScreenLifecycleCoordinator: () -> Void
    }

    private let uiHandlers: [DemoAlignedChatScreenAssemblyAction: () -> Void]
    private let coordinatorHandlers: [DemoAlignedChatScreenAssemblyAction: () -> Void]

    init(dependencies: Dependencies) {
        uiHandlers = [
            .layout: dependencies.configureLayout,
            .collectionView: dependencies.configureCollectionView,
            .composer: dependencies.configureComposer,
            .jumpToBottomButton: dependencies.configureJumpToBottomButton,
            .olderLoadingIndicator: dependencies.configureOlderLoadingIndicator,
            .navigationItems: dependencies.configureNavigationItems
        ]

        coordinatorHandlers = [
            .viewportScrollCoordinator: dependencies.configureViewportScrollCoordinator,
            .messageApplyCoordinator: dependencies.configureMessageApplyCoordinator,
            .sendFailureHintPresenter: dependencies.configureSendFailureHintPresenter,
            .chatContextProvider: dependencies.configureChatContextProvider,
            .messageFailureFeedbackCoordinator: dependencies.configureMessageFailureFeedbackCoordinator,
            .failureFeedbackActions: dependencies.configureFailureFeedbackActions,
            .mediaProgressPresenter: dependencies.configureMediaProgressPresenter,
            .textSendCoordinator: dependencies.configureTextSendCoordinator,
            .mediaMessageSendCoordinator: dependencies.configureMediaMessageSendCoordinator,
            .mediaSendCoordinator: dependencies.configureMediaSendCoordinator,
            .messageActionCoordinator: dependencies.configureMessageActionCoordinator,
            .paginationCoordinator: dependencies.configurePaginationCoordinator,
            .viewportCoordinator: dependencies.configureViewportCoordinator,
            .composerActionCoordinator: dependencies.configureComposerActionCoordinator,
            .keyboardLifecycleCoordinator: dependencies.configureKeyboardLifecycleCoordinator,
            .messageFlowCoordinator: dependencies.configureMessageFlowCoordinator,
            .controllerBindingCoordinator: dependencies.configureControllerBindingCoordinator,
            .chatRouteCoordinator: dependencies.configureChatRouteCoordinator,
            .chatScreenLifecycleCoordinator: dependencies.configureChatScreenLifecycleCoordinator
        ]
    }

    func performUIAction(_ action: DemoAlignedChatScreenAssemblyAction) -> Bool {
        guard let handler = uiHandlers[action] else { return false }
        handler()
        return true
    }

    func performCoordinatorAction(_ action: DemoAlignedChatScreenAssemblyAction) -> Bool {
        guard let handler = coordinatorHandlers[action] else { return false }
        handler()
        return true
    }
}
