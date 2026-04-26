import Foundation

enum OpenIMDemoBaselineReceiveMessageOpt: Int, Codable, Equatable {
    case receive = 0
    case notReceive = 1
    case notNotify = 2
}

enum OpenIMDemoBaselineConversationType: Int, Codable, Equatable {
    case undefine = 0
    case c2c = 1
    case superGroup = 3
    case notification = 4
}

enum OpenIMDemoBaselineMessageStatus: Int, Codable, Equatable {
    case undefine = 0
    case sending = 1
    case sendSuccess = 2
    case sendFailure = 3
    case deleted = 4
    case revoke = 5
}

enum OpenIMDemoBaselineMessageContentType: Int, Codable, Equatable {
    case unknown = -1
    case text = 101
    case image = 102
    case audio = 103
    case video = 104
    case file = 105
    case custom = 110
    case typing = 113
}

struct OpenIMDemoBaselineUserInfo: Codable, Equatable {
    var userID: String
    var nickname: String?
    var remark: String?
    var faceURL: String?
}

struct OpenIMDemoBaselineFriendInfo: Codable, Equatable {
    var userID: String
    var nickname: String?
    var faceURL: String?
    var ownerUserID: String?
    var remark: String?
}

struct OpenIMDemoBaselineGroupInfo: Codable, Equatable {
    var groupID: String
    var groupName: String?
    var faceURL: String?
    var ownerUserID: String?
    var memberCount: Int
}

struct OpenIMDemoBaselineGroupMemberInfo: Codable, Equatable {
    var userID: String
    var groupID: String?
    var nickname: String?
    var faceURL: String?
}

struct OpenIMDemoBaselineMessageMediaPayload: Codable, Equatable {
    var mediaURL: String?
    var thumbnailURL: String?
    var width: Double?
    var height: Double?
    var durationSeconds: Int?
    var fileName: String?
    var fileSizeBytes: Int?
}

struct OpenIMDemoBaselineMessageInfo: Codable, Equatable, Identifiable {
    var id: String { clientMsgID }

    var clientMsgID: String
    var serverMsgID: String?
    var createTime: TimeInterval
    var sendTime: TimeInterval
    var sessionType: OpenIMDemoBaselineConversationType
    var sendID: String
    var recvID: String?
    var contentType: OpenIMDemoBaselineMessageContentType
    var senderNickname: String?
    var senderFaceURL: String?
    var groupID: String?
    var content: String?
    var media: OpenIMDemoBaselineMessageMediaPayload?
    var isRead: Bool
    var status: OpenIMDemoBaselineMessageStatus
    var isAnchor: Bool = false
}

struct OpenIMDemoBaselineConversationInfo: Codable, Equatable, Identifiable {
    var id: String { conversationID }

    var conversationID: String
    var userID: String?
    var groupID: String?
    var showName: String?
    var faceURL: String?
    var recvMsgOpt: OpenIMDemoBaselineReceiveMessageOpt
    var unreadCount: Int
    var conversationType: OpenIMDemoBaselineConversationType
    var latestMsgSendTime: Int
    var draftText: String?
    var draftTextTime: Int
    var isPinned: Bool
    var latestMsg: OpenIMDemoBaselineMessageInfo?
}

extension OpenIMDemoBaselineConversationType {
    init(sessionKind: OpenIMDemoBaselineConversationSeed.SessionKind) {
        switch sessionKind {
        case .direct:
            self = .c2c
        case .group:
            self = .superGroup
        }
    }
}

extension OpenIMDemoBaselineMessageContentType {
    init(kind: ChatMessageKind) {
        switch kind {
        case .text:
            self = .text
        case .image:
            self = .image
        case .video:
            self = .video
        case .voice:
            self = .audio
        case .file:
            self = .file
        case .typing:
            self = .typing
        case .custom, .emoji, .location, .card, .system, .unknown:
            self = .custom
        }
    }
}

extension OpenIMDemoBaselineMessageStatus {
    init(deliveryStatus: ChatMessageDeliveryStatus) {
        switch deliveryStatus {
        case .sending:
            self = .sending
        case .sent:
            self = .sendSuccess
        case .failed:
            self = .sendFailure
        }
    }
}
