import Foundation
import Combine

protocol ProfileSocialRepository {
    func fetchMyProfile() async throws -> UserProfile
    func fetchUserProfile(userID: String) async throws -> UserProfile
    func fetchPostsByUser(userID: String, cursor: String?) async throws -> FeedPage
    func fetchMyLikeHistory(cursor: String?) async throws -> ActivityPostPage
    func fetchMyRepostHistory(cursor: String?) async throws -> ActivityPostPage
    func fetchUserCheckins(userID: String, page: Int, limit: Int, type: String?) async throws -> CheckinListPage
    func toggleLike(postID: String, shouldLike: Bool) async throws -> Post
    func toggleRepost(postID: String, shouldRepost: Bool) async throws -> Post
    func fetchFollowers(userID: String, cursor: String?) async throws -> FollowListPage
    func fetchFollowing(userID: String, cursor: String?) async throws -> FollowListPage
    func fetchFriends(userID: String, cursor: String?) async throws -> FollowListPage
    func toggleFollow(userID: String, shouldFollow: Bool) async throws -> UserSummary
    func uploadMyAvatar(imageData: Data, fileName: String, mimeType: String) async throws -> AvatarUploadResponse
    func updateMyProfile(input: UpdateMyProfileInput) async throws -> UserProfile
}

struct ProfileSocialRepositoryAdapter: ProfileSocialRepository {
    private let socialService: SocialService
    private let webService: WebFeatureService

    init(
        socialService: SocialService,
        webService: WebFeatureService
    ) {
        self.socialService = socialService
        self.webService = webService
    }

    func fetchMyProfile() async throws -> UserProfile {
        try await socialService.fetchMyProfile()
    }

    func fetchUserProfile(userID: String) async throws -> UserProfile {
        try await socialService.fetchUserProfile(userID: userID)
    }

    func fetchPostsByUser(userID: String, cursor: String?) async throws -> FeedPage {
        try await socialService.fetchPostsByUser(userID: userID, cursor: cursor)
    }

    func fetchMyLikeHistory(cursor: String?) async throws -> ActivityPostPage {
        try await socialService.fetchMyLikeHistory(cursor: cursor)
    }

    func fetchMyRepostHistory(cursor: String?) async throws -> ActivityPostPage {
        try await socialService.fetchMyRepostHistory(cursor: cursor)
    }

    func fetchUserCheckins(userID: String, page: Int, limit: Int, type: String?) async throws -> CheckinListPage {
        try await webService.fetchUserCheckins(userID: userID, page: page, limit: limit, type: type)
    }

    func toggleLike(postID: String, shouldLike: Bool) async throws -> Post {
        try await socialService.toggleLike(postID: postID, shouldLike: shouldLike)
    }

    func toggleRepost(postID: String, shouldRepost: Bool) async throws -> Post {
        try await socialService.toggleRepost(postID: postID, shouldRepost: shouldRepost)
    }

    func fetchFollowers(userID: String, cursor: String?) async throws -> FollowListPage {
        try await socialService.fetchFollowers(userID: userID, cursor: cursor)
    }

    func fetchFollowing(userID: String, cursor: String?) async throws -> FollowListPage {
        try await socialService.fetchFollowing(userID: userID, cursor: cursor)
    }

    func fetchFriends(userID: String, cursor: String?) async throws -> FollowListPage {
        try await socialService.fetchFriends(userID: userID, cursor: cursor)
    }

    func toggleFollow(userID: String, shouldFollow: Bool) async throws -> UserSummary {
        try await socialService.toggleFollow(userID: userID, shouldFollow: shouldFollow)
    }

    func uploadMyAvatar(imageData: Data, fileName: String, mimeType: String) async throws -> AvatarUploadResponse {
        try await socialService.uploadMyAvatar(imageData: imageData, fileName: fileName, mimeType: mimeType)
    }

    func updateMyProfile(input: UpdateMyProfileInput) async throws -> UserProfile {
        try await socialService.updateMyProfile(input: input)
    }
}

struct ProfileDashboardSnapshot {
    let profile: UserProfile
    let recentPosts: [Post]
    let likedItems: [ActivityPostItem]
    let repostedItems: [ActivityPostItem]
    let recentCheckins: [WebCheckin]
}

struct LoadMyProfileDashboardUseCase {
    private let repository: ProfileSocialRepository

