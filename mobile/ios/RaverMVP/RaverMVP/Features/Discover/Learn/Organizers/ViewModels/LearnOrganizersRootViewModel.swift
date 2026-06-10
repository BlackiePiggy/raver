import Foundation

@MainActor
final class LearnOrganizersRootViewModel: ObservableObject {
    @Published private(set) var festivals: [LearnFestival] = []
    @Published private(set) var pagination: BFFPagination?
    @Published private(set) var phase: LoadPhase = .idle
    @Published private(set) var isLoading = false
    @Published private(set) var isRefreshing = false
    @Published private(set) var isLoadingMore = false
    @Published var bannerMessage: String?

    private let pageSize = 10
    private var hasTriggeredInitialLoad = false

    func triggerInitialLoadIfNeeded(isActive: Bool, repository: DiscoverWikiRepository) async {
        guard isActive else { return }
        guard !hasTriggeredInitialLoad else { return }
        hasTriggeredInitialLoad = true
        await reload(repository: repository, force: false)
    }

    func reload(repository: DiscoverWikiRepository, force: Bool = true) async {
        if isLoading, !force { return }

        let hadContent = !festivals.isEmpty
        isLoading = true
        if hadContent {
            isRefreshing = true
        } else {
            phase = .initialLoading
        }
        defer {
            isLoading = false
            isRefreshing = false
        }

        do {
            let page = try await repository.fetchLearnFestivalPage(page: 1, limit: pageSize, search: nil)
            festivals = page.items.map(LearnFestival.init(web:))
            pagination = page.pagination
            phase = festivals.isEmpty ? .empty : .success
            bannerMessage = nil
        } catch {
            let message = error.userFacingMessage ?? LT(
                "主办方加载失败，请稍后重试",
                "Failed to load organizers. Please try again later.",
                "主催を読み込めませんでした。時間をおいて再試行してください。"
            )
            if hadContent {
                bannerMessage = message
                phase = .success
            } else {
                phase = .failure(message: message)
            }
        }
    }

    func loadMoreIfNeeded(repository: DiscoverWikiRepository) async {
        guard !isLoading, !isLoadingMore else { return }
        guard let pagination, pagination.page < pagination.totalPages else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let response = try await repository.fetchLearnFestivalPage(
                page: pagination.page + 1,
                limit: pageSize,
                search: nil
            )
            let existingIDs = Set(festivals.map(\.id))
            let appended = response.items
                .map(LearnFestival.init(web:))
                .filter { !existingIDs.contains($0.id) }
            festivals.append(contentsOf: appended)
            self.pagination = response.pagination
            phase = festivals.isEmpty ? .empty : .success
        } catch {
            bannerMessage = error.userFacingMessage ?? LT(
                "主办方加载失败，请稍后重试",
                "Failed to load organizers. Please try again later.",
                "主催を読み込めませんでした。時間をおいて再試行してください。"
            )
        }
    }

    func upsertFestival(_ updated: LearnFestival) {
        if let index = festivals.firstIndex(where: { $0.id == updated.id }) {
            festivals[index] = updated
        } else {
            festivals.insert(updated, at: 0)
        }
    }
}
