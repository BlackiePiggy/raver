import Foundation

final class LiveSocialService: SocialService {
    private let baseURL: URL
    private let session: URLSession
    private var token: String? {
        get { SessionTokenStore.shared.token }
        set { SessionTokenStore.shared.token = newValue }
    }

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func login(username: String, password: String) async throws -> Session {
        let body = ["username": username, "password": password]
        let sessionResponse: Session = try await request(path: "/v1/auth/login", method: "POST", body: body)
        token = sessionResponse.token
        return sessionResponse
    }

    func register(username: String, email: String, password: String, displayName: String) async throws -> Session {
        let body = [
            "username": username,
            "email": email,
            "password": password,
            "displayName": displayName
        ]
        let sessionResponse: Session = try await request(path: "/v1/auth/register", method: "POST", body: body)
        token = sessionResponse.token
        return sessionResponse
    }

    func logout() async {
        token = nil
    }

    func fetchFeed(cursor: String?) async throws -> FeedPage {
        var path = "/v1/feed"
        if let cursor {
            path += "?cursor=\(cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor)"
        }
        return try await request(path: path, method: "GET")
    }

    func searchFeed(query: String) async throws -> FeedPage {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return try await request(path: "/v1/feed/search?q=\(encoded)", method: "GET")
    }

    func createPost(input: CreatePostInput) async throws -> Post {
        try await request(path: "/v1/feed/posts", method: "POST", body: input)
    }

    func toggleLike(postID: String, shouldLike: Bool) async throws -> Post {
        try await request(path: "/v1/feed/posts/\(postID)/like", method: shouldLike ? "POST" : "DELETE")
    }

    func fetchComments(postID: String) async throws -> [Comment] {
        try await request(path: "/v1/feed/posts/\(postID)/comments", method: "GET")
    }

    func addComment(postID: String, content: String) async throws -> Comment {
        try await request(path: "/v1/feed/posts/\(postID)/comments", method: "POST", body: ["content": content])
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
        try await request(path: "/v1/chat/conversations?type=\(type.rawValue)", method: "GET")
    }

    func markConversationRead(conversationID: String) async throws {
        let _: GenericSuccessResponse = try await request(
            path: "/v1/chat/conversations/\(conversationID)/read",
            method: "POST"
        )
    }

    func startDirectConversation(identifier: String) async throws -> Conversation {
        try await request(
            path: "/v1/chat/direct/start",
            method: "POST",
            body: ["identifier": identifier]
        )
    }

    func fetchMessages(conversationID: String) async throws -> [ChatMessage] {
        try await request(path: "/v1/chat/conversations/\(conversationID)/messages", method: "GET")
    }

    func sendMessage(conversationID: String, content: String) async throws -> ChatMessage {
        try await request(path: "/v1/chat/conversations/\(conversationID)/messages", method: "POST", body: ["content": content])
    }

    func fetchRecommendedSquads() async throws -> [SquadSummary] {
        try await request(path: "/v1/squads/recommended", method: "GET")
    }

    func fetchSquadProfile(squadID: String) async throws -> SquadProfile {
        try await request(path: "/v1/squads/\(squadID)/profile", method: "GET")
    }

    func joinSquad(squadID: String) async throws {
        let _: JoinSquadResponse = try await request(path: "/v1/squads/\(squadID)/join", method: "POST")
    }

    func createSquad(input: CreateSquadInput) async throws -> Conversation {
        try await request(path: "/v1/squads", method: "POST", body: input)
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
        let _: GenericSuccessResponse = try await request(
            path: "/v1/squads/\(squadID)/my-settings",
            method: "PATCH",
            body: input
        )
    }

    func updateSquadInfo(squadID: String, input: UpdateSquadInfoInput) async throws {
        let _: GenericSuccessResponse = try await request(
            path: "/v1/squads/\(squadID)/manage",
            method: "PATCH",
            body: input
        )
    }

    func fetchNotifications(limit: Int) async throws -> NotificationInbox {
        let normalized = max(1, min(50, limit))
        return try await request(path: "/v1/notifications?limit=\(normalized)", method: "GET")
    }

    func fetchNotificationUnreadCount() async throws -> NotificationUnreadCount {
        try await request(path: "/v1/notifications/unread-count", method: "GET")
    }

    func markNotificationRead(notificationID: String) async throws {
        let _: GenericSuccessResponse = try await request(
            path: "/v1/notifications/read",
            method: "POST",
            body: ["notificationId": notificationID]
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

    func toggleFollow(userID: String, shouldFollow: Bool) async throws -> UserSummary {
        try await request(path: "/v1/social/users/\(userID)/follow", method: shouldFollow ? "POST" : "DELETE")
    }

    func toggleRepost(postID: String, shouldRepost: Bool) async throws -> Post {
        try await request(path: "/v1/feed/posts/\(postID)/repost", method: shouldRepost ? "POST" : "DELETE")
    }

    private func request<T: Decodable>(path: String, method: String, body: Encodable? = nil) async throws -> T {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw ServiceError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try JSONEncoder.raver.encode(AnyEncodable(body))
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ServiceError.invalidResponse
        }

        if http.statusCode == 401 {
            NotificationCenter.default.post(name: .raverSessionExpired, object: nil)
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
}

private struct JoinSquadResponse: Decodable {
    let success: Bool
}

private struct GenericSuccessResponse: Decodable {
    let success: Bool
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
