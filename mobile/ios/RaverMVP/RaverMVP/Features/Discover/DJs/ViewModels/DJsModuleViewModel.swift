import Foundation
import Combine

@MainActor
final class DJsModuleViewModel: ObservableObject {
    @Published private(set) var djs: [WebDJ] = []
    @Published private(set) var spotlightDJs: [WebDJ] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isRefreshingHotBatch = false
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
        defer { isLoading = false }

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
            hasLoadedInitial = true
        } catch {
            errorMessage = error.userFacingMessage
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
