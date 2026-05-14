import Foundation
import UIKit

struct DemoAlignedChatRouteCoordinatorFactoryDependencies {
    let presenter: UIViewController
    let conversation: Conversation
    let repository: ChatSettingsRepository
    let onNavigate: ((AppRoute) -> Void)?
    let onLeaveConversation: (() -> Void)?
}

enum DemoAlignedChatRouteCoordinatorFactory {
    @MainActor
    static func make(
        dependencies: DemoAlignedChatRouteCoordinatorFactoryDependencies
    ) -> DemoAlignedChatRouteCoordinator {
        DemoAlignedChatRouteCoordinator(
            presenter: dependencies.presenter,
            conversation: dependencies.conversation,
            repository: dependencies.repository,
            onNavigate: dependencies.onNavigate,
            onLeaveConversation: dependencies.onLeaveConversation
        )
    }
}
