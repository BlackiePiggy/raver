import Foundation

enum ConversationType: String, Codable, CaseIterable, Identifiable {
    case direct
    case group

    var id: String { rawValue }
    var title: String {
        switch self {
        case .direct: return L("私信", "Direct")
        case .group: return L("小队", "Squad")
        }
    }
}

struct Session: Codable {
    let token: String
    let refreshToken: String?
    let user: UserSummary

    init(token: String, refreshToken: String? = nil, user: UserSummary) {
        self.token = token
        self.refreshToken = refreshToken
        self.user = user
    }

    private enum CodingKeys: String, CodingKey {
        case token
        case accessToken
        case refreshToken
        case user
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let tokenValue = try container.decodeIfPresent(String.self, forKey: .token)
            ?? container.decode(String.self, forKey: .accessToken)
        let refreshTokenValue = try container.decodeIfPresent(String.self, forKey: .refreshToken)
        let userValue = try container.decode(UserSummary.self, forKey: .user)

        token = tokenValue
        refreshToken = refreshTokenValue
        user = userValue
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(token, forKey: .token)
        try container.encodeIfPresent(refreshToken, forKey: .refreshToken)
        try container.encode(user, forKey: .user)
    }
}

struct OpenIMBootstrap: Codable {
    let enabled: Bool
    let userID: String
    let token: String?
    let apiURL: String
    let wsURL: String
    let platformID: Int
    let systemUserID: String
    let expiresAt: String?
}

struct UserSummary: Codable, Identifiable, Hashable {
    let id: String
    var username: String
    var displayName: String
    var avatarURL: String?
    var isFollowing: Bool
}

struct UserProfile: Codable, Identifiable {
    let id: String
    var username: String
    var displayName: String
    var bio: String
    var avatarURL: String?
    var tags: [String]
    var isFollowersListPublic: Bool
    var isFollowingListPublic: Bool
    var canViewFollowersList: Bool
    var canViewFollowingList: Bool
    var followersCount: Int
    var followingCount: Int
    var friendsCount: Int
    var postsCount: Int
    var isFollowing: Bool?
}

struct Post: Codable, Identifiable, Hashable {
    let id: String
    var author: UserSummary
    var content: String
    var images: [String]
    var location: String?
    var eventID: String?
    var boundDjIDs: [String]
    var boundBrandIDs: [String]
    var boundEventIDs: [String]
    var squad: PostSquad?
    var createdAt: Date
    var displayPublishedAt: Date?
    var likeCount: Int
    var repostCount: Int
    var saveCount: Int
    var shareCount: Int
    var commentCount: Int
    var isLiked: Bool
    var isReposted: Bool
    var isSaved: Bool
    var isHidden: Bool
    var recommendationReasonCode: String?
    var recommendationReason: String?

