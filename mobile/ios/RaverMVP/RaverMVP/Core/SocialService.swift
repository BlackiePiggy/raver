import Foundation
import Combine

enum GroupInviteOption: String, Codable, CaseIterable {
    case forbid
    case auth
    case any

    var title: String {
        switch self {
        case .forbid:
            return L("禁止邀请", "Invite Disabled")
        case .auth:
            return L("管理员审批", "Admin Approval")
        case .any:
            return L("自动通过", "Auto Approval")
        }
    }
}

struct GroupMemberDirectory: Codable, Hashable {
    var members: [SquadMemberProfile]
    var myRole: String?
}

// Temporary compatibility zone for surfaces that still return `ChatMessage`.
protocol IMChatCompatibilityService: AnyObject {
    func fetchMessages(conversationID: String) async throws -> [ChatMessage]
    func fetchMessages(
        conversationID: String,
        startClientMsgID: String?,
        count: Int
    ) async throws -> ChatMessageHistoryPage
    func sendMessage(conversationID: String, content: String) async throws -> ChatMessage
    func sendImageMessage(conversationID: String, fileURL: URL) async throws -> ChatMessage
    func sendVideoMessage(conversationID: String, fileURL: URL) async throws -> ChatMessage
    func sendVoiceMessage(conversationID: String, fileURL: URL) async throws -> ChatMessage
    func sendFileMessage(conversationID: String, fileURL: URL) async throws -> ChatMessage
    func sendTypingStatus(conversationID: String, isTyping: Bool) async throws
    func revokeMessage(conversationID: String, messageID: String) async throws -> String
    func deleteMessage(conversationID: String, messageID: String) async throws
}

enum FeedMode: String, Codable, CaseIterable, Identifiable {
    case recommended
    case following
    case latest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recommended: return L("推荐", "Recommended")
        case .following: return L("关注", "Following")
        case .latest: return L("最新", "Latest")
        }
    }
}

protocol SocialService: IMChatConversationDataSource, IMChatCompatibilityService {
    func restoreSession() async -> Session?
    func login(username: String, password: String) async throws -> Session
    func loginWithSms(phoneNumber: String, code: String) async throws -> Session
    func sendLoginSmsCode(phoneNumber: String) async throws -> Int
    func register(username: String, email: String, password: String, displayName: String) async throws -> Session
    func logout() async
    func fetchTencentIMBootstrap() async throws -> TencentIMBootstrap

    func fetchFeed(cursor: String?, mode: FeedMode?) async throws -> FeedPage
    func searchFeed(query: String) async throws -> FeedPage
    func fetchPost(postID: String) async throws -> Post
    func createPost(input: CreatePostInput) async throws -> Post
    func updatePost(postID: String, input: UpdatePostInput) async throws -> Post
    func deletePost(postID: String) async throws
    func toggleLike(postID: String, shouldLike: Bool) async throws -> Post
    func toggleSave(postID: String, shouldSave: Bool) async throws -> Post
    func recordShare(postID: String, channel: String, status: String) async throws -> Post
    func hidePost(postID: String, reason: String?) async throws
    func recordFeedEvent(input: FeedEventInput) async throws

    func fetchComments(postID: String) async throws -> [Comment]
    func addComment(postID: String, content: String, parentCommentID: String?) async throws -> Comment

    func searchUsers(query: String) async throws -> [UserSummary]
    func fetchUserProfile(userID: String) async throws -> UserProfile
    func fetchPostsByUser(userID: String, cursor: String?) async throws -> FeedPage
    func fetchFollowers(userID: String, cursor: String?) async throws -> FollowListPage
    func fetchFollowing(userID: String, cursor: String?) async throws -> FollowListPage
    func fetchFriends(userID: String, cursor: String?) async throws -> FollowListPage

