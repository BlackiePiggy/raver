import Foundation

@MainActor
final class LearnGenresRootViewModel: ObservableObject {
    @Published private(set) var genreTree: [LearnGenreTreeSummaryNode] = []
    @Published private(set) var phase: LoadPhase = .idle
    @Published private(set) var isLoading = false
    @Published private(set) var isRefreshing = false
    @Published var bannerMessage: String?

    private var hasTriggeredInitialLoad = false

    func triggerInitialLoadIfNeeded(isActive: Bool, repository: DiscoverWikiRepository) async {
        guard isActive else { return }
        guard !hasTriggeredInitialLoad else { return }
        hasTriggeredInitialLoad = true
        await reload(repository: repository, force: false)
    }

    func reload(repository: DiscoverWikiRepository, force: Bool = true) async {
        if isLoading, !force { return }

        let hadContent = !genreTree.isEmpty
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
            genreTree = try await repository.fetchLearnGenreTreeSummary()
            phase = genreTree.isEmpty ? .empty : .success
            bannerMessage = nil
        } catch {
            let message = error.userFacingMessage ?? LT(
                "学习内容加载失败，请稍后重试",
                "Failed to load learn content. Please try again later.",
                "学習コンテンツを読み込めませんでした。時間をおいて再試行してください。"
            )
            if hadContent {
                bannerMessage = message
                phase = .success
            } else {
                phase = .failure(message: message)
            }
        }
    }
}
