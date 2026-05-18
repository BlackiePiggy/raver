import Foundation
import Combine

protocol ProfileUserRepository {
    func fetchMyProfile() async throws -> UserProfile
    func fetchUserProfile(userID: String) async throws -> UserProfile
    func fetchFollowers(userID: String, cursor: String?) async throws -> FollowListPage
    func fetchFollowing(userID: String, cursor: String?) async throws -> FollowListPage
    func fetchFriends(userID: String, cursor: String?) async throws -> FollowListPage
    func toggleFollow(userID: String, shouldFollow: Bool) async throws -> UserSummary
    func uploadMyAvatar(imageData: Data, fileName: String, mimeType: String) async throws -> AvatarUploadResponse
    func updateMyProfile(input: UpdateMyProfileInput) async throws -> UserProfile
}

protocol ProfileContentRepository {
    func fetchPostsByUser(userID: String, cursor: String?) async throws -> FeedPage
    func fetchMyLikeHistory(cursor: String?) async throws -> ActivityPostPage
    func fetchMyRepostHistory(cursor: String?) async throws -> ActivityPostPage
    func fetchMySaveHistory(cursor: String?) async throws -> ActivityPostPage
    func fetchEvent(id: String) async throws -> WebEvent
    func fetchFollowedDJs(page: Int, limit: Int) async throws -> DJListPage
    func fetchMyPublishes() async throws -> MyPublishes
    func fetchMyContentSubmissions() async throws -> [ContentSubmissionSummary]
    func fetchMyContentSubmission(id: String) async throws -> ContentSubmissionDetail
    func resubmitMyContentSubmission(id: String, payload: [String: ContentSubmissionJSONValue], changeNote: String?) async throws -> ContentSubmissionDetail
    func toggleLike(postID: String, shouldLike: Bool) async throws -> Post
    func toggleRepost(postID: String, shouldRepost: Bool) async throws -> Post
    func toggleSave(postID: String, shouldSave: Bool) async throws -> Post
    func deleteDJSet(id: String) async throws
    func deleteEvent(id: String) async throws
    func deleteRatingEvent(id: String) async throws
    func deleteRatingUnit(id: String) async throws
}

protocol ProfileCheckinRepository {
    func fetchUserCheckins(userID: String, page: Int, limit: Int, type: String?) async throws -> CheckinListPage
    func fetchMyCheckins(page: Int, limit: Int, type: String?) async throws -> CheckinListPage
    func fetchMyCheckinsOverview() async throws -> MyCheckinsOverviewResponse
    func fetchUserCheckinsOverview(userID: String) async throws -> MyCheckinsOverviewResponse
    func fetchMyCheckinsTimeline(page: Int, limit: Int) async throws -> MyCheckinsTimelinePage
    func fetchUserCheckinsTimeline(userID: String, page: Int, limit: Int) async throws -> MyCheckinsTimelinePage
    func fetchMyCheckinsGalleryEvents(page: Int, limit: Int) async throws -> MyCheckinsGalleryEventPage
    func fetchUserCheckinsGalleryEvents(userID: String, page: Int, limit: Int) async throws -> MyCheckinsGalleryEventPage
    func fetchMyCheckinsGalleryArtists(page: Int, limit: Int) async throws -> MyCheckinsGalleryArtistPage
    func fetchUserCheckinsGalleryArtists(userID: String, page: Int, limit: Int) async throws -> MyCheckinsGalleryArtistPage
    func deleteCheckin(id: String) async throws
}

struct ProfileUserRepositoryAdapter: ProfileUserRepository {
    private let socialService: SocialService

    init(socialService: SocialService) {
        self.socialService = socialService
    }

    func fetchMyProfile() async throws -> UserProfile {
        try await socialService.fetchMyProfile()
    }

