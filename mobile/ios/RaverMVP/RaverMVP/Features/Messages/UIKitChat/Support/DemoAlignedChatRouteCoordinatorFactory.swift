import Foundation
import UIKit

struct DemoAlignedChatRouteCoordinatorFactoryDependencies {
    let presenter: UIViewController
    let conversation: Conversation
    let service: SocialService
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
            service: dependencies.service,
            onNavigate: dependencies.onNavigate,
            onLeaveConversation: dependencies.onLeaveConversation
        )
    }
}
