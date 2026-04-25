import Foundation

enum DemoAlignedChatScreenAssemblyActionHandlerDependenciesFactory {
    private static let coveredActions: [DemoAlignedChatScreenAssemblyAction] = [
        .layout,
        .collectionView,
        .composer,
        .jumpToBottomButton,
        .olderLoadingIndicator,
        .navigationItems,
        .viewportScrollCoordinator,
        .messageApplyCoordinator,
        .sendFailureHintPresenter,
        .chatContextProvider,
        .messageFailureFeedbackCoordinator,
        .failureFeedbackActions,
        .mediaProgressPresenter,
        .textSendCoordinator,
        .mediaMessageSendCoordinator,
        .mediaSendCoordinator,
        .messageActionCoordinator,
        .paginationCoordinator,
        .viewportCoordinator,
        .composerActionCoordinator,
        .keyboardLifecycleCoordinator,
        .messageFlowCoordinator,
        .controllerBindingCoordinator,
        .chatRouteCoordinator,
        .chatScreenLifecycleCoordinator
    ]

    static func make(
        executeAction: @escaping (DemoAlignedChatScreenAssemblyAction) -> Void
    ) -> DemoAlignedChatScreenAssemblyActionHandlers.Dependencies {
        #if DEBUG
        assertActionCoverage()
        #endif

        return DemoAlignedChatScreenAssemblyActionHandlers.Dependencies(
            configureLayout: { executeAction(.layout) },
            configureCollectionView: { executeAction(.collectionView) },
            configureComposer: { executeAction(.composer) },
            configureJumpToBottomButton: { executeAction(.jumpToBottomButton) },
            configureOlderLoadingIndicator: { executeAction(.olderLoadingIndicator) },
            configureNavigationItems: { executeAction(.navigationItems) },
            configureViewportScrollCoordinator: { executeAction(.viewportScrollCoordinator) },
            configureMessageApplyCoordinator: { executeAction(.messageApplyCoordinator) },
            configureSendFailureHintPresenter: { executeAction(.sendFailureHintPresenter) },
            configureChatContextProvider: { executeAction(.chatContextProvider) },
            configureMessageFailureFeedbackCoordinator: { executeAction(.messageFailureFeedbackCoordinator) },
            configureFailureFeedbackActions: { executeAction(.failureFeedbackActions) },
            configureMediaProgressPresenter: { executeAction(.mediaProgressPresenter) },
            configureTextSendCoordinator: { executeAction(.textSendCoordinator) },
            configureMediaMessageSendCoordinator: { executeAction(.mediaMessageSendCoordinator) },
            configureMediaSendCoordinator: { executeAction(.mediaSendCoordinator) },
            configureMessageActionCoordinator: { executeAction(.messageActionCoordinator) },
            configurePaginationCoordinator: { executeAction(.paginationCoordinator) },
            configureViewportCoordinator: { executeAction(.viewportCoordinator) },
            configureComposerActionCoordinator: { executeAction(.composerActionCoordinator) },
            configureKeyboardLifecycleCoordinator: { executeAction(.keyboardLifecycleCoordinator) },
            configureMessageFlowCoordinator: { executeAction(.messageFlowCoordinator) },
            configureControllerBindingCoordinator: { executeAction(.controllerBindingCoordinator) },
            configureChatRouteCoordinator: { executeAction(.chatRouteCoordinator) },
            configureChatScreenLifecycleCoordinator: { executeAction(.chatScreenLifecycleCoordinator) }
        )
    }

    #if DEBUG
    private static func assertActionCoverage() {
        let coveredSet = Set(coveredActions)
        let planSet = Set(DemoAlignedChatScreenAssemblyPlanBuilder.orderedActions)
        guard coveredSet != planSet else { return }

        let missing = planSet.subtracting(coveredSet).map(\.rawValue).sorted()
        let extra = coveredSet.subtracting(planSet).map(\.rawValue).sorted()
        assertionFailure(
            """
            Assembly action coverage mismatch.
            missing_in_handler_factory=\(missing)
            extra_in_handler_factory=\(extra)
            """
        )
    }
    #endif
}
