import Foundation

final class LiveWebFeatureService: WebFeatureService {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func fetchEvents(page: Int, limit: Int, search: String?, eventType: String?, status: String?) async throws -> EventListPage {
        var queryItems = [
            URLQueryItem(name: "page", value: "\(max(1, page))"),
            URLQueryItem(name: "limit", value: "\(max(1, min(100, limit)))")
        ]
        if let search, !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            queryItems.append(URLQueryItem(name: "search", value: search))
        }
        if let eventType, !eventType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            queryItems.append(URLQueryItem(name: "eventType", value: eventType))
        }
        if let status, !status.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            queryItems.append(URLQueryItem(name: "status", value: status))
        }
        let response: BFFEnvelope<BFFItems<WebEvent>> = try await request(path: "/v1/events", method: "GET", queryItems: queryItems)
        return EventListPage(items: response.data.items.map(localizedEvent), pagination: response.pagination)
    }

    func fetchEvent(id: String) async throws -> WebEvent {
        let response: BFFEnvelope<WebEvent> = try await request(path: "/v1/events/\(id)", method: "GET")
        return localizedEvent(response.data)
    }

    func fetchMyEvents() async throws -> [WebEvent] {
        let response: BFFEnvelope<BFFItems<WebEvent>> = try await request(path: "/v1/events/my", method: "GET")
        return response.data.items.map(localizedEvent)
    }

    func createEvent(input: CreateEventInput) async throws -> WebEvent {
        let response: BFFEnvelope<WebEvent> = try await request(path: "/v1/events", method: "POST", body: input)
        return localizedEvent(response.data)
    }

    func updateEvent(id: String, input: UpdateEventInput) async throws -> WebEvent {
        let response: BFFEnvelope<WebEvent> = try await request(path: "/v1/events/\(id)", method: "PATCH", body: input)
        return localizedEvent(response.data)
    }

    func deleteEvent(id: String) async throws {
        let _: BFFEnvelope<GenericSuccess> = try await request(path: "/v1/events/\(id)", method: "DELETE")
    }

    func uploadEventImage(
        imageData: Data,
        fileName: String,
        mimeType: String,
        eventID: String?,
        usage: String?
    ) async throws -> UploadMediaResponse {
        var fields: [String: String] = [:]
        if let eventID, !eventID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fields["eventId"] = eventID
        }
        if let usage, !usage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fields["usage"] = usage
        }
        let response: BFFEnvelope<UploadMediaResponse> = try await uploadMultipart(
            path: "/v1/events/upload-image",
            data: imageData,
            fileName: fileName,
            mimeType: mimeType,
            fieldName: "image",
            fields: fields
        )
        return response.data
    }

    func uploadRatingImage(
        imageData: Data,
        fileName: String,
        mimeType: String,
        ratingEventID: String?,
        ratingUnitID: String?,
        usage: String?
    ) async throws -> UploadMediaResponse {
        var fields: [String: String] = [:]
        if let ratingEventID, !ratingEventID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fields["ratingEventId"] = ratingEventID
        }
        if let ratingUnitID, !ratingUnitID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fields["ratingUnitId"] = ratingUnitID
        }
        if let usage, !usage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fields["usage"] = usage
        }
        let response: BFFEnvelope<UploadMediaResponse> = try await uploadMultipart(
            path: "/v1/rating/upload-image",
            data: imageData,
            fileName: fileName,
            mimeType: mimeType,
            fieldName: "image",
            fields: fields
        )
        return response.data
    }

    func importEventLineupFromImage(
        imageData: Data,
        fileName: String,
        mimeType: String,
        startDate: Date?,
        endDate: Date?
    ) async throws -> EventLineupImageImportResponse {
        var fields: [String: String] = [:]
        if let startDate {
            fields["startDate"] = ISO8601DateFormatter().string(from: startDate)
        }
        if let endDate {
            fields["endDate"] = ISO8601DateFormatter().string(from: endDate)
        }
        let response: BFFEnvelope<EventLineupImageImportResponse> = try await uploadMultipart(
            path: "/v1/events/lineup/import-image",
            data: imageData,
            fileName: fileName,
            mimeType: mimeType,
            fieldName: "image",
            fields: fields,
            timeoutInterval: 120
        )
        return response.data
    }

    func uploadPostImage(imageData: Data, fileName: String, mimeType: String) async throws -> UploadMediaResponse {
        let response: BFFEnvelope<UploadMediaResponse> = try await uploadMultipart(
            path: "/v1/feed/upload-image",
            data: imageData,
            fileName: fileName,
            mimeType: mimeType,
            fieldName: "image"
        )
        return response.data
    }

    func uploadPostVideo(videoData: Data, fileName: String, mimeType: String) async throws -> UploadMediaResponse {
        let response: BFFEnvelope<UploadMediaResponse> = try await uploadMultipart(
            path: "/v1/feed/upload-video",
            data: videoData,
            fileName: fileName,
            mimeType: mimeType,
            fieldName: "video"
        )
        return response.data
    }

    func uploadWikiBrandImage(
        imageData: Data,
        fileName: String,
        mimeType: String,
        brandID: String?,
        usage: String?
    ) async throws -> UploadMediaResponse {
        var fields: [String: String] = [:]
        if let brandID, !brandID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fields["brandId"] = brandID
        }
        if let usage, !usage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fields["usage"] = usage
        }
        let response: BFFEnvelope<UploadMediaResponse> = try await uploadMultipart(
            path: "/v1/wiki/brands/upload-image",
            data: imageData,
            fileName: fileName,
            mimeType: mimeType,
            fieldName: "image",
            fields: fields
        )
        return response.data
    }

    func fetchDJs(page: Int, limit: Int, search: String?, sortBy: String) async throws -> DJListPage {
        var queryItems = [
            URLQueryItem(name: "page", value: "\(max(1, page))"),
            URLQueryItem(name: "limit", value: "\(max(1, min(100, limit)))"),
            URLQueryItem(name: "sortBy", value: sortBy)
        ]
        if let search, !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            queryItems.append(URLQueryItem(name: "search", value: search))
        }
        let response: BFFEnvelope<BFFItems<WebDJ>> = try await request(path: "/v1/djs", method: "GET", queryItems: queryItems)
        return DJListPage(items: response.data.items.map(localizedDJ), pagination: response.pagination)
    }

    func fetchDJ(id: String) async throws -> WebDJ {
        let response: BFFEnvelope<WebDJ> = try await request(path: "/v1/djs/\(id)", method: "GET")
        return localizedDJ(response.data)
    }

    func searchSpotifyDJs(query: String, limit: Int) async throws -> [SpotifyDJCandidate] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let response: BFFEnvelope<BFFItems<SpotifyDJCandidate>> = try await request(
            path: "/v1/djs/spotify/search",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "q", value: trimmed),
                URLQueryItem(name: "limit", value: "\(max(1, min(20, limit)))")
            ]
        )
        return response.data.items
    }

    func searchDiscogsDJs(query: String, limit: Int) async throws -> [DiscogsDJCandidate] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let response: BFFEnvelope<BFFItems<DiscogsDJCandidate>> = try await request(
            path: "/v1/djs/discogs/search",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "q", value: trimmed),
                URLQueryItem(name: "limit", value: "\(max(1, min(20, limit)))")
            ]
        )
        return response.data.items
    }

    func fetchDiscogsDJArtist(id: Int) async throws -> DiscogsDJArtistDetail {
        let response: BFFEnvelope<DiscogsDJArtistDetail> = try await request(
            path: "/v1/djs/discogs/artists/\(id)",
            method: "GET"
        )
        return response.data
    }

    func importSpotifyDJ(input: ImportSpotifyDJInput) async throws -> ImportSpotifyDJResponse {
        let response: BFFEnvelope<ImportSpotifyDJResponse> = try await request(
            path: "/v1/djs/spotify/import",
            method: "POST",
            body: input
        )
        var payload = response.data
        payload.dj = localizedDJ(payload.dj)
        return payload
    }

    func importDiscogsDJ(input: ImportDiscogsDJInput) async throws -> ImportDiscogsDJResponse {
        let response: BFFEnvelope<ImportDiscogsDJResponse> = try await request(
            path: "/v1/djs/discogs/import",
            method: "POST",
            body: input
        )
        var payload = response.data
        payload.dj = localizedDJ(payload.dj)
        return payload
    }

    func importManualDJ(input: ImportManualDJInput) async throws -> ImportManualDJResponse {
        let response: BFFEnvelope<ImportManualDJResponse> = try await request(
            path: "/v1/djs/manual/import",
            method: "POST",
            body: input
        )
        var payload = response.data
        payload.dj = localizedDJ(payload.dj)
        return payload
    }

    func updateDJ(id: String, input: UpdateDJInput) async throws -> WebDJ {
        let response: BFFEnvelope<WebDJ> = try await request(
            path: "/v1/djs/\(id)",
            method: "PATCH",
            body: input
        )
        return localizedDJ(response.data)
    }

    func uploadDJImage(
        imageData: Data,
        fileName: String,
        mimeType: String,
        djID: String,
        usage: String
    ) async throws -> UploadMediaResponse {
        let response: BFFEnvelope<UploadMediaResponse> = try await uploadMultipart(
            path: "/v1/djs/upload-image",
            data: imageData,
            fileName: fileName,
            mimeType: mimeType,
            fieldName: "image",
            fields: [
                "djId": djID,
                "usage": usage
            ]
        )
        return response.data
    }

    func fetchDJSets(djID: String) async throws -> [WebDJSet] {
        let response: BFFEnvelope<BFFItems<WebDJSet>> = try await request(path: "/v1/djs/\(djID)/sets", method: "GET")
        return response.data.items.map(localizedDJSet)
    }

    func fetchDJEvents(djID: String) async throws -> [WebEvent] {
        let response: BFFEnvelope<BFFItems<WebEvent>> = try await request(path: "/v1/djs/\(djID)/events", method: "GET")
        return response.data.items.map(localizedEvent)
    }

    func fetchDJFollowStatus(djID: String) async throws -> Bool {
        let response: BFFEnvelope<DJFollowStatusPayload> = try await request(path: "/v1/djs/\(djID)/follow-status", method: "GET")
        return response.data.isFollowing
    }

    func toggleDJFollow(djID: String, shouldFollow: Bool) async throws -> WebDJ {
        let response: BFFEnvelope<WebDJ> = try await request(
            path: "/v1/djs/\(djID)/follow",
            method: shouldFollow ? "POST" : "DELETE"
        )
        return localizedDJ(response.data)
    }

    func fetchDJSets(page: Int, limit: Int, sortBy: String, djID: String?) async throws -> DJSetListPage {
        var queryItems = [
            URLQueryItem(name: "page", value: "\(max(1, page))"),
            URLQueryItem(name: "limit", value: "\(max(1, min(100, limit)))"),
            URLQueryItem(name: "sortBy", value: sortBy)
        ]
        if let djID, !djID.isEmpty {
            queryItems.append(URLQueryItem(name: "djId", value: djID))
        }
        let response: BFFEnvelope<BFFItems<WebDJSet>> = try await request(path: "/v1/dj-sets", method: "GET", queryItems: queryItems)
        return DJSetListPage(items: response.data.items.map(localizedDJSet), pagination: response.pagination)
    }

    func fetchEventDJSets(eventName: String) async throws -> [WebDJSet] {
        let normalized = eventName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return [] }
        let queryItems = [
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "limit", value: "200"),
            URLQueryItem(name: "sortBy", value: "latest"),
            URLQueryItem(name: "eventName", value: normalized),
        ]
        let response: BFFEnvelope<BFFItems<WebDJSet>> = try await request(path: "/v1/dj-sets", method: "GET", queryItems: queryItems)
        return response.data.items.map(localizedDJSet)
    }

    func fetchDJSet(id: String) async throws -> WebDJSet {
        let response: BFFEnvelope<WebDJSet> = try await request(path: "/v1/dj-sets/\(id)", method: "GET")
        return localizedDJSet(response.data)
    }

    func fetchMyDJSets() async throws -> [WebDJSet] {
        let response: BFFEnvelope<BFFItems<WebDJSet>> = try await request(path: "/v1/dj-sets/mine", method: "GET")
        return response.data.items.map(localizedDJSet)
    }

    func createDJSet(input: CreateDJSetInput) async throws -> WebDJSet {
        let response: BFFEnvelope<WebDJSet> = try await request(path: "/v1/dj-sets", method: "POST", body: input)
        return localizedDJSet(response.data)
    }

    func updateDJSet(id: String, input: UpdateDJSetInput) async throws -> WebDJSet {
        let response: BFFEnvelope<WebDJSet> = try await request(path: "/v1/dj-sets/\(id)", method: "PATCH", body: input)
        return localizedDJSet(response.data)
    }

    func deleteDJSet(id: String) async throws {
        let _: BFFEnvelope<GenericSuccess> = try await request(path: "/v1/dj-sets/\(id)", method: "DELETE")
    }

    func replaceTracks(setID: String, tracks: [CreateTrackInput]) async throws -> WebDJSet {
        let response: BFFEnvelope<WebDJSet> = try await request(
            path: "/v1/dj-sets/\(setID)/tracks",
            method: "PUT",
            body: ReplaceTracksInput(tracks: tracks)
        )
        return localizedDJSet(response.data)
    }

    func fetchTracklists(setID: String) async throws -> [WebTracklistSummary] {
        let response: BFFEnvelope<BFFItems<WebTracklistSummary>> = try await request(
            path: "/v1/dj-sets/\(setID)/tracklists",
            method: "GET"
        )
        return response.data.items
    }

    func fetchTracklistDetail(setID: String, tracklistID: String) async throws -> WebTracklistDetail {
        let response: BFFEnvelope<WebTracklistDetail> = try await request(
            path: "/v1/dj-sets/\(setID)/tracklists/\(tracklistID)",
            method: "GET"
        )
        return response.data
    }

    func createTracklist(setID: String, input: CreateTracklistInput) async throws -> WebTracklistDetail {
        let response: BFFEnvelope<WebTracklistDetail> = try await request(
            path: "/v1/dj-sets/\(setID)/tracklists",
            method: "POST",
            body: input
        )
        return response.data
    }

    func autoLinkTracks(setID: String) async throws {
        let _: BFFEnvelope<GenericSuccess> = try await request(path: "/v1/dj-sets/\(setID)/auto-link", method: "POST")
    }

    func previewVideo(videoURL: String) async throws -> [String : String] {
        let response: BFFEnvelope<VideoPreviewPayload> = try await request(
            path: "/v1/dj-sets/preview",
            method: "GET",
            queryItems: [URLQueryItem(name: "videoUrl", value: videoURL)]
        )
        return [
            "platform": response.data.platform,
            "videoId": response.data.videoId,
            "title": response.data.title,
            "description": response.data.description,
            "thumbnailUrl": response.data.thumbnailUrl
        ]
    }

    func uploadSetThumbnail(imageData: Data, fileName: String, mimeType: String) async throws -> UploadMediaResponse {
        let response: BFFEnvelope<UploadMediaResponse> = try await uploadMultipart(
            path: "/v1/dj-sets/upload-thumbnail",
            data: imageData,
            fileName: fileName,
            mimeType: mimeType,
            fieldName: "image"
        )
        return response.data
    }

    func uploadSetVideo(videoData: Data, fileName: String, mimeType: String) async throws -> UploadMediaResponse {
        let response: BFFEnvelope<UploadMediaResponse> = try await uploadMultipart(
            path: "/v1/dj-sets/upload-video",
            data: videoData,
            fileName: fileName,
            mimeType: mimeType,
            fieldName: "video"
        )
        return response.data
    }

    func fetchSetComments(setID: String) async throws -> [WebSetComment] {
        let response: BFFEnvelope<BFFItems<WebSetComment>> = try await request(path: "/v1/dj-sets/\(setID)/comments", method: "GET")
        return response.data.items
    }

    func addSetComment(setID: String, input: CreateSetCommentInput) async throws -> WebSetComment {
        let response: BFFEnvelope<WebSetComment> = try await request(path: "/v1/dj-sets/\(setID)/comments", method: "POST", body: input)
        return response.data
    }

    func updateSetComment(commentID: String, content: String) async throws -> WebSetComment {
        let response: BFFEnvelope<WebSetComment> = try await request(path: "/v1/comments/\(commentID)", method: "PATCH", body: ["content": content])
        return response.data
    }

    func deleteSetComment(commentID: String) async throws {
        let _: BFFEnvelope<GenericSuccess> = try await request(path: "/v1/comments/\(commentID)", method: "DELETE")
    }

    func fetchMyCheckins(page: Int, limit: Int, type: String?) async throws -> CheckinListPage {
        try await fetchMyCheckins(page: page, limit: limit, type: type, eventID: nil, djID: nil)
    }

    func fetchMyCheckins(page: Int, limit: Int, type: String?, eventID: String?, djID: String?) async throws -> CheckinListPage {
        try await fetchCheckins(
            page: page,
            limit: limit,
            type: type,
            userID: nil,
            eventID: eventID,
            djID: djID
        )
    }

    func fetchUserCheckins(userID: String, page: Int, limit: Int, type: String?) async throws -> CheckinListPage {
        try await fetchUserCheckins(userID: userID, page: page, limit: limit, type: type, eventID: nil, djID: nil)
    }

    func fetchUserCheckins(userID: String, page: Int, limit: Int, type: String?, eventID: String?, djID: String?) async throws -> CheckinListPage {
        try await fetchCheckins(
            page: page,
            limit: limit,
            type: type,
            userID: userID,
            eventID: eventID,
            djID: djID
        )
    }

    func fetchMyDJCheckinCount(djID: String) async throws -> Int {
        let page = try await fetchCheckins(
            page: 1,
            limit: 1,
            type: "dj",
            userID: nil,
            eventID: nil,
            djID: djID
        )
        return page.pagination?.total ?? page.items.count
    }

    private func fetchCheckins(
        page: Int,
        limit: Int,
        type: String?,
        userID: String?,
        eventID: String?,
        djID: String?
    ) async throws -> CheckinListPage {
        var queryItems = [
            URLQueryItem(name: "page", value: "\(max(1, page))"),
            URLQueryItem(name: "limit", value: "\(max(1, min(100, limit)))")
        ]
        if let type, !type.isEmpty {
            queryItems.append(URLQueryItem(name: "type", value: type))
        }
        if let userID, !userID.isEmpty {
            queryItems.append(URLQueryItem(name: "userId", value: userID))
        }
        if let eventID, !eventID.isEmpty {
            queryItems.append(URLQueryItem(name: "eventId", value: eventID))
        }
        if let djID, !djID.isEmpty {
            queryItems.append(URLQueryItem(name: "djId", value: djID))
        }
        let response: BFFEnvelope<BFFItems<WebCheckin>> = try await request(path: "/v1/checkins", method: "GET", queryItems: queryItems)
        let localizedItems = response.data.items.map(localizedCheckin)
        return CheckinListPage(items: localizedItems, pagination: response.pagination)
    }

    func createCheckin(input: CreateCheckinInput) async throws -> WebCheckin {
        let response: BFFEnvelope<WebCheckin> = try await request(path: "/v1/checkins", method: "POST", body: input)
        return localizedCheckin(response.data)
    }

    func updateCheckin(id: String, input: UpdateCheckinInput) async throws -> WebCheckin {
        let response: BFFEnvelope<WebCheckin> = try await request(path: "/v1/checkins/\(id)", method: "PATCH", body: input)
        return localizedCheckin(response.data)
    }

    func deleteCheckin(id: String) async throws {
        let _: BFFEnvelope<GenericSuccess> = try await request(path: "/v1/checkins/\(id)", method: "DELETE")
    }

    func fetchRatingEvents() async throws -> [WebRatingEvent] {
        let response: BFFEnvelope<BFFItems<WebRatingEvent>> = try await request(path: "/v1/rating-events", method: "GET")
        return response.data.items
    }

    func fetchEventRatingEvents(eventID: String) async throws -> [WebRatingEvent] {
        let response: BFFEnvelope<BFFItems<WebRatingEvent>> = try await request(
            path: "/v1/events/\(eventID)/rating-events",
            method: "GET"
        )
        return response.data.items
    }

    func fetchRatingEvent(id: String) async throws -> WebRatingEvent {
        let response: BFFEnvelope<WebRatingEvent> = try await request(path: "/v1/rating-events/\(id)", method: "GET")
        return response.data
    }

    func fetchDJRatingUnits(djID: String) async throws -> [WebRatingUnit] {
        let response: BFFEnvelope<BFFItems<WebRatingUnit>> = try await request(
            path: "/v1/djs/\(djID)/rating-units",
            method: "GET"
        )
        return response.data.items
    }

    func createRatingEvent(input: CreateRatingEventInput) async throws -> WebRatingEvent {
        let response: BFFEnvelope<WebRatingEvent> = try await request(path: "/v1/rating-events", method: "POST", body: input)
        return response.data
    }

    func createRatingEventFromEvent(eventID: String) async throws -> WebRatingEvent {
        let payload = ["eventId": eventID]
        let response: BFFEnvelope<WebRatingEvent> = try await request(
            path: "/v1/rating-events/from-event",
            method: "POST",
            body: payload
        )
        return response.data
    }

    func updateRatingEvent(id: String, input: UpdateRatingEventInput) async throws -> WebRatingEvent {
        let response: BFFEnvelope<WebRatingEvent> = try await request(path: "/v1/rating-events/\(id)", method: "PATCH", body: input)
        return response.data
    }

    func deleteRatingEvent(id: String) async throws {
        let _: BFFEnvelope<GenericSuccess> = try await request(path: "/v1/rating-events/\(id)", method: "DELETE")
    }

    func createRatingUnit(eventID: String, input: CreateRatingUnitInput) async throws -> WebRatingUnit {
        let response: BFFEnvelope<WebRatingUnit> = try await request(path: "/v1/rating-events/\(eventID)/units", method: "POST", body: input)
        return response.data
    }

    func updateRatingUnit(id: String, input: UpdateRatingUnitInput) async throws -> WebRatingUnit {
        let response: BFFEnvelope<WebRatingUnit> = try await request(path: "/v1/rating-units/\(id)", method: "PATCH", body: input)
        return response.data
    }

    func deleteRatingUnit(id: String) async throws {
        let _: BFFEnvelope<GenericSuccess> = try await request(path: "/v1/rating-units/\(id)", method: "DELETE")
    }

    func fetchRatingUnit(id: String) async throws -> WebRatingUnit {
        let response: BFFEnvelope<WebRatingUnit> = try await request(path: "/v1/rating-units/\(id)", method: "GET")
        return response.data
    }

    func addRatingComment(unitID: String, input: CreateRatingCommentInput) async throws -> WebRatingComment {
        let response: BFFEnvelope<WebRatingComment> = try await request(path: "/v1/rating-units/\(unitID)/comments", method: "POST", body: input)
        return response.data
    }

    func fetchLearnGenres() async throws -> [LearnGenreNode] {
        let response: BFFEnvelope<[LearnGenreNode]> = try await request(path: "/v1/learn/genres", method: "GET")
        return response.data
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
        var queryItems = [
            URLQueryItem(name: "page", value: "\(max(1, page))"),
            URLQueryItem(name: "limit", value: "\(max(1, min(500, limit)))"),
            URLQueryItem(name: "sortBy", value: sortBy),
            URLQueryItem(name: "order", value: order)
        ]
        if let search, !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            queryItems.append(URLQueryItem(name: "search", value: search))
        }
        if let nation, !nation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            queryItems.append(URLQueryItem(name: "nation", value: nation))
        }
        if let genre, !genre.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            queryItems.append(URLQueryItem(name: "genre", value: genre))
        }

        let response: BFFEnvelope<BFFItems<LearnLabel>> = try await request(
            path: "/v1/learn/labels",
            method: "GET",
            queryItems: queryItems
        )
        return LearnLabelListPage(items: response.data.items, pagination: response.pagination)
    }

    func fetchLearnFestivals(search: String?) async throws -> [WebLearnFestival] {
        var queryItems: [URLQueryItem] = []
        if let search, !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            queryItems.append(URLQueryItem(name: "search", value: search))
        }
        let response: BFFEnvelope<BFFItems<WebLearnFestival>> = try await request(
            path: "/v1/learn/festivals",
            method: "GET",
            queryItems: queryItems
        )
        return response.data.items.map(localizedLearnFestival)
    }

    func createLearnFestival(input: CreateLearnFestivalInput) async throws -> WebLearnFestival {
        let response: BFFEnvelope<WebLearnFestival> = try await request(
            path: "/v1/learn/festivals",
            method: "POST",
            body: input
        )
        return localizedLearnFestival(response.data)
    }

    func updateLearnFestival(id: String, input: UpdateLearnFestivalInput) async throws -> WebLearnFestival {
        let response: BFFEnvelope<WebLearnFestival> = try await request(
            path: "/v1/learn/festivals/\(id)",
            method: "PATCH",
            body: input
        )
        return localizedLearnFestival(response.data)
    }

    func fetchRankingBoards() async throws -> [RankingBoard] {
        let response: BFFEnvelope<[RankingBoard]> = try await request(path: "/v1/learn/rankings", method: "GET")
        return response.data
    }

    func fetchRankingBoardDetail(boardID: String, year: Int?) async throws -> RankingBoardDetail {
        var queryItems: [URLQueryItem] = []
        if let year {
            queryItems.append(URLQueryItem(name: "year", value: "\(year)"))
        }
        let response: BFFEnvelope<RankingBoardDetail> = try await request(
            path: "/v1/learn/rankings/\(boardID)",
            method: "GET",
            queryItems: queryItems
        )
        return response.data
    }

    func fetchMyPublishes() async throws -> MyPublishes {
        let response: BFFEnvelope<MyPublishes> = try await request(path: "/v1/publishes/me", method: "GET")
        return response.data
    }

    private func request<T: Decodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        body: Encodable? = nil
    ) async throws -> T {
        let url = try buildURL(path: path, queryItems: queryItems)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        if let token = SessionTokenStore.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try JSONEncoder.raver.encode(AnyEncodable(body))
        }

        let (data, response) = try await session.data(for: request)
        return try decodeResponse(data: data, response: response)
    }

    private func uploadMultipart<T: Decodable>(
        path: String,
        data: Data,
        fileName: String,
        mimeType: String,
        fieldName: String,
        fields: [String: String] = [:],
        timeoutInterval: TimeInterval = 30
    ) async throws -> T {
        let url = try buildURL(path: path, queryItems: [])
        let boundary = "Boundary-\(UUID().uuidString)"

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeoutInterval
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        if let token = SessionTokenStore.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()
        for (name, value) in fields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (responseData, response) = try await session.data(for: request)
        return try decodeResponse(data: responseData, response: response)
    }

    private func buildURL(path: String, queryItems: [URLQueryItem]) throws -> URL {
        guard let base = URL(string: path, relativeTo: baseURL) else {
            throw ServiceError.invalidResponse
        }
        guard !queryItems.isEmpty else {
            return base
        }
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: true) else {
            throw ServiceError.invalidResponse
        }
        components.queryItems = queryItems
        guard let url = components.url else {
            throw ServiceError.invalidResponse
        }
        return url
    }

    private func localizedEvent(_ event: WebEvent) -> WebEvent {
        var localized = event
        let language = AppLanguagePreference.current.effectiveLanguage
        if let nameI18n = event.nameI18n {
            let next = nameI18n.text(for: language).trimmingCharacters(in: .whitespacesAndNewlines)
            if !next.isEmpty { localized.name = next }
        }
        if let descriptionI18n = event.descriptionI18n {
            let next = descriptionI18n.text(for: language).trimmingCharacters(in: .whitespacesAndNewlines)
            localized.description = next.isEmpty ? localized.description : next
        }
        if let countryI18n = event.countryI18n {
            let next = countryI18n.text(for: language).trimmingCharacters(in: .whitespacesAndNewlines)
            if !next.isEmpty { localized.country = next }
        }
        return localized
    }

    private func localizedDJ(_ dj: WebDJ) -> WebDJ {
        var localized = dj
        let language = AppLanguagePreference.current.effectiveLanguage
        if let nameI18n = dj.nameI18n {
            let next = nameI18n.text(for: language).trimmingCharacters(in: .whitespacesAndNewlines)
            if !next.isEmpty { localized.name = next }
        }
        if let bioI18n = dj.bioI18n {
            let next = bioI18n.text(for: language).trimmingCharacters(in: .whitespacesAndNewlines)
            localized.bio = next.isEmpty ? localized.bio : next
        }
        if let countryI18n = dj.countryI18n {
            let next = countryI18n.text(for: language).trimmingCharacters(in: .whitespacesAndNewlines)
            if !next.isEmpty { localized.country = next }
        }
        return localized
    }

    private func localizedDJSet(_ set: WebDJSet) -> WebDJSet {
        var localized = set
        if let dj = set.dj {
            localized.dj = localizedDJ(dj)
        }
        localized.lineupDjs = set.lineupDjs.map(localizedDJ)
        return localized
    }

    private func localizedLearnFestival(_ festival: WebLearnFestival) -> WebLearnFestival {
        var localized = festival
        let language = AppLanguagePreference.current.effectiveLanguage
        if let nameI18n = festival.nameI18n {
            let next = nameI18n.text(for: language).trimmingCharacters(in: .whitespacesAndNewlines)
            if !next.isEmpty { localized.name = next }
        }
        if let descriptionI18n = festival.descriptionI18n {
            let next = descriptionI18n.text(for: language).trimmingCharacters(in: .whitespacesAndNewlines)
            if !next.isEmpty { localized.introduction = next }
        }
        if let countryI18n = festival.countryI18n {
            let next = countryI18n.text(for: language).trimmingCharacters(in: .whitespacesAndNewlines)
            if !next.isEmpty { localized.country = next }
        }
        if let cityI18n = festival.cityI18n {
            let next = cityI18n.text(for: language).trimmingCharacters(in: .whitespacesAndNewlines)
            if !next.isEmpty { localized.city = next }
        }
        if let frequencyI18n = festival.frequencyI18n {
            let next = frequencyI18n.text(for: language).trimmingCharacters(in: .whitespacesAndNewlines)
            if !next.isEmpty { localized.frequency = next }
        }
        return localized
    }

    private func localizedCheckin(_ checkin: WebCheckin) -> WebCheckin {
        var localized = checkin
        let language = AppLanguagePreference.current.effectiveLanguage
        if var event = checkin.event {
            if let nameI18n = event.nameI18n {
                let next = nameI18n.text(for: language).trimmingCharacters(in: .whitespacesAndNewlines)
                if !next.isEmpty { event.name = next }
            }
            if let countryI18n = event.countryI18n {
                let next = countryI18n.text(for: language).trimmingCharacters(in: .whitespacesAndNewlines)
                if !next.isEmpty { event.country = next }
            }
            localized.event = event
        }
        if var dj = checkin.dj {
            if let nameI18n = dj.nameI18n {
                let next = nameI18n.text(for: language).trimmingCharacters(in: .whitespacesAndNewlines)
                if !next.isEmpty { dj.name = next }
            }
            if let countryI18n = dj.countryI18n {
                let next = countryI18n.text(for: language).trimmingCharacters(in: .whitespacesAndNewlines)
                if !next.isEmpty { dj.country = next }
            }
            localized.dj = dj
        }
        return localized
    }

    private func decodeResponse<T: Decodable>(data: Data, response: URLResponse) throws -> T {
        guard let http = response as? HTTPURLResponse else {
            throw ServiceError.invalidResponse
        }

        if http.statusCode == 401 {
            NotificationCenter.default.post(name: .raverSessionExpired, object: nil)
            throw ServiceError.unauthorized
        }

        if http.statusCode == 304 {
            throw ServiceError.message("缓存响应未命中最新数据，请下拉刷新重试")
        }

        guard (200...299).contains(http.statusCode) else {
            if let apiError = try? JSONDecoder.raver.decode(BFFErrorResponse.self, from: data),
               !apiError.error.isEmpty {
                throw ServiceError.message(apiError.error)
            }
            let message = String(data: data, encoding: .utf8) ?? "请求失败"
            throw ServiceError.message(message)
        }

        do {
            return try JSONDecoder.raver.decode(T.self, from: data)
        } catch let decodingError as DecodingError {
            print("Web BFF decode error:", decodingError)
            throw ServiceError.message("接口返回格式不匹配，请检查 Web BFF 契约")
        } catch {
            print("Web BFF decode error:", error)
            throw ServiceError.message("接口返回格式不匹配，请检查 Web BFF 契约")
        }
    }
}

private struct BFFEnvelope<T: Decodable>: Decodable {
    var data: T
    var pagination: BFFPagination?
    var errorCode: String?
    var message: String?
}

private struct BFFItems<T: Decodable>: Decodable {
    var items: [T]
}

private struct GenericSuccess: Decodable {
    var success: Bool
}

private struct DJFollowStatusPayload: Decodable {
    var isFollowing: Bool
}

private struct VideoPreviewPayload: Decodable {
    var platform: String
    var videoId: String
    var title: String
    var description: String
    var thumbnailUrl: String
}

private struct BFFErrorResponse: Decodable {
    var error: String
}

private struct AnyEncodable: Encodable {
    private let encodeClosure: (Encoder) throws -> Void

    init(_ wrapped: Encodable) {
        self.encodeClosure = { encoder in
            try wrapped.encode(to: encoder)
        }
    }

    func encode(to encoder: Encoder) throws {
        try encodeClosure(encoder)
    }
}
