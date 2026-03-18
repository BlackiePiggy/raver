import Foundation
import Combine

@MainActor
final class FeedViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var error: String?

    private let service: SocialService
    private var nextCursor: String?
    private var hasMore = true

    init(service: SocialService) {
        self.service = service
    }

    func load() async {
        if isLoading { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let page = try await service.fetchFeed(cursor: nil)
            posts = page.posts
            nextCursor = page.nextCursor
            hasMore = page.nextCursor != nil
            self.error = nil
        } catch {
            self.error = error.localizedDescription
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
            let page = try await service.fetchFeed(cursor: cursor)
            let existingIds = Set(posts.map(\.id))
            posts.append(contentsOf: page.posts.filter { !existingIds.contains($0.id) })
            nextCursor = page.nextCursor
            hasMore = page.nextCursor != nil
            self.error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func toggleLike(post: Post) async {
        do {
            let updated = try await service.toggleLike(postID: post.id, shouldLike: !post.isLiked)
            replace(updated)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func toggleRepost(post: Post) async {
        do {
            let updated = try await service.toggleRepost(postID: post.id, shouldRepost: !post.isReposted)
            replace(updated)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func toggleFollow(author: UserSummary) async {
        do {
            let updatedAuthor = try await service.toggleFollow(userID: author.id, shouldFollow: !author.isFollowing)
            for index in posts.indices where posts[index].author.id == updatedAuthor.id {
                posts[index].author = updatedAuthor
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func mergeNewPost(_ post: Post) {
        posts.insert(post, at: 0)
    }

    private func replace(_ post: Post) {
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
        posts[index] = post
    }
}
