import Foundation

@MainActor
protocol OpenIMDemoBaselineIMControllerBridge: AnyObject {
    var currentUserID: String? { get }

    func currentUserInfo(seed: OpenIMDemoBaselineConversationSeed) -> OpenIMDemoBaselineUserInfo?
    func conversationInfo(
        from seed: OpenIMDemoBaselineConversationSeed,
        unreadCount: Int,
        latestMessage: OpenIMDemoBaselineMessageInfo?
    ) -> OpenIMDemoBaselineConversationInfo
    func otherUserInfo(seed: OpenIMDemoBaselineConversationSeed) -> OpenIMDemoBaselineFriendInfo?
    func groupInfo(seed: OpenIMDemoBaselineConversationSeed) -> OpenIMDemoBaselineGroupInfo?
    func groupMembers(
        seed: OpenIMDemoBaselineConversationSeed,
        userIDs: [String]?
    ) async -> [OpenIMDemoBaselineGroupMemberInfo]
    func messageInfo(
        from message: ChatMessage,
        seed: OpenIMDemoBaselineConversationSeed
    ) -> OpenIMDemoBaselineMessageInfo
    func messageInfos(
        from messages: [ChatMessage],
        seed: OpenIMDemoBaselineConversationSeed
    ) -> [OpenIMDemoBaselineMessageInfo]
}
