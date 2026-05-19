import Foundation

protocol WebFeatureService {
    func fetchEvents(page: Int, limit: Int, search: String?, eventType: String?, status: String?, wikiFestivalId: String?) async throws -> EventListPage
    func fetchRecommendedEvents(limit: Int, statuses: [String]?) async throws -> [WebEvent]
    func fetchEvent(id: String) async throws -> WebEvent
    func fetchMyEvents() async throws -> [WebEvent]
    func fetchFavoriteEvents(page: Int, limit: Int) async throws -> EventListPage
    func fetchEventFavoriteStatus(eventID: String) async throws -> EventFavoriteStatus
    func favoriteEvent(eventID: String) async throws -> EventFavoriteStatus
    func unfavoriteEvent(eventID: String) async throws
    func createEvent(input: CreateEventInput) async throws -> CreateEventResult
    func updateEvent(id: String, input: UpdateEventInput) async throws -> WebEvent
    func deleteEvent(id: String) async throws
    func uploadEventImage(
        imageData: Data,
        fileName: String,
        mimeType: String,
        eventID: String?,
        usage: String?
    ) async throws -> UploadMediaResponse
    func uploadRatingImage(
        imageData: Data,
        fileName: String,
        mimeType: String,
        ratingEventID: String?,
        ratingUnitID: String?,
        usage: String?
    ) async throws -> UploadMediaResponse
    func importEventLineupFromImage(
        imageData: Data,
        fileName: String,
        mimeType: String,
        startDate: Date?,
        endDate: Date?
    ) async throws -> EventLineupImageImportResponse
    func uploadPostImage(imageData: Data, fileName: String, mimeType: String) async throws -> UploadMediaResponse
    func uploadPostVideo(videoData: Data, fileName: String, mimeType: String) async throws -> UploadMediaResponse
    func uploadWikiBrandImage(
        imageData: Data,
        fileName: String,
        mimeType: String,
        brandID: String?,
        usage: String?
    ) async throws -> UploadMediaResponse

    func fetchDJs(page: Int, limit: Int, search: String?, sortBy: String) async throws -> DJListPage
    func fetchRecommendedDJs(limit: Int) async throws -> [WebDJ]
    func fetchOnboardingDJCandidates(limit: Int) async throws -> [WebDJ]
    func fetchOnboardingPreferenceOptions() async throws -> OnboardingPreferenceOptions
    func fetchDJ(id: String) async throws -> WebDJ
    func searchSpotifyDJs(query: String, limit: Int) async throws -> [SpotifyDJCandidate]
    func searchDiscogsDJs(query: String, limit: Int) async throws -> [DiscogsDJCandidate]
    func fetchDiscogsDJArtist(id: Int) async throws -> DiscogsDJArtistDetail
    func importSpotifyDJ(input: ImportSpotifyDJInput) async throws -> ImportDJResult<ImportSpotifyDJResponse>
    func importDiscogsDJ(input: ImportDiscogsDJInput) async throws -> ImportDJResult<ImportDiscogsDJResponse>
    func importManualDJ(input: ImportManualDJInput) async throws -> ImportDJResult<ImportManualDJResponse>
    func updateDJ(id: String, input: UpdateDJInput) async throws -> WebDJ
    func uploadDJImage(
        imageData: Data,
        fileName: String,
        mimeType: String,
        djID: String,
        usage: String
    ) async throws -> UploadMediaResponse
    func fetchDJSets(djID: String) async throws -> [WebDJSet]
    func fetchDJEvents(djID: String) async throws -> [WebEvent]
    func fetchDJFollowStatus(djID: String) async throws -> Bool
    func toggleDJFollow(djID: String, shouldFollow: Bool) async throws -> WebDJ
    func fetchFollowedDJs(page: Int, limit: Int) async throws -> DJListPage

    func fetchDJSets(page: Int, limit: Int, sortBy: String, djID: String?) async throws -> DJSetListPage
    func fetchEventDJSets(eventID: String, eventName: String) async throws -> [WebDJSet]
    func fetchDJSet(id: String) async throws -> WebDJSet
    func fetchMyDJSets() async throws -> [WebDJSet]
    func createDJSet(input: CreateDJSetInput) async throws -> CreateContentResult<WebDJSet>
    func updateDJSet(id: String, input: UpdateDJSetInput) async throws -> WebDJSet
    func deleteDJSet(id: String) async throws
    func replaceTracks(setID: String, tracks: [CreateTrackInput]) async throws -> WebDJSet
    func fetchTracklists(setID: String) async throws -> [WebTracklistSummary]
    func fetchTracklistDetail(setID: String, tracklistID: String) async throws -> WebTracklistDetail
    func createTracklist(setID: String, input: CreateTracklistInput) async throws -> WebTracklistDetail
    func autoLinkTracks(setID: String) async throws
    func previewVideo(videoURL: String) async throws -> [String: String]
    func uploadSetThumbnail(imageData: Data, fileName: String, mimeType: String) async throws -> UploadMediaResponse
    func uploadSetVideo(videoData: Data, fileName: String, mimeType: String) async throws -> UploadMediaResponse

    func fetchSetComments(setID: String) async throws -> [WebSetComment]
    func addSetComment(setID: String, input: CreateSetCommentInput) async throws -> WebSetComment
    func updateSetComment(commentID: String, content: String) async throws -> WebSetComment
    func deleteSetComment(commentID: String) async throws

