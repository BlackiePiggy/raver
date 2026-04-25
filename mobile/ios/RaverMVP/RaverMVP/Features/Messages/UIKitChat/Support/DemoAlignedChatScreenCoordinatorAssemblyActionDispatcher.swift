import Foundation

struct DemoAlignedChatScreenCoordinatorAssemblyActionDispatcher {
    let performContextAction: (DemoAlignedChatScreenAssemblyAction) -> Bool
    let performMediaAction: (DemoAlignedChatScreenAssemblyAction) -> Bool
    let performScrollAction: (DemoAlignedChatScreenAssemblyAction) -> Bool
    let performMessagePipelineAction: (DemoAlignedChatScreenAssemblyAction) -> Bool
    let performRouteLifecycleAction: (DemoAlignedChatScreenAssemblyAction) -> Bool

    func execute(_ action: DemoAlignedChatScreenAssemblyAction) -> Bool {
        if performContextAction(action) { return true }
        if performMediaAction(action) { return true }
        if performScrollAction(action) { return true }
        if performMessagePipelineAction(action) { return true }
        if performRouteLifecycleAction(action) { return true }
        return false
    }
}