    func fetchConversations(type: ConversationType) async throws -> [Conversation]
    func markConversationRead(conversationID: String) async throws
    func setConversationPinned(conversationID: String, pinned: Bool) async throws
    func markConversationUnread(conversationID: String, unread: Bool) async throws
    func hideConversation(conversationID: String) async throws
    func setConversationMuted(conversationID: String, muted: Bool) async throws
    func clearConversationHistory(conversationID: String) async throws
    func isTencentFriend(userID: String) async throws -> Bool
    func fetchFriendRemark(userID: String) async throws -> String?
    func setFriendRemark(userID: String, remark: String?) async throws
    func isUserBlacklisted(userID: String) async throws -> Bool
    func setUserBlacklisted(userID: String, blacklisted: Bool) async throws
    func startDirectConversation(identifier: String) async throws -> Conversation
    func fetchRecommendedSquads() async throws -> [SquadSummary]
    func fetchMySquads() async throws -> [SquadSummary]
    func fetchSquadProfile(squadID: String) async throws -> SquadProfile
    func joinSquad(squadID: String) async throws
    func leaveSquad(squadID: String) async throws
    func disbandSquad(squadID: String) async throws
    func inviteUserToSquad(squadID: String, inviteeUserID: String) async throws
    func createSquad(input: CreateSquadInput) async throws -> Conversation
    func uploadSquadAvatar(squadID: String, imageData: Data, fileName: String, mimeType: String) async throws -> AvatarUploadResponse
    func updateSquadMySettings(squadID: String, input: UpdateSquadMySettingsInput) async throws
    func updateSquadInfo(squadID: String, input: UpdateSquadInfoInput) async throws
    func updateSquadMemberRole(squadID: String, memberUserID: String, role: String) async throws
    func removeSquadMember(squadID: String, memberUserID: String) async throws
    func fetchSquadInviteOption(squadID: String) async throws -> GroupInviteOption
    func setSquadInviteOption(squadID: String, option: GroupInviteOption) async throws
    func fetchSquadMemberDirectory(squadID: String) async throws -> GroupMemberDirectory
    func fetchNotifications(limit: Int) async throws -> NotificationInbox
    func fetchNotificationUnreadCount() async throws -> NotificationUnreadCount
    func markNotificationRead(notificationID: String) async throws
    func markNotificationsRead(type: AppNotificationType) async throws
    func registerDevicePushToken(
        deviceID: String,
        platform: String,
        pushToken: String,
        appVersion: String?,
        locale: String?
    ) async throws
    func deactivateDevicePushToken(deviceID: String, platform: String) async throws

    func fetchMyProfile() async throws -> UserProfile
    func updateMyProfile(input: UpdateMyProfileInput) async throws -> UserProfile
    func uploadMyAvatar(imageData: Data, fileName: String, mimeType: String) async throws -> AvatarUploadResponse
    func fetchMyLikeHistory(cursor: String?) async throws -> ActivityPostPage
    func fetchMyRepostHistory(cursor: String?) async throws -> ActivityPostPage
    func fetchMySaveHistory(cursor: String?) async throws -> ActivityPostPage
    func toggleFollow(userID: String, shouldFollow: Bool) async throws -> UserSummary
    func toggleRepost(postID: String, shouldRepost: Bool) async throws -> Post
}

extension IMChatCompatibilityService {
    func sendImageMessage(conversationID: String, fileURL: URL) async throws -> ChatMessage {
        _ = fileURL
        throw ServiceError.message("Not supported")
    }

    func sendVideoMessage(conversationID: String, fileURL: URL) async throws -> ChatMessage {
        _ = fileURL
        throw ServiceError.message("Not supported")
    }

    func sendVoiceMessage(conversationID: String, fileURL: URL) async throws -> ChatMessage {
        _ = fileURL
        throw ServiceError.message("Not supported")
    }

    func sendFileMessage(conversationID: String, fileURL: URL) async throws -> ChatMessage {
        _ = fileURL
        throw ServiceError.message("Not supported")
    }

    func sendTypingStatus(conversationID: String, isTyping: Bool) async throws {
        _ = conversationID
        _ = isTyping
    }

