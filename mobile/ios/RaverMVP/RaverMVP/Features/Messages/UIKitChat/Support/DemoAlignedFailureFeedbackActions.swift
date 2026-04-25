import Foundation

@MainActor
final class DemoAlignedFailureFeedbackActions {
    private weak var coordinator: DemoAlignedMessageFailureFeedbackCoordinator?

    init(coordinator: DemoAlignedMessageFailureFeedbackCoordinator) {
        self.coordinator = coordinator
    }

    func showSendFailureHint() {
        coordinator?.showSendFailureHint()
    }

    func show(message: String, reason: String) {
        coordinator?.show(message: message, reason: reason)
    }

    func reset() {
        coordinator?.reset()
    }
}
