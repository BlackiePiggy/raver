import Foundation
import RaverEventAdminContract

protocol WebFeatureService {
    func prepareAuthenticatedRequestForUserAction(source: String) async throws
    func fetchQuizConfigSummary() async throws -> QuizConfigSummary
    func fetchQuizStatus() async throws -> QuizConfigSummary
    func createQuizSession(mode: QuizSessionMode) async throws -> QuizSessionCreateResponse
    func submitQuizSession(
        sessionId: String,
        answers: [QuizSubmitAnswerPayload],
        presentedQuestionIds: [String]?
    ) async throws -> QuizSessionSubmitResponse
    func abandonQuizSession(sessionId: String, reason: QuizSessionAbandonReason?) async throws -> QuizSessionAbandonResponse
    func fetchPersonalityStatus() async throws -> PersonalityStatusSummary
    func fetchPersonalityResult() async throws -> PersonalityResultEnvelope
    func createPersonalitySession(mode: PersonalitySessionMode) async throws -> PersonalitySessionCreateResponse
    func savePersonalitySessionAnswer(
        sessionId: String,
        answers: [PersonalityAnswerPayload],
        currentQuestionIndex: Int?
    ) async throws -> PersonalitySessionAnswerSaveResponse
    func submitPersonalitySession(
        sessionId: String,
        answers: [PersonalityAnswerPayload]
    ) async throws -> PersonalitySessionSubmitResponse
    func abandonPersonalitySession(sessionId: String) async throws -> PersonalitySessionAbandonResponse
    func fetchEvents(page: Int, limit: Int, search: String?, eventType: String?, status: String?, wikiFestivalId: String?) async throws -> EventListPage
    func fetchEventsBootstrap(limit: Int, search: String?, eventType: String?) async throws -> EventsBootstrapResponse
    func fetchFestivalEventFeed(wikiFestivalId: String, upcomingPage: Int, upcomingLimit: Int, endedPage: Int, endedLimit: Int) async throws -> FestivalEventFeedResponse
    func fetchRecommendedEvents(limit: Int, statuses: [String]?) async throws -> [WebEvent]
    func fetchEventSummary(id: String) async throws -> WebEvent
    func fetchEventContributors(eventID: String) async throws -> WebEntityContributorPage
    func fetchEventLineup(eventID: String) async throws -> [WebEventLineupArtist]
    func fetchEventTimetable(eventID: String) async throws -> [WebEventLineupSlot]
    func fetchEvent(id: String) async throws -> WebEvent
    func searchEventTimezones(query: String, limit: Int) async throws -> [EventTimezoneLookupItem]
    func fetchMyEvents() async throws -> [WebEvent]
    func fetchMyEvents(page: Int, limit: Int) async throws -> EventListPage
    func fetchFavoriteEvents(page: Int, limit: Int) async throws -> EventListPage
    func fetchEventFavoriteStatus(eventID: String) async throws -> EventFavoriteStatus
    func fetchEventCheckinStatus(eventID: String) async throws -> EventCheckinStatus
    func favoriteEvent(eventID: String) async throws -> EventFavoriteStatus
    func unfavoriteEvent(eventID: String) async throws
    // Legacy EventEditorView compatibility surface. New event flows should use generated EventAdmin* inputs.
    @available(*, deprecated, message: "Legacy Event editor surface. Use createEvent(input: EventAdminCreateInput).")
    func createEvent(input: CreateEventInput) async throws -> CreateEventResult
    @available(*, deprecated, message: "Legacy Event editor surface. Use updateEvent(id:input: EventAdminUpdateInput).")
    func updateEvent(id: String, input: UpdateEventInput) async throws -> CreateContentResult<WebEvent>
    @available(*, deprecated, message: "Legacy Event editor surface. Use previewEventLineupTimetableAlignment(input: EventAdminCreateInput).")
    func previewEventLineupTimetableAlignment(input: CreateEventInput) async throws -> EventLineupTimetableAlignmentPreview
    func createEvent(input: EventAdminCreateInput) async throws -> CreateEventResult
    func updateEvent(id: String, input: EventAdminUpdateInput) async throws -> CreateContentResult<WebEvent>
    func previewEventLineupTimetableAlignment(input: EventAdminCreateInput) async throws -> EventLineupTimetableAlignmentPreview
    func deleteEvent(id: String) async throws
    func uploadEventImage(
        imageData: Data,
        fileName: String,
        mimeType: String,
        eventID: String?,
        draftID: String?,
        usage: String?
    ) async throws -> UploadMediaResponse
    func deleteEventUploadedImages(
        eventID: String?,
        draftID: String?,
        urls: [String]
    ) async throws
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
    func createEventLineupImageImportJob(input: EventLineupAIImportRequest) async throws -> EventLineupAIImportJobResponse
    func fetchEventLineupImageImportJob(id: String) async throws -> EventLineupAIImportJobResponse
    func cancelEventLineupImageImportJob(id: String) async throws -> EventLineupAIImportJobResponse
    func createEventPosterImageImportJob(input: EventPosterAIImportRequest) async throws -> EventPosterAIImportJobResponse
    func fetchEventPosterImageImportJob(id: String) async throws -> EventPosterAIImportJobResponse
    func cancelEventPosterImageImportJob(id: String) async throws -> EventPosterAIImportJobResponse
    func importEventTimetableFromImage(input: EventTimetableImageImportRequest) async throws -> EventTimetableImageImportResponse
    func createEventTimetableImageImportJob(input: EventTimetableImageImportRequest) async throws -> EventTimetableImageImportJobResponse
    func fetchEventTimetableImageImportJob(id: String) async throws -> EventTimetableImageImportJobResponse
    func cancelEventTimetableImageImportJob(id: String) async throws -> EventTimetableImageImportJobResponse
    func matchExactDJs(names: [String]) async throws -> [DJExactMatchItem]
    func uploadPostImage(imageData: Data, fileName: String, mimeType: String) async throws -> UploadMediaResponse
    func uploadPostVideo(videoData: Data, fileName: String, mimeType: String) async throws -> UploadMediaResponse
    func uploadWikiBrandImage(
        imageData: Data,
        fileName: String,
        mimeType: String,
        brandID: String?,
        draftID: String?,
        usage: String?
    ) async throws -> UploadMediaResponse
    func deleteWikiBrandUploadedImages(
        brandID: String?,
        draftID: String?,
        urls: [String]
    ) async throws

