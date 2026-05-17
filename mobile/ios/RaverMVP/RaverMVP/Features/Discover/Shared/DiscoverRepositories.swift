import Foundation

protocol DJListRepository {
    func fetchDJs(page: Int, limit: Int, search: String?, sortBy: String) async throws -> DJListPage
    func fetchRecommendedDJs(limit: Int) async throws -> [WebDJ]
    func fetchOnboardingDJCandidates(limit: Int) async throws -> [WebDJ]
}

protocol DJReadRepository {
    func fetchDJ(id: String) async throws -> WebDJ
}

protocol DJLinkedContentRepository {
    func fetchDJSets(djID: String) async throws -> [WebDJSet]
    func fetchDJEvents(djID: String) async throws -> [WebEvent]
    func fetchDJRatingUnits(djID: String) async throws -> [WebRatingUnit]
    func fetchMyDJCheckinCount(djID: String) async throws -> Int
}

protocol DJRelationRepository {
    func toggleDJFollow(djID: String, shouldFollow: Bool) async throws -> WebDJ
}

protocol DJCommandRepository {
    func updateDJ(id: String, input: UpdateDJInput) async throws -> WebDJ
}

protocol DJRankingRepository {
    func fetchRankingBoards() async throws -> [RankingBoard]
    func fetchRankingBoardDetail(boardID: String, year: Int?) async throws -> RankingBoardDetail
}

protocol DJImportRepository {
    func searchSpotifyDJs(query: String, limit: Int) async throws -> [SpotifyDJCandidate]
    func searchDiscogsDJs(query: String, limit: Int) async throws -> [DiscogsDJCandidate]
    func fetchDiscogsDJArtist(id: Int) async throws -> DiscogsDJArtistDetail
    func importSpotifyDJ(input: ImportSpotifyDJInput) async throws -> ImportDJResult<ImportSpotifyDJResponse>
    func importDiscogsDJ(input: ImportDiscogsDJInput) async throws -> ImportDJResult<ImportDiscogsDJResponse>
    func importManualDJ(input: ImportManualDJInput) async throws -> ImportDJResult<ImportManualDJResponse>
}

protocol DJMediaRepository {
    func uploadDJImage(
        imageData: Data,
        fileName: String,
        mimeType: String,
        djID: String,
        usage: String
    ) async throws -> UploadMediaResponse
}

struct DJListRepositoryAdapter: DJListRepository {
    private let service: WebFeatureService

    init(service: WebFeatureService) {
        self.service = service
    }

    func fetchDJs(page: Int, limit: Int, search: String?, sortBy: String) async throws -> DJListPage {
        try await service.fetchDJs(page: page, limit: limit, search: search, sortBy: sortBy)
    }

    func fetchRecommendedDJs(limit: Int) async throws -> [WebDJ] {
        try await service.fetchRecommendedDJs(limit: limit)
    }

    func fetchOnboardingDJCandidates(limit: Int) async throws -> [WebDJ] {
        try await service.fetchOnboardingDJCandidates(limit: limit)
    }
}

struct DJReadRepositoryAdapter: DJReadRepository {
    private let service: WebFeatureService

    init(service: WebFeatureService) {
        self.service = service
    }

    func fetchDJ(id: String) async throws -> WebDJ {
        try await service.fetchDJ(id: id)
    }
}

struct DJLinkedContentRepositoryAdapter: DJLinkedContentRepository {
    private let service: WebFeatureService

    init(service: WebFeatureService) {
        self.service = service
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
}

struct DJRelationRepositoryAdapter: DJRelationRepository {
    private let service: WebFeatureService

    init(service: WebFeatureService) {
        self.service = service
    }

    func toggleDJFollow(djID: String, shouldFollow: Bool) async throws -> WebDJ {
        try await service.toggleDJFollow(djID: djID, shouldFollow: shouldFollow)
    }
}

struct DJCommandRepositoryAdapter: DJCommandRepository {
    private let service: WebFeatureService

    init(service: WebFeatureService) {
        self.service = service
    }