    func fetchMyCheckins(page: Int, limit: Int, type: String?) async throws -> CheckinListPage
    func fetchMyCheckins(page: Int, limit: Int, type: String?, eventID: String?, djID: String?) async throws -> CheckinListPage
    func fetchUserCheckins(userID: String, page: Int, limit: Int, type: String?) async throws -> CheckinListPage
    func fetchUserCheckins(userID: String, page: Int, limit: Int, type: String?, eventID: String?, djID: String?) async throws -> CheckinListPage
    func fetchMyCheckinsOverview() async throws -> MyCheckinsOverviewResponse
    func fetchUserCheckinsOverview(userID: String) async throws -> MyCheckinsOverviewResponse
    func fetchMyCheckinsTimeline(page: Int, limit: Int) async throws -> MyCheckinsTimelinePage
    func fetchUserCheckinsTimeline(userID: String, page: Int, limit: Int) async throws -> MyCheckinsTimelinePage
    func fetchMyCheckinsGalleryEvents(page: Int, limit: Int) async throws -> MyCheckinsGalleryEventPage
    func fetchUserCheckinsGalleryEvents(userID: String, page: Int, limit: Int) async throws -> MyCheckinsGalleryEventPage
    func fetchMyCheckinsGalleryArtists(page: Int, limit: Int) async throws -> MyCheckinsGalleryArtistPage
    func fetchUserCheckinsGalleryArtists(userID: String, page: Int, limit: Int) async throws -> MyCheckinsGalleryArtistPage
    func fetchMyCheckinsStats() async throws -> MyCheckinsOverviewStats
    func fetchUserCheckinsStats(userID: String) async throws -> MyCheckinsOverviewStats
    func fetchMyDJCheckinCount(djID: String) async throws -> Int
    func createCheckin(input: CreateCheckinInput) async throws -> WebCheckin
    func updateCheckin(id: String, input: UpdateCheckinInput) async throws -> WebCheckin
    func deleteCheckin(id: String) async throws

    func fetchRatingEvents() async throws -> [WebRatingEvent]
    func fetchEventRatingEvents(eventID: String) async throws -> [WebRatingEvent]
    func fetchRatingEvent(id: String) async throws -> WebRatingEvent
    func fetchDJRatingUnits(djID: String) async throws -> [WebRatingUnit]
    func createRatingEvent(input: CreateRatingEventInput) async throws -> CreateContentResult<WebRatingEvent>
    func createRatingEventFromEvent(eventID: String) async throws -> WebRatingEvent
    func updateRatingEvent(id: String, input: UpdateRatingEventInput) async throws -> WebRatingEvent
    func deleteRatingEvent(id: String) async throws
    func createRatingUnit(eventID: String, input: CreateRatingUnitInput) async throws -> CreateContentResult<WebRatingUnit>
    func updateRatingUnit(id: String, input: UpdateRatingUnitInput) async throws -> WebRatingUnit
    func deleteRatingUnit(id: String) async throws
    func fetchRatingUnit(id: String) async throws -> WebRatingUnit
    func addRatingComment(unitID: String, input: CreateRatingCommentInput) async throws -> WebRatingComment

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
    func createLearnLabel(input: CreateLearnLabelInput) async throws -> CreateContentResult<LearnLabel>
    func fetchLearnFestivals(search: String?) async throws -> [WebLearnFestival]
    func createLearnFestival(input: CreateLearnFestivalInput) async throws -> CreateContentResult<WebLearnFestival>
    func updateLearnFestival(id: String, input: UpdateLearnFestivalInput) async throws -> WebLearnFestival
    func fetchRankingBoards() async throws -> [RankingBoard]
    func fetchRankingBoardDetail(boardID: String, year: Int?) async throws -> RankingBoardDetail
    func searchGlobal(query: String, tab: GlobalSearchTab, limit: Int) async throws -> GlobalSearchResponse

    func fetchMyPublishes() async throws -> MyPublishes
    func fetchMyContentSubmissions() async throws -> [ContentSubmissionSummary]
    func fetchMyContentSubmission(id: String) async throws -> ContentSubmissionDetail
    func createContentSubmission(entityType: String, payload: [String: ContentSubmissionJSONValue]) async throws -> ContentSubmissionDetail
    func resubmitMyContentSubmission(id: String, payload: [String: ContentSubmissionJSONValue], changeNote: String?) async throws -> ContentSubmissionDetail
}

extension WebFeatureService {
    func fetchEvents(page: Int, limit: Int, search: String?, eventType: String?, status: String?) async throws -> EventListPage {
        try await fetchEvents(
            page: page,
            limit: limit,
            search: search,
            eventType: eventType,
            status: status,
            wikiFestivalId: nil
        )
    }

    func uploadEventImage(imageData: Data, fileName: String, mimeType: String) async throws -> UploadMediaResponse {
        try await uploadEventImage(
            imageData: imageData,
            fileName: fileName,
            mimeType: mimeType,
            eventID: nil,
            usage: nil
        )
    }

    func uploadRatingImage(imageData: Data, fileName: String, mimeType: String) async throws -> UploadMediaResponse {
        try await uploadRatingImage(
            imageData: imageData,
            fileName: fileName,
            mimeType: mimeType,
            ratingEventID: nil,
            ratingUnitID: nil,
            usage: nil
        )
    }
}
