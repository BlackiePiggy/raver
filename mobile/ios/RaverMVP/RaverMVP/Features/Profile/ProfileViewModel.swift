import Foundation
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {
    enum Section: String, CaseIterable, Identifiable {
        case recent
        case likes
        case reposts

        var id: String { rawValue }

        var title: String {
            switch self {
            case .recent: return "近期动态"
            case .likes: return "点赞历史"
            case .reposts: return "转发历史"
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

    private let service: SocialService
    private let webService: WebFeatureService

    init(service: SocialService, webService: WebFeatureService = AppEnvironment.makeWebService()) {
        self.service = service
        self.webService = webService
    }

    func load() async {
        if isLoading { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let profileValue = try await service.fetchMyProfile()
            profile = profileValue

            async let postsTask = service.fetchPostsByUser(userID: profileValue.id, cursor: nil)
            async let likesTask = service.fetchMyLikeHistory(cursor: nil)
            async let repostsTask = service.fetchMyRepostHistory(cursor: nil)

            let (postsPage, likesPage, repostsPage) = try await (postsTask, likesTask, repostsTask)
            recentPosts = postsPage.posts.filter { !$0.isRaverNews }
            likedItems = likesPage.items
            repostedItems = repostsPage.items
            if let checkinPage = try? await webService.fetchUserCheckins(userID: profileValue.id, page: 1, limit: 6, type: nil) {
                recentCheckins = checkinPage.items
            } else {
                recentCheckins = []
            }
            error = nil
        } catch {
            self.error = error.localizedDescription
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
                recentPosts = try await service.fetchPostsByUser(userID: profile.id, cursor: nil).posts.filter { !$0.isRaverNews }
            case .likes:
                likedItems = try await service.fetchMyLikeHistory(cursor: nil).items
            case .reposts:
                repostedItems = try await service.fetchMyRepostHistory(cursor: nil).items
            }
            if let checkinPage = try? await webService.fetchUserCheckins(userID: profile.id, page: 1, limit: 6, type: nil) {
                recentCheckins = checkinPage.items
            }
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func applyUpdatedProfile(_ profile: UserProfile) {
        self.profile = profile
    }

    func toggleLike(post: Post) async {
        do {
            let updated = try await service.toggleLike(postID: post.id, shouldLike: !post.isLiked)
            replacePost(updated)
            if !updated.isLiked {
                likedItems.removeAll { $0.post.id == updated.id }
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func toggleRepost(post: Post) async {
        do {
            let updated = try await service.toggleRepost(postID: post.id, shouldRepost: !post.isReposted)
            replacePost(updated)
            if !updated.isReposted {
                repostedItems.removeAll { $0.post.id == updated.id }
            }
        } catch {
            self.error = error.localizedDescription
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
