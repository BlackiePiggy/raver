import Foundation
import Combine

protocol CircleFeedRepository {
    func fetchFeed(cursor: String?) async throws -> FeedPage
    func toggleLike(postID: String, shouldLike: Bool) async throws -> Post
    func toggleRepost(postID: String, shouldRepost: Bool) async throws -> Post
    func toggleFollow(userID: String, shouldFollow: Bool) async throws -> UserSummary
}

struct CircleFeedRepositoryAdapter: CircleFeedRepository {
    private let service: SocialService

    init(service: SocialService) {
        self.service = service
    }

    func fetchFeed(cursor: String?) async throws -> FeedPage {
        try await service.fetchFeed(cursor: cursor)
    }

    func toggleLike(postID: String, shouldLike: Bool) async throws -> Post {
        try await service.toggleLike(postID: postID, shouldLike: shouldLike)
    }

    func toggleRepost(postID: String, shouldRepost: Bool) async throws -> Post {
        try await service.toggleRepost(postID: postID, shouldRepost: shouldRepost)
    }

    func toggleFollow(userID: String, shouldFollow: Bool) async throws -> UserSummary {
        try await service.toggleFollow(userID: userID, shouldFollow: shouldFollow)
    }
}

@MainActor
final class FeedViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var error: String?

    private let repository: CircleFeedRepository
    private var nextCursor: String?
    private var hasMore = true

    init(repository: CircleFeedRepository) {
        self.repository = repository
    }

    func load() async {
        if isLoading { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let page = try await repository.fetchFeed(cursor: nil)
            posts = page.posts.filter { !$0.isRaverNews }
            nextCursor = page.nextCursor
            hasMore = page.nextCursor != nil
            self.error = nil
        } catch {
            self.error = error.userFacingMessage
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
            let page = try await repository.fetchFeed(cursor: cursor)
            let existingIds = Set(posts.map(\.id))
            posts.append(contentsOf: page.posts.filter { !existingIds.contains($0.id) && !$0.isRaverNews })
            nextCursor = page.nextCursor
            hasMore = page.nextCursor != nil
            self.error = nil
        } catch {
            self.error = error.userFacingMessage
        }
    }

    func toggleLike(post: Post) async {
        do {
            let updated = try await repository.toggleLike(postID: post.id, shouldLike: !post.isLiked)
            replace(updated)
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
    }

    func mergeUpdatedPost(_ post: Post) {
        replace(post)
    }

    func removePost(_ postID: String) {
        posts.removeAll { $0.id == postID }
    }

    private func replace(_ post: Post) {
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
        posts[index] = post
    }
}