    func fetchUserProfile(userID: String) async throws -> UserProfile {
        try await socialService.fetchUserProfile(userID: userID)
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

struct ProfileContentRepositoryAdapter: ProfileContentRepository {
    private let socialService: SocialService
    private let webService: WebFeatureService

    init(
        socialService: SocialService,
        webService: WebFeatureService
    ) {
        self.socialService = socialService
        self.webService = webService
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

    func fetchEvent(id: String) async throws -> WebEvent {
        try await webService.fetchEvent(id: id)
    }

    func fetchFollowedDJs(page: Int, limit: Int) async throws -> DJListPage {
        try await webService.fetchFollowedDJs(page: page, limit: limit)
    }

    func fetchMyPublishes() async throws -> MyPublishes {
        try await webService.fetchMyPublishes()
    }

    func fetchMyContentSubmissions() async throws -> [ContentSubmissionSummary] {
        try await webService.fetchMyContentSubmissions()
    }

    func fetchMyContentSubmission(id: String) async throws -> ContentSubmissionDetail {
        try await webService.fetchMyContentSubmission(id: id)
    }

    func resubmitMyContentSubmission(
        id: String,
        payload: [String: ContentSubmissionJSONValue],
        changeNote: String?
    ) async throws -> ContentSubmissionDetail {
        try await webService.resubmitMyContentSubmission(id: id, payload: payload, changeNote: changeNote)
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

    func deleteDJSet(id: String) async throws {
        try await webService.deleteDJSet(id: id)
    }

    func deleteEvent(id: String) async throws {
        try await webService.deleteEvent(id: id)
    }

    func deleteRatingEvent(id: String) async throws {
        try await webService.deleteRatingEvent(id: id)
    }

    func deleteRatingUnit(id: String) async throws {
        try await webService.deleteRatingUnit(id: id)
    }
}

struct ProfileCheckinRepositoryAdapter: ProfileCheckinRepository {
    private let webService: WebFeatureService

    init(webService: WebFeatureService) {
        self.webService = webService
    }

    func fetchUserCheckins(userID: String, page: Int, limit: Int, type: String?) async throws -> CheckinListPage {
        try await webService.fetchUserCheckins(userID: userID, page: page, limit: limit, type: type)
    }

    func fetchMyCheckins(page: Int, limit: Int, type: String?) async throws -> CheckinListPage {
        try await webService.fetchMyCheckins(page: page, limit: limit, type: type)
    }

    func fetchMyCheckinsOverview() async throws -> MyCheckinsOverviewResponse {
        try await webService.fetchMyCheckinsOverview()
    }

    func fetchUserCheckinsOverview(userID: String) async throws -> MyCheckinsOverviewResponse {
        try await webService.fetchUserCheckinsOverview(userID: userID)
    }

    func fetchMyCheckinsTimeline(page: Int, limit: Int) async throws -> MyCheckinsTimelinePage {
        try await webService.fetchMyCheckinsTimeline(page: page, limit: limit)
    }

    func fetchUserCheckinsTimeline(userID: String, page: Int, limit: Int) async throws -> MyCheckinsTimelinePage {
        try await webService.fetchUserCheckinsTimeline(userID: userID, page: page, limit: limit)
    }

    func fetchMyCheckinsGalleryEvents(page: Int, limit: Int) async throws -> MyCheckinsGalleryEventPage {
        try await webService.fetchMyCheckinsGalleryEvents(page: page, limit: limit)
    }

    func fetchUserCheckinsGalleryEvents(userID: String, page: Int, limit: Int) async throws -> MyCheckinsGalleryEventPage {
        try await webService.fetchUserCheckinsGalleryEvents(userID: userID, page: page, limit: limit)
    }

    func fetchMyCheckinsGalleryArtists(page: Int, limit: Int) async throws -> MyCheckinsGalleryArtistPage {
        try await webService.fetchMyCheckinsGalleryArtists(page: page, limit: limit)
    }

    func fetchUserCheckinsGalleryArtists(userID: String, page: Int, limit: Int) async throws -> MyCheckinsGalleryArtistPage {
        try await webService.fetchUserCheckinsGalleryArtists(userID: userID, page: page, limit: limit)
    }

    func deleteCheckin(id: String) async throws {
        try await webService.deleteCheckin(id: id)
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
    private let userRepository: ProfileUserRepository
    private let contentRepository: ProfileContentRepository
    private let checkinRepository: ProfileCheckinRepository

    init(
        userRepository: ProfileUserRepository,
        contentRepository: ProfileContentRepository,
        checkinRepository: ProfileCheckinRepository
    ) {
        self.userRepository = userRepository
        self.contentRepository = contentRepository
        self.checkinRepository = checkinRepository
    }

    func execute() async throws -> ProfileDashboardSnapshot {
        let profileValue = try await userRepository.fetchMyProfile()

        async let postsTask = contentRepository.fetchPostsByUser(userID: profileValue.id, cursor: nil)
        async let likesTask = contentRepository.fetchMyLikeHistory(cursor: nil)
        async let repostsTask = contentRepository.fetchMyRepostHistory(cursor: nil)
        async let savesTask = contentRepository.fetchMySaveHistory(cursor: nil)

        let (postsPage, likesPage, repostsPage, savesPage) = try await (postsTask, likesTask, repostsTask, savesTask)
        let checkins = (try? await checkinRepository.fetchUserCheckins(userID: profileValue.id, page: 1, limit: 6, type: nil))?.items ?? []

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
        case published
        case saves
        case likes

        var id: String { rawValue }

        var title: String {
            switch self {
            case .published: return LT("我发的帖子", "My Posts", "自分の投稿")
            case .saves: return LT("我收藏的帖子", "Saved", "保存済み投稿")
            case .likes: return LT("我 Like 的帖子", "Liked", "いいねした投稿")
            }
        }

        var iconName: String {
            switch self {
            case .published: return "square.and.pencil"
            case .saves: return "star"
            case .likes: return "heart"
            }
        }
    }

    @Published var profile: UserProfile?
    @Published var recentPosts: [Post] = []
    @Published var likedItems: [ActivityPostItem] = []
    @Published var repostedItems: [ActivityPostItem] = []
    @Published var savedItems: [ActivityPostItem] = []
    @Published var recentCheckins: [WebCheckin] = []
    @Published var appearance: UserAssetAppearance?
    @Published var selectedSection: Section = .published
    @Published private(set) var phase: LoadPhase = .idle
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var bannerMessage: String?
    @Published var error: String?

    private let userRepository: ProfileUserRepository
    private let contentRepository: ProfileContentRepository
    private let checkinRepository: ProfileCheckinRepository
    private let virtualAssetRepository: VirtualAssetRepository
    private let loadDashboardUseCase: LoadMyProfileDashboardUseCase
    private let offlineSnapshotStorageKey = "raver.profile.offlineSnapshot.v1"

    init(
        userRepository: ProfileUserRepository,
        contentRepository: ProfileContentRepository,
        checkinRepository: ProfileCheckinRepository,
        virtualAssetRepository: VirtualAssetRepository = AppEnvironment.makeVirtualAssetRepository()
    ) {
        self.userRepository = userRepository
        self.contentRepository = contentRepository
        self.checkinRepository = checkinRepository
        self.virtualAssetRepository = virtualAssetRepository
        self.loadDashboardUseCase = LoadMyProfileDashboardUseCase(
            userRepository: userRepository,
            contentRepository: contentRepository,
            checkinRepository: checkinRepository
        )
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
            await loadAppearance(for: dashboard.profile.id)
            persistOfflineSnapshot()
            phase = .success
            bannerMessage = nil
            self.error = nil
        } catch {
            if restoreOfflineSnapshot() {
                phase = .success
                bannerMessage = LT("当前离线，已显示上次同步的个人主页数据。", "You're offline. Showing your latest synced profile snapshot.", "現在オフラインです。最後に同期したプロフィールデータを表示しています。")
                self.error = nil
            } else if hadContent {
                bannerMessage = error.userFacingMessage ?? LT("个人主页更新失败，请稍后重试", "Failed to refresh profile. Please try again later.", "プロフィールを更新できませんでした。時間をおいて再試行してください。")
                phase = .success
            } else {
                let message = error.userFacingMessage ?? LT("个人主页加载失败，请稍后重试", "Failed to load profile. Please try again later.", "プロフィールを読み込めませんでした。時間をおいて再試行してください。")
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
            case .published:
                recentPosts = try await contentRepository.fetchPostsByUser(userID: profile.id, cursor: nil).posts.filter { !$0.isRaverNews }
            case .saves:
                savedItems = try await contentRepository.fetchMySaveHistory(cursor: nil).items
            case .likes:
                likedItems = try await contentRepository.fetchMyLikeHistory(cursor: nil).items
            }
            if let checkinPage = try? await checkinRepository.fetchUserCheckins(userID: profile.id, page: 1, limit: 6, type: nil) {
                recentCheckins = checkinPage.items
            }
            await loadAppearance(for: profile.id)
            persistOfflineSnapshot()
            phase = .success
            bannerMessage = nil
            self.error = nil
        } catch {
            guard !error.isUserInitiatedCancellation else { return }
            bannerMessage = error.userFacingMessage ?? LT("当前内容刷新失败，请稍后重试", "Failed to refresh this section. Please try again later.", "この内容を更新できませんでした。時間をおいて再試行してください。")
        }
    }

    func applyUpdatedProfile(_ profile: UserProfile) {
        if var existing = self.profile, existing.id == profile.id {
            existing.username = profile.username
            existing.displayName = profile.displayName
            existing.bio = profile.bio.isEmpty ? existing.bio : profile.bio
            existing.avatarURL = profile.avatarURL
            existing.qrCodeURL = profile.qrCodeURL ?? existing.qrCodeURL
            existing.tags = profile.tags.isEmpty ? existing.tags : profile.tags
            existing.isFollowersListPublic = profile.isFollowersListPublic
            existing.isFollowingListPublic = profile.isFollowingListPublic
            existing.canViewFollowersList = profile.canViewFollowersList
            existing.canViewFollowingList = profile.canViewFollowingList
            if profile.followersCount > 0 { existing.followersCount = profile.followersCount }
            if profile.followingCount > 0 { existing.followingCount = profile.followingCount }
            if profile.friendsCount > 0 { existing.friendsCount = profile.friendsCount }
            if profile.postsCount > 0 { existing.postsCount = profile.postsCount }
            existing.isFollowing = profile.isFollowing ?? existing.isFollowing
            existing.isFriend = profile.isFriend ?? existing.isFriend
            self.profile = existing
        } else {
            self.profile = profile
        }
        phase = .success
        persistOfflineSnapshot()
    }

    func refreshAppearance() async {
        guard let userID = profile?.id else { return }
        await loadAppearance(for: userID, preferCache: false)
    }

    func toggleLike(post: Post) async {
        do {
            let updated = try await contentRepository.toggleLike(postID: post.id, shouldLike: !post.isLiked)
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
            let updated = try await contentRepository.toggleRepost(postID: post.id, shouldRepost: !post.isReposted)
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
            let updated = try await contentRepository.toggleSave(postID: post.id, shouldSave: !post.isSaved)
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
        if appearance == nil {
            appearance = virtualAssetRepository.cachedAppearance(userID: snapshot.profile.id)
        }
        return true
    }

    private func loadAppearance(for userID: String, preferCache: Bool = true) async {
        if preferCache, appearance == nil, let cached = virtualAssetRepository.cachedAppearance(userID: userID) {
            appearance = cached
        }

        do {
            appearance = try await virtualAssetRepository.fetchAppearance(userID: userID)
            if let appearance {
                recordProfileExposures(appearance)
            }
        } catch {
            VirtualAssetTelemetry.record(event: "load_failed", surface: "profile", userID: userID)
            if appearance == nil {
                appearance = virtualAssetRepository.cachedAppearance(userID: userID) ?? .empty(userID: userID)
            }
        }
    }

    private func recordProfileExposures(_ appearance: UserAssetAppearance) {
        let visibleAssets = [
            appearance.avatarFrame,
            appearance.titleMedal
        ].compactMap { $0 } + appearance.profileBadges

        for asset in visibleAssets {
            VirtualAssetTelemetry.record(
                event: "exposure",
                surface: "profile",
                userID: appearance.userID,
                assetID: asset.id,
                assetType: asset.type
            )
        }
    }
}
