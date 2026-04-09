import Foundation
import Combine

@MainActor
final class EventsSearchResultsViewModel: ObservableObject {
    let query: String

    @Published private(set) var events: [WebEvent] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let service: WebFeatureService
    private var page = 1
    private var totalPages = 1
    private var hasLoaded = false

    var canLoadMore: Bool {
        page <= totalPages
    }

    init(query: String, service: WebFeatureService) {
        self.query = query
        self.service = service
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        await refresh()
    }

    func refresh() async {
        page = 1
        totalPages = 1
        events = []
        errorMessage = nil
        await loadMore()
    }

    func loadMoreIfNeeded(currentEvent: WebEvent?) async {
        guard let currentEvent else { return }
        guard currentEvent.id == events.last?.id else { return }
        await loadMore()
    }

    private func loadMore() async {
        guard !isLoading else { return }
        guard canLoadMore else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await service.fetchEvents(
                page: page,
                limit: 20,
                search: query,
                eventType: nil,
                status: "all"
            )
            events.append(contentsOf: result.items)
            totalPages = result.pagination?.totalPages ?? 1
            page += 1
            errorMessage = nil
        } catch {
            errorMessage = error.userFacingMessage
        }
    }
}

@MainActor
final class NewsSearchResultsViewModel: ObservableObject {
    let query: String

    @Published private(set) var articles: [DiscoverNewsArticle] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let socialService: SocialService
    private var hasLoaded = false

    init(query: String, socialService: SocialService) {
        self.query = query
        self.socialService = socialService
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        await refresh()
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let page = try await socialService.searchFeed(query: query)
            articles = page.posts
                .compactMap { DiscoverNewsCodec.decode(post: $0) }
                .sorted(by: { $0.publishedAt > $1.publishedAt })
            errorMessage = nil
        } catch {
            errorMessage = error.userFacingMessage
        }
    }
}

@MainActor
final class DJsSearchResultsViewModel: ObservableObject {
    let query: String

    @Published private(set) var djs: [WebDJ] = []
    @Published private(set) var rankingBoards: [RankingBoard] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let service: WebFeatureService
    private var hasLoaded = false

    init(query: String, service: WebFeatureService) {
        self.query = query
        self.service = service
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        await refresh()
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            async let djPage = service.fetchDJs(page: 1, limit: 100, search: query, sortBy: "followerCount")
            async let boardList = service.fetchRankingBoards()

            djs = try await djPage.items
            let allBoards = try await boardList
            let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            rankingBoards = allBoards.filter { board in
                board.title.lowercased().contains(keyword)
                    || (board.subtitle?.lowercased().contains(keyword) ?? false)
            }
            errorMessage = nil
        } catch {
            errorMessage = error.userFacingMessage
        }
    }
}

@MainActor
final class SetsSearchResultsViewModel: ObservableObject {
    let query: String

    @Published private(set) var sets: [WebDJSet] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let service: WebFeatureService
    private var hasLoaded = false

    init(query: String, service: WebFeatureService) {
        self.query = query
        self.service = service
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        await refresh()
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            var pool: [WebDJSet] = []
            var currentPage = 1
            var totalPages = 1

            repeat {
                let page = try await service.fetchDJSets(page: currentPage, limit: 20, sortBy: "latest", djID: nil)
                pool.append(contentsOf: page.items)
                totalPages = page.pagination?.totalPages ?? 1
                currentPage += 1
            } while currentPage <= totalPages && currentPage <= 4

            let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            sets = pool.filter { item in
                item.title.lowercased().contains(keyword)
                    || (item.dj?.name.lowercased().contains(keyword) ?? false)
                    || item.djId.lowercased().contains(keyword)
            }
            errorMessage = nil
        } catch {
            errorMessage = error.userFacingMessage
        }
    }
}

@MainActor
final class WikiSearchResultsViewModel: ObservableObject {
    let query: String

    @Published private(set) var labels: [LearnLabel] = []
    @Published private(set) var festivals: [LearnFestival] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let service: WebFeatureService
    private var hasLoaded = false

    init(query: String, service: WebFeatureService) {
        self.query = query
        self.service = service
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        await refresh()
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            async let labelPage = service.fetchLearnLabels(
                page: 1,
                limit: 500,
                sortBy: LearnLabelSortOption.soundcloudFollowers.apiValue,
                order: LearnLabelSortOrder.desc.rawValue,
                search: query,
                nation: nil,
                genre: nil
            )
            async let festivalList = service.fetchLearnFestivals(search: query)

            labels = try await labelPage.items
            festivals = try await festivalList.map { LearnFestival(web: $0) }
            errorMessage = nil
        } catch {
            errorMessage = error.userFacingMessage
        }
    }
}
