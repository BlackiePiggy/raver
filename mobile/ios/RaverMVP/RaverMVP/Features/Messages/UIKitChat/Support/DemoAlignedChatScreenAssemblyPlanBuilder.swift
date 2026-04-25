import Foundation

enum DemoAlignedChatScreenAssemblyAction: String {
    case layout = "layout"
    case collectionView = "collection_view"
    case viewportScrollCoordinator = "viewport_scroll_coordinator"
    case messageApplyCoordinator = "message_apply_coordinator"
    case composer = "composer"
    case sendFailureHintPresenter = "send_failure_hint_presenter"
    case chatContextProvider = "chat_context_provider"
    case messageFailureFeedbackCoordinator = "message_failure_feedback_coordinator"
    case failureFeedbackActions = "failure_feedback_actions"
    case mediaProgressPresenter = "media_progress_presenter"
    case textSendCoordinator = "text_send_coordinator"
    case mediaMessageSendCoordinator = "media_message_send_coordinator"
    case mediaSendCoordinator = "media_send_coordinator"
    case messageActionCoordinator = "message_action_coordinator"
    case jumpToBottomButton = "jump_to_bottom_button"
    case olderLoadingIndicator = "older_loading_indicator"
    case paginationCoordinator = "pagination_coordinator"
    case viewportCoordinator = "viewport_coordinator"
    case composerActionCoordinator = "composer_action_coordinator"
    case keyboardLifecycleCoordinator = "keyboard_lifecycle_coordinator"
    case messageFlowCoordinator = "message_flow_coordinator"
    case controllerBindingCoordinator = "controller_binding_coordinator"
    case chatRouteCoordinator = "chat_route_coordinator"
    case chatScreenLifecycleCoordinator = "chat_screen_lifecycle_coordinator"
    case navigationItems = "navigation_items"
}

struct DemoAlignedChatScreenAssemblyPlan {
    let expectedOrder: [String]
    let steps: [DemoAlignedChatScreenAssemblyCoordinator.Step]
}

enum DemoAlignedChatScreenAssemblyPlanBuilder {
    static let orderedActions: [DemoAlignedChatScreenAssemblyAction] = [
        .layout,
        .collectionView,
        .viewportScrollCoordinator,
        .messageApplyCoordinator,
        .composer,
        .sendFailureHintPresenter,
        .chatContextProvider,
        .messageFailureFeedbackCoordinator,
        .failureFeedbackActions,
        .mediaProgressPresenter,
        .textSendCoordinator,
        .mediaMessageSendCoordinator,
        .mediaSendCoordinator,
        .messageActionCoordinator,
        .jumpToBottomButton,
        .olderLoadingIndicator,
        .paginationCoordinator,
        .viewportCoordinator,
        .composerActionCoordinator,
        .keyboardLifecycleCoordinator,
        .messageFlowCoordinator,
        .controllerBindingCoordinator,
        .chatRouteCoordinator,
        .chatScreenLifecycleCoordinator,
        .navigationItems
    ]

    static func make(execute: @escaping (DemoAlignedChatScreenAssemblyAction) -> Void) -> DemoAlignedChatScreenAssemblyPlan {
        let steps: [DemoAlignedChatScreenAssemblyCoordinator.Step] = orderedActions.map { action in
            DemoAlignedChatScreenAssemblyCoordinator.Step(
                id: action.rawValue,
                action: { execute(action) }
            )
        }

        return DemoAlignedChatScreenAssemblyPlan(
            expectedOrder: orderedActions.map(\.rawValue),
            steps: steps
        )
    }
}
