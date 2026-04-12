import Foundation
import Combine

struct DiscoverDJsSearchResult {
    let djs: [WebDJ]
    let rankingBoards: [RankingBoard]
}

protocol DiscoverDJsRepository {
    func fetchDJs(page: Int, limit: Int, search: String?, sortBy: String) async throws -> DJListPage
    func fetchDJ(id: String) async throws -> WebDJ
    func fetchDJSets(djID: String) async throws -> [WebDJSet]
    func fetchDJEvents(djID: String) async throws -> [WebEvent]
    func fetchDJRatingUnits(djID: String) async throws -> [WebRatingUnit]
    func fetchMyDJCheckinCount(djID: String) async throws -> Int
    func toggleDJFollow(djID: String, shouldFollow: Bool) async throws -> WebDJ
    func updateDJ(id: String, input: UpdateDJInput) async throws -> WebDJ
    func fetchRankingBoards() async throws -> [RankingBoard]
    func fetchRankingBoardDetail(boardID: String, year: Int?) async throws -> RankingBoardDetail
    func searchSpotifyDJs(query: String, limit: Int) async throws -> [SpotifyDJCandidate]
    func searchDiscogsDJs(query: String, limit: Int) async throws -> [DiscogsDJCandidate]
    func fetchDiscogsDJArtist(id: Int) async throws -> DiscogsDJArtistDetail
    func importSpotifyDJ(input: ImportSpotifyDJInput) async throws -> ImportSpotifyDJResponse
    func importDiscogsDJ(input: ImportDiscogsDJInput) async throws -> ImportDiscogsDJResponse
    func importManualDJ(input: ImportManualDJInput) async throws -> ImportManualDJResponse
    func uploadDJImage(
        imageData: Data,
        fileName: String,
        mimeType: String,
        djID: String,
        usage: String
    ) async throws -> UploadMediaResponse
}

struct DiscoverDJsRepositoryAdapter: DiscoverDJsRepository {
    private let service: WebFeatureService

    init(service: WebFeatureService) {
        self.service = service
    }

    func fetchDJs(page: Int, limit: Int, search: String?, sortBy: String) async throws -> DJListPage {
        try await service.fetchDJs(page: page, limit: limit, search: search, sortBy: sortBy)
    }

    func fetchDJ(id: String) async throws -> WebDJ {
        try await service.fetchDJ(id: id)
    }

    func fetchDJSets(djID: String) async throws -> [WebDJSet] {
        try await service.fetchDJSets(djID: djID)
    }

    func fetchDJEvents(djID: String) async throws -> [WebEvent] {
        try await service.fetchDJEvents(djID: djID)
    }

    func fetchDJRatingUnits(djID: String) async throws -> [WebRatingUnit] {
        try await service.fetchDJRatingUnits(djID: djID)
    }

    func fetchMyDJCheckinCount(djID: String) async throws -> Int {
        try await service.fetchMyDJCheckinCount(djID: djID)
    }

    func toggleDJFollow(djID: String, shouldFollow: Bool) async throws -> WebDJ {
        try await service.toggleDJFollow(djID: djID, shouldFollow: shouldFollow)
    }

    func updateDJ(id: String, input: UpdateDJInput) async throws -> WebDJ {
        try await service.updateDJ(id: id, input: input)
    }

    func fetchRankingBoards() async throws -> [RankingBoard] {
        try await service.fetchRankingBoards()
    }

    func fetchRankingBoardDetail(boardID: String, year: Int?) async throws -> RankingBoardDetail {
        try await service.fetchRankingBoardDetail(boardID: boardID, year: year)
    }

    func searchSpotifyDJs(query: String, limit: Int) async throws -> [SpotifyDJCandidate] {
        try await service.searchSpotifyDJs(query: query, limit: limit)
    }

    func searchDiscogsDJs(query: String, limit: Int) async throws -> [DiscogsDJCandidate] {
        try await service.searchDiscogsDJs(query: query, limit: limit)
    }

    func fetchDiscogsDJArtist(id: Int) async throws -> DiscogsDJArtistDetail {
        try await service.fetchDiscogsDJArtist(id: id)
    }

    func importSpotifyDJ(input: ImportSpotifyDJInput) async throws -> ImportSpotifyDJResponse {
        try await service.importSpotifyDJ(input: input)
    }

