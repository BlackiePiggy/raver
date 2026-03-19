import Foundation

@MainActor
final class FollowListViewModel: ObservableObject {
    @Published var users: [UserSummary] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var error: String?

    let userID: String
    let kind: FollowListKind

    private let service: SocialService
    private var nextCursor: String?
    private var hasMore = true

    init(userID: String, kind: FollowListKind, service: SocialService) {
        self.userID = userID
        self.kind = kind
        self.service = service
    }

    func load() async {
        if isLoading { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let page = try await fetchPage(cursor: nil)
            users = page.users
            nextCursor = page.nextCursor
            hasMore = page.nextCursor != nil
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func refresh() async {
        await load()
    }

    func loadMoreIfNeeded(currentUser: UserSummary) async {
        guard hasMore, !isLoadingMore, !isLoading else { return }
        guard currentUser.id == users.last?.id else { return }
        guard let cursor = nextCursor else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let page = try await fetchPage(cursor: cursor)
            let existing = Set(users.map(\.id))
            users.append(contentsOf: page.users.filter { !existing.contains($0.id) })
            nextCursor = page.nextCursor
            hasMore = page.nextCursor != nil
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func fetchPage(cursor: String?) async throws -> FollowListPage {
        switch kind {
        case .followers:
            return try await service.fetchFollowers(userID: userID, cursor: cursor)
        case .following:
            return try await service.fetchFollowing(userID: userID, cursor: cursor)
        case .friends:
            return try await service.fetchFriends(userID: userID, cursor: cursor)
        }
    }

    func toggleFollow(user: UserSummary) async {
        do {
            let updated = try await service.toggleFollow(userID: user.id, shouldFollow: !user.isFollowing)
            if let index = users.firstIndex(where: { $0.id == user.id }) {
                users[index] = updated
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