    init(
        id: String,
        author: UserSummary,
        content: String,
        images: [String],
        location: String? = nil,
        eventID: String? = nil,
        boundDjIDs: [String] = [],
        boundBrandIDs: [String] = [],
        boundEventIDs: [String] = [],
        squad: PostSquad? = nil,
        createdAt: Date,
        displayPublishedAt: Date? = nil,
        likeCount: Int,
        repostCount: Int,
        saveCount: Int = 0,
        shareCount: Int = 0,
        commentCount: Int,
        isLiked: Bool,
        isReposted: Bool,
        isSaved: Bool = false,
        isHidden: Bool = false,
        recommendationReasonCode: String? = nil,
        recommendationReason: String? = nil
    ) {
        self.id = id
        self.author = author
        self.content = content
        self.images = images
        self.location = location
        self.eventID = eventID
        self.boundDjIDs = boundDjIDs
        self.boundBrandIDs = boundBrandIDs
        self.boundEventIDs = boundEventIDs
        self.squad = squad
        self.createdAt = createdAt
        self.displayPublishedAt = displayPublishedAt
        self.likeCount = likeCount
        self.repostCount = repostCount
        self.saveCount = saveCount
        self.shareCount = shareCount
        self.commentCount = commentCount
        self.isLiked = isLiked
        self.isReposted = isReposted
        self.isSaved = isSaved
        self.isHidden = isHidden
        self.recommendationReasonCode = recommendationReasonCode
        self.recommendationReason = recommendationReason
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case author
        case content
        case images
        case location
        case eventID
        case boundDjIDs
        case boundBrandIDs
        case boundEventIDs
        case squad
        case createdAt
        case displayPublishedAt
        case likeCount
        case repostCount
        case saveCount
        case shareCount
        case commentCount
        case isLiked
        case isReposted
        case isSaved
        case isHidden
        case recommendationReasonCode
        case recommendationReason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        author = try container.decode(UserSummary.self, forKey: .author)
        content = try container.decode(String.self, forKey: .content)
        images = try container.decodeIfPresent([String].self, forKey: .images) ?? []
        location = try container.decodeIfPresent(String.self, forKey: .location)
        eventID = try container.decodeIfPresent(String.self, forKey: .eventID)
        boundDjIDs = try container.decodeIfPresent([String].self, forKey: .boundDjIDs) ?? []
        boundBrandIDs = try container.decodeIfPresent([String].self, forKey: .boundBrandIDs) ?? []
        boundEventIDs = try container.decodeIfPresent([String].self, forKey: .boundEventIDs) ?? []
        squad = try container.decodeIfPresent(PostSquad.self, forKey: .squad)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        displayPublishedAt = try container.decodeIfPresent(Date.self, forKey: .displayPublishedAt)
        likeCount = try container.decodeIfPresent(Int.self, forKey: .likeCount) ?? 0
        repostCount = try container.decodeIfPresent(Int.self, forKey: .repostCount) ?? 0
        saveCount = try container.decodeIfPresent(Int.self, forKey: .saveCount) ?? 0
        shareCount = try container.decodeIfPresent(Int.self, forKey: .shareCount) ?? 0
        commentCount = try container.decodeIfPresent(Int.self, forKey: .commentCount) ?? 0
        isLiked = try container.decodeIfPresent(Bool.self, forKey: .isLiked) ?? false
        isReposted = try container.decodeIfPresent(Bool.self, forKey: .isReposted) ?? false
        isSaved = try container.decodeIfPresent(Bool.self, forKey: .isSaved) ?? false
        isHidden = try container.decodeIfPresent(Bool.self, forKey: .isHidden) ?? false
        recommendationReasonCode = try container.decodeIfPresent(String.self, forKey: .recommendationReasonCode)
        recommendationReason = try container.decodeIfPresent(String.self, forKey: .recommendationReason)
    }
}

struct PostSquad: Codable, Hashable, Identifiable {
    let id: String
    var name: String
    var avatarURL: String?
}

struct Comment: Codable, Identifiable, Hashable {
    let id: String
    let postID: String
    var parentCommentID: String?
    var rootCommentID: String?
    var depth: Int
    var author: UserSummary
    var replyToAuthor: UserSummary?
    var content: String
    var createdAt: Date

    init(
        id: String,
        postID: String,
        parentCommentID: String? = nil,
        rootCommentID: String? = nil,
        depth: Int = 0,
        author: UserSummary,
        replyToAuthor: UserSummary? = nil,
        content: String,
        createdAt: Date
    ) {
        self.id = id
        self.postID = postID
        self.parentCommentID = parentCommentID
        self.rootCommentID = rootCommentID
        self.depth = depth
        self.author = author
        self.replyToAuthor = replyToAuthor
        self.content = content
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case postID
        case parentCommentID
        case rootCommentID
        case depth
        case author
        case replyToAuthor
        case content
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        postID = try container.decode(String.self, forKey: .postID)
        parentCommentID = try container.decodeIfPresent(String.self, forKey: .parentCommentID)
        rootCommentID = try container.decodeIfPresent(String.self, forKey: .rootCommentID)
        depth = try container.decodeIfPresent(Int.self, forKey: .depth) ?? 0
        author = try container.decode(UserSummary.self, forKey: .author)
        replyToAuthor = try container.decodeIfPresent(UserSummary.self, forKey: .replyToAuthor)
        content = try container.decode(String.self, forKey: .content)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}

struct Conversation: Codable, Identifiable, Hashable {
    let id: String
    var type: ConversationType
    var title: String
    var avatarURL: String?
    var openIMConversationID: String? = nil
    var lastMessage: String
    var lastMessageSenderID: String?
    var unreadCount: Int
    var updatedAt: Date
    var peer: UserSummary?

    var previewText: String {
        if let sender = lastMessageSenderID, !sender.isEmpty {
            return "\(sender): \(lastMessage)"
        }
        return lastMessage
    }
}

enum ChatMessageKind: String, Codable, Hashable, CaseIterable {
    case text
    case image
    case video
    case voice
    case file
    case emoji
    case location
    case card
    case custom
    case system
    case typing
    case unknown
}

enum ChatMessageDeliveryStatus: String, Codable, Hashable, CaseIterable {
    case sending
    case sent
    case failed
}

struct ChatMessageMediaPayload: Codable, Hashable {
    var mediaURL: String? = nil
    var thumbnailURL: String? = nil
    var width: Double? = nil
    var height: Double? = nil
    var durationSeconds: Int? = nil
    var fileName: String? = nil
    var fileSizeBytes: Int? = nil
}

struct ChatMessage: Codable, Identifiable, Hashable {
    let id: String
    let conversationID: String
    var sender: UserSummary
    var content: String
    var createdAt: Date
    var isMine: Bool
    var kind: ChatMessageKind = .text
    var media: ChatMessageMediaPayload? = nil
    var deliveryStatus: ChatMessageDeliveryStatus = .sent
    var deliveryError: String? = nil

