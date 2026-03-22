import Foundation

protocol WebFeatureService {
    func fetchEvents(page: Int, limit: Int, search: String?, eventType: String?, status: String?) async throws -> EventListPage
    func fetchEvent(id: String) async throws -> WebEvent
    func fetchMyEvents() async throws -> [WebEvent]
    func createEvent(input: CreateEventInput) async throws -> WebEvent
    func updateEvent(id: String, input: UpdateEventInput) async throws -> WebEvent
    func deleteEvent(id: String) async throws
    func uploadEventImage(imageData: Data, fileName: String, mimeType: String) async throws -> UploadMediaResponse

    func fetchDJs(page: Int, limit: Int, search: String?, sortBy: String) async throws -> DJListPage
    func fetchDJ(id: String) async throws -> WebDJ
    func fetchDJSets(djID: String) async throws -> [WebDJSet]
    func fetchDJEvents(djID: String) async throws -> [WebEvent]
    func fetchDJFollowStatus(djID: String) async throws -> Bool
    func toggleDJFollow(djID: String, shouldFollow: Bool) async throws -> WebDJ

    func fetchDJSets(page: Int, limit: Int, sortBy: String, djID: String?) async throws -> DJSetListPage
    func fetchDJSet(id: String) async throws -> WebDJSet
    func fetchMyDJSets() async throws -> [WebDJSet]
    func createDJSet(input: CreateDJSetInput) async throws -> WebDJSet
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
    func fetchUserCheckins(userID: String, page: Int, limit: Int, type: String?) async throws -> CheckinListPage
    func fetchMyDJCheckinCount(djID: String) async throws -> Int
    func createCheckin(input: CreateCheckinInput) async throws -> WebCheckin
    func deleteCheckin(id: String) async throws

    func fetchRatingEvents() async throws -> [WebRatingEvent]
    func fetchRatingEvent(id: String) async throws -> WebRatingEvent
    func createRatingEvent(input: CreateRatingEventInput) async throws -> WebRatingEvent
    func updateRatingEvent(id: String, input: UpdateRatingEventInput) async throws -> WebRatingEvent
    func deleteRatingEvent(id: String) async throws
    func createRatingUnit(eventID: String, input: CreateRatingUnitInput) async throws -> WebRatingUnit
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
    func fetchRankingBoards() async throws -> [RankingBoard]
    func fetchRankingBoardDetail(boardID: String, year: Int?) async throws -> RankingBoardDetail

    func fetchMyPublishes() async throws -> MyPublishes
}
