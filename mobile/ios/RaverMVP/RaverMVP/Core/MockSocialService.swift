import Foundation

actor MockSocialService: SocialService {
    private var currentUser = UserSummary(
        id: "u_me",
        username: "blackie",
        displayName: "Blackie",
        avatarURL: MockSocialService.seededAvatarURL(for: "u_me"),
        isFollowing: false
    )

    private var usersByID: [String: UserSummary] = [:]
    private var profilesByID: [String: UserProfile] = [:]
    private var posts: [Post] = []
    private var commentsByPost: [String: [Comment]] = [:]
    private var conversations: [Conversation] = []
    private var messagesByConversation: [String: [ChatMessage]] = [:]
    private var squads: [SquadProfile] = []
    private var notifications: [AppNotification] = []

    private var followersByUserID: [String: Set<String>] = [:]
    private var followingByUserID: [String: Set<String>] = [:]
    private var likeActionAtByPostID: [String: Date] = [:]
    private var repostActionAtByPostID: [String: Date] = [:]

    init() {
        let seed = Self.makeSeed()
        currentUser = seed.currentUser
        usersByID = seed.usersByID
        profilesByID = seed.profilesByID
        posts = seed.posts
        commentsByPost = seed.commentsByPost
        conversations = seed.conversations
        messagesByConversation = seed.messagesByConversation
        squads = seed.squads
        notifications = seed.notifications
        followersByUserID = seed.followersByUserID
        followingByUserID = seed.followingByUserID
        likeActionAtByPostID = seed.likeActionAtByPostID
        repostActionAtByPostID = seed.repostActionAtByPostID
    }

    func login(username: String, password: String) async throws -> Session {
        _ = password
        let normalized = username.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalized.isEmpty {
            currentUser.username = normalized
            currentUser.displayName = normalized.capitalized
            usersByID[currentUser.id]?.username = currentUser.username
            usersByID[currentUser.id]?.displayName = currentUser.displayName
            profilesByID[currentUser.id]?.username = currentUser.username
            profilesByID[currentUser.id]?.displayName = currentUser.displayName
            for index in posts.indices where posts[index].author.id == currentUser.id {
                posts[index].author.username = currentUser.username
                posts[index].author.displayName = currentUser.displayName
            }
        }
        if currentUser.avatarURL?.isEmpty ?? true {
            currentUser.avatarURL = Self.seededAvatarURL(for: currentUser.id)
        }
        usersByID[currentUser.id]?.avatarURL = currentUser.avatarURL
        profilesByID[currentUser.id]?.avatarURL = currentUser.avatarURL
        for index in posts.indices where posts[index].author.id == currentUser.id {
            posts[index].author.avatarURL = currentUser.avatarURL
        }
        return Session(token: "mock_token", user: currentUser)
    }

    func register(username: String, email: String, password: String, displayName: String) async throws -> Session {
        _ = email
        _ = password
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        currentUser.username = username
        currentUser.displayName = name.isEmpty ? username.capitalized : name
        currentUser.avatarURL = Self.seededAvatarURL(for: currentUser.id)

        usersByID[currentUser.id] = currentUser
        profilesByID[currentUser.id] = UserProfile(
            id: currentUser.id,
            username: currentUser.username,
            displayName: currentUser.displayName,
            bio: "",
            avatarURL: currentUser.avatarURL,
            tags: [],
            isFollowersListPublic: true,
            isFollowingListPublic: true,
            canViewFollowersList: true,
            canViewFollowingList: true,
            followersCount: followersByUserID[currentUser.id]?.count ?? 0,
            followingCount: followingByUserID[currentUser.id]?.count ?? 0,
            friendsCount: friendIDs(for: currentUser.id).count,
            postsCount: posts.filter { $0.author.id == currentUser.id }.count,
            isFollowing: nil
        )

        applyCurrentFollowFlags()
        return Session(token: "mock_token", user: currentUser)
    }

    func logout() async {}

    func fetchFeed(cursor: String?) async throws -> FeedPage {
        _ = cursor
        let sorted = posts.sorted(by: { $0.createdAt > $1.createdAt })
        return FeedPage(posts: sorted, nextCursor: nil)
    }

    func searchFeed(query: String) async throws -> FeedPage {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.isEmpty {
            return FeedPage(posts: [], nextCursor: nil)
        }

        let filtered = posts.filter { post in
            post.content.lowercased().contains(normalized) ||
                post.author.username.lowercased().contains(normalized) ||
                post.author.displayName.lowercased().contains(normalized)
        }
        return FeedPage(posts: filtered.sorted(by: { $0.createdAt > $1.createdAt }), nextCursor: nil)
    }

    func fetchPost(postID: String) async throws -> Post {
        guard let post = posts.first(where: { $0.id == postID }) else {
            throw ServiceError.message("动态不存在")
        }
        return post
    }

    func createPost(input: CreatePostInput) async throws -> Post {
        let trimmed = input.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedImages = input.images.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let normalizedLocation: String? = {
            let trimmed = input.location?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? nil : trimmed
        }()
        if trimmed.isEmpty && normalizedImages.isEmpty {
            throw ServiceError.message("请填写正文或添加媒体")
        }

        let new = Post(
            id: UUID().uuidString,
            author: currentUser,
            content: trimmed,
            images: normalizedImages,
            location: normalizedLocation,
            eventID: nil,
            boundDjIDs: input.boundDjIDs,
            boundBrandIDs: input.boundBrandIDs,
            boundEventIDs: input.boundEventIDs,
            squad: nil,
            createdAt: Date(),
            likeCount: 0,
            repostCount: 0,
            commentCount: 0,
            isLiked: false,
            isReposted: false
        )
        posts.insert(new, at: 0)
        commentsByPost[new.id] = []
        profilesByID[currentUser.id]?.postsCount = posts.filter { $0.author.id == currentUser.id }.count
        return new
    }

    func updatePost(postID: String, input: UpdatePostInput) async throws -> Post {
        guard let index = posts.firstIndex(where: { $0.id == postID }) else {
            throw ServiceError.message("动态不存在")
        }
        let target = posts[index]
        guard target.author.id == currentUser.id else {
            throw ServiceError.message("无权编辑该动态")
        }

        let trimmed = input.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedImages = input.images
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let normalizedLocation: String? = {
            let trimmed = input.location?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? nil : trimmed
        }()
        if trimmed.isEmpty && normalizedImages.isEmpty {
            throw ServiceError.message("请填写正文或添加媒体")
        }

        var updated = target
        updated.content = trimmed
        updated.images = normalizedImages
        updated.location = normalizedLocation
        if let next = input.boundDjIDs {
            updated.boundDjIDs = next
        }
        if let next = input.boundBrandIDs {
            updated.boundBrandIDs = next
        }
        if let next = input.boundEventIDs {
            updated.boundEventIDs = next
        }
        posts[index] = updated
        return updated
    }

    func deletePost(postID: String) async throws {
        guard let index = posts.firstIndex(where: { $0.id == postID }) else {
            throw ServiceError.message("动态不存在")
        }
        let target = posts[index]
        guard target.author.id == currentUser.id else {
            throw ServiceError.message("无权删除该动态")
        }
        posts.remove(at: index)
        commentsByPost.removeValue(forKey: postID)
        likeActionAtByPostID.removeValue(forKey: postID)
        repostActionAtByPostID.removeValue(forKey: postID)
        profilesByID[currentUser.id]?.postsCount = posts.filter { $0.author.id == currentUser.id }.count
    }

    func toggleLike(postID: String, shouldLike: Bool) async throws -> Post {
        guard let index = posts.firstIndex(where: { $0.id == postID }) else {
            throw ServiceError.message("动态不存在")
        }

        var post = posts[index]
        if shouldLike && !post.isLiked {
            post.isLiked = true
            post.likeCount += 1
            likeActionAtByPostID[postID] = Date()
        } else if !shouldLike && post.isLiked {
            post.isLiked = false
            post.likeCount = max(0, post.likeCount - 1)
            likeActionAtByPostID.removeValue(forKey: postID)
        }

        posts[index] = post
        return post
    }

    func toggleRepost(postID: String, shouldRepost: Bool) async throws -> Post {
        guard let index = posts.firstIndex(where: { $0.id == postID }) else {
            throw ServiceError.message("动态不存在")
        }

        var post = posts[index]
        if shouldRepost && !post.isReposted {
            post.isReposted = true
            post.repostCount += 1
            repostActionAtByPostID[postID] = Date()
        } else if !shouldRepost && post.isReposted {
            post.isReposted = false
            post.repostCount = max(0, post.repostCount - 1)
            repostActionAtByPostID.removeValue(forKey: postID)
        }

        posts[index] = post
        return post
    }

    func fetchComments(postID: String) async throws -> [Comment] {
        commentsByPost[postID, default: []].sorted(by: { $0.createdAt < $1.createdAt })
    }

    func addComment(postID: String, content: String) async throws -> Comment {
        guard let index = posts.firstIndex(where: { $0.id == postID }) else {
            throw ServiceError.message("动态不存在")
        }

        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            throw ServiceError.message("评论不能为空")
        }

        let newComment = Comment(
            id: UUID().uuidString,
            postID: postID,
            author: currentUser,
            content: trimmed,
            createdAt: Date()
        )

        commentsByPost[postID, default: []].append(newComment)

        var post = posts[index]
        post.commentCount += 1
        posts[index] = post

        return newComment
    }

    func searchUsers(query: String) async throws -> [UserSummary] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.isEmpty {
            return []
        }

        return usersByID.values
            .filter {
                $0.id != currentUser.id &&
                    ($0.username.lowercased().contains(normalized) ||
                        $0.displayName.lowercased().contains(normalized))
            }
            .sorted(by: { $0.username < $1.username })
    }

    func fetchUserProfile(userID: String) async throws -> UserProfile {
        guard var profile = profilesByID[userID] else {
            throw ServiceError.message("用户不存在")
        }

        profile.followersCount = followersByUserID[userID]?.count ?? 0
        profile.followingCount = followingByUserID[userID]?.count ?? 0
        profile.friendsCount = friendIDs(for: userID).count
        profile.postsCount = posts.filter { $0.author.id == userID }.count
        profile.canViewFollowersList = (userID == currentUser.id) || profile.isFollowersListPublic
        profile.canViewFollowingList = (userID == currentUser.id) || profile.isFollowingListPublic
        profile.isFollowing = userID == currentUser.id ? nil : (followingByUserID[currentUser.id]?.contains(userID) ?? false)

        return profile
    }

    func fetchPostsByUser(userID: String, cursor: String?) async throws -> FeedPage {
        _ = cursor
        let filtered = posts
            .filter { $0.author.id == userID }
            .sorted(by: { $0.createdAt > $1.createdAt })
        return FeedPage(posts: filtered, nextCursor: nil)
    }

    func fetchFollowers(userID: String, cursor: String?) async throws -> FollowListPage {
        _ = cursor
        guard let profile = profilesByID[userID] else {
            throw ServiceError.message("用户不存在")
        }
        if userID != currentUser.id && !profile.isFollowersListPublic {
            throw ServiceError.message("Followers list is private")
        }

        let ids = Array(followersByUserID[userID] ?? []).sorted()
        let users = ids.compactMap { usersByID[$0] }
        return FollowListPage(users: users, nextCursor: nil)
    }

    func fetchFollowing(userID: String, cursor: String?) async throws -> FollowListPage {
        _ = cursor
        guard let profile = profilesByID[userID] else {
            throw ServiceError.message("用户不存在")
        }
        if userID != currentUser.id && !profile.isFollowingListPublic {
            throw ServiceError.message("Following list is private")
        }

        let ids = Array(followingByUserID[userID] ?? []).sorted()
        let users = ids.compactMap { usersByID[$0] }
        return FollowListPage(users: users, nextCursor: nil)
    }

    func fetchFriends(userID: String, cursor: String?) async throws -> FollowListPage {
        _ = cursor
        guard profilesByID[userID] != nil else {
            throw ServiceError.message("用户不存在")
        }

        let ids = Array(friendIDs(for: userID)).sorted()
        let users = ids.compactMap { usersByID[$0] }
        return FollowListPage(users: users, nextCursor: nil)
    }

    func fetchConversations(type: ConversationType) async throws -> [Conversation] {
        conversations
            .filter { $0.type == type }
            .sorted(by: { $0.updatedAt > $1.updatedAt })
    }

    func markConversationRead(conversationID: String) async throws {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        conversations[index].unreadCount = 0
    }

    func startDirectConversation(identifier: String) async throws -> Conversation {
        let normalized = identifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.isEmpty {
            throw ServiceError.message("请输入用户名")
        }

        if let existing = conversations.first(where: {
            $0.type == .direct && $0.title.lowercased() == normalized
        }) {
            return existing
        }

        let targetUser = usersByID.values.first(where: { $0.username.lowercased() == normalized })
        let title = targetUser?.displayName ?? identifier

        let conversation = Conversation(
            id: "dm_\(UUID().uuidString)",
            type: .direct,
            title: title,
            avatarURL: targetUser?.avatarURL,
            lastMessage: "开始聊天吧",
            lastMessageSenderID: nil,
            unreadCount: 0,
            updatedAt: Date(),
            peer: targetUser
        )

        conversations.append(conversation)
        messagesByConversation[conversation.id] = []
        return conversation
    }

    func fetchMessages(conversationID: String) async throws -> [ChatMessage] {
        let sorted = messagesByConversation[conversationID, default: []]
            .sorted(by: { $0.createdAt < $1.createdAt })

        guard let squad = squads.first(where: { $0.id == conversationID }) else {
            return sorted
        }

        let nicknameMap = Dictionary(uniqueKeysWithValues: squad.members.map { ($0.id, $0.shownName) })
        return sorted.map { message in
            var updated = message
            if let nickname = nicknameMap[message.sender.id], !nickname.isEmpty {
                updated.sender.displayName = nickname
            }
            return updated
        }
    }

    func sendMessage(conversationID: String, content: String) async throws -> ChatMessage {
        var sender = currentUser
        if let squad = squads.first(where: { $0.id == conversationID }),
           let myMember = squad.members.first(where: { $0.id == currentUser.id }) {
            sender.displayName = myMember.shownName
        }

        let message = ChatMessage(
            id: UUID().uuidString,
            conversationID: conversationID,
            sender: sender,
            content: content,
            createdAt: Date(),
            isMine: true
        )

        messagesByConversation[conversationID, default: []].append(message)

        if let index = conversations.firstIndex(where: { $0.id == conversationID }) {
            conversations[index].lastMessage = content
            conversations[index].lastMessageSenderID = currentUser.id
            conversations[index].updatedAt = Date()
        }

        return message
    }

    func fetchRecommendedSquads() async throws -> [SquadSummary] {
        squads.map { squad in
            SquadSummary(
                id: squad.id,
                name: squad.name,
                description: squad.description,
                avatarURL: squad.avatarURL,
                bannerURL: squad.bannerURL,
                isPublic: squad.isPublic,
                memberCount: squad.memberCount,
                isMember: squad.isMember,
                lastMessage: squad.lastMessage,
                updatedAt: squad.updatedAt
            )
        }
    }

    func fetchMySquads() async throws -> [SquadSummary] {
        squads
            .filter(\.isMember)
            .map { squad in
                SquadSummary(
                    id: squad.id,
                    name: squad.name,
                    description: squad.description,
                    avatarURL: squad.avatarURL,
                    bannerURL: squad.bannerURL,
                    isPublic: squad.isPublic,
                    memberCount: squad.memberCount,
                    isMember: true,
                    lastMessage: squad.lastMessage,
                    updatedAt: squad.updatedAt
                )
            }
    }

    func fetchSquadProfile(squadID: String) async throws -> SquadProfile {
        guard let squad = squads.first(where: { $0.id == squadID }) else {
            throw ServiceError.message("小队不存在")
        }
        return squad
    }

    func joinSquad(squadID: String) async throws {
        guard let index = squads.firstIndex(where: { $0.id == squadID }) else {
            throw ServiceError.message("小队不存在")
        }
        if !squads[index].isMember {
            squads[index].isMember = true
            squads[index].memberCount += 1
            squads[index].myRole = "member"
            squads[index].myNickname = nil
            squads[index].myNotificationsEnabled = true
            squads[index].canEditGroup = false
            if !squads[index].members.contains(where: { $0.id == currentUser.id }) {
                squads[index].members.insert(
                    SquadMemberProfile(
                        id: currentUser.id,
                        username: currentUser.username,
                        displayName: currentUser.displayName,
                        avatarURL: currentUser.avatarURL,
                        isFollowing: false,
                        role: "member",
                        nickname: nil,
                        isCaptain: false,
                        isAdmin: false
                    ),
                    at: 0
                )
            }
            squads[index].updatedAt = Date()
            if !conversations.contains(where: { $0.id == squadID }) {
                conversations.append(
                    Conversation(
                        id: squadID,
                        type: .group,
                        title: squads[index].name,
                        avatarURL: squads[index].avatarURL,
                        lastMessage: squads[index].lastMessage ?? "欢迎加入小队",
                        lastMessageSenderID: nil,
                        unreadCount: 0,
                        updatedAt: Date(),
                        peer: nil
                    )
                )
                messagesByConversation[squadID] = []
            }
        }
    }

    func createSquad(input: CreateSquadInput) async throws -> Conversation {
        let selectedMemberIds = Array(
            Set(
                input.memberIds
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty && $0 != currentUser.id }
            )
        )

        let myFriendIds = friendIDs(for: currentUser.id)
        let hasNonFriend = selectedMemberIds.contains { !myFriendIds.contains($0) }
        if hasNonFriend {
            throw ServiceError.message("只能从好友列表中选择小队成员")
        }

        let normalizedName = input.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let fallbackName = "\(currentUser.id)+\(Int(Date().timeIntervalSince1970))创建的小队"
        let finalName = normalizedName.isEmpty ? fallbackName : normalizedName
        let normalizedDescription = input.description?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedBannerURL = input.bannerURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        let squadID = "grp_\(UUID().uuidString)"
        let now = Date()

        let leaderMember = SquadMemberProfile(
            id: currentUser.id,
            username: currentUser.username,
            displayName: currentUser.displayName,
            avatarURL: currentUser.avatarURL,
            isFollowing: false,
            role: "leader",
            nickname: nil,
            isCaptain: true,
            isAdmin: true
        )

        let selectedMembers: [SquadMemberProfile] = selectedMemberIds.compactMap { id in
            guard let user = usersByID[id] else { return nil }
            return SquadMemberProfile(
                id: user.id,
                username: user.username,
                displayName: user.displayName,
                avatarURL: user.avatarURL,
                isFollowing: user.isFollowing,
                role: "member",
                nickname: nil,
                isCaptain: false,
                isAdmin: false
            )
        }

        let profile = SquadProfile(
            id: squadID,
            name: finalName,
            description: normalizedDescription?.isEmpty == false ? normalizedDescription : nil,
            avatarURL: nil,
            bannerURL: normalizedBannerURL?.isEmpty == false ? normalizedBannerURL : nil,
            notice: "",
            qrCodeURL: nil,
            isPublic: input.isPublic,
            maxMembers: 50,
            memberCount: selectedMembers.count + 1,
            isMember: true,
            canEditGroup: true,
            myRole: "leader",
            myNickname: nil,
            myNotificationsEnabled: true,
            leader: currentUser,
            members: [leaderMember] + selectedMembers,
            lastMessage: nil,
            updatedAt: now,
            recentMessages: [],
            activities: []
        )
        squads.insert(profile, at: 0)
        messagesByConversation[squadID] = []

        let conversation = Conversation(
            id: squadID,
            type: .group,
            title: finalName,
            avatarURL: nil,
            lastMessage: "暂无消息",
            lastMessageSenderID: nil,
            unreadCount: 0,
            updatedAt: now,
            peer: nil
        )
        conversations.insert(conversation, at: 0)
        return conversation
    }

    func uploadSquadAvatar(
        squadID: String,
        imageData: Data,
        fileName: String,
        mimeType: String
    ) async throws -> AvatarUploadResponse {
        _ = imageData
        _ = mimeType
        guard let squadIndex = squads.firstIndex(where: { $0.id == squadID }) else {
            throw ServiceError.message("小队不存在")
        }
        guard squads[squadIndex].myRole == "leader" || squads[squadIndex].myRole == "admin" else {
            throw ServiceError.message("仅小队管理员可修改小队头像")
        }

        let url = "mock://squads/\(fileName)"
        squads[squadIndex].avatarURL = url
        squads[squadIndex].updatedAt = Date()
        if let conversationIndex = conversations.firstIndex(where: { $0.id == squadID }) {
            conversations[conversationIndex].avatarURL = url
            conversations[conversationIndex].updatedAt = Date()
        }
        return AvatarUploadResponse(avatarURL: url)
    }

    func updateSquadMySettings(squadID: String, input: UpdateSquadMySettingsInput) async throws {
        guard let squadIndex = squads.firstIndex(where: { $0.id == squadID }) else {
            throw ServiceError.message("小队不存在")
        }
        guard squads[squadIndex].isMember else {
            throw ServiceError.message("你还不是小队成员")
        }
        guard let memberIndex = squads[squadIndex].members.firstIndex(where: { $0.id == currentUser.id }) else {
            throw ServiceError.message("你还不是小队成员")
        }

        let trimmedNickname = input.nickname?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        squads[squadIndex].members[memberIndex].nickname = trimmedNickname.isEmpty ? nil : trimmedNickname
        squads[squadIndex].myNickname = squads[squadIndex].members[memberIndex].nickname
        squads[squadIndex].myNotificationsEnabled = input.notificationsEnabled
    }

    func updateSquadInfo(squadID: String, input: UpdateSquadInfoInput) async throws {
        guard let squadIndex = squads.firstIndex(where: { $0.id == squadID }) else {
            throw ServiceError.message("小队不存在")
        }
        let myRole = squads[squadIndex].members.first(where: { $0.id == currentUser.id })?.role
        guard myRole == "leader" || myRole == "admin" else {
            throw ServiceError.message("仅小队管理员可修改小队资料")
        }

        let trimmedName = input.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            throw ServiceError.message("小队名称不能为空")
        }

        squads[squadIndex].name = trimmedName
        let trimmedDescription = input.description.trimmingCharacters(in: .whitespacesAndNewlines)
        squads[squadIndex].description = trimmedDescription.isEmpty ? nil : trimmedDescription
        if let isPublic = input.isPublic {
            squads[squadIndex].isPublic = isPublic
        }
        let trimmedNotice = input.notice.trimmingCharacters(in: .whitespacesAndNewlines)
        squads[squadIndex].notice = trimmedNotice

        let trimmedAvatar = input.avatarURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        squads[squadIndex].avatarURL = trimmedAvatar.isEmpty ? nil : trimmedAvatar

        let trimmedBanner = input.bannerURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        squads[squadIndex].bannerURL = trimmedBanner.isEmpty ? nil : trimmedBanner

        let trimmedQRCode = input.qrCodeURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        squads[squadIndex].qrCodeURL = trimmedQRCode.isEmpty ? nil : trimmedQRCode
        squads[squadIndex].updatedAt = Date()

        if let conversationIndex = conversations.firstIndex(where: { $0.id == squadID }) {
            conversations[conversationIndex].title = squads[squadIndex].name
            conversations[conversationIndex].avatarURL = squads[squadIndex].avatarURL
            conversations[conversationIndex].updatedAt = Date()
        }
    }

    func fetchNotifications(limit: Int) async throws -> NotificationInbox {
        let normalized = max(1, min(limit, 50))
        let sorted = notifications.sorted(by: { $0.createdAt > $1.createdAt })
        let limited = Array(sorted.prefix(normalized))
        let unread = notifications.filter { !$0.isRead }.count
        return NotificationInbox(unreadCount: unread, items: limited)
    }

    func fetchNotificationUnreadCount() async throws -> NotificationUnreadCount {
        let unreadItems = notifications.filter { !$0.isRead }
        return NotificationUnreadCount(
            total: unreadItems.count,
            follows: unreadItems.filter { $0.type == .follow }.count,
            likes: unreadItems.filter { $0.type == .like }.count,
            comments: unreadItems.filter { $0.type == .comment }.count,
            squadInvites: unreadItems.filter { $0.type == .squadInvite }.count
        )
    }

    func markNotificationRead(notificationID: String) async throws {
        guard let index = notifications.firstIndex(where: { $0.id == notificationID }) else { return }
        notifications[index].isRead = true
    }

    func fetchMyProfile() async throws -> UserProfile {
        guard var profile = profilesByID[currentUser.id] else {
            throw ServiceError.message("用户不存在")
        }
        profile.followersCount = followersByUserID[currentUser.id]?.count ?? 0
        profile.followingCount = followingByUserID[currentUser.id]?.count ?? 0
        profile.friendsCount = friendIDs(for: currentUser.id).count
        profile.postsCount = posts.filter { $0.author.id == currentUser.id }.count
        profile.canViewFollowersList = true
        profile.canViewFollowingList = true
        profile.isFollowing = nil
        return profile
    }

    func updateMyProfile(input: UpdateMyProfileInput) async throws -> UserProfile {
        let displayName = input.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if displayName.isEmpty {
            throw ServiceError.message("昵称不能为空")
        }

        currentUser.displayName = displayName
        usersByID[currentUser.id]?.displayName = displayName
        profilesByID[currentUser.id]?.displayName = displayName
        profilesByID[currentUser.id]?.bio = input.bio.trimmingCharacters(in: .whitespacesAndNewlines)
        profilesByID[currentUser.id]?.tags = input.tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        profilesByID[currentUser.id]?.isFollowersListPublic = input.isFollowersListPublic
        profilesByID[currentUser.id]?.isFollowingListPublic = input.isFollowingListPublic

        for index in posts.indices where posts[index].author.id == currentUser.id {
            posts[index].author.displayName = displayName
        }

        return try await fetchMyProfile()
    }

    func uploadMyAvatar(imageData: Data, fileName: String, mimeType: String) async throws -> AvatarUploadResponse {
        _ = imageData
        _ = mimeType
        let url = "mock://avatars/\(fileName)"
        currentUser.avatarURL = url
        usersByID[currentUser.id]?.avatarURL = url
        profilesByID[currentUser.id]?.avatarURL = url

        for index in posts.indices where posts[index].author.id == currentUser.id {
            posts[index].author.avatarURL = url
        }

        for (postID, comments) in commentsByPost {
            var updatedComments = comments
            for index in updatedComments.indices where updatedComments[index].author.id == currentUser.id {
                updatedComments[index].author.avatarURL = url
            }
            commentsByPost[postID] = updatedComments
        }

        for index in conversations.indices {
            guard conversations[index].type == .direct,
                  conversations[index].peer?.id == currentUser.id else { continue }
            conversations[index].peer?.avatarURL = url
        }

        for (conversationID, messages) in messagesByConversation {
            var updatedMessages = messages
            for index in updatedMessages.indices where updatedMessages[index].sender.id == currentUser.id {
                updatedMessages[index].sender.avatarURL = url
            }
            messagesByConversation[conversationID] = updatedMessages
        }

        for index in squads.indices {
            if squads[index].leader.id == currentUser.id {
                squads[index].leader.avatarURL = url
            }

            for memberIndex in squads[index].members.indices where squads[index].members[memberIndex].id == currentUser.id {
                squads[index].members[memberIndex].avatarURL = url
            }

            for messageIndex in squads[index].recentMessages.indices where squads[index].recentMessages[messageIndex].sender.id == currentUser.id {
                squads[index].recentMessages[messageIndex].sender.avatarURL = url
            }

            for activityIndex in squads[index].activities.indices where squads[index].activities[activityIndex].createdBy.id == currentUser.id {
                squads[index].activities[activityIndex].createdBy.avatarURL = url
            }
        }

        for index in notifications.indices where notifications[index].actor?.id == currentUser.id {
            notifications[index].actor?.avatarURL = url
        }

        return AvatarUploadResponse(avatarURL: url)
    }

    func fetchMyLikeHistory(cursor: String?) async throws -> ActivityPostPage {
        _ = cursor
        let items = likeActionAtByPostID
            .compactMap { postID, actionAt -> ActivityPostItem? in
                guard let post = posts.first(where: { $0.id == postID }) else { return nil }
                return ActivityPostItem(actionAt: actionAt, post: post)
            }
            .sorted(by: { $0.actionAt > $1.actionAt })

        return ActivityPostPage(items: items, nextCursor: nil)
    }

    func fetchMyRepostHistory(cursor: String?) async throws -> ActivityPostPage {
        _ = cursor
        let items = repostActionAtByPostID
            .compactMap { postID, actionAt -> ActivityPostItem? in
                guard let post = posts.first(where: { $0.id == postID }) else { return nil }
                return ActivityPostItem(actionAt: actionAt, post: post)
            }
            .sorted(by: { $0.actionAt > $1.actionAt })

        return ActivityPostPage(items: items, nextCursor: nil)
    }

    func toggleFollow(userID: String, shouldFollow: Bool) async throws -> UserSummary {
        guard var user = usersByID[userID] else {
            throw ServiceError.message("用户不存在")
        }

        var myFollowing = followingByUserID[currentUser.id] ?? []
        var targetFollowers = followersByUserID[userID] ?? []

        if shouldFollow {
            myFollowing.insert(userID)
            targetFollowers.insert(currentUser.id)
        } else {
            myFollowing.remove(userID)
            targetFollowers.remove(currentUser.id)
        }

        followingByUserID[currentUser.id] = myFollowing
        followersByUserID[userID] = targetFollowers

        user.isFollowing = shouldFollow
        usersByID[userID] = user

        if var targetProfile = profilesByID[userID] {
            targetProfile.followersCount = targetFollowers.count
            targetProfile.friendsCount = friendIDs(for: userID).count
            targetProfile.isFollowing = shouldFollow
            profilesByID[userID] = targetProfile
        }

        if var me = profilesByID[currentUser.id] {
            me.followingCount = myFollowing.count
            me.friendsCount = friendIDs(for: currentUser.id).count
            profilesByID[currentUser.id] = me
        }

        applyCurrentFollowFlags()
        return usersByID[userID] ?? user
    }

    private func applyCurrentFollowFlags() {
        let following = followingByUserID[currentUser.id] ?? []

        for id in usersByID.keys where id != currentUser.id {
            usersByID[id]?.isFollowing = following.contains(id)
        }

        for index in posts.indices {
            let authorID = posts[index].author.id
            if authorID == currentUser.id {
                posts[index].author.isFollowing = false
            } else {
                posts[index].author.isFollowing = following.contains(authorID)
            }
        }
    }

    private func friendIDs(for userID: String) -> Set<String> {
        let following = followingByUserID[userID] ?? []
        let followers = followersByUserID[userID] ?? []
        return following.intersection(followers)
    }

    private static func seededAvatarURL(for seed: String) -> String {
        let encoded = seed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? seed
        return "https://api.dicebear.com/9.x/adventurer-neutral/png?seed=\(encoded)&backgroundType=gradientLinear"
    }

    private static func makeSeed() -> (
        currentUser: UserSummary,
        usersByID: [String: UserSummary],
        profilesByID: [String: UserProfile],
        posts: [Post],
        commentsByPost: [String: [Comment]],
        conversations: [Conversation],
        messagesByConversation: [String: [ChatMessage]],
        squads: [SquadProfile],
        notifications: [AppNotification],
        followersByUserID: [String: Set<String>],
        followingByUserID: [String: Set<String>],
        likeActionAtByPostID: [String: Date],
        repostActionAtByPostID: [String: Date]
    ) {
        let now = Date()
        let currentUser = UserSummary(
            id: "u_me",
            username: "blackie",
            displayName: "Blackie",
            avatarURL: seededAvatarURL(for: "u_me"),
            isFollowing: false
        )
        let alice = UserSummary(
            id: "u_1",
            username: "warehouse_anya",
            displayName: "Anya",
            avatarURL: seededAvatarURL(for: "u_1"),
            isFollowing: true
        )
        let bob = UserSummary(
            id: "u_2",
            username: "techno_hao",
            displayName: "Hao",
            avatarURL: seededAvatarURL(for: "u_2"),
            isFollowing: false
        )
        let squadAvatarURL = seededAvatarURL(for: "grp_1")

        let posts: [Post] = [
            Post(
                id: "p_1",
                author: alice,
                content: "昨晚在上海的 set 太炸了，谁也在现场？",
                images: ["https://images.unsplash.com/photo-1492684223066-81342ee5ff30"],
                squad: PostSquad(id: "grp_1", name: "Raver Shanghai Squad", avatarURL: squadAvatarURL),
                createdAt: now.addingTimeInterval(-1800),
                likeCount: 23,
                repostCount: 4,
                commentCount: 4,
                isLiked: false,
                isReposted: false
            ),
            Post(
                id: "p_2",
                author: bob,
                content: "本周 techno 推荐歌单更新了，想要链接评论区留1。",
                images: [],
                squad: nil,
                createdAt: now.addingTimeInterval(-7200),
                likeCount: 12,
                repostCount: 1,
                commentCount: 2,
                isLiked: true,
                isReposted: false
            )
        ]

        let commentsByPost: [String: [Comment]] = [
            "p_1": [
                Comment(
                    id: "c_1",
                    postID: "p_1",
                    author: bob,
                    content: "我也在，灯光和低频都很顶。",
                    createdAt: now.addingTimeInterval(-1200)
                )
            ]
        ]

        let conversations: [Conversation] = [
            Conversation(
                id: "dm_1",
                type: .direct,
                title: alice.displayName,
                avatarURL: alice.avatarURL,
                lastMessage: "我们周五去活动吗？",
                lastMessageSenderID: alice.id,
                unreadCount: 2,
                updatedAt: now.addingTimeInterval(-300),
                peer: alice
            ),
            Conversation(
                id: "grp_1",
                type: .group,
                title: "Raver Shanghai Squad",
                avatarURL: squadAvatarURL,
                lastMessage: "今晚 10 点集合",
                lastMessageSenderID: alice.id,
                unreadCount: 5,
                updatedAt: now.addingTimeInterval(-500),
                peer: nil
            )
        ]

        let messagesByConversation: [String: [ChatMessage]] = [
            "dm_1": [
                ChatMessage(
                    id: "m_1",
                    conversationID: "dm_1",
                    sender: alice,
                    content: "这周有空一起去新场地吗？",
                    createdAt: now.addingTimeInterval(-1200),
                    isMine: false
                )
            ],
            "grp_1": [
                ChatMessage(
                    id: "m_2",
                    conversationID: "grp_1",
                    sender: alice,
                    content: "大家到场在小队里报个到。",
                    createdAt: now.addingTimeInterval(-1500),
                    isMine: false
                )
            ]
        ]

        let squads: [SquadProfile] = [
            SquadProfile(
                id: "grp_1",
                name: "Raver Shanghai Squad",
                description: "上海本地电音社群，约活动、分享 set、现场打卡。",
                avatarURL: squadAvatarURL,
                bannerURL: nil,
                notice: "本周五 21:30 门口集合，进场后在小队里报到。",
                qrCodeURL: nil,
                isPublic: true,
                maxMembers: 80,
                memberCount: 42,
                isMember: true,
                canEditGroup: true,
                myRole: "leader",
                myNickname: "Blackie",
                myNotificationsEnabled: true,
                leader: currentUser,
                members: [
                    SquadMemberProfile(
                        id: currentUser.id,
                        username: currentUser.username,
                        displayName: currentUser.displayName,
                        avatarURL: currentUser.avatarURL,
                        isFollowing: false,
                        role: "leader",
                        nickname: "Blackie",
                        isCaptain: true,
                        isAdmin: true
                    ),
                    SquadMemberProfile(
                        id: alice.id,
                        username: alice.username,
                        displayName: alice.displayName,
                        avatarURL: alice.avatarURL,
                        isFollowing: true,
                        role: "admin",
                        nickname: "Anya",
                        isCaptain: false,
                        isAdmin: true
                    ),
                    SquadMemberProfile(
                        id: bob.id,
                        username: bob.username,
                        displayName: bob.displayName,
                        avatarURL: bob.avatarURL,
                        isFollowing: false,
                        role: "member",
                        nickname: nil,
                        isCaptain: false,
                        isAdmin: false
                    )
                ],
                lastMessage: "今晚 10 点集合",
                updatedAt: now.addingTimeInterval(-500),
                recentMessages: [
                    SquadMessagePreview(
                        id: "grp_prev_1",
                        content: "今晚 10 点集合",
                        createdAt: now.addingTimeInterval(-500),
                        sender: alice
                    ),
                    SquadMessagePreview(
                        id: "grp_prev_2",
                        content: "出发前记得带耳塞",
                        createdAt: now.addingTimeInterval(-900),
                        sender: bob
                    )
                ],
                activities: [
                    SquadActivityItem(
                        id: "act_1",
                        title: "周末仓库派对团建",
                        description: "统一 21:00 在地铁口集合，现场分队。",
                        location: "上海静安",
                        date: now.addingTimeInterval(60 * 60 * 24 * 2),
                        createdBy: alice
                    ),
                    SquadActivityItem(
                        id: "act_2",
                        title: "试听会",
                        description: "分享最近收藏的 set 和新歌。",
                        location: "线上语音",
                        date: now.addingTimeInterval(60 * 60 * 24 * 5),
                        createdBy: bob
                    )
                ]
            )
        ]

        let notifications: [AppNotification] = [
            AppNotification(
                id: "n_1",
                type: .follow,
                createdAt: now.addingTimeInterval(-260),
                isRead: false,
                actor: alice,
                text: "\(alice.displayName) 关注了你",
                target: AppNotificationTarget(type: "user", id: alice.id, title: alice.displayName)
            ),
            AppNotification(
                id: "n_2",
                type: .comment,
                createdAt: now.addingTimeInterval(-820),
                isRead: false,
                actor: bob,
                text: "\(bob.displayName) 评论了你：这条动态很有共鸣",
                target: AppNotificationTarget(type: "post", id: "p_1", title: "昨晚在上海的 set 太炸了")
            ),
            AppNotification(
                id: "n_3",
                type: .squadInvite,
                createdAt: now.addingTimeInterval(-1400),
                isRead: false,
                actor: alice,
                text: "\(alice.displayName) 邀请你加入小队「Raver Shanghai Squad」",
                target: AppNotificationTarget(type: "squad", id: "grp_1", title: "Raver Shanghai Squad")
            )
        ]

        let followersByUserID: [String: Set<String>] = [
            currentUser.id: [alice.id],
            alice.id: [currentUser.id],
            bob.id: []
        ]

        let followingByUserID: [String: Set<String>] = [
            currentUser.id: [alice.id],
            alice.id: [currentUser.id],
            bob.id: []
        ]

        let profilesByID: [String: UserProfile] = [
            currentUser.id: UserProfile(
                id: currentUser.id,
                username: currentUser.username,
                displayName: currentUser.displayName,
                bio: "MVP 阶段个人简介，后续由 BFF 聚合 Mastodon 资料和业务字段。",
                avatarURL: currentUser.avatarURL,
                tags: ["Techno", "House"],
                isFollowersListPublic: true,
                isFollowingListPublic: true,
                canViewFollowersList: true,
                canViewFollowingList: true,
                followersCount: followersByUserID[currentUser.id]?.count ?? 0,
                followingCount: followingByUserID[currentUser.id]?.count ?? 0,
                friendsCount: followingByUserID[currentUser.id]?.intersection(followersByUserID[currentUser.id] ?? []).count ?? 0,
                postsCount: posts.filter { $0.author.id == currentUser.id }.count,
                isFollowing: nil
            ),
            alice.id: UserProfile(
                id: alice.id,
                username: alice.username,
                displayName: alice.displayName,
                bio: "这是 Anya 的公开主页（Mock 数据）。",
                avatarURL: alice.avatarURL,
                tags: ["EDM", "Melodic"],
                isFollowersListPublic: true,
                isFollowingListPublic: true,
                canViewFollowersList: true,
                canViewFollowingList: true,
                followersCount: followersByUserID[alice.id]?.count ?? 0,
                followingCount: followingByUserID[alice.id]?.count ?? 0,
                friendsCount: followingByUserID[alice.id]?.intersection(followersByUserID[alice.id] ?? []).count ?? 0,
                postsCount: posts.filter { $0.author.id == alice.id }.count,
                isFollowing: true
            ),
            bob.id: UserProfile(
                id: bob.id,
                username: bob.username,
                displayName: bob.displayName,
                bio: "这是 Hao 的公开主页（Mock 数据）。",
                avatarURL: bob.avatarURL,
                tags: ["Trance"],
                isFollowersListPublic: true,
                isFollowingListPublic: true,
                canViewFollowersList: true,
                canViewFollowingList: true,
                followersCount: followersByUserID[bob.id]?.count ?? 0,
                followingCount: followingByUserID[bob.id]?.count ?? 0,
                friendsCount: followingByUserID[bob.id]?.intersection(followersByUserID[bob.id] ?? []).count ?? 0,
                postsCount: posts.filter { $0.author.id == bob.id }.count,
                isFollowing: false
            )
        ]

        let usersByID: [String: UserSummary] = [
            currentUser.id: currentUser,
            alice.id: alice,
            bob.id: bob
        ]

        let likeActionAtByPostID: [String: Date] = [
            "p_2": now.addingTimeInterval(-600)
        ]

        let repostActionAtByPostID: [String: Date] = [:]

        return (
            currentUser,
            usersByID,
            profilesByID,
            posts,
            commentsByPost,
            conversations,
            messagesByConversation,
            squads,
            notifications,
            followersByUserID,
            followingByUserID,
            likeActionAtByPostID,
            repostActionAtByPostID
        )
    }
}