    func updateDJ(id: String, input: UpdateDJInput) async throws -> WebDJ {
        try await service.updateDJ(id: id, input: input)
    }
}

struct DJRankingRepositoryAdapter: DJRankingRepository {
    private let service: WebFeatureService

    init(service: WebFeatureService) {
        self.service = service
    }

    func fetchRankingBoards() async throws -> [RankingBoard] {
        try await service.fetchRankingBoards()
    }

    func fetchRankingBoardDetail(boardID: String, year: Int?) async throws -> RankingBoardDetail {
        try await service.fetchRankingBoardDetail(boardID: boardID, year: year)
    }
}

struct DJImportRepositoryAdapter: DJImportRepository {
    private let service: WebFeatureService

    init(service: WebFeatureService) {
        self.service = service
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

    func importSpotifyDJ(input: ImportSpotifyDJInput) async throws -> ImportDJResult<ImportSpotifyDJResponse> {
        try await service.importSpotifyDJ(input: input)
    }

    func importDiscogsDJ(input: ImportDiscogsDJInput) async throws -> ImportDJResult<ImportDiscogsDJResponse> {
        try await service.importDiscogsDJ(input: input)
    }

    func importManualDJ(input: ImportManualDJInput) async throws -> ImportDJResult<ImportManualDJResponse> {
        try await service.importManualDJ(input: input)
    }
}

struct DJMediaRepositoryAdapter: DJMediaRepository {
    private let service: WebFeatureService

