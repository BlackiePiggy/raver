import Foundation
import Combine

private actor AuthRefreshGate {
    private var inFlightTask: Task<Session, Error>?

    func run(_ operation: @escaping () async throws -> Session) async throws -> Session {
        if let inFlightTask {
            return try await inFlightTask.value
        }

        let task = Task { try await operation() }
        inFlightTask = task
        defer { inFlightTask = nil }
        return try await task.value
    }
}

final class LiveSocialService: SocialService {
    private let baseURL: URL
    private let session: URLSession
    private let imSession = TencentIMSession.shared
    private let refreshGate = AuthRefreshGate()
    private var token: String? {
        get { SessionTokenStore.shared.token }
        set { SessionTokenStore.shared.token = newValue }
    }
    private var refreshToken: String? {
        get { SessionTokenStore.shared.refreshToken }
        set { SessionTokenStore.shared.refreshToken = newValue }
    }

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func restoreSession() async -> Session? {
        guard refreshToken != nil else {
            return nil
        }

        do {
            let refreshed = try await refreshGate.run { [weak self] in
                guard let self else { throw ServiceError.unauthorized }
                return try await self.refreshSessionInternal()
            }
            return refreshed
        } catch {
            token = nil
            refreshToken = nil
            return nil
        }
    }

    func login(username: String, password: String) async throws -> Session {
        let body = ["username": username, "password": password]
        let sessionResponse: Session = try await request(
            path: "/v1/auth/login",
            method: "POST",
            body: body,
            allowAuthRetry: false,
            includeAccessToken: false,
            postSessionExpiredOnUnauthorized: false
        )
        token = sessionResponse.token
        refreshToken = sessionResponse.refreshToken
        return sessionResponse
    }

    func loginWithSms(phoneNumber: String, code: String) async throws -> Session {
        let body = ["phone": phoneNumber, "code": code]
        let sessionResponse: Session = try await request(
            path: "/v1/auth/sms/login",
            method: "POST",
            body: body,
            allowAuthRetry: false,
            includeAccessToken: false,
            postSessionExpiredOnUnauthorized: false
        )
        token = sessionResponse.token
        refreshToken = sessionResponse.refreshToken
        return sessionResponse
    }

    func sendLoginSmsCode(phoneNumber: String) async throws -> Int {
        let body = ["phone": phoneNumber, "scene": "login"]
        let response: SmsCodeSendResponse = try await request(
            path: "/v1/auth/sms/send",
            method: "POST",
            body: body,
            allowAuthRetry: false,
            includeAccessToken: false,
            postSessionExpiredOnUnauthorized: false
        )
        return max(0, response.expiresInSeconds)
    }

    func register(username: String, email: String, password: String, displayName: String) async throws -> Session {
        let body = [
            "username": username,
            "email": email,
            "password": password,
            "displayName": displayName
        ]
        let sessionResponse: Session = try await request(
            path: "/v1/auth/register",
            method: "POST",
            body: body,
            allowAuthRetry: false,
            includeAccessToken: false,
            postSessionExpiredOnUnauthorized: false
        )
        token = sessionResponse.token
        refreshToken = sessionResponse.refreshToken
        return sessionResponse
    }

    func logout() async {
        if let refreshToken {
            let body = ["refreshToken": refreshToken]
            do {
                let _: GenericSuccessResponse = try await request(
                    path: "/v1/auth/logout",
                    method: "POST",
                    body: body,
                    allowAuthRetry: false,
                    includeAccessToken: false,
                    postSessionExpiredOnUnauthorized: false
                )
            } catch {
                // Ignore network/logout errors and always clear local session.
            }
        }
        token = nil
        refreshToken = nil
    }

    func fetchTencentIMBootstrap() async throws -> TencentIMBootstrap {
        try await request(path: "/v1/im/tencent/bootstrap", method: "GET")
    }

    func fetchFeed(cursor: String?, mode: FeedMode?) async throws -> FeedPage {
        var queryItems = ["limit=12"]
        if let cursor {
            let encoded = cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor
            queryItems.append("cursor=\(encoded)")
        }
        if let mode {
            queryItems.append("mode=\(mode.rawValue)")
        }
        let path = "/v1/feed?\(queryItems.joined(separator: "&"))"
        return try await request(path: path, method: "GET")
    }

