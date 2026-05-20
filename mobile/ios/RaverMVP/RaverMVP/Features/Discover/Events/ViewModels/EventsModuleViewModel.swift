import Foundation
import Combine

struct DiscoverEventsPageRequest: Equatable {
    let page: Int
    let limit: Int
    let search: String?
    let eventType: String?
    let status: String?
    let wikiFestivalId: String?

    init(page: Int, limit: Int, search: String?, eventType: String?, status: String?, wikiFestivalId: String? = nil) {
        self.page = page
        self.limit = limit
        self.search = search
        self.eventType = eventType
        self.status = status
        self.wikiFestivalId = wikiFestivalId
    }
}

protocol EventListRepository {
    func fetchEvents(request: DiscoverEventsPageRequest) async throws -> EventListPage
    func fetchEventsBootstrap(limit: Int, search: String?, eventType: String?) async throws -> EventsBootstrapResponse
    func fetchFestivalEventFeed(
        wikiFestivalId: String,
        upcomingPage: Int,
        upcomingLimit: Int,
        endedPage: Int,
        endedLimit: Int
    ) async throws -> FestivalEventFeedResponse
}

protocol EventRecommendationRepository {
    func fetchRecommendedEvents(limit: Int, statuses: [String]?) async throws -> [WebEvent]
}

protocol EventReadRepository {
    func fetchEvent(id: String) async throws -> WebEvent
}

protocol RatingRepository {
    func fetchRatingEvents() async throws -> [WebRatingEvent]
    func fetchRatingEvents(page: Int, limit: Int) async throws -> RatingEventListPage
    func fetchRatingEvent(id: String) async throws -> WebRatingEvent
    func fetchRatingUnit(id: String) async throws -> WebRatingUnit
    func createRatingEvent(input: CreateRatingEventInput) async throws -> CreateContentResult<WebRatingEvent>
    func createRatingEventFromEvent(eventID: String) async throws -> WebRatingEvent
    func createRatingUnit(eventID: String, input: CreateRatingUnitInput) async throws -> CreateContentResult<WebRatingUnit>
    func updateRatingEvent(id: String, input: UpdateRatingEventInput) async throws -> WebRatingEvent
    func updateRatingUnit(id: String, input: UpdateRatingUnitInput) async throws -> WebRatingUnit
    func deleteRatingEvent(id: String) async throws
    func deleteRatingUnit(id: String) async throws
    func fetchEventRatingEvents(eventID: String) async throws -> [WebRatingEvent]
    func fetchEventRatingEvents(eventID: String, page: Int, limit: Int) async throws -> RatingEventListPage
    func addRatingComment(unitID: String, input: CreateRatingCommentInput) async throws -> WebRatingComment
    func uploadRatingImage(
        imageData: Data,
        fileName: String,
        mimeType: String,
        ratingEventID: String?,
        ratingUnitID: String?,
        usage: String?
    ) async throws -> UploadMediaResponse
}

protocol EventLiveDiscussionRepository {
    func fetchEventLiveComments(eventID: String, cursor: String?, sort: EventLiveCommentSortMode) async throws -> EventLiveCommentPage
    func addEventLiveComment(eventID: String, content: String, imageURLs: [String], parentCommentID: String?) async throws -> EventLiveComment
    func toggleEventLiveCommentLike(commentID: String, shouldLike: Bool) async throws -> EventLiveComment
}

protocol EventCommandRepository {
    func createEvent(input: CreateEventInput) async throws -> CreateEventResult
    func updateEvent(id: String, input: UpdateEventInput) async throws -> WebEvent
    func deleteEvent(id: String) async throws
}

protocol EventMediaRepository {
    func uploadEventImage(
        imageData: Data,
        fileName: String,
        mimeType: String,
        eventID: String?,
        usage: String?
    ) async throws -> UploadMediaResponse
    func uploadPostImage(imageData: Data, fileName: String, mimeType: String) async throws -> UploadMediaResponse
    func importEventLineupFromImage(
        imageData: Data,
        fileName: String,
        mimeType: String,
        startDate: Date?,
        endDate: Date?
    ) async throws -> EventLineupImageImportResponse
}