    init(repository: ProfileSocialRepository) {
        self.repository = repository
    }

    func execute() async throws -> ProfileDashboardSnapshot {
        let profileValue = try await repository.fetchMyProfile()

        async let postsTask = repository.fetchPostsByUser(userID: profileValue.id, cursor: nil)
        async let likesTask = repository.fetchMyLikeHistory(cursor: nil)
        async let repostsTask = repository.fetchMyRepostHistory(cursor: nil)

        let (postsPage, likesPage, repostsPage) = try await (postsTask, likesTask, repostsTask)
        let checkins = (try? await repository.fetchUserCheckins(userID: profileValue.id, page: 1, limit: 6, type: nil))?.items ?? []

        return ProfileDashboardSnapshot(
            profile: profileValue,
            recentPosts: postsPage.posts.filter { !$0.isRaverNews },
            likedItems: likesPage.items,
            repostedItems: repostsPage.items,
            recentCheckins: checkins
        )
    }
}

@MainActor
final class ProfileViewModel: ObservableObject {
    enum Section: String, CaseIterable, Identifiable {
        case recent
        case likes
        case reposts

        var id: String { rawValue }

        var title: String {
            switch self {
            case .recent: return L("近期动态", "Recent")
            case .likes: return L("点赞历史", "Likes")
            case .reposts: return L("转发历史", "Reposts")
            }
        }
    }

    @Published var profile: UserProfile?
    @Published var recentPosts: [Post] = []
    @Published var likedItems: [ActivityPostItem] = []
    @Published var repostedItems: [ActivityPostItem] = []
    @Published var recentCheckins: [WebCheckin] = []
    @Published var selectedSection: Section = .recent
    @Published var isLoading = false
    @Published var error: String?

    private let repository: ProfileSocialRepository
    private let loadDashboardUseCase: LoadMyProfileDashboardUseCase

    init(repository: ProfileSocialRepository) {
        self.repository = repository
        self.loadDashboardUseCase = LoadMyProfileDashboardUseCase(repository: repository)
    }

    func load() async {
        if isLoading { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let dashboard = try await loadDashboardUseCase.execute()
            profile = dashboard.profile
            recentPosts = dashboard.recentPosts
            likedItems = dashboard.likedItems
            repostedItems = dashboard.repostedItems
            recentCheckins = dashboard.recentCheckins
            error = nil
        } catch {
            self.error = error.userFacingMessage
        }
    }

    func refreshSection() async {
        guard let profile else {
            await load()
            return
        }

        do {
            switch selectedSection {
            case .recent:
                recentPosts = try await repository.fetchPostsByUser(userID: profile.id, cursor: nil).posts.filter { !$0.isRaverNews }
            case .likes:
                likedItems = try await repository.fetchMyLikeHistory(cursor: nil).items
            case .reposts:
                repostedItems = try await repository.fetchMyRepostHistory(cursor: nil).items
            }
            if let checkinPage = try? await repository.fetchUserCheckins(userID: profile.id, page: 1, limit: 6, type: nil) {
                recentCheckins = checkinPage.items
            }
            error = nil
        } catch {
            self.error = error.userFacingMessage
        }
    }

    func applyUpdatedProfile(_ profile: UserProfile) {
        self.profile = profile
    }

    func toggleLike(post: Post) async {
        do {
            let updated = try await repository.toggleLike(postID: post.id, shouldLike: !post.isLiked)
            replacePost(updated)
            if !updated.isLiked {
                likedItems.removeAll { $0.post.id == updated.id }
            }
        } catch {
            self.error = error.userFacingMessage
        }
    }

    func toggleRepost(post: Post) async {
        do {
            let updated = try await repository.toggleRepost(postID: post.id, shouldRepost: !post.isReposted)
            replacePost(updated)
            if !updated.isReposted {
                repostedItems.removeAll { $0.post.id == updated.id }
            }
        } catch {
            self.error = error.userFacingMessage
        }
    }

    private func replacePost(_ updated: Post) {
        if let idx = recentPosts.firstIndex(where: { $0.id == updated.id }) {
            recentPosts[idx] = updated
        }

        for index in likedItems.indices where likedItems[index].post.id == updated.id {
            likedItems[index].post = updated
        }

        for index in repostedItems.indices where repostedItems[index].post.id == updated.id {
            repostedItems[index].post = updated
        }
    }
}