    init(service: WebFeatureService) {
        self.service = service
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

protocol SetListRepository {
    func fetchDJSets(page: Int, limit: Int, sortBy: String, djID: String?) async throws -> DJSetListPage
}

protocol SetReadRepository {
    func fetchDJSet(id: String) async throws -> WebDJSet
}

protocol SetCommentRepository {
    func fetchSetComments(setID: String) async throws -> [WebSetComment]
    func addSetComment(setID: String, input: CreateSetCommentInput) async throws -> WebSetComment
}

protocol SetCommandRepository {
    func deleteDJSet(id: String) async throws
    func createDJSet(input: CreateDJSetInput) async throws -> CreateContentResult<WebDJSet>
    func updateDJSet(id: String, input: UpdateDJSetInput) async throws -> WebDJSet
}

protocol TracklistRepository {
    func fetchTracklists(setID: String) async throws -> [WebTracklistSummary]
    func fetchTracklistDetail(setID: String, tracklistID: String) async throws -> WebTracklistDetail
    func createTracklist(setID: String, input: CreateTracklistInput) async throws -> WebTracklistDetail
    func replaceTracks(setID: String, tracks: [CreateTrackInput]) async throws -> WebDJSet
    func autoLinkTracks(setID: String) async throws
}

protocol SetEventLookupRepository {
    func fetchEvents(page: Int, limit: Int, search: String?, eventType: String?, status: String?) async throws -> EventListPage
}

protocol SetMediaRepository {
    func previewVideo(videoURL: String) async throws -> [String: String]
    func uploadSetThumbnail(imageData: Data, fileName: String, mimeType: String) async throws -> UploadMediaResponse
    func uploadSetVideo(videoData: Data, fileName: String, mimeType: String) async throws -> UploadMediaResponse
}

struct SetListRepositoryAdapter: SetListRepository {
    private let service: WebFeatureService

    init(service: WebFeatureService) {
        self.service = service
    }

    func fetchDJSets(page: Int, limit: Int, sortBy: String, djID: String?) async throws -> DJSetListPage {
        try await service.fetchDJSets(page: page, limit: limit, sortBy: sortBy, djID: djID)
    }
}

struct SetReadRepositoryAdapter: SetReadRepository {
    private let service: WebFeatureService

    init(service: WebFeatureService) {
        self.service = service
    }

    func fetchDJSet(id: String) async throws -> WebDJSet {
        try await service.fetchDJSet(id: id)
    }
}

struct SetCommentRepositoryAdapter: SetCommentRepository {
    private let service: WebFeatureService

    init(service: WebFeatureService) {
        self.service = service
    }

    func fetchSetComments(setID: String) async throws -> [WebSetComment] {
        try await service.fetchSetComments(setID: setID)
    }

    func addSetComment(setID: String, input: CreateSetCommentInput) async throws -> WebSetComment {
        try await service.addSetComment(setID: setID, input: input)
    }
}

struct SetCommandRepositoryAdapter: SetCommandRepository {
    private let service: WebFeatureService

    init(service: WebFeatureService) {
        self.service = service
    }

    func deleteDJSet(id: String) async throws {
        try await service.deleteDJSet(id: id)
    }

    func createDJSet(input: CreateDJSetInput) async throws -> CreateContentResult<WebDJSet> {
        try await service.createDJSet(input: input)
    }

    func updateDJSet(id: String, input: UpdateDJSetInput) async throws -> WebDJSet {
        try await service.updateDJSet(id: id, input: input)
    }
}

struct TracklistRepositoryAdapter: TracklistRepository {
    private let service: WebFeatureService

    init(service: WebFeatureService) {
        self.service = service
    }

    func fetchTracklists(setID: String) async throws -> [WebTracklistSummary] {
        try await service.fetchTracklists(setID: setID)
    }

    func fetchTracklistDetail(setID: String, tracklistID: String) async throws -> WebTracklistDetail {
        try await service.fetchTracklistDetail(setID: setID, tracklistID: tracklistID)
    }

    func createTracklist(setID: String, input: CreateTracklistInput) async throws -> WebTracklistDetail {
        try await service.createTracklist(setID: setID, input: input)
    }

    func replaceTracks(setID: String, tracks: [CreateTrackInput]) async throws -> WebDJSet {
        try await service.replaceTracks(setID: setID, tracks: tracks)
    }

    func autoLinkTracks(setID: String) async throws {
        try await service.autoLinkTracks(setID: setID)
    }
}

struct SetEventLookupRepositoryAdapter: SetEventLookupRepository {
    private let service: WebFeatureService

    init(service: WebFeatureService) {
        self.service = service
    }

    func fetchEvents(page: Int, limit: Int, search: String?, eventType: String?, status: String?) async throws -> EventListPage {
        try await service.fetchEvents(page: page, limit: limit, search: search, eventType: eventType, status: status)
    }
}

struct SetMediaRepositoryAdapter: SetMediaRepository {
    private let service: WebFeatureService

    init(service: WebFeatureService) {
        self.service = service
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
    func createLearnLabel(input: CreateLearnLabelInput) async throws -> CreateContentResult<LearnLabel>
    func fetchLearnFestivals(search: String?) async throws -> [WebLearnFestival]
    func createLearnFestival(input: CreateLearnFestivalInput) async throws -> CreateContentResult<WebLearnFestival>
    func updateLearnFestival(id: String, input: UpdateLearnFestivalInput) async throws -> WebLearnFestival
    func uploadWikiBrandImage(
        imageData: Data,
        fileName: String,
        mimeType: String,
        brandID: String?,
        usage: String?
    ) async throws -> UploadMediaResponse
    func fetchFollowedBrandUpdatePreference() async throws -> FollowedBrandUpdatePreference
    func updateFollowedBrandUpdatePreference(
        _ input: FollowedBrandUpdatePreferenceInput
    ) async throws -> FollowedBrandUpdatePreference
}

struct DiscoverWikiRepositoryAdapter: DiscoverWikiRepository {
    private let service: WebFeatureService
    private let socialService: SocialService

    init(service: WebFeatureService, socialService: SocialService) {
        self.service = service
        self.socialService = socialService
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

    func createLearnLabel(input: CreateLearnLabelInput) async throws -> CreateContentResult<LearnLabel> {
        try await service.createLearnLabel(input: input)
    }

    func createLearnFestival(input: CreateLearnFestivalInput) async throws -> CreateContentResult<WebLearnFestival> {
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

    func fetchFollowedBrandUpdatePreference() async throws -> FollowedBrandUpdatePreference {
        try await socialService.fetchFollowedBrandUpdatePreference()
    }

    func updateFollowedBrandUpdatePreference(
        _ input: FollowedBrandUpdatePreferenceInput
    ) async throws -> FollowedBrandUpdatePreference {
        try await socialService.updateFollowedBrandUpdatePreference(input)
    }
}
