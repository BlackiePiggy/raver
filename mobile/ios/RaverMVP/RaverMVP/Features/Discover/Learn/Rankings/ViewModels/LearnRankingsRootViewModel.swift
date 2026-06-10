import Foundation

@MainActor
final class LearnRankingsRootViewModel: ObservableObject {
    @Published private(set) var rankingBoards: [RankingBoard] = []
    @Published private(set) var phase: LoadPhase = .idle
    @Published private(set) var isLoading = false
    @Published private(set) var isRefreshing = false
    @Published var bannerMessage: String?

    private var hasTriggeredInitialLoad = false

    func triggerInitialLoadIfNeeded(isActive: Bool, repository: DJRankingRepository) async {
        guard isActive else { return }
        guard !hasTriggeredInitialLoad else { return }
        hasTriggeredInitialLoad = true
        await reload(repository: repository, force: false)
    }

    func reload(repository: DJRankingRepository, force: Bool = true) async {
        if isLoading, !force { return }

        let hadContent = !rankingBoards.isEmpty
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
            rankingBoards = try await repository.fetchRankingBoards()
            phase = rankingBoards.isEmpty ? .empty : .success
            bannerMessage = nil
        } catch {
            let message = error.userFacingMessage ?? LT(
                "榜单加载失败，请稍后重试",
                "Failed to load rankings. Please try again later.",
                "ランキングを読み込めませんでした。時間をおいて再試行してください。"
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
