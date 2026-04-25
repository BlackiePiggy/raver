import Foundation

struct DemoAlignedChatScreenAssemblyCoordinatorFactoryDependencies {
    let executeAssemblyConfigurationAction: (DemoAlignedChatScreenAssemblyAction) -> Void
    let onUnhandledAction: (DemoAlignedChatScreenAssemblyAction) -> Void
    let onAssembled: () -> Void
}

enum DemoAlignedChatScreenAssemblyCoordinatorFactory {
    @MainActor
    static func make(
        dependencies: DemoAlignedChatScreenAssemblyCoordinatorFactoryDependencies
    ) -> DemoAlignedChatScreenAssemblyCoordinator {
        let actionHandlers = DemoAlignedChatScreenAssemblyActionHandlers(
            dependencies: DemoAlignedChatScreenAssemblyActionHandlerDependenciesFactory.make(
                executeAction: dependencies.executeAssemblyConfigurationAction
            )
        )

        let actionExecutor = DemoAlignedChatScreenAssemblyActionExecutor(
            performUIAction: { action in
                actionHandlers.performUIAction(action)
            },
            performCoordinatorAction: { action in
                actionHandlers.performCoordinatorAction(action)
            },
            onUnhandledAction: { action in
                dependencies.onUnhandledAction(action)
            }
        )

        let plan = DemoAlignedChatScreenAssemblyPlanBuilder.make { action in
            actionExecutor.execute(action)
        }

        return DemoAlignedChatScreenAssemblyCoordinator(
            steps: plan.steps,
            expectedOrder: plan.expectedOrder,
            onAssembled: dependencies.onAssembled
        )
    }
}
