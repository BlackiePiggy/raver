import Foundation
import Combine

@MainActor
final class UserProfileViewModel: ObservableObject {
    @Published var profile: UserProfile?
    @Published var posts: [Post] = []
    @Published var recentCheckins: [WebCheckin] = []
    @Published private(set) var phase: LoadPhase = .idle
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var isLoadingMore = false
    @Published var bannerMessage: String?
    @Published var error: String?

    private let userID: String
    private let repository: ProfileSocialRepository
    private var nextCursor: String?
    private var hasMore = true

    init(userID: String, repository: ProfileSocialRepository) {
        self.userID = userID
        self.repository = repository
    }

    func load() async {
        if isLoading { return }
        isLoading = true
        let hadContent = profile != nil || !posts.isEmpty
        if hadContent {
            isRefreshing = true
        } else {
            phase = .initialLoading
        }
        defer { isLoading = false }
        defer { isRefreshing = false }

        do {
            async let profileTask = repository.fetchUserProfile(userID: userID)
            async let postsTask = repository.fetchPostsByUser(userID: userID, cursor: nil)
            let (profileValue, page) = try await (profileTask, postsTask)

            profile = profileValue
            posts = page.posts.filter { !$0.isRaverNews }
            if let checkinPage = try? await repository.fetchUserCheckins(userID: userID, page: 1, limit: 6, type: nil) {
                recentCheckins = checkinPage.items
            } else {
                recentCheckins = []
            }
            nextCursor = page.nextCursor
            hasMore = page.nextCursor != nil
            phase = .success
            bannerMessage = nil
            error = nil
        } catch {
            let message = error.userFacingMessage ?? L("用户主页加载失败，请稍后重试", "Failed to load profile. Please try again later.")
            if hadContent {
                bannerMessage = message
                phase = .success
            } else {
                phase = .failure(message: message)
            }
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
            let page = try await repository.fetchPostsByUser(userID: userID, cursor: cursor)
            let existing = Set(posts.map(\.id))
            posts.append(contentsOf: page.posts.filter { !existing.contains($0.id) && !$0.isRaverNews })
            nextCursor = page.nextCursor
            hasMore = page.nextCursor != nil
            bannerMessage = nil
            error = nil
        } catch {
            bannerMessage = error.userFacingMessage
        }
    }

    func toggleFollow() async {
        guard let profile else { return }
        do {
            let updated = try await repository.toggleFollow(userID: profile.id, shouldFollow: !(profile.isFollowing ?? false))
            var refreshed = try await repository.fetchUserProfile(userID: profile.id)
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
            let updated = try await repository.toggleLike(postID: post.id, shouldLike: !post.isLiked)
            if let index = posts.firstIndex(where: { $0.id == updated.id }) {
                posts[index] = updated
            }
        } catch {
            self.error = error.userFacingMessage
        }
    }

    func toggleRepost(post: Post) async {
        do {
            let updated = try await repository.toggleRepost(postID: post.id, shouldRepost: !post.isReposted)
            if let index = posts.firstIndex(where: { $0.id == updated.id }) {
                posts[index] = updated
            }
        } catch {
            self.error = error.userFacingMessage
        }
    }
}