protocol EventDiscussionMediaRepository {
    func uploadPostImage(imageData: Data, fileName: String, mimeType: String) async throws -> UploadMediaResponse
}

protocol EventCheckinRepository {
    func fetchMyCheckins(page: Int, limit: Int, type: String?) async throws -> CheckinListPage
    func fetchMyCheckins(page: Int, limit: Int, type: String?, eventID: String?, djID: String?) async throws -> CheckinListPage
    func createCheckin(input: CreateCheckinInput) async throws -> WebCheckin
    func updateCheckin(id: String, input: UpdateCheckinInput) async throws -> WebCheckin
    func deleteCheckin(id: String) async throws
    func fetchFavoriteEvents(page: Int, limit: Int) async throws -> EventListPage
    func fetchEventFavoriteStatus(eventID: String) async throws -> EventFavoriteStatus
    func favoriteEvent(eventID: String) async throws -> EventFavoriteStatus
    func unfavoriteEvent(eventID: String) async throws
}

protocol EventRelatedContentRepository {
    func fetchEventDJSets(eventID: String, eventName: String) async throws -> [WebDJSet]
}

struct EventListRepositoryAdapter: EventListRepository {
    private let service: WebFeatureService

    init(service: WebFeatureService) {
        self.service = service
    }

    func fetchEvents(request: DiscoverEventsPageRequest) async throws -> EventListPage {
        try await service.fetchEvents(
            page: request.page,
            limit: request.limit,
            search: request.search,
            eventType: request.eventType,
            status: request.status,
            wikiFestivalId: request.wikiFestivalId
        )
    }

    func fetchEventsBootstrap(limit: Int, search: String?, eventType: String?) async throws -> EventsBootstrapResponse {
        try await service.fetchEventsBootstrap(limit: limit, search: search, eventType: eventType)
    }

    func fetchFestivalEventFeed(
        wikiFestivalId: String,
        upcomingPage: Int,
        upcomingLimit: Int,
        endedPage: Int,
        endedLimit: Int
    ) async throws -> FestivalEventFeedResponse {
        try await service.fetchFestivalEventFeed(
            wikiFestivalId: wikiFestivalId,
            upcomingPage: upcomingPage,
            upcomingLimit: upcomingLimit,
            endedPage: endedPage,
            endedLimit: endedLimit
        )
    }
}

struct EventRecommendationRepositoryAdapter: EventRecommendationRepository {
    private let service: WebFeatureService

    init(service: WebFeatureService) {
        self.service = service
    }

    func fetchRecommendedEvents(limit: Int, statuses: [String]?) async throws -> [WebEvent] {
        try await service.fetchRecommendedEvents(limit: limit, statuses: statuses)
    }
}

struct EventReadRepositoryAdapter: EventReadRepository {
    private let service: WebFeatureService

    init(service: WebFeatureService) {
        self.service = service
    }

    func fetchEvent(id: String) async throws -> WebEvent {
        try await service.fetchEvent(id: id)
    }
}

struct EventLiveDiscussionRepositoryAdapter: EventLiveDiscussionRepository {
    private let service: SocialService

    init(service: SocialService) {
        self.service = service
    }

    func fetchEventLiveComments(
        eventID: String,
        cursor: String?,
        sort: EventLiveCommentSortMode
    ) async throws -> EventLiveCommentPage {
        try await service.fetchEventLiveComments(eventID: eventID, cursor: cursor, sort: sort)
    }

    func addEventLiveComment(
        eventID: String,
        content: String,
        imageURLs: [String],
        parentCommentID: String?
    ) async throws -> EventLiveComment {
        try await service.addEventLiveComment(
            eventID: eventID,
            content: content,
            imageURLs: imageURLs,
            parentCommentID: parentCommentID
        )
    }

