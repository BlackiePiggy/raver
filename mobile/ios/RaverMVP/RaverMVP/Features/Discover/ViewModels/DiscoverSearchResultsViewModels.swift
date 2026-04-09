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
