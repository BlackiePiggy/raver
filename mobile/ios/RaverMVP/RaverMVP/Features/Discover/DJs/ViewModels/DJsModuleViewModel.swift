import Foundation
import Combine

@MainActor
final class DJsModuleViewModel: ObservableObject {
    @Published private(set) var djs: [WebDJ] = []
    @Published private(set) var spotlightDJs: [WebDJ] = []
    @Published private(set) var phase: LoadPhase = .idle
    @Published private(set) var isLoading = false
    @Published private(set) var isRefreshing = false
    @Published private(set) var isRefreshingHotBatch = false
    @Published var bannerMessage: String?
    @Published var errorMessage: String?

    private let repository: DiscoverDJsRepository
    private let hotDJBatchSize: Int
    private var hasLoadedInitial = false

    init(repository: DiscoverDJsRepository, hotDJBatchSize: Int = 25) {
        self.repository = repository
        self.hotDJBatchSize = hotDJBatchSize
    }

    var spotlightCarouselDJs: [WebDJ] {
        let source = !spotlightDJs.isEmpty
            ? spotlightDJs
            : djs.sorted { ($0.followerCount ?? 0) > ($1.followerCount ?? 0) }
        var seen = Set<String>()
        return source.filter { seen.insert($0.id).inserted }
    }

    var filteredDJs: [WebDJ] {
        djs
    }

    func loadIfNeeded() async {
        guard !hasLoadedInitial else { return }
        await reload()
    }

    func reload() async {
        guard !isLoading else { return }
        isLoading = true
        let hadContent = !djs.isEmpty || !spotlightDJs.isEmpty
        if hadContent {
            isRefreshing = true
        } else {
            phase = .initialLoading
        }
        defer { isLoading = false }
        defer { isRefreshing = false }

        do {
            errorMessage = nil
            async let hotPageTask = repository.fetchDJs(page: 1, limit: hotDJBatchSize, search: nil, sortBy: "random")
            async let spotlightPageTask = repository.fetchDJs(page: 1, limit: 10, search: nil, sortBy: "followerCount")

            let hotPage = try await hotPageTask
            let spotlightPage = try? await spotlightPageTask
            djs = hotPage.items
            spotlightDJs = sanitizeSpotlightDJs(spotlightPage?.items ?? [])

            if djs.isEmpty {
                await refreshRandomHotBatch()
            }
            if spotlightDJs.isEmpty {
                spotlightDJs = sanitizeSpotlightDJs(djs.sorted { ($0.followerCount ?? 0) > ($1.followerCount ?? 0) })
            }
            phase = spotlightCarouselDJs.isEmpty ? .empty : .success
            bannerMessage = nil
            hasLoadedInitial = true
        } catch {
            let message = error.userFacingMessage ?? L("DJ 列表加载失败，请稍后重试", "Failed to load DJs. Please try again later.")
            if hadContent {
                bannerMessage = message
                phase = .success
            } else {
                phase = .failure(message: message)
            }
        }
    }

    private func refreshRandomHotBatch() async {
        guard !isRefreshingHotBatch else { return }
        isRefreshingHotBatch = true
        defer { isRefreshingHotBatch = false }

        do {
            let page = try await repository.fetchDJs(page: 1, limit: hotDJBatchSize, search: nil, sortBy: "random")
            let nextBatch = page.items
            if !nextBatch.isEmpty {
                djs = nextBatch
                if spotlightDJs.isEmpty {
                    spotlightDJs = sanitizeSpotlightDJs(nextBatch.sorted { ($0.followerCount ?? 0) > ($1.followerCount ?? 0) })
                }
            }
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    private func sanitizeSpotlightDJs(_ items: [WebDJ]) -> [WebDJ] {
        var seen = Set<String>()
        return items.filter { seen.insert($0.id).inserted }
    }
}