    func fetchDJs(page: Int, limit: Int, search: String?, sortBy: String) async throws -> DJListPage
    func fetchRecommendedDJs(limit: Int) async throws -> [WebDJ]
    func fetchOnboardingDJCandidates(limit: Int) async throws -> [WebDJ]
    func fetchOnboardingPreferenceOptions() async throws -> OnboardingPreferenceOptions
    func fetchDJ(id: String) async throws -> WebDJ
    func fetchDJContributors(djID: String) async throws -> WebEntityContributorPage
    func searchSpotifyDJs(query: String, limit: Int) async throws -> [SpotifyDJCandidate]
    func searchDiscogsDJs(query: String, limit: Int) async throws -> [DiscogsDJCandidate]
    func fetchDiscogsDJArtist(id: Int) async throws -> DiscogsDJArtistDetail
    func importSpotifyDJ(input: ImportSpotifyDJInput) async throws -> ImportDJResult<ImportSpotifyDJResponse>
    func importDiscogsDJ(input: ImportDiscogsDJInput) async throws -> ImportDJResult<ImportDiscogsDJResponse>
    func importManualDJ(input: ImportManualDJInput) async throws -> ImportDJResult<ImportManualDJResponse>
    func updateDJ(id: String, input: UpdateDJInput) async throws -> CreateContentResult<WebDJ>
    func uploadDJImage(
        imageData: Data,
        fileName: String,
        mimeType: String,
        djID: String?,
        draftID: String?,
        usage: String
    ) async throws -> UploadMediaResponse
    func deleteDJUploadedImages(
        draftID: String?,
        urls: [String]
    ) async throws
    func fetchDJSets(djID: String) async throws -> [WebDJSet]
    func fetchDJSets(djID: String, page: Int, limit: Int) async throws -> DJSetListPage
    func fetchDJEvents(djID: String, page: Int, limit: Int, statuses: [String]?) async throws -> EventListPage
    func fetchDJFollowStatus(djID: String) async throws -> Bool
    func toggleDJFollow(djID: String, shouldFollow: Bool) async throws -> WebDJ
    func fetchFollowedDJs(page: Int, limit: Int) async throws -> DJListPage