    func toggleEventLiveCommentLike(commentID: String, shouldLike: Bool) async throws -> EventLiveComment {
        try await service.toggleEventLiveCommentLike(commentID: commentID, shouldLike: shouldLike)
    }
}

struct EventCommandRepositoryAdapter: EventCommandRepository {
    private let service: WebFeatureService
    private let accountEnforcementStatusProvider: (() async -> AccountEnforcementStatus?)?

    init(
        service: WebFeatureService,
        accountEnforcementStatusProvider: (() async -> AccountEnforcementStatus?)? = nil
    ) {
        self.service = service
        self.accountEnforcementStatusProvider = accountEnforcementStatusProvider
    }

    private func ensureAllowed(_ scopes: [AccountEnforcementScope]) async throws {
        guard let accountEnforcementStatusProvider else { return }
        guard let status = await accountEnforcementStatusProvider(),
              let restriction = status.restriction(for: scopes) else {
            return
        }
        throw ServiceError.accountEnforcementRestricted(restriction)
    }

    func createEvent(input: CreateEventInput) async throws -> CreateEventResult {
        try await ensureAllowed([.eventCreate])
        return try await service.createEvent(input: input)
    }

    func updateEvent(id: String, input: UpdateEventInput) async throws -> WebEvent {
        try await service.updateEvent(id: id, input: input)
    }

    func deleteEvent(id: String) async throws {
        try await service.deleteEvent(id: id)
    }
}

struct EventMediaRepositoryAdapter: EventMediaRepository, EventDiscussionMediaRepository {
    private let service: WebFeatureService
    private let accountEnforcementStatusProvider: (() async -> AccountEnforcementStatus?)?

    init(
        service: WebFeatureService,
        accountEnforcementStatusProvider: (() async -> AccountEnforcementStatus?)? = nil
    ) {
        self.service = service
        self.accountEnforcementStatusProvider = accountEnforcementStatusProvider
    }

    private func ensureAllowed(_ scopes: [AccountEnforcementScope]) async throws {
        guard let accountEnforcementStatusProvider else { return }
        guard let status = await accountEnforcementStatusProvider(),
              let restriction = status.restriction(for: scopes) else {
            return
        }
        throw ServiceError.accountEnforcementRestricted(restriction)
    }

    func uploadEventImage(
        imageData: Data,
        fileName: String,
        mimeType: String,
        eventID: String?,
        usage: String?
    ) async throws -> UploadMediaResponse {
        try await ensureAllowed([.mediaUpload])
        return try await service.uploadEventImage(
            imageData: imageData,
            fileName: fileName,
            mimeType: mimeType,
            eventID: eventID,
            usage: usage
        )
    }

    func uploadPostImage(imageData: Data, fileName: String, mimeType: String) async throws -> UploadMediaResponse {
        try await ensureAllowed([.mediaUpload])
        return try await service.uploadPostImage(
            imageData: imageData,
            fileName: fileName,
            mimeType: mimeType
        )
    }

    func importEventLineupFromImage(
        imageData: Data,
        fileName: String,
        mimeType: String,
        startDate: Date?,
        endDate: Date?
    ) async throws -> EventLineupImageImportResponse {
        try await ensureAllowed([.mediaUpload])
        return try await service.importEventLineupFromImage(
            imageData: imageData,
            fileName: fileName,
            mimeType: mimeType,
            startDate: startDate,
            endDate: endDate
        )
    }
}

struct EventCheckinRepositoryAdapter: EventCheckinRepository {
    private let service: WebFeatureService

    init(service: WebFeatureService) {
        self.service = service
    }

    func fetchMyCheckins(page: Int, limit: Int, type: String?) async throws -> CheckinListPage {
        try await service.fetchMyCheckins(page: page, limit: limit, type: type)
    }

    func fetchMyCheckins(page: Int, limit: Int, type: String?, eventID: String?, djID: String?) async throws -> CheckinListPage {
        try await service.fetchMyCheckins(page: page, limit: limit, type: type, eventID: eventID, djID: djID)
    }

