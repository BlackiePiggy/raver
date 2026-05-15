import Foundation
import Combine

enum PostHideReasonOption: String, CaseIterable, Identifiable {
    case notRelevant = "not_relevant"
    case seenTooOften = "seen_too_often"
    case lowQuality = "low_quality"
    case author = "author"
    case other = "other"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .notRelevant:
            return LT("不感兴趣", "Not interested", "興味がない")
        case .seenTooOften:
            return LT("总是刷到", "Seeing this too often", "表示されすぎる")
        case .lowQuality:
            return LT("内容质量低", "Low quality", "コンテンツの品質が低い")
        case .author:
            return LT("不想看这个作者", "Don't want posts from this author", "この投稿者の投稿を見たくない")
        case .other:
            return LT("其他", "其他", "その他")
        }
    }
}

protocol FeedStreamRepository {
    func fetchFeed(cursor: String?, mode: FeedMode?, eventID: String?) async throws -> FeedPage
}

protocol PostReadRepository {
    func fetchPost(postID: String) async throws -> Post
}

protocol PostCommandRepository {
    func createPost(input: CreatePostInput) async throws -> CreatePostResult
    func updatePost(postID: String, input: UpdatePostInput) async throws -> Post
    func deletePost(postID: String) async throws
}

protocol PostInteractionRepository {
    func toggleLike(postID: String, shouldLike: Bool) async throws -> Post
    func toggleRepost(postID: String, shouldRepost: Bool) async throws -> Post
    func toggleSave(postID: String, shouldSave: Bool) async throws -> Post
    func recordShare(postID: String, channel: String, status: String) async throws -> Post
    func hidePost(postID: String, reason: String?) async throws
    func toggleFollow(userID: String, shouldFollow: Bool) async throws -> UserSummary
}

protocol FeedEventTrackingRepository {
    func recordFeedEvent(input: FeedEventInput) async throws
}

protocol PostCommentRepository {
    func fetchComments(postID: String) async throws -> [Comment]
    func addComment(postID: String, content: String, parentCommentID: String?) async throws -> Comment
}

protocol PostMediaRepository {
    func uploadPostImage(imageData: Data, fileName: String, mimeType: String) async throws -> UploadMediaResponse
    func uploadPostVideo(videoData: Data, fileName: String, mimeType: String) async throws -> UploadMediaResponse
}

struct FeedStreamRepositoryAdapter: FeedStreamRepository {
    private let service: SocialService

    init(service: SocialService) {
        self.service = service
    }

    func fetchFeed(cursor: String?, mode: FeedMode?, eventID: String?) async throws -> FeedPage {
        try await service.fetchFeed(cursor: cursor, mode: mode, eventID: eventID)
    }
}

struct PostReadRepositoryAdapter: PostReadRepository {
    private let service: SocialService

    init(service: SocialService) {
        self.service = service
    }

    func fetchPost(postID: String) async throws -> Post {
        try await service.fetchPost(postID: postID)
    }
}

struct PostCommandRepositoryAdapter: PostCommandRepository {
    private let service: SocialService

    init(service: SocialService) {
        self.service = service
    }

    func createPost(input: CreatePostInput) async throws -> CreatePostResult {
        try await service.createPost(input: input)
    }

    func updatePost(postID: String, input: UpdatePostInput) async throws -> Post {
        try await service.updatePost(postID: postID, input: input)
    }

    func deletePost(postID: String) async throws {
        try await service.deletePost(postID: postID)
    }
}

struct PostInteractionRepositoryAdapter: PostInteractionRepository {
    private let service: SocialService

    init(service: SocialService) {
        self.service = service
    }

    func toggleLike(postID: String, shouldLike: Bool) async throws -> Post {
        try await service.toggleLike(postID: postID, shouldLike: shouldLike)
    }

    func toggleRepost(postID: String, shouldRepost: Bool) async throws -> Post {
        try await service.toggleRepost(postID: postID, shouldRepost: shouldRepost)
    }

    func toggleSave(postID: String, shouldSave: Bool) async throws -> Post {
        try await service.toggleSave(postID: postID, shouldSave: shouldSave)
    }

    func recordShare(postID: String, channel: String, status: String) async throws -> Post {
        try await service.recordShare(postID: postID, channel: channel, status: status)
    }

    func hidePost(postID: String, reason: String?) async throws {
        try await service.hidePost(postID: postID, reason: reason)
    }

    func toggleFollow(userID: String, shouldFollow: Bool) async throws -> UserSummary {
        try await service.toggleFollow(userID: userID, shouldFollow: shouldFollow)
    }
}

struct FeedEventTrackingRepositoryAdapter: FeedEventTrackingRepository {
    private let service: SocialService

    init(service: SocialService) {
        self.service = service
    }

