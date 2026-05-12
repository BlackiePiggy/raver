import Foundation

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

    func fetchFollowedBrandUpdatePreference() async throws -> FollowedBrandUpdatePreference {
        try await socialService.fetchFollowedBrandUpdatePreference()
    }

    func updateFollowedBrandUpdatePreference(
        _ input: FollowedBrandUpdatePreferenceInput
    ) async throws -> FollowedBrandUpdatePreference {
        try await socialService.updateFollowedBrandUpdatePreference(input)
    }
}
