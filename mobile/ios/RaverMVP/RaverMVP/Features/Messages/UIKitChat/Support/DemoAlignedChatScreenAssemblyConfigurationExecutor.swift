import Foundation

@MainActor
struct DemoAlignedChatScreenAssemblyConfigurationExecutor {
    private let dispatcherBundle: DemoAlignedChatScreenAssemblyActionDispatcherBundle
    private let coordinatorDispatcher: DemoAlignedChatScreenCoordinatorAssemblyActionDispatcher
    private let onUnhandledAction: (DemoAlignedChatScreenAssemblyAction) -> Void

    init(
        dispatcherBundle: DemoAlignedChatScreenAssemblyActionDispatcherBundle,
        onUnhandledAction: @escaping (DemoAlignedChatScreenAssemblyAction) -> Void
    ) {
        self.dispatcherBundle = dispatcherBundle
        self.onUnhandledAction = onUnhandledAction
        self.coordinatorDispatcher = DemoAlignedChatScreenCoordinatorAssemblyActionDispatcher(
            performContextAction: { action in
                dispatcherBundle.coordinatorContext.execute(action)
            },
            performMediaAction: { action in
                dispatcherBundle.coordinatorMedia.execute(action)
            },
            performScrollAction: { action in
                dispatcherBundle.coordinatorScroll.execute(action)
            },
            performMessagePipelineAction: { action in
                dispatcherBundle.coordinatorMessagePipeline.execute(action)
            },
            performRouteLifecycleAction: { action in
                dispatcherBundle.coordinatorRouteLifecycle.execute(action)
            }
        )
    }

    func execute(_ action: DemoAlignedChatScreenAssemblyAction) {
        if dispatcherBundle.ui.execute(action) { return }
        if coordinatorDispatcher.execute(action) { return }
        onUnhandledAction(action)
    }
}

struct DemoAlignedChatScreenAssemblyConfigurationExecutorFactoryDependencies {
    let dispatcherBundleDependencies: DemoAlignedChatScreenAssemblyActionDispatcherBundleDependencies
    let onUnhandledAction: (DemoAlignedChatScreenAssemblyAction) -> Void
}

enum DemoAlignedChatScreenAssemblyConfigurationExecutorFactory {
    @MainActor
    static func make(
        dependencies: DemoAlignedChatScreenAssemblyConfigurationExecutorFactoryDependencies
    ) -> DemoAlignedChatScreenAssemblyConfigurationExecutor {
        let dispatcherBundle = DemoAlignedChatScreenAssemblyActionDispatcherBundleFactory.make(
            dependencies: dependencies.dispatcherBundleDependencies
        )
        return DemoAlignedChatScreenAssemblyConfigurationExecutor(
            dispatcherBundle: dispatcherBundle,
            onUnhandledAction: dependencies.onUnhandledAction
        )
    }
}