    func searchFeed(query: String) async throws -> FeedPage {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return try await request(path: "/v1/feed/search?q=\(encoded)", method: "GET")
    }

    func fetchPost(postID: String) async throws -> Post {
        try await request(path: "/v1/feed/posts/\(postID)", method: "GET")
    }

    func createPost(input: CreatePostInput) async throws -> Post {
        try await request(path: "/v1/feed/posts", method: "POST", body: input)
    }

    func updatePost(postID: String, input: UpdatePostInput) async throws -> Post {
        try await request(path: "/v1/feed/posts/\(postID)", method: "PATCH", body: input)
    }

    func deletePost(postID: String) async throws {
        let _: GenericSuccessResponse = try await request(path: "/v1/feed/posts/\(postID)", method: "DELETE")
    }

    func toggleLike(postID: String, shouldLike: Bool) async throws -> Post {
        try await request(path: "/v1/feed/posts/\(postID)/like", method: shouldLike ? "POST" : "DELETE")
    }

    func toggleSave(postID: String, shouldSave: Bool) async throws -> Post {
        try await request(path: "/v1/feed/posts/\(postID)/save", method: shouldSave ? "POST" : "DELETE")
    }

    func recordShare(postID: String, channel: String, status: String) async throws -> Post {
        try await request(
            path: "/v1/feed/posts/\(postID)/share",
            method: "POST",
            body: ["channel": channel, "status": status]
        )
    }

    func hidePost(postID: String, reason: String?) async throws {
        let _: GenericSuccessResponse = try await request(
            path: "/v1/feed/posts/\(postID)/hide",
            method: "POST",
            body: ["reason": reason ?? "not_relevant"]
        )
    }

    func recordFeedEvent(input: FeedEventInput) async throws {
        let _: GenericSuccessResponse = try await request(
            path: "/v1/feed/events",
            method: "POST",
            body: input
        )
    }

    func fetchComments(postID: String) async throws -> [Comment] {
        try await request(path: "/v1/feed/posts/\(postID)/comments", method: "GET")
    }

