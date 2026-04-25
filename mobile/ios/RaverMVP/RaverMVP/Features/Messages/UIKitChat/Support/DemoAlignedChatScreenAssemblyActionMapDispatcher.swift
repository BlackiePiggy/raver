import Foundation

struct DemoAlignedChatScreenAssemblyActionMapDispatcher {
    private let actionMappings: [DemoAlignedChatScreenAssemblyAction: () -> Void]

    init(actionMappings: [DemoAlignedChatScreenAssemblyAction: () -> Void]) {
        self.actionMappings = actionMappings
    }

    func execute(_ action: DemoAlignedChatScreenAssemblyAction) -> Bool {
        guard let mappedAction = actionMappings[action] else { return false }
        mappedAction()
        return true
    }
}
