import Foundation

@MainActor
final class GlobalSearchResultsViewModel: ObservableObject {
    enum LoadPhase: Equatable {
        case idle
        case loading
        case loaded
        case empty
        case failed(String)
    }

    @Published private(set) var query: String
    @Published private(set) var allItems: [GlobalSearchItem] = []
    @Published private(set) var phaseByTab: [GlobalSearchTab: LoadPhase] = [:]
    @Published private(set) var partialFailureTabs: Set<GlobalSearchTab> = []
    @Published private(set) var countsByTab: [GlobalSearchTab: Int] = [:]

    private let repository: GlobalSearchRepository
    private let resultLimit = 60

    init(query: String, repository: GlobalSearchRepository) {
        self.query = query
        self.repository = repository
        GlobalSearchTab.allCases.forEach { phaseByTab[$0] = .idle }
        GlobalSearchTab.allCases.forEach { countsByTab[$0] = 0 }
    }

    func loadInitial() {
        guard allItems.isEmpty else { return }
        Task {
            await load(query: query, requestedTab: .all, resetTabs: true)
        }
    }

    func submitSearch(_ rawQuery: String) {
        let keyword = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return }
        GlobalSearchTelemetry.submitted(query: keyword, source: "results_header")
        Task {
            await load(query: keyword, requestedTab: .all, resetTabs: true)
        }
    }

    func refresh(tab: GlobalSearchTab) async {
        await load(query: query, requestedTab: tab, resetTabs: tab == .all)
    }

    func retry(tab: GlobalSearchTab) {
        Task {
            await load(query: query, requestedTab: tab, resetTabs: tab == .all)
        }
    }

    func items(for tab: GlobalSearchTab) -> [GlobalSearchItem] {
        switch tab {
        case .all:
            return allItems.sorted { $0.relevanceScore > $1.relevanceScore }
        default:
            return allItems
                .filter { tab.searchableItemTypes.contains($0.type) }
                .sorted { $0.relevanceScore > $1.relevanceScore }
        }
    }

    func count(for tab: GlobalSearchTab) -> Int {
        countsByTab[tab] ?? items(for: tab).count
    }

    func previewItems(for tab: GlobalSearchTab, limit: Int = 3) -> [GlobalSearchItem] {
        Array(items(for: tab).prefix(limit))
    }

    var totalCount: Int {
        allItems.count
    }

    var topMatches: [GlobalSearchItem] {
        Array(items(for: .all).prefix(5))
    }

    var previewTabs: [GlobalSearchTab] {
        [.events, .djs, .peopleSquads, .posts, .news, .sets, .rankings, .ratings, .festivals, .labels, .genreTree]
            .filter { !items(for: $0).isEmpty }
    }

    private func load(query nextQuery: String, requestedTab: GlobalSearchTab, resetTabs: Bool) async {
        let startedAt = GlobalSearchTelemetry.loadStarted(query: nextQuery, tab: requestedTab)
        query = nextQuery
        if resetTabs {
            GlobalSearchTab.allCases.forEach { phaseByTab[$0] = .loading }
        } else {
            phaseByTab[requestedTab] = .loading
        }

        do {
            let response = try await repository.searchGlobal(query: nextQuery, tab: requestedTab, limit: resultLimit)
            apply(response, requestedTab: requestedTab)
            GlobalSearchTelemetry.loadSucceeded(
                query: response.query,
                tab: requestedTab,
                itemCount: response.items.count,
                partialErrorCount: response.partialErrors.count,
                startedAt: startedAt
            )
        } catch {
            GlobalSearchTelemetry.loadFailed(query: nextQuery, tab: requestedTab, error: error, startedAt: startedAt)
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            if resetTabs {
                GlobalSearchTab.allCases.forEach { phaseByTab[$0] = .failed(message) }
            } else {
                phaseByTab[requestedTab] = .failed(message)
            }
        }
    }

    private func apply(_ response: GlobalSearchResponse, requestedTab: GlobalSearchTab) {
        query = response.query
        if requestedTab == .all {
            allItems = response.items
        } else {
            let existing = allItems.filter { !requestedTab.searchableItemTypes.contains($0.type) }
            allItems = existing + response.items
        }

        if requestedTab == .all {
            countsByTab = Dictionary(uniqueKeysWithValues: GlobalSearchTab.allCases.map { ($0, response.count(for: $0)) })
            partialFailureTabs = Set(response.partialErrors.map(\.tab))
        } else {
            countsByTab[requestedTab] = response.count(for: requestedTab)
            countsByTab[.all] = allItems.count
            partialFailureTabs.remove(requestedTab)
            response.partialErrors.forEach { partialFailureTabs.insert($0.tab) }
        }

        GlobalSearchTab.allCases.forEach { tab in
            if requestedTab == .all || tab == requestedTab || partialFailureTabs.contains(tab) {
                if partialFailureTabs.contains(tab) {
                    phaseByTab[tab] = .failed(LT("\(tab.title)结果加载失败", "\(tab.title) results failed", "\(tab.title)結果の読み込みに失敗しました"))
                } else {
                    phaseByTab[tab] = count(for: tab) > 0 ? .loaded : .empty
                }
            }
        }
    }
}
