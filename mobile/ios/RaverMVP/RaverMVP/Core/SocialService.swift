import Foundation

protocol SocialService {
    func login(username: String, password: String) async throws -> Session
    func register(username: String, email: String, password: String, displayName: String) async throws -> Session
    func logout() async

    func fetchFeed(cursor: String?) async throws -> FeedPage
    func searchFeed(query: String) async throws -> FeedPage
    func createPost(input: CreatePostInput) async throws -> Post
    func updatePost(postID: String, input: UpdatePostInput) async throws -> Post
    func deletePost(postID: String) async throws
    func toggleLike(postID: String, shouldLike: Bool) async throws -> Post

    func fetchComments(postID: String) async throws -> [Comment]
    func addComment(postID: String, content: String) async throws -> Comment

    func searchUsers(query: String) async throws -> [UserSummary]
    func fetchUserProfile(userID: String) async throws -> UserProfile
    func fetchPostsByUser(userID: String, cursor: String?) async throws -> FeedPage
    func fetchFollowers(userID: String, cursor: String?) async throws -> FollowListPage
    func fetchFollowing(userID: String, cursor: String?) async throws -> FollowListPage
    func fetchFriends(userID: String, cursor: String?) async throws -> FollowListPage

    func fetchConversations(type: ConversationType) async throws -> [Conversation]
    func markConversationRead(conversationID: String) async throws
    func startDirectConversation(identifier: String) async throws -> Conversation
    func fetchMessages(conversationID: String) async throws -> [ChatMessage]
    func sendMessage(conversationID: String, content: String) async throws -> ChatMessage
    func fetchRecommendedSquads() async throws -> [SquadSummary]
    func fetchMySquads() async throws -> [SquadSummary]
    func fetchSquadProfile(squadID: String) async throws -> SquadProfile
    func joinSquad(squadID: String) async throws
    func createSquad(input: CreateSquadInput) async throws -> Conversation
    func uploadSquadAvatar(squadID: String, imageData: Data, fileName: String, mimeType: String) async throws -> AvatarUploadResponse
    func updateSquadMySettings(squadID: String, input: UpdateSquadMySettingsInput) async throws
    func updateSquadInfo(squadID: String, input: UpdateSquadInfoInput) async throws
    func fetchNotifications(limit: Int) async throws -> NotificationInbox
    func fetchNotificationUnreadCount() async throws -> NotificationUnreadCount
    func markNotificationRead(notificationID: String) async throws

    func fetchMyProfile() async throws -> UserProfile
    func updateMyProfile(input: UpdateMyProfileInput) async throws -> UserProfile
    func uploadMyAvatar(imageData: Data, fileName: String, mimeType: String) async throws -> AvatarUploadResponse
    func fetchMyLikeHistory(cursor: String?) async throws -> ActivityPostPage
    func fetchMyRepostHistory(cursor: String?) async throws -> ActivityPostPage
    func toggleFollow(userID: String, shouldFollow: Bool) async throws -> UserSummary
    func toggleRepost(postID: String, shouldRepost: Bool) async throws -> Post
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
