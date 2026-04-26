import Foundation

struct OpenIMDemoBaselineChatContext: Equatable {
    let seed: OpenIMDemoBaselineConversationSeed
    let conversationInfo: OpenIMDemoBaselineConversationInfo
    let currentUserInfo: OpenIMDemoBaselineUserInfo?
    let otherUserInfo: OpenIMDemoBaselineFriendInfo?
    let groupInfo: OpenIMDemoBaselineGroupInfo?
}

@MainActor
enum OpenIMDemoBaselineChatContextFactory {
    static func make(
        conversation: Conversation,
        latestMessages: [ChatMessage] = [],
        bridge: OpenIMDemoBaselineIMControllerBridge
    ) -> OpenIMDemoBaselineChatContext {
        let seed = OpenIMDemoBaselineFactory.makeConversationSeed(conversation: conversation)
        let latestMessage = latestMessages.last.map { bridge.messageInfo(from: $0, seed: seed) }

        return OpenIMDemoBaselineChatContext(
            seed: seed,
            conversationInfo: bridge.conversationInfo(
                from: seed,
                unreadCount: conversation.unreadCount,
                latestMessage: latestMessage
            ),
            currentUserInfo: bridge.currentUserInfo(seed: seed),
            otherUserInfo: bridge.otherUserInfo(seed: seed),
            groupInfo: bridge.groupInfo(seed: seed)
        )
    }
}
