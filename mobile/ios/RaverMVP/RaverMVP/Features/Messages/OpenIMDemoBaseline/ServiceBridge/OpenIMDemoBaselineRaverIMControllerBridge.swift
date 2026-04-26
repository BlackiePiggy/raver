import Foundation

@MainActor
final class OpenIMDemoBaselineRaverIMControllerBridge: OpenIMDemoBaselineIMControllerBridge {
    static let shared = OpenIMDemoBaselineRaverIMControllerBridge(session: .shared)

    private let session: OpenIMSession

    init(session: OpenIMSession) {
        self.session = session
    }

    var currentUserID: String? {
        session.currentBusinessUserIDSnapshot()
    }

    func currentUserInfo(seed: OpenIMDemoBaselineConversationSeed) -> OpenIMDemoBaselineUserInfo? {
        guard let userID = seed.currentUserID ?? currentUserID else {
            return nil
        }

        return OpenIMDemoBaselineUserInfo(
            userID: userID,
            nickname: userID,
            remark: nil,
            faceURL: nil
        )
    }

    func conversationInfo(
        from seed: OpenIMDemoBaselineConversationSeed,
        unreadCount: Int = 0,
        latestMessage: OpenIMDemoBaselineMessageInfo? = nil
    ) -> OpenIMDemoBaselineConversationInfo {
        OpenIMDemoBaselineConversationInfo(
            conversationID: seed.openIMConversationID ?? seed.businessConversationID,
            userID: seed.peerUserID,
            groupID: seed.groupID,
            showName: seed.title,
            faceURL: seed.faceURL,
            recvMsgOpt: .receive,
            unreadCount: unreadCount,
            conversationType: .init(sessionKind: seed.sessionKind),
            latestMsgSendTime: Int(latestMessage?.sendTime ?? 0),
            draftText: nil,
            draftTextTime: 0,
            isPinned: false,
            latestMsg: latestMessage
        )
    }

    func otherUserInfo(seed: OpenIMDemoBaselineConversationSeed) -> OpenIMDemoBaselineFriendInfo? {
        guard let peerUserID = seed.peerUserID else {
            return nil
        }

        return OpenIMDemoBaselineFriendInfo(
            userID: peerUserID,
            nickname: seed.title,
            faceURL: seed.faceURL,
            ownerUserID: seed.currentUserID ?? currentUserID,
            remark: nil
        )
    }

    func groupInfo(seed: OpenIMDemoBaselineConversationSeed) -> OpenIMDemoBaselineGroupInfo? {
        guard let groupID = seed.groupID else {
            return nil
        }

        return OpenIMDemoBaselineGroupInfo(
            groupID: groupID,
            groupName: seed.title,
            faceURL: seed.faceURL,
            ownerUserID: nil,
            memberCount: 0
        )
    }

    func groupMembers(
        seed: OpenIMDemoBaselineConversationSeed,
        userIDs: [String]? = nil
    ) async -> [OpenIMDemoBaselineGroupMemberInfo] {
        let ids = userIDs ?? []
        return ids.map {
            OpenIMDemoBaselineGroupMemberInfo(
                userID: $0,
                groupID: seed.groupID,
                nickname: $0,
                faceURL: nil
            )
        }
    }

    func messageInfo(
        from message: ChatMessage,
        seed: OpenIMDemoBaselineConversationSeed
    ) -> OpenIMDemoBaselineMessageInfo {
        let receiverID: String?
        switch seed.sessionKind {
        case .direct:
            receiverID = seed.peerUserID
        case .group:
            receiverID = nil
        }

        return OpenIMDemoBaselineMessageInfo(
            clientMsgID: message.id,
            serverMsgID: nil,
            createTime: message.createdAt.timeIntervalSince1970 * 1000,
            sendTime: message.createdAt.timeIntervalSince1970 * 1000,
            sessionType: .init(sessionKind: seed.sessionKind),
            sendID: message.sender.id,
            recvID: receiverID,
            contentType: .init(kind: message.kind),
            senderNickname: message.sender.displayName,
            senderFaceURL: message.sender.avatarURL,
            groupID: seed.groupID,
            content: message.content,
            media: .init(
                mediaURL: message.media?.mediaURL,
                thumbnailURL: message.media?.thumbnailURL,
                width: message.media?.width,
                height: message.media?.height,
                durationSeconds: message.media?.durationSeconds,
                fileName: message.media?.fileName,
                fileSizeBytes: message.media?.fileSizeBytes
            ),
            isRead: !message.isMine || message.deliveryStatus == .sent,
            status: .init(deliveryStatus: message.deliveryStatus)
        )
    }

    func messageInfos(
        from messages: [ChatMessage],
        seed: OpenIMDemoBaselineConversationSeed
    ) -> [OpenIMDemoBaselineMessageInfo] {
        messages.map { messageInfo(from: $0, seed: seed) }
    }
}