    func importDiscogsDJ(input: ImportDiscogsDJInput) async throws -> ImportDiscogsDJResponse {
        try await service.importDiscogsDJ(input: input)
    }

    func importManualDJ(input: ImportManualDJInput) async throws -> ImportManualDJResponse {
        try await service.importManualDJ(input: input)
    }

    func uploadDJImage(
        imageData: Data,
        fileName: String,
        mimeType: String,
        djID: String,
        usage: String
    ) async throws -> UploadMediaResponse {
        try await service.uploadDJImage(
            imageData: imageData,
            fileName: fileName,
            mimeType: mimeType,
            djID: djID,
            usage: usage
        )
    }
}

struct SearchDiscoverDJsUseCase {
    private let repository: DiscoverDJsRepository

    init(repository: DiscoverDJsRepository) {
        self.repository = repository
    }

    func execute(query: String) async throws -> DiscoverDJsSearchResult {
        async let djPage = repository.fetchDJs(page: 1, limit: 100, search: query, sortBy: "followerCount")
        async let boardList = repository.fetchRankingBoards()

        let djs = try await djPage.items
        let allBoards = try await boardList
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let rankingBoards = allBoards.filter { board in
            board.title.lowercased().contains(keyword)
                || (board.subtitle?.lowercased().contains(keyword) ?? false)
        }
        return DiscoverDJsSearchResult(djs: djs, rankingBoards: rankingBoards)
    }
}

protocol DiscoverSetsRepository {
    func fetchDJSets(page: Int, limit: Int, sortBy: String, djID: String?) async throws -> DJSetListPage
    func fetchDJSet(id: String) async throws -> WebDJSet
    func fetchSetComments(setID: String) async throws -> [WebSetComment]
    func addSetComment(setID: String, input: CreateSetCommentInput) async throws -> WebSetComment
    func deleteDJSet(id: String) async throws
    func fetchTracklists(setID: String) async throws -> [WebTracklistSummary]
    func fetchTracklistDetail(setID: String, tracklistID: String) async throws -> WebTracklistDetail
    func fetchEvents(page: Int, limit: Int, search: String?, eventType: String?, status: String?) async throws -> EventListPage
    func createTracklist(setID: String, input: CreateTracklistInput) async throws -> WebTracklistDetail
    func previewVideo(videoURL: String) async throws -> [String: String]
    func uploadSetThumbnail(imageData: Data, fileName: String, mimeType: String) async throws -> UploadMediaResponse
    func uploadSetVideo(videoData: Data, fileName: String, mimeType: String) async throws -> UploadMediaResponse
    func createDJSet(input: CreateDJSetInput) async throws -> WebDJSet
    func updateDJSet(id: String, input: UpdateDJSetInput) async throws -> WebDJSet
    func replaceTracks(setID: String, tracks: [CreateTrackInput]) async throws -> WebDJSet
    func autoLinkTracks(setID: String) async throws
}

struct DiscoverSetsRepositoryAdapter: DiscoverSetsRepository {
    private let service: WebFeatureService

    init(service: WebFeatureService) {
        self.service = service
    }

    func fetchDJSets(page: Int, limit: Int, sortBy: String, djID: String?) async throws -> DJSetListPage {
        try await service.fetchDJSets(page: page, limit: limit, sortBy: sortBy, djID: djID)
    }

    func fetchDJSet(id: String) async throws -> WebDJSet {
        try await service.fetchDJSet(id: id)
    }

    func fetchSetComments(setID: String) async throws -> [WebSetComment] {
        try await service.fetchSetComments(setID: setID)
    }

    func addSetComment(setID: String, input: CreateSetCommentInput) async throws -> WebSetComment {
        try await service.addSetComment(setID: setID, input: input)
    }

    func deleteDJSet(id: String) async throws {
        try await service.deleteDJSet(id: id)
    }

    func fetchTracklists(setID: String) async throws -> [WebTracklistSummary] {
        try await service.fetchTracklists(setID: setID)
    }

    func fetchTracklistDetail(setID: String, tracklistID: String) async throws -> WebTracklistDetail {
        try await service.fetchTracklistDetail(setID: setID, tracklistID: tracklistID)
    }

