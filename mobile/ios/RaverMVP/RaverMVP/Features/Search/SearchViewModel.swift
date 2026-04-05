import Foundation
import Combine

@MainActor
final class SearchViewModel: ObservableObject {
    enum Scope: String, CaseIterable, Identifiable {
        case users
        case posts
        case squads

        var id: String { rawValue }
        var title: String {
            switch self {
            case .users: return L("用户", "Users")
            case .posts: return L("动态", "Posts")
            case .squads: return L("小队", "Squads")
            }
        }
    }

    @Published var query = ""
    @Published var scope: Scope = .users
    @Published var users: [UserSummary] = []
    @Published var posts: [Post] = []
    @Published var squads: [SquadSummary] = []
    @Published var isLoading = false
    @Published var error: String?

    private let service: SocialService

    init(service: SocialService) {
        self.service = service
    }

    func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            users = []
            posts = []
            if scope != .squads {
                return
            }
        }

        if scope == .squads {
            isLoading = true
            defer { isLoading = false }
            do {
                var recommended = try await service.fetchRecommendedSquads()
                if !trimmed.isEmpty {
                    recommended = recommended.filter {
                        $0.name.localizedCaseInsensitiveContains(trimmed) ||
                            ($0.description?.localizedCaseInsensitiveContains(trimmed) ?? false)
                    }
                }
                squads = recommended
                users = []
                posts = []
                error = nil
            } catch {
                self.error = error.userFacingMessage
            }
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            switch scope {
            case .users:
                users = try await service.searchUsers(query: trimmed)
                posts = []
                squads = []
            case .posts:
                posts = try await service.searchFeed(query: trimmed).posts.filter { !$0.isRaverNews }
                users = []
                squads = []
            case .squads:
                squads = try await service.fetchRecommendedSquads()
                users = []
                posts = []
            }
            self.error = nil
        } catch {
            self.error = error.userFacingMessage
        }
    }

    func toggleFollow(user: UserSummary) async {
        do {
            let updated = try await service.toggleFollow(userID: user.id, shouldFollow: !user.isFollowing)
            if let index = users.firstIndex(where: { $0.id == updated.id }) {
                users[index] = updated
            }
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