    init(
        id: String,
        conversationID: String,
        sender: UserSummary,
        content: String,
        createdAt: Date,
        isMine: Bool,
        kind: ChatMessageKind = .text,
        media: ChatMessageMediaPayload? = nil,
        deliveryStatus: ChatMessageDeliveryStatus = .sent,
        deliveryError: String? = nil
    ) {
        self.id = id
        self.conversationID = conversationID
        self.sender = sender
        self.content = content
        self.createdAt = createdAt
        self.isMine = isMine
        self.kind = kind
        self.media = media
        self.deliveryStatus = deliveryStatus
        self.deliveryError = deliveryError
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case conversationID
        case sender
        case content
        case createdAt
        case isMine
        case kind
        case media
        case deliveryStatus
        case deliveryError
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        conversationID = try container.decode(String.self, forKey: .conversationID)
        sender = try container.decode(UserSummary.self, forKey: .sender)
        content = try container.decode(String.self, forKey: .content)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        isMine = try container.decode(Bool.self, forKey: .isMine)
        kind = try container.decodeIfPresent(ChatMessageKind.self, forKey: .kind) ?? .text
        media = try container.decodeIfPresent(ChatMessageMediaPayload.self, forKey: .media)
        deliveryStatus = try container.decodeIfPresent(ChatMessageDeliveryStatus.self, forKey: .deliveryStatus) ?? .sent
        deliveryError = try container.decodeIfPresent(String.self, forKey: .deliveryError)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(conversationID, forKey: .conversationID)
        try container.encode(sender, forKey: .sender)
        try container.encode(content, forKey: .content)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(isMine, forKey: .isMine)
        try container.encode(kind, forKey: .kind)
        try container.encodeIfPresent(media, forKey: .media)
        try container.encode(deliveryStatus, forKey: .deliveryStatus)
        try container.encodeIfPresent(deliveryError, forKey: .deliveryError)
    }
}

struct FeedPage: Codable {
    let posts: [Post]
    let nextCursor: String?
}

struct FeedEventInput: Codable {
    let sessionID: String
    let eventType: String
    var postID: String?
    var feedMode: FeedMode?
    var position: Int?
    var metadata: [String: String]?

    private enum CodingKeys: String, CodingKey {
        case sessionID = "sessionId"
        case eventType
        case postID
        case feedMode
        case position
        case metadata
    }
}

struct FollowListPage: Codable {
    let users: [UserSummary]
    let nextCursor: String?
}

struct CreatePostInput: Codable {
    let content: String
    let images: [String]
    var location: String?
    var boundDjIDs: [String]
    var boundBrandIDs: [String]
    var boundEventIDs: [String]

    init(
        content: String,
        images: [String],
        location: String? = nil,
        boundDjIDs: [String] = [],
        boundBrandIDs: [String] = [],
        boundEventIDs: [String] = []
    ) {
        self.content = content
        self.images = images
        self.location = location
        self.boundDjIDs = boundDjIDs
        self.boundBrandIDs = boundBrandIDs
        self.boundEventIDs = boundEventIDs
    }
}

struct UpdatePostInput: Codable {
    let content: String
    let images: [String]
    var location: String?
    var boundDjIDs: [String]?
    var boundBrandIDs: [String]?
    var boundEventIDs: [String]?

    init(
        content: String,
        images: [String],
        location: String? = nil,
        boundDjIDs: [String]? = nil,
        boundBrandIDs: [String]? = nil,
        boundEventIDs: [String]? = nil
    ) {
        self.content = content
        self.images = images
        self.location = location
        self.boundDjIDs = boundDjIDs
        self.boundBrandIDs = boundBrandIDs
        self.boundEventIDs = boundEventIDs
    }
}

struct UpdateMyProfileInput: Codable {
    var displayName: String
    var bio: String
    var tags: [String]
    var isFollowersListPublic: Bool
    var isFollowingListPublic: Bool
}

struct AvatarUploadResponse: Codable {
    let avatarURL: String
}

struct ActivityPostItem: Codable, Identifiable, Hashable {
    var actionAt: Date
    var post: Post