    func fetchDJSets(page: Int, limit: Int, sortBy: String, djID: String?) async throws -> DJSetListPage
    func fetchEventDJSets(eventID: String, eventName: String) async throws -> [WebDJSet]
    func fetchDJSet(id: String) async throws -> WebDJSet
    func fetchMyDJSets() async throws -> [WebDJSet]
    func fetchMyDJSets(page: Int, limit: Int) async throws -> DJSetListPage
    func createDJSet(input: CreateDJSetInput) async throws -> CreateContentResult<WebDJSet>
    func updateDJSet(id: String, input: UpdateDJSetInput) async throws -> WebDJSet
    func deleteDJSet(id: String) async throws
    func replaceTracks(setID: String, tracks: [CreateTrackInput]) async throws -> WebDJSet
    func fetchTracklists(setID: String) async throws -> [WebTracklistSummary]
    func fetchTracklists(setID: String, page: Int, limit: Int) async throws -> TracklistSummaryPage
    func fetchTracklistDetail(setID: String, tracklistID: String) async throws -> WebTracklistDetail
    func createTracklist(setID: String, input: CreateTracklistInput) async throws -> WebTracklistDetail
    func autoLinkTracks(setID: String) async throws
    func previewVideo(videoURL: String) async throws -> [String: String]
    func uploadSetThumbnail(imageData: Data, fileName: String, mimeType: String) async throws -> UploadMediaResponse
    func uploadSetVideo(videoData: Data, fileName: String, mimeType: String) async throws -> UploadMediaResponse

    func fetchSetComments(setID: String) async throws -> [WebSetComment]
    func fetchSetComments(setID: String, page: Int, limit: Int) async throws -> SetCommentListPage
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
    func fetchRatingEvents(page: Int, limit: Int) async throws -> RatingEventListPage
    func fetchEventRatingEvents(eventID: String) async throws -> [WebRatingEvent]
    func fetchEventRatingEvents(eventID: String, page: Int, limit: Int) async throws -> RatingEventListPage
    func fetchRatingEvent(id: String) async throws -> WebRatingEvent
    func fetchDJRatingUnits(djID: String) async throws -> [WebRatingUnit]
    func fetchDJRatingUnits(djID: String, page: Int, limit: Int) async throws -> RatingUnitListPage
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
    func fetchLearnGenreTreeSummary() async throws -> [LearnGenreTreeSummaryNode]
    func fetchLearnGenreDetail(id: String) async throws -> LearnGenreDetail
    func fetchLearnFestivalPage(page: Int, limit: Int, search: String?) async throws -> LearnFestivalListPage
    func fetchLearnFestival(id: String) async throws -> WebLearnFestival
    func fetchLearnLabel(id: String) async throws -> LearnLabel
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
    func updateLearnFestival(id: String, input: UpdateLearnFestivalInput) async throws -> CreateContentResult<WebLearnFestival>
    func fetchRankingBoards() async throws -> [RankingBoard]
    func fetchRankingBoardDetail(boardID: String, year: Int?) async throws -> RankingBoardDetail
    func searchGlobal(query: String, tab: GlobalSearchTab, limit: Int) async throws -> GlobalSearchResponse

    func fetchMyPublishes() async throws -> MyPublishes
    func fetchMyContributionCenterSummary() async throws -> WebContributionCenterSummary
    func fetchMyContributionHistory(entityType: String, cursor: String?, limit: Int) async throws -> WebContributionHistoryPage
    func fetchMyContentSubmissions() async throws -> [ContentSubmissionSummary]
    func fetchMyContentSubmissions(page: Int, limit: Int) async throws -> ContentSubmissionListPage
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
            draftID: nil,
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

enum QuizSessionMode: String, Codable, Hashable {
    case standard = "standard"
    case debugSet = "debug_set"
}

enum QuizSessionAbandonReason: String, Codable, Hashable {
    case userAbandon = "user_abandon"
    case preflightFailed = "preflight_failed"
}

struct QuizConfigSummary: Decodable {
    let isEnabled: Bool
    let questionCount: Int
    let passCorrectCount: Int
    let dailyAttemptLimit: Int
    let effectiveDailyAttemptLimit: Int?
    let isUnlimitedAttempts: Bool
    let attemptMode: String
    let defaultTimeLimitSec: Int
    let dailyLimitTimeZone: String
    let allowRetakeAfterPass: Bool
    let allowRestartDuringSession: Bool
    let todayAttemptCount: Int
    let todayRemainingAttempts: Int
    let hasPermanentPass: Bool
    let passedAt: String?
    let canStart: Bool
    let activeSessionId: String?
    let disabledReason: String?
    let canUseDebugQuestionSet: Bool
    let debugQuestionSetCount: Int
    let canStartDebugQuestionSet: Bool
}

struct QuizQuestionOptionPayload: Decodable, Identifiable, Hashable {
    let optionId: String
    let text: String?
    let imageUrl: String?
    let sortOrder: Int

