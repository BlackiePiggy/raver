import Foundation
import UIKit
import OUICore

@MainActor
enum OpenIMDemoBaselineFactory {
    static let imControllerBridge: OpenIMDemoBaselineIMControllerBridge =
        OpenIMDemoBaselineRaverIMControllerBridge.shared
    static let dataProviderBridge: OpenIMDemoBaselineDataProviderBridge =
        OpenIMDemoBaselineRaverDataProviderBridge.shared
    static let dataProviderEventBridge: OpenIMDemoBaselineDataProviderEventBridge =
        OpenIMDemoBaselineInMemoryDataProviderEventBridge.shared
    static let dataProviderEventPump: OpenIMDemoBaselineRaverDataProviderEventPump =
        OpenIMDemoBaselineRaverDataProviderEventPump.shared
    static let chatViewControllerBuilder = ChatViewControllerBuilder()

    static func makeConversationSeed(
        conversation: Conversation
    ) -> OpenIMDemoBaselineConversationSeed {
        OpenIMDemoBaselineConversationSeedFactory.make(
            from: conversation,
            session: .shared
        )
    }

    static func makeBuilderEntryViewController(
        conversation: Conversation,
        latestMessages: [ChatMessage] = [],
        hiddenInputBar: Bool = false
    ) -> UIViewController {
        _ = dataProviderEventPump
        let context = makeChatContext(
            conversation: conversation,
            latestMessages: latestMessages
        )
        let conversationInfo = OpenIMDemoBaselineOUICoreAdapter.conversationInfo(
            from: context.conversationInfo
        )
        let anchorMessage = latestMessages.last.map {
            OpenIMDemoBaselineOUICoreAdapter.messageInfo(
                from: imControllerBridge.messageInfo(from: $0, seed: context.seed)
            )
        }
        return chatViewControllerBuilder.build(
            conversationInfo,
            anchorMessage: anchorMessage,
            hiddenInputBar: hiddenInputBar
        )
    }

    static func makeChatContext(
        conversation: Conversation,
        latestMessages: [ChatMessage] = []
    ) -> OpenIMDemoBaselineChatContext {
        OpenIMDemoBaselineChatContextFactory.make(
            conversation: conversation,
            latestMessages: latestMessages,
            bridge: imControllerBridge
        )
    }
}
