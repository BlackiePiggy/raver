import Foundation

enum DemoAlignedChatAssemblyMissingDependencyStep: String {
    case messageApplyCoordinator = "message_apply_coordinator"
    case messageFailureFeedbackCoordinator = "message_failure_feedback_coordinator"
    case failureFeedbackActions = "failure_feedback_actions"
    case mediaSendCoordinator = "media_send_coordinator"
    case mediaProgressPresenter = "media_progress_presenter"
    case textSendCoordinator = "text_send_coordinator"
    case mediaMessageSendCoordinator = "media_message_send_coordinator"
    case messageActionCoordinator = "message_action_coordinator"
    case messageFlowCoordinator = "message_flow_coordinator"
}

struct DemoAlignedChatAssemblyContextFailureDependencies {
    let chatContextProvider: DemoAlignedChatContextProvider
    let failureFeedbackActions: DemoAlignedFailureFeedbackActions
}

struct DemoAlignedChatAssemblyMediaCoordinatorDependencies {
    let mediaProgressPresenter: DemoAlignedMediaSendProgressPresenter
    let chatContextProvider: DemoAlignedChatContextProvider
    let failureFeedbackActions: DemoAlignedFailureFeedbackActions
}

struct DemoAlignedChatAssemblyDependencyResolver {
    private let conversationIDProvider: () -> String

    init(conversationIDProvider: @escaping () -> String) {
        self.conversationIDProvider = conversationIDProvider
    }

    func makeMissingDependencyReporter(
        for step: DemoAlignedChatAssemblyMissingDependencyStep
    ) -> ([String]) -> Void {
        { [self] dependencies in
            reportMissing(step: step, dependencies: dependencies)
        }
    }

    func reportMissing(
        step: DemoAlignedChatAssemblyMissingDependencyStep,
        dependencies: [String]
    ) {
        reportMissing(step: step.rawValue, dependencies: dependencies)
    }

    func reportMissing(step: String, dependencies: [String]) {
        let missingDependencies = dependencies.joined(separator: ",")
        DemoAlignedChatLogger.assemblyDependencyMissing(
            conversationID: conversationIDProvider(),
            step: step,
            dependencies: missingDependencies
        )
        #if DEBUG
        assertionFailure(
            "Chat assembly dependency missing. step=\(step) dependencies=\(missingDependencies)"
        )
        #endif
    }

    func resolveContextFailureDependencies(
        step: String,
        chatContextProvider: DemoAlignedChatContextProvider?,
        failureFeedbackActions: DemoAlignedFailureFeedbackActions?
    ) -> DemoAlignedChatAssemblyContextFailureDependencies? {
        guard let chatContextProvider, let failureFeedbackActions else {
            reportMissing(
                step: step,
                dependencies: ["chatContextProvider", "failureFeedbackActions"]
            )
            return nil
        }
        return DemoAlignedChatAssemblyContextFailureDependencies(
            chatContextProvider: chatContextProvider,
            failureFeedbackActions: failureFeedbackActions
        )
    }

    func resolveMediaCoordinatorDependencies(
        step: String,
        mediaProgressPresenter: DemoAlignedMediaSendProgressPresenter?,
        chatContextProvider: DemoAlignedChatContextProvider?,
        failureFeedbackActions: DemoAlignedFailureFeedbackActions?
    ) -> DemoAlignedChatAssemblyMediaCoordinatorDependencies? {
        guard let mediaProgressPresenter else {
            reportMissing(
                step: step,
                dependencies: ["mediaProgressPresenter"]
            )
            return nil
        }
        guard let context = resolveContextFailureDependencies(
            step: step,
            chatContextProvider: chatContextProvider,
            failureFeedbackActions: failureFeedbackActions
        ) else {
            return nil
        }
        return DemoAlignedChatAssemblyMediaCoordinatorDependencies(
            mediaProgressPresenter: mediaProgressPresenter,
            chatContextProvider: context.chatContextProvider,
            failureFeedbackActions: context.failureFeedbackActions
        )
    }
}
