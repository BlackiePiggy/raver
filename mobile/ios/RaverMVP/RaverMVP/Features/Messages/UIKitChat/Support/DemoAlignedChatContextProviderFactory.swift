import Foundation

struct DemoAlignedChatContextProviderFactoryDependencies {
    let conversationIDResolver: () -> String
}

enum DemoAlignedChatContextProviderFactory {
    @MainActor
    static func make(
        dependencies: DemoAlignedChatContextProviderFactoryDependencies
    ) -> DemoAlignedChatContextProvider {
        DemoAlignedChatContextProvider(
            conversationIDResolver: dependencies.conversationIDResolver
        )
    }
}
