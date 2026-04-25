import Foundation

struct DemoAlignedFailureFeedbackActionsFactoryDependencies {
    let coordinator: DemoAlignedMessageFailureFeedbackCoordinator?
    let onMissingDependencies: ([String]) -> Void
}

enum DemoAlignedFailureFeedbackActionsFactory {
    @MainActor
    static func make(
        dependencies: DemoAlignedFailureFeedbackActionsFactoryDependencies
    ) -> DemoAlignedFailureFeedbackActions? {
        guard let coordinator = dependencies.coordinator else {
            dependencies.onMissingDependencies(["messageFailureFeedbackCoordinator"])
            return nil
        }
        return DemoAlignedFailureFeedbackActions(coordinator: coordinator)
    }
}
