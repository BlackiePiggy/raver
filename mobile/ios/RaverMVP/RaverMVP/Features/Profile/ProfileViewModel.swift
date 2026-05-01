import Foundation
import Combine

protocol ProfileSocialRepository {
    func fetchMyProfile() async throws -> UserProfile
    func fetchUserProfile(userID: String) async throws -> UserProfile
    func fetchPostsByUser(userID: String, cursor: String?) async throws -> FeedPage
    func fetchMyLikeHistory(cursor: String?) async throws -> ActivityPostPage
    func fetchMyRepostHistory(cursor: String?) async throws -> ActivityPostPage
    func fetchMySaveHistory(cursor: String?) async throws -> ActivityPostPage
    func fetchUserCheckins(userID: String, page: Int, limit: Int, type: String?) async throws -> CheckinListPage
    func toggleLike(postID: String, shouldLike: Bool) async throws -> Post
    func toggleRepost(postID: String, shouldRepost: Bool) async throws -> Post
    func toggleSave(postID: String, shouldSave: Bool) async throws -> Post
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

    func fetchMySaveHistory(cursor: String?) async throws -> ActivityPostPage {
        try await socialService.fetchMySaveHistory(cursor: cursor)
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

    func toggleSave(postID: String, shouldSave: Bool) async throws -> Post {
        try await socialService.toggleSave(postID: postID, shouldSave: shouldSave)
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
    let savedItems: [ActivityPostItem]
    let recentCheckins: [WebCheckin]
}

private struct ProfileOfflineSnapshot: Codable {
    var profile: UserProfile
    var recentPosts: [Post]
    var likedItems: [ActivityPostItem]
    var repostedItems: [ActivityPostItem]
    var savedItems: [ActivityPostItem]
    var recentCheckins: [WebCheckin]
    var cachedAt: Date
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
        async let savesTask = repository.fetchMySaveHistory(cursor: nil)

        let (postsPage, likesPage, repostsPage, savesPage) = try await (postsTask, likesTask, repostsTask, savesTask)
        let checkins = (try? await repository.fetchUserCheckins(userID: profileValue.id, page: 1, limit: 6, type: nil))?.items ?? []

        return ProfileDashboardSnapshot(
            profile: profileValue,
            recentPosts: postsPage.posts.filter { !$0.isRaverNews },
            likedItems: likesPage.items,
            repostedItems: repostsPage.items,
            savedItems: savesPage.items,
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
        case saves

        var id: String { rawValue }

        var title: String {
            switch self {
            case .recent: return L("近期动态", "Recent")
            case .likes: return L("点赞历史", "Likes")
            case .reposts: return L("转发历史", "Reposts")
            case .saves: return L("收藏", "Saves")
            }
        }
    }

    @Published var profile: UserProfile?
    @Published var recentPosts: [Post] = []
    @Published var likedItems: [ActivityPostItem] = []
    @Published var repostedItems: [ActivityPostItem] = []
    @Published var savedItems: [ActivityPostItem] = []
    @Published var recentCheckins: [WebCheckin] = []
    @Published var selectedSection: Section = .recent
    @Published private(set) var phase: LoadPhase = .idle
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var bannerMessage: String?
    @Published var error: String?

    private let repository: ProfileSocialRepository
    private let loadDashboardUseCase: LoadMyProfileDashboardUseCase
    private let offlineSnapshotStorageKey = "raver.profile.offlineSnapshot.v1"

    init(repository: ProfileSocialRepository) {
        self.repository = repository
        self.loadDashboardUseCase = LoadMyProfileDashboardUseCase(repository: repository)
    }

    func load() async {
        if isLoading { return }
        isLoading = true
        let hadContent = profile != nil
        if hadContent {
            isRefreshing = true
        } else {
            phase = .initialLoading
        }
        defer { isLoading = false }
        defer { isRefreshing = false }

        do {
            let dashboard = try await loadDashboardUseCase.execute()
            profile = dashboard.profile
            recentPosts = dashboard.recentPosts
            likedItems = dashboard.likedItems
            repostedItems = dashboard.repostedItems
            savedItems = dashboard.savedItems
            recentCheckins = dashboard.recentCheckins
            persistOfflineSnapshot()
            phase = .success
            bannerMessage = nil
            self.error = nil
        } catch {
            if restoreOfflineSnapshot() {
                phase = .success
                bannerMessage = L("当前离线，已显示上次同步的个人主页数据。", "You're offline. Showing your latest synced profile snapshot.")
                self.error = nil
            } else if hadContent {
                bannerMessage = error.userFacingMessage ?? L("个人主页更新失败，请稍后重试", "Failed to refresh profile. Please try again later.")
                phase = .success
            } else {
                let message = error.userFacingMessage ?? L("个人主页加载失败，请稍后重试", "Failed to load profile. Please try again later.")
                phase = .failure(message: message)
            }
        }
    }

    func refreshSection() async {
        guard let profile else {
            await load()
            return
        }

        isRefreshing = true
        defer { isRefreshing = false }

        do {
            switch selectedSection {
            case .recent:
                recentPosts = try await repository.fetchPostsByUser(userID: profile.id, cursor: nil).posts.filter { !$0.isRaverNews }
            case .likes:
                likedItems = try await repository.fetchMyLikeHistory(cursor: nil).items
            case .reposts:
                repostedItems = try await repository.fetchMyRepostHistory(cursor: nil).items
            case .saves:
                savedItems = try await repository.fetchMySaveHistory(cursor: nil).items
            }
            if let checkinPage = try? await repository.fetchUserCheckins(userID: profile.id, page: 1, limit: 6, type: nil) {
                recentCheckins = checkinPage.items
            }
            persistOfflineSnapshot()
            phase = .success
            bannerMessage = nil
            self.error = nil
        } catch {
            bannerMessage = error.userFacingMessage ?? L("当前内容刷新失败，请稍后重试", "Failed to refresh this section. Please try again later.")
        }
    }

    func applyUpdatedProfile(_ profile: UserProfile) {
        self.profile = profile
        phase = .success
        persistOfflineSnapshot()
    }

    func toggleLike(post: Post) async {
        do {
            let updated = try await repository.toggleLike(postID: post.id, shouldLike: !post.isLiked)
            replacePost(updated)
            if !updated.isLiked {
                likedItems.removeAll { $0.post.id == updated.id }
            }
            persistOfflineSnapshot()
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
            persistOfflineSnapshot()
        } catch {
            self.error = error.userFacingMessage
        }
    }

    func toggleSave(post: Post) async {
        do {
            let updated = try await repository.toggleSave(postID: post.id, shouldSave: !post.isSaved)
            replacePost(updated)
            if !updated.isSaved {
                savedItems.removeAll { $0.post.id == updated.id }
            }
            persistOfflineSnapshot()
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

        for index in savedItems.indices where savedItems[index].post.id == updated.id {
            savedItems[index].post = updated
        }
    }

    private func persistOfflineSnapshot() {
        guard let profile else { return }
        let snapshot = ProfileOfflineSnapshot(
            profile: profile,
            recentPosts: recentPosts,
            likedItems: likedItems,
            repostedItems: repostedItems,
            savedItems: savedItems,
            recentCheckins: recentCheckins,
            cachedAt: Date()
        )

        do {
            let data = try JSONEncoder.raver.encode(snapshot)
            UserDefaults.standard.set(data, forKey: offlineSnapshotStorageKey)
        } catch {
            assertionFailure("Failed to persist profile offline snapshot: \(error)")
        }
    }

    private func restoreOfflineSnapshot() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: offlineSnapshotStorageKey),
              let snapshot = try? JSONDecoder.raver.decode(ProfileOfflineSnapshot.self, from: data) else {
            return false
        }

        profile = snapshot.profile
        recentPosts = snapshot.recentPosts
        likedItems = snapshot.likedItems
        repostedItems = snapshot.repostedItems
        savedItems = snapshot.savedItems
        recentCheckins = snapshot.recentCheckins
        return true
    }
}
