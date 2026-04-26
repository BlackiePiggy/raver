import Foundation
import OUICore

enum OpenIMDemoBaselineOUICoreAdapter {
    static func conversationInfo(
        from conversation: OpenIMDemoBaselineConversationInfo,
        isInGroup: Bool = true
    ) -> ConversationInfo {
        let payload: [String: Any?] = [
            "conversationID": conversation.conversationID,
            "userID": conversation.userID,
            "groupID": conversation.groupID,
            "showName": conversation.showName,
            "faceURL": conversation.faceURL,
            "recvMsgOpt": conversation.recvMsgOpt.rawValue,
            "unreadCount": conversation.unreadCount,
            "conversationType": conversation.conversationType.rawValue,
            "latestMsgSendTime": conversation.latestMsgSendTime,
            "draftText": conversation.draftText,
            "draftTextTime": conversation.draftTextTime,
            "isPinned": conversation.isPinned,
            "latestMsg": conversation.latestMsg.map(messagePayload),
            "groupAtType": 0,
            "ex": nil,
            "isPrivateChat": false,
            "burnDuration": 30.0,
            "isMsgDestruct": false,
            "msgDestructTime": 0.0,
            "isNotInGroup": !isInGroup,
        ]
        return decode(ConversationInfo.self, from: payload)
    }

    static func messageInfo(from message: OpenIMDemoBaselineMessageInfo) -> MessageInfo {
        decode(MessageInfo.self, from: messagePayload(message))
    }

    private static func messagePayload(_ message: OpenIMDemoBaselineMessageInfo) -> [String: Any?] {
        let media = message.media
        let picturePayload: [String: Any?] = [
            "sourcePath": nil,
            "sourcePicture": pictureInfoPayload(
                url: media?.mediaURL,
                width: media?.width,
                height: media?.height,
                size: media?.fileSizeBytes
            ),
            "bigPicture": pictureInfoPayload(
                url: media?.mediaURL,
                width: media?.width,
                height: media?.height,
                size: media?.fileSizeBytes
            ),
            "snapshotPicture": pictureInfoPayload(
                url: media?.thumbnailURL ?? media?.mediaURL,
                width: media?.width,
                height: media?.height,
                size: media?.fileSizeBytes
            ),
        ]

        let payload: [String: Any?] = [
            "clientMsgID": message.clientMsgID,
            "serverMsgID": message.serverMsgID,
            "createTime": message.createTime,
            "sendTime": message.sendTime,
            "sessionType": message.sessionType.rawValue,
            "sendID": message.sendID,
            "recvID": message.recvID,
            "handleMsg": nil,
            "msgFrom": 100,
            "contentType": message.contentType.rawValue,
            "senderPlatformID": 1,
            "senderNickname": message.senderNickname,
            "senderFaceUrl": message.senderFaceURL,
            "groupID": message.groupID,
            "content": message.content,
            "seq": 0,
            "isRead": message.isRead,
            "status": message.status.rawValue,
            "attachedInfo": nil,
            "ex": nil,
            "localEx": nil,
            "offlinePushInfo": [
                "title": nil,
                "desc": nil,
                "iOSPushSound": nil,
                "iOSBadgeCount": false,
                "operatorUserID": nil,
                "ex": nil,
            ],
            "textElem": message.contentType == .text ? ["content": message.content] : nil,
            "pictureElem": message.contentType == .image ? picturePayload : nil,
            "soundElem": message.contentType == .audio ? [
                "uuID": nil,
                "soundPath": nil,
                "sourceUrl": media?.mediaURL,
                "dataSize": media?.fileSizeBytes ?? 0,
                "duration": media?.durationSeconds ?? 0,
            ] : nil,
            "videoElem": message.contentType == .video ? [
                "videoUUID": nil,
                "videoPath": nil,
                "videoUrl": media?.mediaURL,
                "videoType": "video/mp4",
                "videoSize": media?.fileSizeBytes ?? 0,
                "duration": media?.durationSeconds ?? 0,
                "snapshotPath": nil,
                "snapshotUUID": nil,
                "snapshotSize": media?.fileSizeBytes ?? 0,
                "snapshotUrl": media?.thumbnailURL,
                "snapshotWidth": media?.width ?? 0,
                "snapshotHeight": media?.height ?? 0,
            ] : nil,
            "fileElem": message.contentType == .file ? [
                "filePath": nil,
                "uuID": nil,
                "sourceUrl": media?.mediaURL,
                "fileName": media?.fileName,
                "fileSize": media?.fileSizeBytes ?? 0,
            ] : nil,
            "mergeElem": nil,
            "atTextElem": nil,
            "locationElem": nil,
            "quoteElem": nil,
            "customElem": nil,
            "notificationElem": nil,
            "faceElem": nil,
            "attachedInfoElem": nil,
            "cardElem": nil,
            "typingElem": message.contentType == .typing ? ["msgTips": message.content] : nil,
        ]
        return payload
    }

    private static func pictureInfoPayload(
        url: String?,
        width: Double?,
        height: Double?,
        size: Int?
    ) -> [String: Any?] {
        [
            "uuID": nil,
            "type": nil,
            "size": size ?? 0,
            "width": width ?? 0,
            "height": height ?? 0,
            "url": url,
        ]
    }

    private static func decode<T: Decodable>(_ type: T.Type, from payload: [String: Any?]) -> T {
        let sanitized = sanitize(payload)
        let data = try! JSONSerialization.data(withJSONObject: sanitized)
        return try! JSONDecoder().decode(T.self, from: data)
    }

    private static func sanitize(_ value: Any?) -> Any {
        switch value {
        case nil:
            return NSNull()
        case let dictionary as [String: Any?]:
            return dictionary.mapValues { sanitize($0) }
        case let array as [Any?]:
            return array.map { sanitize($0) }
        default:
            return value as Any
        }
    }

    private static func messageContentType(
        from type: OpenIMDemoBaselineMessageContentType
    ) -> OUICore.MessageContentType {
        switch type {
        case .unknown:
            return .unknown
        case .text:
            return .text
        case .image:
            return .image
        case .audio:
            return .audio
        case .video:
            return .video
        case .file:
            return .file
        case .typing:
            return .typing
        case .custom:
            return .custom
        }
    }
}