    func fetchEvents(page: Int, limit: Int, search: String?, eventType: String?, status: String?) async throws -> EventListPage {
        try await service.fetchEvents(page: page, limit: limit, search: search, eventType: eventType, status: status)
    }

    func createTracklist(setID: String, input: CreateTracklistInput) async throws -> WebTracklistDetail {
        try await service.createTracklist(setID: setID, input: input)
    }

    func previewVideo(videoURL: String) async throws -> [String: String] {
        try await service.previewVideo(videoURL: videoURL)
    }

    func uploadSetThumbnail(imageData: Data, fileName: String, mimeType: String) async throws -> UploadMediaResponse {
        try await service.uploadSetThumbnail(imageData: imageData, fileName: fileName, mimeType: mimeType)
    }

    func uploadSetVideo(videoData: Data, fileName: String, mimeType: String) async throws -> UploadMediaResponse {
        try await service.uploadSetVideo(videoData: videoData, fileName: fileName, mimeType: mimeType)
    }

    func createDJSet(input: CreateDJSetInput) async throws -> WebDJSet {
        try await service.createDJSet(input: input)
    }

    func updateDJSet(id: String, input: UpdateDJSetInput) async throws -> WebDJSet {
        try await service.updateDJSet(id: id, input: input)
    }

    func replaceTracks(setID: String, tracks: [CreateTrackInput]) async throws -> WebDJSet {
        try await service.replaceTracks(setID: setID, tracks: tracks)
    }

    func autoLinkTracks(setID: String) async throws {
        try await service.autoLinkTracks(setID: setID)
    }
}

struct SearchDiscoverSetsUseCase {
    private let repository: DiscoverSetsRepository

    init(repository: DiscoverSetsRepository) {
        self.repository = repository
    }

    func execute(query: String) async throws -> [WebDJSet] {
        var pool: [WebDJSet] = []
        var currentPage = 1
        var totalPages = 1

        repeat {
            let page = try await repository.fetchDJSets(page: currentPage, limit: 20, sortBy: "latest", djID: nil)
            pool.append(contentsOf: page.items)
            totalPages = page.pagination?.totalPages ?? 1
            currentPage += 1
        } while currentPage <= totalPages && currentPage <= 4

        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return pool.filter { item in
            item.title.lowercased().contains(keyword)
                || (item.dj?.name.lowercased().contains(keyword) ?? false)
                || item.djId.lowercased().contains(keyword)
        }
    }
}

struct DiscoverWikiSearchResult {
    let labels: [LearnLabel]
    let festivals: [LearnFestival]
}

protocol DiscoverWikiRepository {
    func fetchLearnGenres() async throws -> [LearnGenreNode]
    func fetchLearnLabels(
        page: Int,
        limit: Int,
        sortBy: String,
        order: String,
        search: String?,
        nation: String?,
        genre: String?
    ) async throws -> LearnLabelListPage
    func fetchLearnFestivals(search: String?) async throws -> [WebLearnFestival]
    func createLearnFestival(input: CreateLearnFestivalInput) async throws -> WebLearnFestival
    func updateLearnFestival(id: String, input: UpdateLearnFestivalInput) async throws -> WebLearnFestival
    func uploadWikiBrandImage(
        imageData: Data,
        fileName: String,
        mimeType: String,
        brandID: String?,
        usage: String?
    ) async throws -> UploadMediaResponse
}

struct DiscoverWikiRepositoryAdapter: DiscoverWikiRepository {
    private let service: WebFeatureService

    init(service: WebFeatureService) {
        self.service = service
    }

    func fetchLearnGenres() async throws -> [LearnGenreNode] {
        try await service.fetchLearnGenres()
    }

    func fetchLearnLabels(
        page: Int,
        limit: Int,
        sortBy: String,
        order: String,
        search: String?,
        nation: String?,
        genre: String?
    ) async throws -> LearnLabelListPage {
        try await service.fetchLearnLabels(
            page: page,
            limit: limit,
            sortBy: sortBy,
            order: order,
            search: search,
            nation: nation,
            genre: genre
        )
    }

    func fetchLearnFestivals(search: String?) async throws -> [WebLearnFestival] {
        try await service.fetchLearnFestivals(search: search)
    }

