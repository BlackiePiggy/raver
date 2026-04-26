import Foundation

@MainActor
protocol OpenIMDemoBaselineDataProviderBridge: AnyObject {
    var currentUserID: String? { get }
    var currentUserInfo: OpenIMDemoBaselineUserInfo? { get }

    func getGroupInfo(
        groupIDs: [String],
        completion: @escaping ([OpenIMDemoBaselineGroupInfo]) -> Void
    )

    func isJoinedGroup(
        groupID: String,
        completion: @escaping (Bool) -> Void
    )

    func getGroupMembersInfo(
        groupID: String,
        userIDs: [String],
        completion: @escaping ([OpenIMDemoBaselineGroupMemberInfo]) -> Void
    )

    func getAllGroupMembers(groupID: String) async -> [OpenIMDemoBaselineGroupMemberInfo]

    func getFriendsInfo(
        userIDs: [String],
        completion: @escaping ([OpenIMDemoBaselineFriendInfo]) -> Void
    )

    func getHistoryMessageList(
        conversationID: String,
        conversationType: OpenIMDemoBaselineConversationType,
        startClientMsgID: String?,
        count: Int,
        completion: @escaping (_ isEnd: Bool, _ messages: [OpenIMDemoBaselineMessageInfo]) -> Void
    )

    func getHistoryMessageListReverse(
        conversationID: String,
        startClientMsgID: String?,
        count: Int,
        completion: @escaping (_ isEnd: Bool, _ messages: [OpenIMDemoBaselineMessageInfo]) -> Void
    )
}

@MainActor
protocol OpenIMDemoBaselineDataProviderEventBridge: AnyObject {
    func observeReceivedMessages(
        _ handler: @escaping (_ messages: [OpenIMDemoBaselineMessageInfo], _ forceReload: Bool) -> Void
    ) -> UUID
    func observeConnectionSyncComplete(_ handler: @escaping () -> Void) -> UUID
    func observeNewMessage(_ handler: @escaping (OpenIMDemoBaselineMessageInfo) -> Void) -> UUID
    func observeGroupMemberInfoChanged(
        _ handler: @escaping (OpenIMDemoBaselineGroupMemberInfo) -> Void
    ) -> UUID
    func observeJoinedGroupAdded(
        _ handler: @escaping (OpenIMDemoBaselineGroupInfo) -> Void
    ) -> UUID
    func observeJoinedGroupDeleted(
        _ handler: @escaping (OpenIMDemoBaselineGroupInfo) -> Void
    ) -> UUID
    func observeFriendInfoChanged(
        _ handler: @escaping (OpenIMDemoBaselineFriendInfo) -> Void
    ) -> UUID
    func observeGroupInfoChanged(
        _ handler: @escaping (OpenIMDemoBaselineGroupInfo) -> Void
    ) -> UUID
    func observeGroupMemberAdded(
        _ handler: @escaping (OpenIMDemoBaselineGroupMemberInfo) -> Void
    ) -> UUID
    func observeGroupMemberDeleted(
        _ handler: @escaping (OpenIMDemoBaselineGroupMemberInfo) -> Void
    ) -> UUID
    func observeTotalUnreadCountChanged(_ handler: @escaping (Int) -> Void) -> UUID
    func observeCurrentUserInfoChanged(
        _ handler: @escaping (OpenIMDemoBaselineUserInfo) -> Void
    ) -> UUID
    func observeIsInGroupChanged(_ handler: @escaping (Bool) -> Void) -> UUID
    func observeConversationChanged(
        _ handler: @escaping ([OpenIMDemoBaselineConversationInfo]) -> Void
    ) -> UUID
    func observeRecordClear(_ handler: @escaping (String) -> Void) -> UUID
    func removeObserver(_ token: UUID)

    func emitConnectionSyncComplete()
    func emitReceived(messages: [OpenIMDemoBaselineMessageInfo], forceReload: Bool)
    func emitIsInGroup(_ isIn: Bool)
    func emitJoinedGroupAdded(_ info: OpenIMDemoBaselineGroupInfo)
    func emitJoinedGroupDeleted(_ info: OpenIMDemoBaselineGroupInfo)
    func emitGroupMemberInfoChanged(_ info: OpenIMDemoBaselineGroupMemberInfo)
    func emitGroupInfoChanged(_ info: OpenIMDemoBaselineGroupInfo)
    func emitFriendInfoChanged(_ info: OpenIMDemoBaselineFriendInfo)
    func emitMyUserInfoChanged(_ info: OpenIMDemoBaselineUserInfo)
    func emitGroupMembersChanged(added: Bool, info: OpenIMDemoBaselineGroupMemberInfo)
    func emitTotalUnreadCountChanged(_ count: Int)
    func emitConversationChanged(_ conversations: [OpenIMDemoBaselineConversationInfo])
    func emitRecordClear(conversationID: String)
}
