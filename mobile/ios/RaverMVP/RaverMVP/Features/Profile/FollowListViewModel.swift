import Foundation

@MainActor
final class FollowListViewModel: ObservableObject {
    @Published var users: [UserSummary] = []
    @Published private(set) var phase: LoadPhase = .idle
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var isLoadingMore = false
    @Published var bannerMessage: String?
    @Published var error: String?

    let userID: String
    let kind: FollowListKind

    private let repository: ProfileSocialRepository
    private var nextCursor: String?
    private var hasMore = true

    init(userID: String, kind: FollowListKind, repository: ProfileSocialRepository) {
        self.userID = userID
        self.kind = kind
        self.repository = repository
    }

    func load() async {
        if isLoading { return }
        isLoading = true
        let hadContent = !users.isEmpty
        if hadContent {
            isRefreshing = true
        } else {
            phase = .initialLoading
        }
        defer { isLoading = false }
        defer { isRefreshing = false }

        do {
            let page = try await fetchPage(cursor: nil)
            users = page.users
            nextCursor = page.nextCursor
            hasMore = page.nextCursor != nil
            phase = users.isEmpty ? .empty : .success
            bannerMessage = nil
            error = nil
        } catch {
            let message = error.userFacingMessage ?? L("列表加载失败，请稍后重试", "Failed to load the list. Please try again later.")
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
            bannerMessage = nil
            error = nil
        } catch {
            bannerMessage = error.userFacingMessage
        }
    }

    private func fetchPage(cursor: String?) async throws -> FollowListPage {
        switch kind {
        case .followers:
            return try await repository.fetchFollowers(userID: userID, cursor: cursor)
        case .following:
            return try await repository.fetchFollowing(userID: userID, cursor: cursor)
        case .friends:
            return try await repository.fetchFriends(userID: userID, cursor: cursor)
        }
    }

    func toggleFollow(user: UserSummary) async {
        do {
            let updated = try await repository.toggleFollow(userID: user.id, shouldFollow: !user.isFollowing)
            if let index = users.firstIndex(where: { $0.id == user.id }) {
                users[index] = updated
            }
        } catch {
            self.error = error.userFacingMessage
        }
    }
}