    func createCheckin(input: CreateCheckinInput) async throws -> WebCheckin {
        try await service.createCheckin(input: input)
    }

    func updateCheckin(id: String, input: UpdateCheckinInput) async throws -> WebCheckin {
        try await service.updateCheckin(id: id, input: input)
    }

    func deleteCheckin(id: String) async throws {
        try await service.deleteCheckin(id: id)
    }

    func fetchFavoriteEvents(page: Int, limit: Int) async throws -> EventListPage {
        try await service.fetchFavoriteEvents(page: page, limit: limit)
    }

    func fetchEventFavoriteStatus(eventID: String) async throws -> EventFavoriteStatus {
        try await service.fetchEventFavoriteStatus(eventID: eventID)
    }

    func favoriteEvent(eventID: String) async throws -> EventFavoriteStatus {
        try await service.favoriteEvent(eventID: eventID)
    }

    func unfavoriteEvent(eventID: String) async throws {
        try await service.unfavoriteEvent(eventID: eventID)
    }
}

struct EventRelatedContentRepositoryAdapter: EventRelatedContentRepository {
    private let service: WebFeatureService

    init(service: WebFeatureService) {
        self.service = service
    }

    func fetchEventDJSets(eventID: String, eventName: String) async throws -> [WebDJSet] {
        try await service.fetchEventDJSets(eventID: eventID, eventName: eventName)
    }
}

struct RatingRepositoryAdapter: RatingRepository {
    private let service: WebFeatureService

    init(service: WebFeatureService) {
        self.service = service
    }

    func fetchRatingEvents() async throws -> [WebRatingEvent] {
        try await service.fetchRatingEvents()
    }

    func fetchRatingEvents(page: Int, limit: Int) async throws -> RatingEventListPage {
        try await service.fetchRatingEvents(page: page, limit: limit)
    }

    func fetchRatingEvent(id: String) async throws -> WebRatingEvent {
        try await service.fetchRatingEvent(id: id)
    }

    func fetchRatingUnit(id: String) async throws -> WebRatingUnit {
        try await service.fetchRatingUnit(id: id)
    }

    func createRatingEvent(input: CreateRatingEventInput) async throws -> CreateContentResult<WebRatingEvent> {
        try await service.createRatingEvent(input: input)
    }

    func createRatingEventFromEvent(eventID: String) async throws -> WebRatingEvent {
        try await service.createRatingEventFromEvent(eventID: eventID)
    }

    func createRatingUnit(eventID: String, input: CreateRatingUnitInput) async throws -> CreateContentResult<WebRatingUnit> {
        try await service.createRatingUnit(eventID: eventID, input: input)
    }

    func updateRatingEvent(id: String, input: UpdateRatingEventInput) async throws -> WebRatingEvent {
        try await service.updateRatingEvent(id: id, input: input)
    }

    func updateRatingUnit(id: String, input: UpdateRatingUnitInput) async throws -> WebRatingUnit {
        try await service.updateRatingUnit(id: id, input: input)
    }

    func deleteRatingEvent(id: String) async throws {
        try await service.deleteRatingEvent(id: id)
    }

    func deleteRatingUnit(id: String) async throws {
        try await service.deleteRatingUnit(id: id)
    }

    func fetchEventRatingEvents(eventID: String) async throws -> [WebRatingEvent] {
        try await service.fetchEventRatingEvents(eventID: eventID)
    }

    func fetchEventRatingEvents(eventID: String, page: Int, limit: Int) async throws -> RatingEventListPage {
        try await service.fetchEventRatingEvents(eventID: eventID, page: page, limit: limit)
    }

    func addRatingComment(unitID: String, input: CreateRatingCommentInput) async throws -> WebRatingComment {
        try await service.addRatingComment(unitID: unitID, input: input)
    }

    func uploadRatingImage(
        imageData: Data,
        fileName: String,
        mimeType: String,
        ratingEventID: String?,
        ratingUnitID: String?,
        usage: String?
    ) async throws -> UploadMediaResponse {
        try await service.uploadRatingImage(
            imageData: imageData,
            fileName: fileName,
            mimeType: mimeType,
            ratingEventID: ratingEventID,
            ratingUnitID: ratingUnitID,
            usage: usage
        )
    }
}

