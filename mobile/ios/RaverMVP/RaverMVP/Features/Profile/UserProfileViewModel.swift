import Foundation
import Combine

@MainActor
final class UserProfileViewModel: ObservableObject {
    @Published var profile: UserProfile?
    @Published var posts: [Post] = []
    @Published var recentCheckins: [WebCheckin] = []
    @Published var appearance: UserAssetAppearance?
    @Published private(set) var phase: LoadPhase = .idle
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var isLoadingMore = false
    @Published var bannerMessage: String?
    @Published var error: String?

    private let userID: String
    private let userRepository: ProfileUserRepository
    private let contentRepository: ProfileContentRepository
    private let checkinRepository: ProfileCheckinRepository
    private let virtualAssetRepository: VirtualAssetRepository
    private var nextCursor: String?
    private var hasMore = true

    init(
        userID: String,
        userRepository: ProfileUserRepository,
        contentRepository: ProfileContentRepository,
        checkinRepository: ProfileCheckinRepository,
        virtualAssetRepository: VirtualAssetRepository = AppEnvironment.makeVirtualAssetRepository()
    ) {
        self.userID = userID
        self.userRepository = userRepository
        self.contentRepository = contentRepository
        self.checkinRepository = checkinRepository
        self.virtualAssetRepository = virtualAssetRepository
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
            async let profileTask = userRepository.fetchUserProfile(userID: userID)
            async let postsTask = contentRepository.fetchPostsByUser(userID: userID, cursor: nil, limit: nil)
            let (profileValue, page) = try await (profileTask, postsTask)

            profile = profileValue
            posts = page.posts.filter { !$0.isRaverNews }
            await loadAppearance(for: profileValue.id)
            if let checkinPage = try? await checkinRepository.fetchUserCheckins(userID: userID, page: 1, limit: 6, type: nil) {
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
            let message = error.userFacingMessage ?? LT("用户主页加载失败，请稍后重试", "Failed to load profile. Please try again later.", "ユーザープロフィールを読み込めませんでした。時間をおいて再試行してください。")
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
            let page = try await contentRepository.fetchPostsByUser(userID: userID, cursor: cursor, limit: nil)
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
            let updated = try await userRepository.toggleFollow(userID: profile.id, shouldFollow: !(profile.isFollowing ?? false))
            var refreshed = try await userRepository.fetchUserProfile(userID: profile.id)
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
            let updated = try await contentRepository.toggleLike(postID: post.id, shouldLike: !post.isLiked)
            if let index = posts.firstIndex(where: { $0.id == updated.id }) {
                posts[index] = updated
            }
        } catch {
            self.error = error.userFacingMessage
        }
    }

    func toggleRepost(post: Post) async {
        do {
            let updated = try await contentRepository.toggleRepost(postID: post.id, shouldRepost: !post.isReposted)
            if let index = posts.firstIndex(where: { $0.id == updated.id }) {
                posts[index] = updated
            }
        } catch {
            self.error = error.userFacingMessage
        }
    }

    private func loadAppearance(for userID: String) async {
        if appearance == nil, let cached = virtualAssetRepository.cachedAppearance(userID: userID) {
            appearance = cached
        }

        do {
            appearance = try await virtualAssetRepository.fetchAppearance(userID: userID)
            if let appearance {
                recordProfileExposures(appearance)
            }
        } catch {
            VirtualAssetTelemetry.record(event: "load_failed", surface: "user_profile", userID: userID)
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
                surface: "user_profile",
                userID: appearance.userID,
                assetID: asset.id,
                assetType: asset.type
            )
        }
    }
}
