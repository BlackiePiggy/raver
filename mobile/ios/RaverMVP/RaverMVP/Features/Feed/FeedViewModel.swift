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
            return L("不感兴趣", "Not interested")
        case .seenTooOften:
            return L("总是刷到", "Seeing this too often")
        case .lowQuality:
            return L("内容质量低", "Low quality")
        case .author:
            return L("不想看这个作者", "Don't want posts from this author")
        case .other:
            return LL("其他")
        }
    }
}

protocol CircleFeedRepository {
    func fetchFeed(cursor: String?, mode: FeedMode?) async throws -> FeedPage
    func toggleLike(postID: String, shouldLike: Bool) async throws -> Post
    func toggleRepost(postID: String, shouldRepost: Bool) async throws -> Post
    func toggleSave(postID: String, shouldSave: Bool) async throws -> Post
    func recordShare(postID: String, channel: String, status: String) async throws -> Post
    func hidePost(postID: String, reason: String?) async throws
    func recordFeedEvent(input: FeedEventInput) async throws
    func toggleFollow(userID: String, shouldFollow: Bool) async throws -> UserSummary
}

struct CircleFeedRepositoryAdapter: CircleFeedRepository {
    private let service: SocialService

    init(service: SocialService) {
        self.service = service
    }

    func fetchFeed(cursor: String?, mode: FeedMode?) async throws -> FeedPage {
        try await service.fetchFeed(cursor: cursor, mode: mode)
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

    func recordFeedEvent(input: FeedEventInput) async throws {
        try await service.recordFeedEvent(input: input)
    }

    func toggleFollow(userID: String, shouldFollow: Bool) async throws -> UserSummary {
        try await service.toggleFollow(userID: userID, shouldFollow: shouldFollow)
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

    private let repository: CircleFeedRepository
    private var nextCursor: String?
    private var hasMore = true
    private let localHiddenStorageKey = "circle.feed.localHiddenPostIds.v1"
    private var localHiddenPostIDs: Set<String>
    private var reportedImpressionPostIDs: Set<String> = []
    private let feedSessionID = UUID().uuidString

    init(repository: CircleFeedRepository) {
        self.repository = repository
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
            let page = try await repository.fetchFeed(cursor: nil, mode: selectedMode)
            posts = page.posts.filter { !$0.isRaverNews && !localHiddenPostIDs.contains($0.id) }
            nextCursor = page.nextCursor
            hasMore = page.nextCursor != nil
            phase = posts.isEmpty ? .empty : .success
            bannerMessage = nil
            self.error = nil
        } catch {
            let message = error.userFacingMessage ?? L("动态加载失败，请稍后重试", "Failed to load posts. Please try again later.")
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
            let page = try await repository.fetchFeed(cursor: cursor, mode: selectedMode)
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
            bannerMessage = error.userFacingMessage
        }
    }

    func toggleLike(post: Post, position: Int? = nil) async {
        do {
            let updated = try await repository.toggleLike(postID: post.id, shouldLike: !post.isLiked)
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
            let updated = try await repository.toggleRepost(postID: post.id, shouldRepost: !post.isReposted)
            replace(updated)
        } catch {
            self.error = error.userFacingMessage
        }
    }

    func toggleSave(post: Post, position: Int? = nil) async {
        do {
            let updated = try await repository.toggleSave(postID: post.id, shouldSave: !post.isSaved)
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
            let updated = try await repository.recordShare(postID: post.id, channel: channel, status: "completed")
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
            try await repository.hidePost(postID: post.id, reason: reason)
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
            let updatedAuthor = try await repository.toggleFollow(userID: author.id, shouldFollow: !author.isFollowing)
            for index in posts.indices where posts[index].author.id == updatedAuthor.id {
                posts[index].author = updatedAuthor
            }
        } catch {
            self.error = error.userFacingMessage
        }
    }

    func mergeNewPost(_ post: Post) {
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
            try await repository.recordFeedEvent(
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