struct FetchDiscoverEventsPageUseCase {
    private let repository: EventListRepository

    init(repository: EventListRepository) {
        self.repository = repository
    }

    func execute(_ request: DiscoverEventsPageRequest) async throws -> EventListPage {
        try await repository.fetchEvents(request: request)
    }
}

struct FetchDiscoverEventsBootstrapUseCase {
    private let repository: EventListRepository

    init(repository: EventListRepository) {
        self.repository = repository
    }

    func execute(limit: Int, search: String?, eventType: String?) async throws -> EventsBootstrapResponse {
        try await repository.fetchEventsBootstrap(limit: limit, search: search, eventType: eventType)
    }
}

struct FetchRecommendedDiscoverEventsUseCase {
    private let repository: EventRecommendationRepository

    init(repository: EventRecommendationRepository) {
        self.repository = repository
    }

    func execute(limit: Int, statuses: [String]?) async throws -> [WebEvent] {
        try await repository.fetchRecommendedEvents(limit: limit, statuses: statuses)
    }
}

struct FetchMarkedEventCheckinsUseCase {
    private let repository: EventCheckinRepository

    init(repository: EventCheckinRepository) {
        self.repository = repository
    }

    func execute(limit: Int = 200) async throws -> [String: String] {
        let page = try await repository.fetchFavoriteEvents(page: 1, limit: limit)
        var markedMap: [String: String] = [:]
        for item in page.items where item.isFavorited == true {
            markedMap[item.id] = item.favoriteId ?? item.id
        }
        return markedMap
    }
}

struct ToggleMarkedEventUseCase {
    private let repository: EventCheckinRepository

    init(repository: EventCheckinRepository) {
        self.repository = repository
    }

    func execute(event: WebEvent, markedCheckinIDsByEventID: [String: String]) async throws -> [String: String] {
        var next = markedCheckinIDsByEventID

        if next[event.id] != nil {
            try await repository.unfavoriteEvent(eventID: event.id)
            next[event.id] = nil
        } else {
            let favorite = try await repository.favoriteEvent(eventID: event.id)
            next[event.id] = favorite.id ?? event.id
        }
        return next
    }
}

private struct EventsModuleOfflineSnapshot: Codable {
    var querySearch: String
    var queryEventTypeKey: String
    var allEvents: [WebEvent]
    var nextAllPage: Int
    var totalAllPages: Int
    var totalOngoingPages: Int
    var totalUpcomingPages: Int
    var cachedAt: Date
}

@MainActor
final class EventsModuleViewModel: ObservableObject {
    struct AllQuery: Equatable {
        let search: String
        let eventTypeKey: String

        var searchParam: String? {
            let trimmed = search.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        var eventTypeParam: String? {
            EventTypeOption.submissionValue(for: eventTypeKey)
        }
    }

    @Published private(set) var allEvents: [WebEvent] = []
    @Published private(set) var isLoadingAll = false
    @Published private(set) var isLoadingMoreAll = false
    @Published var errorMessage: String?

    private let fetchEventsBootstrapUseCase: FetchDiscoverEventsBootstrapUseCase
    private let fetchEventsPageUseCase: FetchDiscoverEventsPageUseCase
    private let pageSize = 5
    private let offlineSnapshotStorageKey = "raver.discover.events.offlineSnapshots.v2"
    private let bootstrapRefreshInterval: TimeInterval = 30

    private var currentAllQuery = AllQuery(search: "", eventTypeKey: "")
    private var nextAllPage = 1
    private var totalAllPages = 1
    private var totalOngoingPages = 1
    private var totalUpcomingPages = 1
    private var allReloadToken = UUID()
    private var lastSuccessfulAllLoadAt: Date?
    private var didHydrateAllFromDiskCache = false