    func createLearnFestival(input: CreateLearnFestivalInput) async throws -> WebLearnFestival {
        try await service.createLearnFestival(input: input)
    }

    func updateLearnFestival(id: String, input: UpdateLearnFestivalInput) async throws -> WebLearnFestival {
        try await service.updateLearnFestival(id: id, input: input)
    }

    func uploadWikiBrandImage(
        imageData: Data,
        fileName: String,
        mimeType: String,
        brandID: String?,
        usage: String?
    ) async throws -> UploadMediaResponse {
        try await service.uploadWikiBrandImage(
            imageData: imageData,
            fileName: fileName,
            mimeType: mimeType,
            brandID: brandID,
            usage: usage
        )
    }
}

struct SearchDiscoverWikiUseCase {
    private let repository: DiscoverWikiRepository

    init(repository: DiscoverWikiRepository) {
        self.repository = repository
    }

    func execute(query: String) async throws -> DiscoverWikiSearchResult {
        async let labelPage = repository.fetchLearnLabels(
            page: 1,
            limit: 500,
            sortBy: LearnLabelSortOption.soundcloudFollowers.apiValue,
            order: LearnLabelSortOrder.desc.rawValue,
            search: query,
            nation: nil,
            genre: nil
        )
        async let festivalList = repository.fetchLearnFestivals(search: query)

        return try await DiscoverWikiSearchResult(
            labels: labelPage.items,
            festivals: festivalList.map { LearnFestival(web: $0) }
        )
    }
}

@MainActor
final class EventsSearchResultsViewModel: ObservableObject {
    let query: String

    @Published private(set) var events: [WebEvent] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let fetchEventsPageUseCase: FetchDiscoverEventsPageUseCase
    private var page = 1
    private var totalPages = 1
    private var hasLoaded = false

    var canLoadMore: Bool {
        page <= totalPages
    }

    init(query: String, repository: DiscoverEventsRepository) {
        self.query = query
        self.fetchEventsPageUseCase = FetchDiscoverEventsPageUseCase(repository: repository)
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
            let result = try await fetchEventsPageUseCase.execute(
                DiscoverEventsPageRequest(
                    page: page,
                    limit: 20,
                    search: query,
                    eventType: nil,
                    status: "all"
                )
            )
            events.append(contentsOf: result.items)
            events.sort { lhs, rhs in
                if lhs.startDate == rhs.startDate {
                    return lhs.endDate > rhs.endDate
                }
                return lhs.startDate > rhs.startDate
            }
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

    private let searchDiscoverNewsUseCase: SearchDiscoverNewsUseCase
    private var hasLoaded = false

    init(query: String, repository: DiscoverNewsRepository) {
        self.query = query
        self.searchDiscoverNewsUseCase = SearchDiscoverNewsUseCase(repository: repository)
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
            articles = try await searchDiscoverNewsUseCase.execute(query: query)
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

    private let searchDiscoverDJsUseCase: SearchDiscoverDJsUseCase
    private var hasLoaded = false

    init(query: String, repository: DiscoverDJsRepository) {
        self.query = query
        self.searchDiscoverDJsUseCase = SearchDiscoverDJsUseCase(repository: repository)
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
            let result = try await searchDiscoverDJsUseCase.execute(query: query)
            djs = result.djs
            rankingBoards = result.rankingBoards
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

    private let searchDiscoverSetsUseCase: SearchDiscoverSetsUseCase
    private var hasLoaded = false

    init(query: String, repository: DiscoverSetsRepository) {
        self.query = query
        self.searchDiscoverSetsUseCase = SearchDiscoverSetsUseCase(repository: repository)
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
            sets = try await searchDiscoverSetsUseCase.execute(query: query)
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

    private let searchDiscoverWikiUseCase: SearchDiscoverWikiUseCase
    private var hasLoaded = false

    init(query: String, repository: DiscoverWikiRepository) {
        self.query = query
        self.searchDiscoverWikiUseCase = SearchDiscoverWikiUseCase(repository: repository)
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
            let result = try await searchDiscoverWikiUseCase.execute(query: query)
            labels = result.labels
            festivals = result.festivals
            errorMessage = nil
        } catch {
            errorMessage = error.userFacingMessage
        }
    }
}