    func recordFeedEvent(input: FeedEventInput) async throws {
        try await service.recordFeedEvent(input: input)
    }
}

struct PostCommentRepositoryAdapter: PostCommentRepository {
    private let service: SocialService

    init(service: SocialService) {
        self.service = service
    }

    func fetchComments(postID: String) async throws -> [Comment] {
        try await service.fetchComments(postID: postID)
    }

    func addComment(postID: String, content: String, parentCommentID: String?) async throws -> Comment {
        try await service.addComment(postID: postID, content: content, parentCommentID: parentCommentID)
    }
}

struct PostMediaRepositoryAdapter: PostMediaRepository {
    private let service: WebFeatureService

    init(service: WebFeatureService) {
        self.service = service
    }

    func uploadPostImage(imageData: Data, fileName: String, mimeType: String) async throws -> UploadMediaResponse {
        try await service.uploadPostImage(imageData: imageData, fileName: fileName, mimeType: mimeType)
    }

    func uploadPostVideo(videoData: Data, fileName: String, mimeType: String) async throws -> UploadMediaResponse {
        try await service.uploadPostVideo(videoData: videoData, fileName: fileName, mimeType: mimeType)
    }
}

@MainActor
final class FeedViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var selectedMode: FeedMode = .recommended
    @Published private(set) var phase: LoadPhase = .idle
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var isLoadingMore = false
    @Published var bannerMessage: String?
    @Published var error: String?

    private let streamRepository: FeedStreamRepository
    private let interactionRepository: PostInteractionRepository
    private let eventTrackingRepository: FeedEventTrackingRepository
    private let eventID: String?
    private var nextCursor: String?
    private var hasMore = true
    private let localHiddenStorageKey = "circle.feed.localHiddenPostIds.v1"
    private var localHiddenPostIDs: Set<String>
    private var reportedImpressionPostIDs: Set<String> = []
    private let feedSessionID = UUID().uuidString

    init(
        streamRepository: FeedStreamRepository,
        interactionRepository: PostInteractionRepository,
        eventTrackingRepository: FeedEventTrackingRepository,
        eventID: String? = nil
    ) {
        self.streamRepository = streamRepository
        self.interactionRepository = interactionRepository
        self.eventTrackingRepository = eventTrackingRepository
        self.eventID = eventID
        if let ids = UserDefaults.standard.array(forKey: localHiddenStorageKey) as? [String] {
            self.localHiddenPostIDs = Set(ids)
        } else {
            self.localHiddenPostIDs = []
        }
    }

    func load() async {
        if isLoading { return }
        isLoading = true
        let hadContent = !posts.isEmpty
        if hadContent {
            isRefreshing = true
        } else {
            phase = .initialLoading
        }
        defer { isLoading = false }
        defer { isRefreshing = false }

        do {
            let page = try await streamRepository.fetchFeed(cursor: nil, mode: selectedMode, eventID: eventID)
            posts = page.posts.filter { !$0.isRaverNews && !localHiddenPostIDs.contains($0.id) }
            nextCursor = page.nextCursor
            hasMore = page.nextCursor != nil
            phase = posts.isEmpty ? .empty : .success
            bannerMessage = nil
            self.error = nil
        } catch {
            if error.isUserInitiatedCancellation {
                return
            }
            let message = error.userFacingMessage ?? LT("动态加载失败，请稍后重试", "Failed to load posts. Please try again later.", "投稿の読み込みに失敗しました。後でもう一度お試しください。")
            if hadContent {
                bannerMessage = message
                phase = posts.isEmpty ? .empty : .success
            } else {
                phase = .failure(message: message)
            }
        }
    }

    func refresh() async {
        await load()
    }

    func loadMoreIfNeeded(currentPost: Post) async {
        guard hasMore, !isLoadingMore, !isLoading else { return }
        guard currentPost.id == posts.last?.id else { return }
        guard let cursor = nextCursor else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let page = try await streamRepository.fetchFeed(cursor: cursor, mode: selectedMode, eventID: eventID)
            let existingIds = Set(posts.map(\.id))
            posts.append(contentsOf: page.posts.filter {
                !existingIds.contains($0.id) &&
                !$0.isRaverNews &&
                !localHiddenPostIDs.contains($0.id)
            })
            nextCursor = page.nextCursor
            hasMore = page.nextCursor != nil
            phase = posts.isEmpty ? .empty : .success
            bannerMessage = nil
            self.error = nil
        } catch {
            if error.isUserInitiatedCancellation {
                return
            }
            bannerMessage = error.userFacingMessage
        }
    }

    func toggleLike(post: Post, position: Int? = nil) async {
        do {
            let updated = try await interactionRepository.toggleLike(postID: post.id, shouldLike: !post.isLiked)
            replace(updated)
            await safeRecordFeedEvent(
                eventType: "feed_like",
                postID: post.id,
                position: position
            )
        } catch {
            self.error = error.userFacingMessage
        }
    }

    func toggleRepost(post: Post) async {
        do {
            let updated = try await interactionRepository.toggleRepost(postID: post.id, shouldRepost: !post.isReposted)
            replace(updated)
        } catch {
            self.error = error.userFacingMessage
        }
    }

    func toggleSave(post: Post, position: Int? = nil) async {
        do {
            let updated = try await interactionRepository.toggleSave(postID: post.id, shouldSave: !post.isSaved)
            replace(updated)
            await safeRecordFeedEvent(
                eventType: "feed_save",
                postID: post.id,
                position: position
            )
        } catch {
            self.error = error.userFacingMessage
        }
    }

    func recordShare(post: Post, channel: String = "system", position: Int? = nil) async {
        do {
            let updated = try await interactionRepository.recordShare(postID: post.id, channel: channel, status: "completed")
            replace(updated)
            await safeRecordFeedEvent(
                eventType: "feed_share",
                postID: post.id,
                position: position,
                metadata: ["channel": channel]
            )
        } catch {
            self.error = error.userFacingMessage
        }
    }

    func hide(post: Post, reason: String? = "not_relevant", position: Int? = nil) async {
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
        let removed = posts.remove(at: index)
        do {
            try await interactionRepository.hidePost(postID: post.id, reason: reason)
            localHiddenPostIDs.insert(post.id)
            persistLocalHiddenPostIDs()
            NotificationCenter.default.post(name: .circlePostDidHide, object: post.id)
            await safeRecordFeedEvent(
                eventType: "feed_hide",
                postID: post.id,
                position: position,
                metadata: ["reason": reason ?? "not_relevant"]
            )
        } catch {
            posts.insert(removed, at: min(index, posts.count))
            self.error = error.userFacingMessage
        }
    }

    func hideLocally(postID: String, position: Int? = nil) {
        localHiddenPostIDs.insert(postID)
        posts.removeAll { $0.id == postID }
        persistLocalHiddenPostIDs()
        NotificationCenter.default.post(name: .circlePostDidHide, object: postID)
        Task {
            await safeRecordFeedEvent(
                eventType: "feed_hide",
                postID: postID,
                position: position,
                metadata: ["reason": "guest_local_hide"]
            )
        }
    }

    func trackImpressionIfNeeded(post: Post, position: Int) {
        guard !reportedImpressionPostIDs.contains(post.id) else { return }
        reportedImpressionPostIDs.insert(post.id)
        Task {
            await safeRecordFeedEvent(
                eventType: "feed_impression",
                postID: post.id,
                position: position,
                metadata: ["source": "feed_card"]
            )
        }
    }

    func trackOpenPost(post: Post, position: Int) {
        Task {
            await safeRecordFeedEvent(
                eventType: "feed_open_post",
                postID: post.id,
                position: position,
                metadata: ["source": "feed_card_tap"]
            )
        }
    }

    func toggleFollow(author: UserSummary) async {
        do {
            let updatedAuthor = try await interactionRepository.toggleFollow(userID: author.id, shouldFollow: !author.isFollowing)
            for index in posts.indices where posts[index].author.id == updatedAuthor.id {
                posts[index].author = updatedAuthor
            }
        } catch {
            self.error = error.userFacingMessage
        }
    }

    func mergeNewPost(_ post: Post) {
        posts.removeAll { $0.id == post.id }
        posts.insert(post, at: 0)
        phase = .success
    }

    func mergeUpdatedPost(_ post: Post) {
        replace(post)
    }

    func removePost(_ postID: String) {
        posts.removeAll { $0.id == postID }
        phase = posts.isEmpty ? .empty : .success
    }

    func switchMode(_ mode: FeedMode) async {
        if selectedMode != mode {
            selectedMode = mode
        }
        nextCursor = nil
        hasMore = true
        posts = []
        bannerMessage = nil
        await load()
    }

    private func replace(_ post: Post) {
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
        posts[index] = post
    }

    private func persistLocalHiddenPostIDs() {
        UserDefaults.standard.set(Array(localHiddenPostIDs), forKey: localHiddenStorageKey)
    }

    private func safeRecordFeedEvent(
        eventType: String,
        postID: String?,
        position: Int?,
        metadata: [String: String]? = nil
    ) async {
        do {
            try await eventTrackingRepository.recordFeedEvent(
                input: FeedEventInput(
                    sessionID: feedSessionID,
                    eventType: eventType,
                    postID: postID,
                    feedMode: selectedMode,
                    position: position,
                    metadata: metadata
                )
            )
        } catch {
            // Feed 埋点失败不影响主流程
        }
    }
}