    init(
        listRepository: EventListRepository,
        eventReadRepository: EventReadRepository,
        checkinRepository: EventCheckinRepository
    ) {
        self.fetchEventsBootstrapUseCase = FetchDiscoverEventsBootstrapUseCase(repository: listRepository)
        _ = eventReadRepository
        _ = checkinRepository
        self.fetchEventsPageUseCase = FetchDiscoverEventsPageUseCase(repository: listRepository)
    }

    var canLoadMoreAll: Bool {
        nextAllPage <= totalAllPages
    }

    func hydrateAllFromCacheIfPossible(query: AllQuery) {
        guard allEvents.isEmpty else { return }
        guard let snapshot = restoreOfflineSnapshot(query: query) else { return }
        applyOfflineSnapshot(snapshot, query: query)
    }

    func reloadAll(query: AllQuery, force: Bool = false) async {
        guard force || query != currentAllQuery || allEvents.isEmpty || shouldRefreshBootstrap(for: query) else { return }

        let token = UUID()
        allReloadToken = token
        currentAllQuery = query
        isLoadingAll = allEvents.isEmpty
        errorMessage = nil

        do {
            let bootstrap = try await fetchEventsBootstrapUseCase.execute(
                limit: pageSize,
                search: query.searchParam,
                eventType: query.eventTypeParam
            )

            guard allReloadToken == token else { return }
            allEvents = mergeAndSortActiveEvents(ongoing: bootstrap.ongoing.items, upcoming: bootstrap.upcoming.items)
            totalOngoingPages = bootstrap.ongoing.pagination?.totalPages ?? 1
            totalUpcomingPages = bootstrap.upcoming.pagination?.totalPages ?? 1
            totalAllPages = max(totalOngoingPages, totalUpcomingPages)
            nextAllPage = 2
            lastSuccessfulAllLoadAt = Date()
            didHydrateAllFromDiskCache = false
            persistOfflineSnapshot(query: query)
        } catch {
            guard allReloadToken == token else { return }
            errorMessage = error.userFacingMessage
        }

        if allReloadToken == token {
            isLoadingAll = false
        }
    }

    func loadMoreAllIfNeeded(query: AllQuery) async {
        guard query == currentAllQuery else { return }
        guard !isLoadingAll, !isLoadingMoreAll, nextAllPage <= totalAllPages else { return }

        let pageToLoad = nextAllPage
        isLoadingMoreAll = true

        do {
            let shouldLoadOngoing = pageToLoad <= totalOngoingPages
            let shouldLoadUpcoming = pageToLoad <= totalUpcomingPages

            async let ongoingPage = try fetchActiveEventsPageIfNeeded(
                shouldLoadOngoing,
                query: query,
                page: pageToLoad,
                status: "ongoing"
            )
            async let upcomingPage = try fetchActiveEventsPageIfNeeded(
                shouldLoadUpcoming,
                query: query,
                page: pageToLoad,
                status: "upcoming"
            )
            let (ongoingResult, upcomingResult) = try await (ongoingPage, upcomingPage)

            guard query == currentAllQuery else { return }
            let mergedPageItems = mergeAndSortActiveEvents(
                ongoing: ongoingResult?.items ?? [],
                upcoming: upcomingResult?.items ?? []
            )
            allEvents = mergeUnique(existing: allEvents, with: mergedPageItems)
            if let ongoingResult {
                totalOngoingPages = ongoingResult.pagination?.totalPages ?? totalOngoingPages
            }
            if let upcomingResult {
                totalUpcomingPages = upcomingResult.pagination?.totalPages ?? totalUpcomingPages
            }
            totalAllPages = max(totalOngoingPages, totalUpcomingPages)
            nextAllPage = pageToLoad + 1
            persistOfflineSnapshot(query: query)
        } catch {
            if query == currentAllQuery {
                errorMessage = error.userFacingMessage
            }
        }

        if query == currentAllQuery {
            isLoadingMoreAll = false
        }
    }

