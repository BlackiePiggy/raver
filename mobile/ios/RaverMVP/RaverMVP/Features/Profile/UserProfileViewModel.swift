import Foundation
import Combine

@MainActor
final class UserProfileViewModel: ObservableObject {
    @Published var profile: UserProfile?
    @Published var posts: [Post] = []
    @Published var recentCheckins: [WebCheckin] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var error: String?

    private let userID: String
    private let service: SocialService
    private let webService: WebFeatureService
    private var nextCursor: String?
    private var hasMore = true

    init(userID: String, service: SocialService, webService: WebFeatureService = AppEnvironment.makeWebService()) {
        self.userID = userID
        self.service = service
        self.webService = webService
    }

    func load() async {
        if isLoading { return }
        isLoading = true
        defer { isLoading = false }

        do {
            async let profileTask = service.fetchUserProfile(userID: userID)
            async let postsTask = service.fetchPostsByUser(userID: userID, cursor: nil)
            let (profileValue, page) = try await (profileTask, postsTask)

            profile = profileValue
            posts = page.posts.filter { !$0.isRaverNews }
            if let checkinPage = try? await webService.fetchUserCheckins(userID: userID, page: 1, limit: 6, type: nil) {
                recentCheckins = checkinPage.items
            } else {
                recentCheckins = []
            }
            nextCursor = page.nextCursor
            hasMore = page.nextCursor != nil
            error = nil
        } catch {
            self.error = error.userFacingMessage
        }
    }

    func refresh() async {
        await load()
    }

    func loadMoreIfNeeded(currentPost: Post) async {
        guard hasMore, !isLoading, !isLoadingMore else { return }
        guard currentPost.id == posts.last?.id else { return }
        guard let cursor = nextCursor else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let page = try await service.fetchPostsByUser(userID: userID, cursor: cursor)
            let existing = Set(posts.map(\.id))
            posts.append(contentsOf: page.posts.filter { !existing.contains($0.id) && !$0.isRaverNews })
            nextCursor = page.nextCursor
            hasMore = page.nextCursor != nil
            error = nil
        } catch {
            self.error = error.userFacingMessage
        }
    }

    func toggleFollow() async {
        guard let profile else { return }
        do {
            let updated = try await service.toggleFollow(userID: profile.id, shouldFollow: !(profile.isFollowing ?? false))
            var refreshed = try await service.fetchUserProfile(userID: profile.id)
            refreshed.isFollowing = updated.isFollowing
            self.profile = refreshed
            for index in posts.indices where posts[index].author.id == updated.id {
                posts[index].author = updated
            }
        } catch {
            self.error = error.userFacingMessage
        }
    }

    func toggleLike(post: Post) async {
        do {
            let updated = try await service.toggleLike(postID: post.id, shouldLike: !post.isLiked)
            if let index = posts.firstIndex(where: { $0.id == updated.id }) {
                posts[index] = updated
            }
        } catch {
            self.error = error.userFacingMessage
        }
    }

    func toggleRepost(post: Post) async {
        do {
            let updated = try await service.toggleRepost(postID: post.id, shouldRepost: !post.isReposted)
            if let index = posts.firstIndex(where: { $0.id == updated.id }) {
                posts[index] = updated
            }
        } catch {
            self.error = error.userFacingMessage
        }
    }
}