    func addComment(postID: String, content: String, parentCommentID: String?) async throws -> Comment {
        var body: [String: String] = ["content": content]
        if let parentCommentID, !parentCommentID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            body["parentCommentID"] = parentCommentID
        }
        return try await request(path: "/v1/feed/posts/\(postID)/comments", method: "POST", body: body)
    }

    func searchUsers(query: String) async throws -> [UserSummary] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return try await request(path: "/v1/users/search?q=\(encoded)", method: "GET")
    }

    func fetchUserProfile(userID: String) async throws -> UserProfile {
        try await request(path: "/v1/users/\(userID)/profile", method: "GET")
    }

    func fetchPostsByUser(userID: String, cursor: String?) async throws -> FeedPage {
        var path = "/v1/users/\(userID)/posts"
        if let cursor {
            path += "?cursor=\(cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor)"
        }
        return try await request(path: path, method: "GET")
    }

    func fetchFollowers(userID: String, cursor: String?) async throws -> FollowListPage {
        var path = "/v1/users/\(userID)/followers"
        if let cursor {
            path += "?cursor=\(cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor)"
        }
        return try await request(path: path, method: "GET")
    }

    func fetchFollowing(userID: String, cursor: String?) async throws -> FollowListPage {
        var path = "/v1/users/\(userID)/following"
        if let cursor {
            path += "?cursor=\(cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor)"
        }
        return try await request(path: path, method: "GET")
    }

    func fetchFriends(userID: String, cursor: String?) async throws -> FollowListPage {
        var path = "/v1/users/\(userID)/friends"
        if let cursor {
            path += "?cursor=\(cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor)"
        }
        return try await request(path: path, method: "GET")
    }

    func fetchConversations(type: ConversationType) async throws -> [Conversation] {
        if let conversations = try await imSession.fetchConversations(type: type) {
            return conversations
        }
        throw await tencentIMUnavailableError(for: "fetch conversations")
    }

    func markConversationRead(conversationID: String) async throws {
        if try await imSession.markConversationRead(conversationID: conversationID) {
            return
        }
        throw await tencentIMUnavailableError(for: "mark conversation read")
    }

    func setConversationPinned(conversationID: String, pinned: Bool) async throws {
        if try await imSession.setConversationPinned(conversationID: conversationID, pinned: pinned) {
            return
        }
        throw await tencentIMUnavailableError(for: "set conversation pinned")
    }

    func markConversationUnread(conversationID: String, unread: Bool) async throws {
        if try await imSession.markConversationUnread(conversationID: conversationID, unread: unread) {
            return
        }
        throw await tencentIMUnavailableError(for: "mark conversation unread")
    }

    func hideConversation(conversationID: String) async throws {
        if try await imSession.hideConversation(conversationID: conversationID) {
            return
        }
        throw await tencentIMUnavailableError(for: "hide conversation")
    }

    func setConversationMuted(conversationID: String, muted: Bool) async throws {
        if try await imSession.setConversationMuted(conversationID: conversationID, muted: muted) {
            return
        }
        throw await tencentIMUnavailableError(for: "set conversation muted")
    }

    func clearConversationHistory(conversationID: String) async throws {
        if try await imSession.clearConversationHistory(conversationID: conversationID) {
            return
        }
        throw await tencentIMUnavailableError(for: "clear conversation history")
    }

    func isTencentFriend(userID: String) async throws -> Bool {
        let myProfile = try await fetchMyProfile()
        let friends = try await fetchFriends(userID: myProfile.id, cursor: nil)
        let platformUserID = TencentIMIdentity.normalizePlatformUserIDForProfile(userID)
        return friends.users.contains(where: { $0.id == platformUserID })
    }

    func fetchFriendRemark(userID: String) async throws -> String? {
        if let remark = try await imSession.fetchFriendRemark(userID: userID) {
            return remark
        }
        return nil
    }

    func setFriendRemark(userID: String, remark: String?) async throws {
        if try await imSession.setFriendRemark(userID: userID, remark: remark) {
            return
        }
        throw await tencentIMUnavailableError(for: "set friend remark")
    }

    func isUserBlacklisted(userID: String) async throws -> Bool {
        try await imSession.isUserBlacklisted(userID: userID)
    }

    func setUserBlacklisted(userID: String, blacklisted: Bool) async throws {
        if try await imSession.setUserBlacklisted(userID: userID, blacklisted: blacklisted) {
            return
        }
        throw await tencentIMUnavailableError(for: "set user blacklisted")
    }

    func startDirectConversation(identifier: String) async throws -> Conversation {
        let raw: Conversation = try await request(
            path: "/v1/chat/direct/start",
            method: "POST",
            body: ["identifier": identifier]
        )
        return normalizeTencentDirectConversation(raw, fallbackIdentifier: identifier)
    }

    func fetchMessages(conversationID: String) async throws -> [ChatMessage] {
        let page = try await fetchMessages(
            conversationID: conversationID,
            startClientMsgID: nil,
            count: 50
        )
        return page.messages
    }

    func fetchMessages(
        conversationID: String,
        startClientMsgID: String?,
        count: Int
    ) async throws -> ChatMessageHistoryPage {
        if let page = try await imSession.fetchMessagesPage(
            conversationID: conversationID,
            startClientMsgID: startClientMsgID,
            count: count
        ) {
            return page
        }
        throw await tencentIMUnavailableError(for: "fetch messages")
    }

    func sendMessage(conversationID: String, content: String) async throws -> ChatMessage {
        if let message = try await imSession.sendTextMessage(
            conversationID: conversationID,
            content: content
        ) {
            return message
        }
        throw await tencentIMUnavailableError(for: "send message")
    }

    func sendImageMessage(conversationID: String, fileURL: URL) async throws -> ChatMessage {
        try await sendImageMessage(conversationID: conversationID, fileURL: fileURL, onProgress: nil)
    }

    func sendImageMessage(
        conversationID: String,
        fileURL: URL,
        onProgress: ((Int) -> Void)?
    ) async throws -> ChatMessage {
        if let message = try await imSession.sendImageMessage(
            conversationID: conversationID,
            fileURL: fileURL,
            onProgress: onProgress
        ) {
            return message
        }
        throw await tencentIMUnavailableError(for: "send image message")
    }

    func sendVideoMessage(conversationID: String, fileURL: URL) async throws -> ChatMessage {
        try await sendVideoMessage(conversationID: conversationID, fileURL: fileURL, onProgress: nil)
    }

    func sendVideoMessage(
        conversationID: String,
        fileURL: URL,
        onProgress: ((Int) -> Void)?
    ) async throws -> ChatMessage {
        if let message = try await imSession.sendVideoMessage(
            conversationID: conversationID,
            fileURL: fileURL,
            onProgress: onProgress
        ) {
            return message
        }
        throw await tencentIMUnavailableError(for: "send video message")
    }

    func sendVoiceMessage(conversationID: String, fileURL: URL) async throws -> ChatMessage {
        if let message = try await imSession.sendVoiceMessage(
            conversationID: conversationID,
            fileURL: fileURL
        ) {
            return message
        }
        throw await tencentIMUnavailableError(for: "send voice message")
    }

    func sendFileMessage(conversationID: String, fileURL: URL) async throws -> ChatMessage {
        if let message = try await imSession.sendFileMessage(
            conversationID: conversationID,
            fileURL: fileURL
        ) {
            return message
        }
        throw await tencentIMUnavailableError(for: "send file message")
    }

    func sendTypingStatus(conversationID: String, isTyping: Bool) async throws {
        if try await imSession.sendTypingStatus(
            conversationID: conversationID,
            isTyping: isTyping
        ) {
            return
        }
        throw await tencentIMUnavailableError(for: "send typing status")
    }

    func revokeMessage(conversationID: String, messageID: String) async throws -> String {
        if let displayText = try await imSession.revokeMessage(
            conversationID: conversationID,
            messageID: messageID
        ) {
            return displayText
        }
        throw await tencentIMUnavailableError(for: "revoke message")
    }

    func deleteMessage(conversationID: String, messageID: String) async throws {
        if try await imSession.deleteMessage(
            conversationID: conversationID,
            messageID: messageID
        ) {
            return
        }
        throw await tencentIMUnavailableError(for: "delete message")
    }

    func fetchRecommendedSquads() async throws -> [SquadSummary] {
        try await request(path: "/v1/squads/recommended", method: "GET")
    }

    func fetchMySquads() async throws -> [SquadSummary] {
        try await request(path: "/v1/squads/mine", method: "GET")
    }

    func fetchSquadProfile(squadID: String) async throws -> SquadProfile {
        try await imSession.fetchSquadProfile(squadID: squadID)
    }

    func joinSquad(squadID: String) async throws {
        if try await imSession.joinSquad(squadID: squadID) {
            return
        }
        throw await tencentIMUnavailableError(for: "join squad")
    }

    func leaveSquad(squadID: String) async throws {
        if try await imSession.leaveSquad(squadID: squadID) {
            return
        }
        throw await tencentIMUnavailableError(for: "leave squad")
    }

    func disbandSquad(squadID: String) async throws {
        if try await imSession.disbandSquad(squadID: squadID) {
            return
        }
        throw await tencentIMUnavailableError(for: "disband squad")
    }

    func inviteUserToSquad(squadID: String, inviteeUserID: String) async throws {
        if try await imSession.inviteUsersToSquad(squadID: squadID, userIDs: [inviteeUserID]) {
            return
        }
        throw await tencentIMUnavailableError(for: "invite users to squad")
    }

    func createSquad(input: CreateSquadInput) async throws -> Conversation {
        if let conversation = try await imSession.createSquad(input: input) {
            return conversation
        }
        throw await tencentIMUnavailableError(for: "create squad")
    }

    func uploadSquadAvatar(
        squadID: String,
        imageData: Data,
        fileName: String,
        mimeType: String
    ) async throws -> AvatarUploadResponse {
        try await uploadMultipart(
            path: "/v1/squads/\(squadID)/avatar",
            data: imageData,
            fileName: fileName,
            mimeType: mimeType,
            fieldName: "avatar"
        )
    }

    func updateSquadMySettings(squadID: String, input: UpdateSquadMySettingsInput) async throws {
        if try await imSession.updateSquadMySettings(squadID: squadID, input: input) {
            return
        }
        throw await tencentIMUnavailableError(for: "update squad my settings")
    }

    func updateSquadInfo(squadID: String, input: UpdateSquadInfoInput) async throws {
        if try await imSession.updateSquadInfo(squadID: squadID, input: input) {
            return
        }
        throw await tencentIMUnavailableError(for: "update squad info")
    }

    func updateSquadMemberRole(squadID: String, memberUserID: String, role: String) async throws {
        if try await imSession.updateSquadMemberRole(squadID: squadID, memberUserID: memberUserID, role: role) {
            return
        }
        throw await tencentIMUnavailableError(for: "update squad member role")
    }

    func removeSquadMember(squadID: String, memberUserID: String) async throws {
        if try await imSession.removeUsersFromSquad(squadID: squadID, userIDs: [memberUserID]) {
            return
        }
        throw await tencentIMUnavailableError(for: "remove squad member")
    }

    func fetchSquadInviteOption(squadID: String) async throws -> GroupInviteOption {
        return try await imSession.fetchSquadInviteOption(squadID: squadID)
    }

    func setSquadInviteOption(squadID: String, option: GroupInviteOption) async throws {
        if try await imSession.setSquadInviteOption(squadID: squadID, option: option) {
            return
        }
        throw await tencentIMUnavailableError(for: "set squad invite option")
    }

    func fetchSquadMemberDirectory(squadID: String) async throws -> GroupMemberDirectory {
        try await imSession.fetchSquadMemberDirectory(squadID: squadID)
    }

    func fetchNotifications(limit: Int) async throws -> NotificationInbox {
        let normalized = max(1, min(50, limit))
        async let inboxResponse: NotificationCenterInboxResponse = request(
            path: "/v1/notification-center/inbox?limit=\(normalized)",
            method: "GET"
        )
        async let unreadResponse: NotificationCenterUnreadCountResponse = request(
            path: "/v1/notification-center/inbox/unread-count",
            method: "GET"
        )
        let (inbox, unread) = try await (inboxResponse, unreadResponse)

        let items = inbox.items.compactMap(mapNotificationCenterInboxItem(_:))
        let effectiveTotal = max(0, unread.communityTotal ?? unread.total)
        return NotificationInbox(unreadCount: effectiveTotal, items: items)
    }

    func fetchNotificationUnreadCount() async throws -> NotificationUnreadCount {
        let response: NotificationCenterUnreadCountResponse = try await request(
            path: "/v1/notification-center/inbox/unread-count",
            method: "GET"
        )
        let effectiveTotal = max(0, response.communityTotal ?? response.total)
        return NotificationUnreadCount(
            total: effectiveTotal,
            follows: max(0, response.follows ?? 0),
            likes: max(0, response.likes ?? 0),
            comments: max(0, response.comments ?? 0),
            squadInvites: max(0, response.squadInvites ?? 0)
        )
    }

    func markNotificationRead(notificationID: String) async throws {
        let _: GenericSuccessResponse = try await request(
            path: "/v1/notification-center/inbox/read",
            method: "POST",
            body: ["inboxId": notificationID]
        )
    }

    func markNotificationsRead(type: AppNotificationType) async throws {
        let _: GenericSuccessResponse = try await request(
            path: "/v1/notification-center/inbox/read",
            method: "POST",
            body: ["notificationType": type.rawValue]
        )
    }

    func registerDevicePushToken(
        deviceID: String,
        platform: String,
        pushToken: String,
        appVersion: String?,
        locale: String?
    ) async throws {
        let _: GenericSuccessResponse = try await request(
            path: "/v1/notification-center/push-tokens",
            method: "POST",
            body: [
                "deviceId": deviceID,
                "platform": platform,
                "pushToken": pushToken,
                "appVersion": appVersion ?? "",
                "locale": locale ?? ""
            ]
        )
    }

    func deactivateDevicePushToken(deviceID: String, platform: String) async throws {
        let _: GenericSuccessResponse = try await request(
            path: "/v1/notification-center/push-tokens",
            method: "DELETE",
            body: [
                "deviceId": deviceID,
                "platform": platform
            ]
        )
    }

    func fetchMyProfile() async throws -> UserProfile {
        try await request(path: "/v1/profile/me", method: "GET")
    }

    func updateMyProfile(input: UpdateMyProfileInput) async throws -> UserProfile {
        try await request(path: "/v1/profile/me", method: "PATCH", body: input)
    }

    func uploadMyAvatar(imageData: Data, fileName: String, mimeType: String) async throws -> AvatarUploadResponse {
        try await uploadMultipart(
            path: "/v1/profile/me/avatar",
            data: imageData,
            fileName: fileName,
            mimeType: mimeType,
            fieldName: "avatar"
        )
    }

    func fetchMyLikeHistory(cursor: String?) async throws -> ActivityPostPage {
        var path = "/v1/profile/me/likes"
        if let cursor {
            path += "?cursor=\(cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor)"
        }
        return try await request(path: path, method: "GET")
    }

    func fetchMyRepostHistory(cursor: String?) async throws -> ActivityPostPage {
        var path = "/v1/profile/me/reposts"
        if let cursor {
            path += "?cursor=\(cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor)"
        }
        return try await request(path: path, method: "GET")
    }

    func fetchMySaveHistory(cursor: String?) async throws -> ActivityPostPage {
        var path = "/v1/profile/me/saves"
        if let cursor {
            path += "?cursor=\(cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor)"
        }
        return try await request(path: path, method: "GET")
    }

    func toggleFollow(userID: String, shouldFollow: Bool) async throws -> UserSummary {
        try await request(path: "/v1/social/users/\(userID)/follow", method: shouldFollow ? "POST" : "DELETE")
    }

    func toggleRepost(postID: String, shouldRepost: Bool) async throws -> Post {
        try await request(path: "/v1/feed/posts/\(postID)/repost", method: shouldRepost ? "POST" : "DELETE")
    }

    private func refreshSessionInternal() async throws -> Session {
        guard let currentRefreshToken = refreshToken, !currentRefreshToken.isEmpty else {
            throw ServiceError.unauthorized
        }

        let body = ["refreshToken": currentRefreshToken]
        let refreshed: Session = try await request(
            path: "/v1/auth/refresh",
            method: "POST",
            body: body,
            allowAuthRetry: false,
            includeAccessToken: false,
            postSessionExpiredOnUnauthorized: false
        )

        token = refreshed.token
        if let nextRefreshToken = refreshed.refreshToken, !nextRefreshToken.isEmpty {
            refreshToken = nextRefreshToken
        }
        return refreshed
    }

    private func performRequest(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ServiceError.invalidResponse
        }
        return (data, http)
    }

    private func request<T: Decodable>(
        path: String,
        method: String,
        body: Encodable? = nil,
        allowAuthRetry: Bool = true,
        includeAccessToken: Bool = true,
        postSessionExpiredOnUnauthorized: Bool = true
    ) async throws -> T {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw ServiceError.invalidResponse
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.timeoutInterval = 15
        urlRequest.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        urlRequest.setValue("no-cache", forHTTPHeaderField: "Pragma")
        if includeAccessToken, let token {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            urlRequest.httpBody = try JSONEncoder.raver.encode(AnyEncodable(body))
        }

        var (data, http) = try await performRequest(urlRequest)

        if http.statusCode == 401 {
            let canRetryWithRefresh = allowAuthRetry && includeAccessToken && path != "/v1/auth/refresh"
            if canRetryWithRefresh {
                do {
                    let refreshed = try await refreshGate.run { [weak self] in
                        guard let self else { throw ServiceError.unauthorized }
                        return try await self.refreshSessionInternal()
                    }

                    var retryRequest = urlRequest
                    retryRequest.setValue("Bearer \(refreshed.token)", forHTTPHeaderField: "Authorization")
                    (data, http) = try await performRequest(retryRequest)
                } catch {
                    if postSessionExpiredOnUnauthorized {
                        NotificationCenter.default.post(name: .raverSessionExpired, object: nil)
                    }
                    throw ServiceError.unauthorized
                }
            } else {
                if postSessionExpiredOnUnauthorized {
                    NotificationCenter.default.post(name: .raverSessionExpired, object: nil)
                }
                throw ServiceError.unauthorized
            }
        }

        if http.statusCode == 401 {
            if postSessionExpiredOnUnauthorized {
                NotificationCenter.default.post(name: .raverSessionExpired, object: nil)
            }
            throw ServiceError.unauthorized
        }

        guard (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "请求失败"
            throw ServiceError.message(message)
        }

        do {
            return try JSONDecoder.raver.decode(T.self, from: data)
        } catch let decodingError as DecodingError {
            print("Social BFF decode error:", decodingError)
            throw ServiceError.message("接口返回格式不匹配，请检查 BFF 契约")
        } catch {
            print("Social BFF decode error:", error)
            throw ServiceError.message("接口返回格式不匹配，请检查 BFF 契约")
        }
    }

    private func uploadMultipart<T: Decodable>(
        path: String,
        data: Data,
        fileName: String,
        mimeType: String,
        fieldName: String
    ) async throws -> T {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw ServiceError.invalidResponse
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (responseData, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ServiceError.invalidResponse
        }

        if http.statusCode == 401 {
            NotificationCenter.default.post(name: .raverSessionExpired, object: nil)
            throw ServiceError.unauthorized
        }

        guard (200...299).contains(http.statusCode) else {
            let message = String(data: responseData, encoding: .utf8) ?? "请求失败"
            throw ServiceError.message(message)
        }

        do {
            return try JSONDecoder.raver.decode(T.self, from: responseData)
        } catch let decodingError as DecodingError {
            print("Social BFF decode error:", decodingError)
            throw ServiceError.message("接口返回格式不匹配，请检查 BFF 契约")
        } catch {
            print("Social BFF decode error:", error)
            throw ServiceError.message("接口返回格式不匹配，请检查 BFF 契约")
        }
    }

    private func tencentIMUnavailableError(for action: String) async -> ServiceError {
        let state = await imSession.connectionStateSnapshot()
        switch state {
        case .unavailable:
            return .message("腾讯云 IM SDK 未加载，请使用 RaverMVP.xcworkspace 运行并确认 CocoaPods 已安装")
        case .disabled:
            return .message("腾讯云 IM 当前被禁用，请检查服务端 /v1/im/tencent/bootstrap 返回 enabled=true")
        case .initializing, .connecting:
            return .message("腾讯云 IM 正在连接，请稍后重试")
        case .failed(let message):
            if message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .message("腾讯云 IM \(action)失败，请检查 SDKAppID、UserSig 和网络")
            }
            return .message("腾讯云 IM \(action)失败：\(message)")
        case .userSigExpired:
            return .message("腾讯云 IM UserSig 已过期，请重新登录")
        case .kickedOffline:
            return .message("腾讯云 IM 会话已在其他设备登录，请重新进入")
        case .idle:
            return .message("腾讯云 IM 尚未初始化，请稍后重试")
        case .connected:
            return .message("腾讯云 IM 会话暂不可用，请稍后重试")
        }
    }

    private func mapNotificationCenterInboxItem(_ item: NotificationCenterInboxItem) -> AppNotification? {
        guard item.type == "community_interaction" else {
            return nil
        }

        guard let appType = mapNotificationCenterSourceToAppType(item.metadata?.source) else {
            return nil
        }

        let actorID = item.metadata?.actorUserID
            ?? item.metadata?.actorUserId
            ?? item.metadata?.inviterUserID
            ?? item.metadata?.inviterUserId

        let target: AppNotificationTarget?
        switch appType {
        case .follow:
            if let actorID, !actorID.isEmpty {
                target = AppNotificationTarget(type: "user", id: actorID, title: nil)
            } else {
                target = nil
            }
        case .like, .comment:
            let postID = item.metadata?.postID ?? item.metadata?.postId
            if let postID, !postID.isEmpty {
                target = AppNotificationTarget(type: "post", id: postID, title: item.metadata?.postPreview)
            } else {
                target = nil
            }
        case .squadInvite:
            let squadID = item.metadata?.squadID ?? item.metadata?.squadId
            if let squadID, !squadID.isEmpty {
                target = AppNotificationTarget(
                    type: "squad",
                    id: squadID,
                    title: item.metadata?.squadName ?? item.metadata?.squadTitle ?? item.title
                )
            } else {
                target = nil
            }
        }

        let text = item.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? item.title : item.body
        return AppNotification(
            id: item.id,
            type: appType,
            createdAt: item.createdAt,
            isRead: item.isRead,
            actor: nil,
            text: text,
            target: target
        )
    }

    private func mapNotificationCenterSourceToAppType(_ source: String?) -> AppNotificationType? {
        guard let normalized = source?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !normalized.isEmpty else {
            return nil
        }
        switch normalized {
        case "user_follow":
            return .follow
        case "post_like":
            return .like
        case "post_comment", "post_comment_reply":
            return .comment
        case "squad_invite":
            return .squadInvite
        default:
            return nil
        }
    }

    private func normalizeTencentDirectConversation(
        _ raw: Conversation,
        fallbackIdentifier: String
    ) -> Conversation {
        let fallback = fallbackIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let peerID = raw.peer?.id.trimmingCharacters(in: .whitespacesAndNewlines)
        let sourceID = (peerID?.isEmpty == false ? peerID : nil) ?? fallback
        let tencentUserID = toTencentIMUserID(sourceID)
        let sdkConversationID = "c2c_\(tencentUserID)"
        let peer = raw.peer.map {
            UserSummary(
                id: $0.id,
                username: $0.username,
                displayName: $0.displayName,
                avatarURL: $0.avatarURL,
                isFollowing: $0.isFollowing
            )
        }
        return Conversation(
            id: tencentUserID,
            type: .direct,
            title: raw.title,
            avatarURL: raw.avatarURL,
            sdkConversationID: sdkConversationID,
            lastMessage: raw.lastMessage,
            lastMessageSenderID: raw.lastMessageSenderID,
            unreadCount: raw.unreadCount,
            updatedAt: raw.updatedAt,
            peer: peer,
            isPinned: raw.isPinned
        )
    }

    private func toTencentIMUserID(_ raw: String) -> String {
        TencentIMIdentity.toTencentIMUserID(raw)
    }
}