    var id: String { optionId }
}

struct QuizQuestionPayload: Decodable, Identifiable, Hashable {
    let questionId: String
    let stemText: String
    let stemImageUrl: String?
    let options: [QuizQuestionOptionPayload]
    let timeLimitSec: Int

    var id: String { questionId }
}

struct QuizSessionCreateResponse: Decodable {
    let mode: QuizSessionMode
    let sessionId: String
    let questionCount: Int
    let passCorrectCount: Int
    let dailyAttemptLimit: Int
    let dailyRemainingAttemptsAfterStart: Int
    let timeZone: String
    let questions: [QuizQuestionPayload]
    let reserveQuestions: [QuizQuestionPayload]
    let startedAt: String
    let expiresAt: String
}

struct QuizSubmitAnswerPayload: Encodable {
    let questionId: String
    let optionId: String?
}

struct QuizSessionSubmitResponse: Decodable {
    let mode: QuizSessionMode
    let sessionId: String
    let totalCount: Int
    let correctCount: Int
    let passCorrectCount: Int
    let passed: Bool
    let passedAt: String?
}

struct QuizSessionAbandonResponse: Decodable {
    let sessionId: String
    let status: String
}

enum PersonalitySessionMode: String, Codable, Hashable {
    case standard = "standard"
    case debugSet = "debug_set"
}

struct PersonalityResultPayload: Decodable, Hashable {
    let code: String
    let title: String
    let subtitle: String?
    let slangTagline: String?
    let genreMapping: String?
    let genreBindings: [WebGenreTagBinding]?
    let description: String
    let imageUrl: String?
    let isHidden: Bool
    let mbtiCode: String?
}

struct PersonalityStatusSummary: Decodable {
    let isEnabled: Bool
    let questionCount: Int
    let axisThreshold: Int
    let resultTypeCapacity: Int
    let hasCompleted: Bool
    let completedAt: String?
    let result: PersonalityResultPayload?
    let canStart: Bool
    let activeSessionId: String?
    let disabledReason: String?
    let canUseDebugQuestionSet: Bool
    let debugQuestionSetCount: Int
    let canStartDebugQuestionSet: Bool
}

struct PersonalityQuestionOptionPayload: Decodable, Identifiable, Hashable {
    let optionId: String
    let text: String?
    let imageUrl: String?
    let sortOrder: Int

    var id: String { optionId }
}

struct PersonalityQuestionPayload: Decodable, Identifiable, Hashable {
    let questionId: String
    let stemText: String
    let stemImageUrl: String?
    let options: [PersonalityQuestionOptionPayload]
    let isEasterEgg: Bool

    var id: String { questionId }
}

struct PersonalitySessionCreateResponse: Decodable {
    let mode: PersonalitySessionMode
    let sessionId: String
    let questionCount: Int
    let axisThreshold: Int
    let questions: [PersonalityQuestionPayload]
    let startedAt: String
}

struct PersonalityAnswerPayload: Codable {
    let questionId: String
    let optionId: String?
}

struct PersonalitySessionAnswerSaveResponse: Decodable {
    let sessionId: String
    let status: String
}

struct PersonalitySessionSubmitResponse: Decodable {
    let mode: PersonalitySessionMode
    let sessionId: String
    let questionCount: Int
    let answeredCount: Int
    let axisScores: [String: Int]
    let result: PersonalityResultPayload
}

struct PersonalitySessionAbandonResponse: Decodable {
    let sessionId: String
    let status: String
}

struct PersonalityResultEnvelope: Decodable {
    let result: PersonalityResultPayload?
}

extension WebFeatureService {
    func submitQuizSession(sessionId: String, answers: [QuizSubmitAnswerPayload]) async throws -> QuizSessionSubmitResponse {
        try await submitQuizSession(sessionId: sessionId, answers: answers, presentedQuestionIds: nil)
    }

    func abandonQuizSession(sessionId: String) async throws -> QuizSessionAbandonResponse {
        try await abandonQuizSession(sessionId: sessionId, reason: nil)
    }

    func savePersonalitySessionAnswer(
        sessionId: String,
        answers: [PersonalityAnswerPayload]
    ) async throws -> PersonalitySessionAnswerSaveResponse {
        try await savePersonalitySessionAnswer(sessionId: sessionId, answers: answers, currentQuestionIndex: nil)
    }
}