    private func mergeUnique(existing: [WebEvent], with incoming: [WebEvent]) -> [WebEvent] {
        var merged = existing
        var seen = Set(existing.map(\.id))
        for item in incoming where seen.insert(item.id).inserted {
            merged.append(item)
        }
        return merged.sorted(by: sortEventByActiveTimeline)
    }

    private func fetchActiveEventsPage(query: AllQuery, page: Int, status: String) async throws -> EventListPage {
        try await fetchEventsPageUseCase.execute(
            DiscoverEventsPageRequest(
                page: page,
                limit: pageSize,
                search: query.searchParam,
                eventType: query.eventTypeParam,
                status: status
            )
        )
    }

    private func fetchActiveEventsPageIfNeeded(
        _ shouldLoad: Bool,
        query: AllQuery,
        page: Int,
        status: String
    ) async throws -> EventListPage? {
        guard shouldLoad else { return nil }
        return try await fetchActiveEventsPage(query: query, page: page, status: status)
    }

    private func mergeAndSortActiveEvents(ongoing: [WebEvent], upcoming: [WebEvent]) -> [WebEvent] {
        mergeUnique(existing: ongoing, with: upcoming)
    }

    private func shouldRefreshBootstrap(for query: AllQuery) -> Bool {
        if didHydrateAllFromDiskCache, query == currentAllQuery {
            return true
        }
        guard query == currentAllQuery else { return true }
        guard let lastSuccessfulAllLoadAt else { return true }
        return Date().timeIntervalSince(lastSuccessfulAllLoadAt) >= bootstrapRefreshInterval
    }

    private func persistOfflineSnapshot(query: AllQuery) {
        let snapshot = EventsModuleOfflineSnapshot(
            querySearch: query.search,
            queryEventTypeKey: query.eventTypeKey,
            allEvents: allEvents,
            nextAllPage: nextAllPage,
            totalAllPages: totalAllPages,
            totalOngoingPages: totalOngoingPages,
            totalUpcomingPages: totalUpcomingPages,
            cachedAt: Date()
        )

        do {
            var snapshots = loadOfflineSnapshots()
            snapshots.removeAll {
                $0.querySearch == query.search && $0.queryEventTypeKey == query.eventTypeKey
            }
            snapshots.append(snapshot)
            snapshots.sort { $0.cachedAt > $1.cachedAt }
            if snapshots.count > 12 {
                snapshots = Array(snapshots.prefix(12))
            }
            let data = try JSONEncoder.raver.encode(snapshots)
            UserDefaults.standard.set(data, forKey: offlineSnapshotStorageKey)
        } catch {
            assertionFailure("Failed to persist discover events offline snapshot: \(error)")
        }
    }

    private func restoreOfflineSnapshot(query: AllQuery) -> EventsModuleOfflineSnapshot? {
        loadOfflineSnapshots().first {
            $0.querySearch == query.search && $0.queryEventTypeKey == query.eventTypeKey
        }
    }

    private func loadOfflineSnapshots() -> [EventsModuleOfflineSnapshot] {
        guard let data = UserDefaults.standard.data(forKey: offlineSnapshotStorageKey),
              let snapshots = try? JSONDecoder.raver.decode([EventsModuleOfflineSnapshot].self, from: data) else {
            return []
        }
        return snapshots
    }

    private func applyOfflineSnapshot(_ snapshot: EventsModuleOfflineSnapshot, query: AllQuery) {
        currentAllQuery = query
        allEvents = snapshot.allEvents
        nextAllPage = snapshot.nextAllPage
        totalAllPages = snapshot.totalAllPages
        totalOngoingPages = snapshot.totalOngoingPages
        totalUpcomingPages = snapshot.totalUpcomingPages
        lastSuccessfulAllLoadAt = snapshot.cachedAt
        didHydrateAllFromDiskCache = true
    }

    private func sortEventByActiveTimeline(_ lhs: WebEvent, _ rhs: WebEvent) -> Bool {
        if lhs.startDate == rhs.startDate {
            return lhs.endDate < rhs.endDate
        }
        return lhs.startDate < rhs.startDate
    }
}