private struct JoinSquadResponse: Decodable {
    let success: Bool
}

private struct GenericSuccessResponse: Decodable {
    let success: Bool
}

private struct SmsCodeSendResponse: Decodable {
    let success: Bool
    let expiresInSeconds: Int
}

private struct NotificationCenterInboxResponse: Decodable {
    let success: Bool
    let items: [NotificationCenterInboxItem]
}

private struct NotificationCenterInboxItem: Decodable {
    let id: String
    let type: String
    let title: String
    let body: String
    let metadata: NotificationCenterInboxMetadata?
    let isRead: Bool
    let createdAt: Date
}

private struct NotificationCenterInboxMetadata: Decodable {
    let source: String?
    let actorUserID: String?
    let actorUserId: String?
    let inviterUserID: String?
    let inviterUserId: String?
    let postID: String?
    let postId: String?
    let postPreview: String?
    let squadID: String?
    let squadId: String?
    let squadName: String?
    let squadTitle: String?
}

private struct NotificationCenterUnreadCountResponse: Decodable {
    let success: Bool
    let total: Int
    let communityTotal: Int?
    let follows: Int?
    let likes: Int?
    let comments: Int?
    let squadInvites: Int?
}

private struct AnyEncodable: Encodable {
    private let encodeClosure: (Encoder) throws -> Void

    init(_ wrapped: Encodable) {
        self.encodeClosure = { encoder in
            try wrapped.encode(to: encoder)
        }
    }

    func encode(to encoder: Encoder) throws {
        try encodeClosure(encoder)
    }
}