    var id: String {
        "\(post.id)_\(actionAt.timeIntervalSince1970)"
    }
}

struct ActivityPostPage: Codable {
    let items: [ActivityPostItem]
    let nextCursor: String?
}

struct SquadSummary: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var description: String?
    var avatarURL: String?
    var bannerURL: String?
    var isPublic: Bool
    var memberCount: Int
    var isMember: Bool
    var lastMessage: String?
    var updatedAt: Date
}

struct SquadMessagePreview: Codable, Identifiable, Hashable {
    let id: String
    var content: String
    var createdAt: Date
    var sender: UserSummary
}

struct SquadMemberProfile: Codable, Identifiable, Hashable {
    let id: String
    var username: String
    var displayName: String
    var avatarURL: String?
    var isFollowing: Bool
    var role: String
    var nickname: String?
    var isCaptain: Bool
    var isAdmin: Bool

    var shownName: String {
        let trimmed = nickname?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? displayName : trimmed
    }
}

struct SquadActivityItem: Codable, Identifiable, Hashable {
    let id: String
    var title: String
    var description: String?
    var location: String?
    var date: Date
    var createdBy: UserSummary
}

struct SquadProfile: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var description: String?
    var avatarURL: String?
    var bannerURL: String?
    var notice: String
    var qrCodeURL: String?
    var isPublic: Bool
    var maxMembers: Int
    var memberCount: Int
    var isMember: Bool
    var canEditGroup: Bool
    var myRole: String?
    var myNickname: String?
    var myNotificationsEnabled: Bool?
    var leader: UserSummary
    var members: [SquadMemberProfile]
    var lastMessage: String?
    var updatedAt: Date
    var recentMessages: [SquadMessagePreview]
    var activities: [SquadActivityItem]
}

struct UpdateSquadMySettingsInput: Codable {
    var nickname: String?
    var notificationsEnabled: Bool
}

struct UpdateSquadInfoInput: Codable {
    var name: String
    var description: String
    var isPublic: Bool?
    var avatarURL: String?
    var bannerURL: String?
    var notice: String
    var qrCodeURL: String?
}

struct CreateSquadInput: Codable {
    var name: String?
    var description: String?
    var isPublic: Bool
    var bannerURL: String?
    var memberIds: [String]
}

enum AppNotificationType: String, Codable, Hashable {
    case follow
    case like
    case comment
    case squadInvite = "squad_invite"

    var title: String {
        switch self {
        case .follow: return L("关注", "Follow")
        case .like: return L("点赞", "Like")
        case .comment: return L("评论", "Comment")
        case .squadInvite: return L("小队邀请", "Squad Invite")
        }
    }

    var iconName: String {
        switch self {
        case .follow: return "person.badge.plus"
        case .like: return "heart.fill"
        case .comment: return "text.bubble.fill"
        case .squadInvite: return "person.3.fill"
        }
    }
}

struct AppNotificationTarget: Codable, Hashable {
    var type: String
    var id: String
    var title: String?
}

struct AppNotification: Codable, Identifiable, Hashable {
    let id: String
    var type: AppNotificationType
    var createdAt: Date
    var isRead: Bool
    var actor: UserSummary?
    var text: String
    var target: AppNotificationTarget?
}

struct NotificationInbox: Codable {
    var unreadCount: Int
    var items: [AppNotification]
}

struct NotificationUnreadCount: Codable {
    var total: Int
    var follows: Int
    var likes: Int
    var comments: Int
    var squadInvites: Int
}

extension Post {
    static let raverNewsMarker = "#RAVER_NEWS"

    var isRaverNews: Bool {
        content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .contains(Self.raverNewsMarker)
    }

    var raverNewsTitle: String {
        raverNewsValue(for: ["标题", "title"]) ?? L("未命名资讯", "Untitled News")
    }

    var raverNewsSource: String {
        raverNewsValue(for: ["来源", "source"]) ?? L("社区投稿", "Community Submission")
    }

    var raverNewsSummary: String {
        raverNewsValue(for: ["摘要", "summary"]) ?? L("暂无摘要", "No Summary")
    }

    private func raverNewsValue(for keys: [String]) -> String? {
        let lines = content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for line in lines {
            for key in keys {
                let prefixes = ["\(key)：", "\(key):", "\(key.uppercased())：", "\(key.uppercased()):"]
                if let prefix = prefixes.first(where: { line.hasPrefix($0) }) {
                    let value = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !value.isEmpty {
                        return value
                    }
                }
            }
        }

        return nil
    }
}
