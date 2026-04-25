import Foundation

@MainActor
struct DemoAlignedChatScreenAssemblyActionExecutor {
    let performUIAction: (DemoAlignedChatScreenAssemblyAction) -> Bool
    let performCoordinatorAction: (DemoAlignedChatScreenAssemblyAction) -> Bool
    let onUnhandledAction: (DemoAlignedChatScreenAssemblyAction) -> Void

    func execute(_ action: DemoAlignedChatScreenAssemblyAction) {
        if performUIAction(action) { return }
        if performCoordinatorAction(action) { return }
        onUnhandledAction(action)
    }
}
