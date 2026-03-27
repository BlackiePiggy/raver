import Foundation

enum ConversationType: String, Codable, CaseIterable, Identifiable {
    case direct
    case group

    var id: String { rawValue }
    var title: String {
        switch self {
        case .direct: return "私信"
        case .group: return "小队"
        }
    }
}

struct Session: Codable {
    let token: String
    let user: UserSummary
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
    var location: String? = nil
    var squad: PostSquad?
    var createdAt: Date
    var likeCount: Int
    var repostCount: Int
    var commentCount: Int
    var isLiked: Bool
    var isReposted: Bool
}

struct PostSquad: Codable, Hashable, Identifiable {
    let id: String
    var name: String
    var avatarURL: String?
}

struct Comment: Codable, Identifiable, Hashable {
    let id: String
    let postID: String
    var author: UserSummary
    var content: String
    var createdAt: Date
}

struct Conversation: Codable, Identifiable, Hashable {
    let id: String
    var type: ConversationType
    var title: String
    var avatarURL: String?
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

struct ChatMessage: Codable, Identifiable, Hashable {
    let id: String
    let conversationID: String
    var sender: UserSummary
    var content: String
    var createdAt: Date
    var isMine: Bool
}

struct FeedPage: Codable {
    let posts: [Post]
    let nextCursor: String?
}

struct FollowListPage: Codable {
    let users: [UserSummary]
    let nextCursor: String?
}

struct CreatePostInput: Codable {
    let content: String
    let images: [String]
    var location: String?

    init(content: String, images: [String], location: String? = nil) {
        self.content = content
        self.images = images
        self.location = location
    }
}

struct UpdatePostInput: Codable {
    let content: String
    let images: [String]
    var location: String?

    init(content: String, images: [String], location: String? = nil) {
        self.content = content
        self.images = images
        self.location = location
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
        case .follow: return "关注"
        case .like: return "点赞"
        case .comment: return "评论"
        case .squadInvite: return "小队邀请"
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
        raverNewsValue(for: ["标题", "title"]) ?? "未命名资讯"
    }

    var raverNewsSource: String {
        raverNewsValue(for: ["来源", "source"]) ?? "社区投稿"
    }

    var raverNewsSummary: String {
        raverNewsValue(for: ["摘要", "summary"]) ?? "暂无摘要"
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