    func revokeMessage(conversationID: String, messageID: String) async throws -> String {
        _ = conversationID
        _ = messageID
        throw ServiceError.message("Not supported")
    }

    func deleteMessage(conversationID: String, messageID: String) async throws {
        _ = conversationID
        _ = messageID
        throw ServiceError.message("Not supported")
    }
}

extension SocialService {
    func setConversationPinned(conversationID: String, pinned: Bool) async throws {
        _ = conversationID
        _ = pinned
        throw ServiceError.message("Not supported")
    }

    func markConversationUnread(conversationID: String, unread: Bool) async throws {
        _ = conversationID
        _ = unread
        throw ServiceError.message("Not supported")
    }

    func hideConversation(conversationID: String) async throws {
        _ = conversationID
        throw ServiceError.message("Not supported")
    }

    func fetchTencentIMBootstrap() async throws -> TencentIMBootstrap {
        throw ServiceError.message("Not supported")
    }

    func setConversationMuted(conversationID: String, muted: Bool) async throws {
        throw ServiceError.message("Not supported")
    }

    func clearConversationHistory(conversationID: String) async throws {
        throw ServiceError.message("Not supported")
    }

    func isTencentFriend(userID: String) async throws -> Bool {
        _ = userID
        throw ServiceError.message("Not supported")
    }

    func fetchFriendRemark(userID: String) async throws -> String? {
        _ = userID
        throw ServiceError.message("Not supported")
    }

    func setFriendRemark(userID: String, remark: String?) async throws {
        _ = userID
        _ = remark
        throw ServiceError.message("Not supported")
    }

    func isUserBlacklisted(userID: String) async throws -> Bool {
        _ = userID
        throw ServiceError.message("Not supported")
    }

    func setUserBlacklisted(userID: String, blacklisted: Bool) async throws {
        _ = userID
        _ = blacklisted
        throw ServiceError.message("Not supported")
    }

    func leaveSquad(squadID: String) async throws {
        throw ServiceError.message("Not supported")
    }

    func disbandSquad(squadID: String) async throws {
        _ = squadID
        throw ServiceError.message("Not supported")
    }

    func inviteUserToSquad(squadID: String, inviteeUserID: String) async throws {
        _ = squadID
        _ = inviteeUserID
        throw ServiceError.message("Not supported")
    }

    func updateSquadMemberRole(squadID: String, memberUserID: String, role: String) async throws {
        _ = squadID
        _ = memberUserID
        _ = role
        throw ServiceError.message("Not supported")
    }

    func removeSquadMember(squadID: String, memberUserID: String) async throws {
        _ = squadID
        _ = memberUserID
        throw ServiceError.message("Not supported")
    }

    func fetchSquadInviteOption(squadID: String) async throws -> GroupInviteOption {
        _ = squadID
        throw ServiceError.message("Not supported")
    }

    func setSquadInviteOption(squadID: String, option: GroupInviteOption) async throws {
        _ = squadID
        _ = option
        throw ServiceError.message("Not supported")
    }

    func fetchSquadMemberDirectory(squadID: String) async throws -> GroupMemberDirectory {
        _ = squadID
        throw ServiceError.message("Not supported")
    }
}

enum ServiceError: LocalizedError {
    case invalidResponse
    case unauthorized
    case message(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return L("服务响应无效", "Invalid service response")
        case .unauthorized:
            return L("登录状态已失效，请重新登录", "Session expired. Please log in again.")
        case .message(let text):
            return LL(text)
        }
    }
}

extension Error {
    var isUserInitiatedCancellation: Bool {
        if self is CancellationError {
            return true
        }

        if let urlError = self as? URLError, urlError.code == .cancelled {
            return true
        }

        let nsError = self as NSError
        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
            return true
        }

        return false
    }

    var userFacingMessage: String? {
        isUserInitiatedCancellation ? nil : localizedDescription
    }
}
