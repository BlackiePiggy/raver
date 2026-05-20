import Foundation

final class LiveWebFeatureService: WebFeatureService {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func fetchEvents(page: Int, limit: Int, search: String?, eventType: String?, status: String?, wikiFestivalId: String? = nil) async throws -> EventListPage {
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
        if let wikiFestivalId, !wikiFestivalId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            queryItems.append(URLQueryItem(name: "wikiFestivalId", value: wikiFestivalId))
        }
        let response: BFFEnvelope<BFFItems<WebEvent>> = try await request(path: "/v1/events", method: "GET", queryItems: queryItems)
        return EventListPage(items: response.data.items.map(localizedEvent), pagination: response.pagination)
    }

    func fetchFestivalEventFeed(
        wikiFestivalId: String,
        upcomingPage: Int,
        upcomingLimit: Int,
        endedPage: Int,
        endedLimit: Int
    ) async throws -> FestivalEventFeedResponse {
        let normalizedFestivalId = wikiFestivalId.trimmingCharacters(in: .whitespacesAndNewlines)
        let response: BFFEnvelope<FestivalEventFeedResponse> = try await request(
            path: "/v1/events/festival-feed",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "wikiFestivalId", value: normalizedFestivalId),
                URLQueryItem(name: "upcomingPage", value: "\(max(1, upcomingPage))"),
                URLQueryItem(name: "upcomingLimit", value: "\(max(1, min(100, upcomingLimit)))"),
                URLQueryItem(name: "endedPage", value: "\(max(1, endedPage))"),
                URLQueryItem(name: "endedLimit", value: "\(max(1, min(100, endedLimit)))")
            ]
        )
        return FestivalEventFeedResponse(
            upcoming: FestivalEventFeedPage(
                items: response.data.upcoming.items.map(localizedEvent),
                pagination: response.data.upcoming.pagination
            ),
            ended: FestivalEventFeedPage(
                items: response.data.ended.items.map(localizedEvent),
                pagination: response.data.ended.pagination
            )
        )
    }

    func fetchRecommendedEvents(limit: Int, statuses: [String]?) async throws -> [WebEvent] {
        var queryItems = [
            URLQueryItem(name: "limit", value: "\(max(1, min(20, limit)))")
        ]
        if let statuses {
            let normalized = statuses
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }
            if !normalized.isEmpty {
                queryItems.append(URLQueryItem(name: "statuses", value: normalized.joined(separator: ",")))
            }
        }
        let response: BFFEnvelope<BFFItems<WebEvent>> = try await request(
            path: "/v1/events/recommendations",
            method: "GET",
            queryItems: queryItems
        )
        return response.data.items.map(localizedEvent)
    }

    func fetchEvent(id: String) async throws -> WebEvent {
        let response: BFFEnvelope<WebEvent> = try await request(path: "/v1/events/\(id)", method: "GET")
        return localizedEvent(response.data)
    }

    func fetchMyEvents() async throws -> [WebEvent] {
        var page = 1
        var merged: [WebEvent] = []

        while true {
            let result = try await fetchMyEvents(page: page, limit: 100)
            merged.append(contentsOf: result.items)
            guard let pagination = result.pagination, page < pagination.totalPages else { break }
            page += 1
        }

        return merged
    }

    func fetchMyEvents(page: Int, limit: Int) async throws -> EventListPage {
        let response: BFFEnvelope<BFFItems<WebEvent>> = try await request(
            path: "/v1/events/my",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "page", value: "\(max(1, page))"),
                URLQueryItem(name: "limit", value: "\(max(1, min(100, limit)))")
            ]
        )
        return EventListPage(items: response.data.items.map(localizedEvent), pagination: response.pagination)
    }

    func fetchFavoriteEvents(page: Int, limit: Int) async throws -> EventListPage {
        let queryItems = [
            URLQueryItem(name: "page", value: "\(max(1, page))"),
            URLQueryItem(name: "limit", value: "\(max(1, min(100, limit)))")
        ]
        let response: BFFEnvelope<BFFItems<WebEvent>> = try await request(
            path: "/v1/events/favorites",
            method: "GET",
            queryItems: queryItems
        )
        return EventListPage(items: response.data.items.map(localizedEvent), pagination: response.pagination)
    }

    func fetchEventFavoriteStatus(eventID: String) async throws -> EventFavoriteStatus {
        let response: BFFEnvelope<EventFavoriteStatus> = try await request(
            path: "/v1/events/\(eventID)/favorite",
            method: "GET"
        )
        return response.data
    }

    func favoriteEvent(eventID: String) async throws -> EventFavoriteStatus {
        let response: BFFEnvelope<EventFavoriteStatus> = try await request(
            path: "/v1/events/\(eventID)/favorite",
            method: "POST"
        )
        return response.data
    }

    func unfavoriteEvent(eventID: String) async throws {
        let _: BFFEnvelope<GenericSuccess> = try await request(
            path: "/v1/events/\(eventID)/favorite",
            method: "DELETE"
        )
    }

    func createEvent(input: CreateEventInput) async throws -> CreateEventResult {
        let response: BFFEnvelope<CreateEventResponsePayload> = try await request(path: "/v1/events", method: "POST", body: input)
        switch response.data {
        case .event(let event):
            return .created(localizedEvent(event))
        case .submission(let payload):
            return .submittedForReview(payload)
        }
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

    func fetchRecommendedDJs(limit: Int) async throws -> [WebDJ] {
        let response: BFFEnvelope<BFFItems<WebDJ>> = try await request(
            path: "/v1/djs/recommendations",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "limit", value: "\(max(1, min(20, limit)))")
            ]
        )
        return response.data.items.map(localizedDJ)
    }

    func fetchOnboardingDJCandidates(limit: Int) async throws -> [WebDJ] {
        let response: BFFEnvelope<BFFItems<WebDJ>> = try await request(
            path: "/v1/djs",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "page", value: "1"),
                URLQueryItem(name: "limit", value: "\(max(1, min(100, limit)))"),
                URLQueryItem(name: "sortBy", value: "soundcloudFollowers"),
                URLQueryItem(name: "onboarding", value: "1")
            ]
        )
        return response.data.items.map(localizedDJ)
    }

    func fetchOnboardingPreferenceOptions() async throws -> OnboardingPreferenceOptions {
        let response: BFFEnvelope<OnboardingPreferenceOptions> = try await request(
            path: "/v1/onboarding/preferences/options",
            method: "GET"
        )
        var options = response.data
        options.brands = options.brands.map(localizedLearnFestival)
        options.djs = options.djs.map(localizedDJ)
        return options
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

    func importSpotifyDJ(input: ImportSpotifyDJInput) async throws -> ImportDJResult<ImportSpotifyDJResponse> {
        let response: BFFEnvelope<ImportDJResult<ImportSpotifyDJResponse>> = try await request(
            path: "/v1/djs/spotify/import",
            method: "POST",
            body: input
        )
        switch response.data {
        case .imported(var payload):
            payload.dj = localizedDJ(payload.dj)
            return .imported(payload)
        case .submittedForReview(let payload):
            return .submittedForReview(payload)
        }
    }

    func importDiscogsDJ(input: ImportDiscogsDJInput) async throws -> ImportDJResult<ImportDiscogsDJResponse> {
        let response: BFFEnvelope<ImportDJResult<ImportDiscogsDJResponse>> = try await request(
            path: "/v1/djs/discogs/import",
            method: "POST",
            body: input
        )
        switch response.data {
        case .imported(var payload):
            payload.dj = localizedDJ(payload.dj)
            return .imported(payload)
        case .submittedForReview(let payload):
            return .submittedForReview(payload)
        }
    }

    func importManualDJ(input: ImportManualDJInput) async throws -> ImportDJResult<ImportManualDJResponse> {
        let response: BFFEnvelope<ImportDJResult<ImportManualDJResponse>> = try await request(
            path: "/v1/djs/manual/import",
            method: "POST",
            body: input
        )
        switch response.data {
        case .imported(var payload):
            payload.dj = localizedDJ(payload.dj)
            return .imported(payload)
        case .submittedForReview(let payload):
            return .submittedForReview(payload)
        }
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
        var page = 1
        var merged: [WebDJSet] = []

        while true {
            let result = try await fetchDJSets(djID: djID, page: page, limit: 100)
            merged.append(contentsOf: result.items)
            guard let pagination = result.pagination, page < pagination.totalPages else { break }
            page += 1
        }

        return merged
    }

    func fetchDJSets(djID: String, page: Int, limit: Int) async throws -> DJSetListPage {
        let response: BFFEnvelope<BFFItems<WebDJSet>> = try await request(
            path: "/v1/djs/\(djID)/sets",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "page", value: "\(max(1, page))"),
                URLQueryItem(name: "limit", value: "\(max(1, min(100, limit)))")
            ]
        )
        return DJSetListPage(items: response.data.items.map(localizedDJSet), pagination: response.pagination)
    }

    func fetchDJEvents(djID: String, page: Int, limit: Int, statuses: [String]?) async throws -> EventListPage {
        var queryItems = [
            URLQueryItem(name: "page", value: "\(max(1, page))"),
            URLQueryItem(name: "limit", value: "\(max(1, min(100, limit)))")
        ]
        if let statuses {
            let normalized = statuses
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }
            if !normalized.isEmpty {
                queryItems.append(URLQueryItem(name: "statuses", value: normalized.joined(separator: ",")))
            }
        }
        let response: BFFEnvelope<BFFItems<WebEvent>> = try await request(
            path: "/v1/djs/\(djID)/events",
            method: "GET",
            queryItems: queryItems
        )
        return EventListPage(items: response.data.items.map(localizedEvent), pagination: response.pagination)
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

    func fetchFollowedDJs(page: Int, limit: Int) async throws -> DJListPage {
        let response: BFFEnvelope<BFFItems<WebDJ>> = try await request(
            path: "/v1/djs/followed",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "page", value: "\(max(1, page))"),
                URLQueryItem(name: "limit", value: "\(max(1, min(100, limit)))")
            ]
        )
        return DJListPage(items: response.data.items.map(localizedDJ), pagination: response.pagination)
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

    func fetchEventDJSets(eventID: String, eventName: String) async throws -> [WebDJSet] {
        let normalizedEventID = eventID.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = eventName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedEventID.isEmpty || !normalized.isEmpty else { return [] }
        var queryItems = [
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "limit", value: "200"),
            URLQueryItem(name: "sortBy", value: "latest"),
        ]
        if !normalizedEventID.isEmpty {
            queryItems.append(URLQueryItem(name: "eventId", value: normalizedEventID))
        }
        if !normalized.isEmpty {
            queryItems.append(URLQueryItem(name: "eventName", value: normalized))
        }
        let response: BFFEnvelope<BFFItems<WebDJSet>> = try await request(path: "/v1/dj-sets", method: "GET", queryItems: queryItems)
        return response.data.items.map(localizedDJSet)
    }

    func fetchDJSet(id: String) async throws -> WebDJSet {
        let response: BFFEnvelope<WebDJSet> = try await request(path: "/v1/dj-sets/\(id)", method: "GET")
        return localizedDJSet(response.data)
    }

    func fetchMyDJSets() async throws -> [WebDJSet] {
        var page = 1
        var merged: [WebDJSet] = []

        while true {
            let result = try await fetchMyDJSets(page: page, limit: 100)
            merged.append(contentsOf: result.items)
            guard let pagination = result.pagination, page < pagination.totalPages else { break }
            page += 1
        }

        return merged
    }

    func fetchMyDJSets(page: Int, limit: Int) async throws -> DJSetListPage {
        let response: BFFEnvelope<BFFItems<WebDJSet>> = try await request(
            path: "/v1/dj-sets/mine",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "page", value: "\(max(1, page))"),
                URLQueryItem(name: "limit", value: "\(max(1, min(100, limit)))")
            ]
        )
        return DJSetListPage(items: response.data.items.map(localizedDJSet), pagination: response.pagination)
    }

    func createDJSet(input: CreateDJSetInput) async throws -> CreateContentResult<WebDJSet> {
        let response: BFFEnvelope<CreateContentResult<WebDJSet>> = try await request(path: "/v1/dj-sets", method: "POST", body: input)
        switch response.data {
        case .created(let set):
            return .created(localizedDJSet(set))
        case .submittedForReview(let payload):
            return .submittedForReview(payload)
        }
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
        var page = 1
        var merged: [WebTracklistSummary] = []

        while true {
            let result = try await fetchTracklists(setID: setID, page: page, limit: 100)
            merged.append(contentsOf: result.items)
            guard let pagination = result.pagination, page < pagination.totalPages else { break }
            page += 1
        }

        return merged
    }

    func fetchTracklists(setID: String, page: Int, limit: Int) async throws -> TracklistSummaryPage {
        let response: BFFEnvelope<BFFItems<WebTracklistSummary>> = try await request(
            path: "/v1/dj-sets/\(setID)/tracklists",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "page", value: "\(max(1, page))"),
                URLQueryItem(name: "limit", value: "\(max(1, min(100, limit)))")
            ]
        )
        return TracklistSummaryPage(items: response.data.items, pagination: response.pagination)
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
            "thumbnailUrl": response.data.thumbnailUrl,
            "authorName": response.data.authorName ?? ""
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
        var page = 1
        var merged: [WebSetComment] = []

        while true {
            let result = try await fetchSetComments(setID: setID, page: page, limit: 100)
            merged.append(contentsOf: result.items)
            guard let pagination = result.pagination, page < pagination.totalPages else { break }
            page += 1
        }

        return merged
    }

    func fetchSetComments(setID: String, page: Int, limit: Int) async throws -> SetCommentListPage {
        let response: BFFEnvelope<BFFItems<WebSetComment>> = try await request(
            path: "/v1/dj-sets/\(setID)/comments",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "page", value: "\(max(1, page))"),
                URLQueryItem(name: "limit", value: "\(max(1, min(100, limit)))")
            ]
        )
        return SetCommentListPage(items: response.data.items, pagination: response.pagination)
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

    func fetchMyCheckinsOverview() async throws -> MyCheckinsOverviewResponse {
        let response: BFFEnvelope<MyCheckinsOverviewResponse> = try await request(
            path: "/v2/me/checkins/overview",
            method: "GET"
        )
        return localizedMyCheckinsOverview(response.data)
    }

    func fetchUserCheckinsOverview(userID: String) async throws -> MyCheckinsOverviewResponse {
        let response: BFFEnvelope<MyCheckinsOverviewResponse> = try await request(
            path: "/v2/users/\(userID)/checkins/overview",
            method: "GET"
        )
        return localizedMyCheckinsOverview(response.data)
    }

    func fetchMyCheckinsTimeline(page: Int, limit: Int) async throws -> MyCheckinsTimelinePage {
        let response: BFFEnvelope<BFFItems<MyCheckinsOverviewTimelineItem>> = try await request(
            path: "/v2/me/checkins/timeline",
            method: "GET",
            queryItems: checkinsPaginationQueryItems(page: page, limit: limit)
        )
        return MyCheckinsTimelinePage(
            items: localizedMyCheckinsTimelineItems(response.data.items),
            pagination: response.pagination
        )
    }

    func fetchUserCheckinsTimeline(userID: String, page: Int, limit: Int) async throws -> MyCheckinsTimelinePage {
        let response: BFFEnvelope<BFFItems<MyCheckinsOverviewTimelineItem>> = try await request(
            path: "/v2/users/\(userID)/checkins/timeline",
            method: "GET",
            queryItems: checkinsPaginationQueryItems(page: page, limit: limit)
        )
        return MyCheckinsTimelinePage(
            items: localizedMyCheckinsTimelineItems(response.data.items),
            pagination: response.pagination
        )
    }

    func fetchMyCheckinsGalleryEvents(page: Int, limit: Int) async throws -> MyCheckinsGalleryEventPage {
        let response: BFFEnvelope<BFFItems<MyCheckinsOverviewGalleryEvent>> = try await request(
            path: "/v2/me/checkins/gallery/events",
            method: "GET",
            queryItems: checkinsPaginationQueryItems(page: page, limit: limit)
        )
        return MyCheckinsGalleryEventPage(
            items: localizedMyCheckinsGalleryEvents(response.data.items),
            pagination: response.pagination
        )
    }

    func fetchUserCheckinsGalleryEvents(userID: String, page: Int, limit: Int) async throws -> MyCheckinsGalleryEventPage {
        let response: BFFEnvelope<BFFItems<MyCheckinsOverviewGalleryEvent>> = try await request(
            path: "/v2/users/\(userID)/checkins/gallery/events",
            method: "GET",
            queryItems: checkinsPaginationQueryItems(page: page, limit: limit)
        )
        return MyCheckinsGalleryEventPage(
            items: localizedMyCheckinsGalleryEvents(response.data.items),
            pagination: response.pagination
        )
    }

    func fetchMyCheckinsGalleryArtists(page: Int, limit: Int) async throws -> MyCheckinsGalleryArtistPage {
        let response: BFFEnvelope<BFFItems<MyCheckinsOverviewGalleryArtist>> = try await request(
            path: "/v2/me/checkins/gallery/djs",
            method: "GET",
            queryItems: checkinsPaginationQueryItems(page: page, limit: limit)
        )
        return MyCheckinsGalleryArtistPage(items: response.data.items, pagination: response.pagination)
    }

    func fetchUserCheckinsGalleryArtists(userID: String, page: Int, limit: Int) async throws -> MyCheckinsGalleryArtistPage {
        let response: BFFEnvelope<BFFItems<MyCheckinsOverviewGalleryArtist>> = try await request(
            path: "/v2/users/\(userID)/checkins/gallery/djs",
            method: "GET",
            queryItems: checkinsPaginationQueryItems(page: page, limit: limit)
        )
        return MyCheckinsGalleryArtistPage(items: response.data.items, pagination: response.pagination)
    }

    func fetchMyCheckinsStats() async throws -> MyCheckinsOverviewStats {
        let response: BFFEnvelope<MyCheckinsOverviewStats> = try await request(
            path: "/v2/me/checkins/stats",
            method: "GET"
        )
        return response.data
    }

    func fetchUserCheckinsStats(userID: String) async throws -> MyCheckinsOverviewStats {
        let response: BFFEnvelope<MyCheckinsOverviewStats> = try await request(
            path: "/v2/users/\(userID)/checkins/stats",
            method: "GET"
        )
        return response.data
    }

    func fetchMyDJCheckinCount(djID: String) async throws -> Int {
        let response: BFFEnvelope<DJWatchedCountResponse> = try await request(
            path: "/v1/djs/\(djID)/watched-count",
            method: "GET"
        )
        return max(0, response.data.count)
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
        let path = input.selections == nil ? "/v1/checkins" : "/v2/checkins"
        let projectionMode = path.hasPrefix("/v2") ? "write-after-refresh" : "legacy-v1"
        print("[CheckinProjection] create request path=\(path) projectionMode=\(projectionMode) type=\(input.type) eventId=\(input.eventId ?? "nil") djId=\(input.djId ?? "nil")")
        let response: BFFEnvelope<WebCheckin> = try await request(path: path, method: "POST", body: input)
        let checkin = localizedCheckin(response.data)
        print("[CheckinProjection] create success checkinId=\(checkin.id) path=\(path) projectionMode=\(projectionMode); posting raverCheckinsDidMutate")
        await MainActor.run {
            CheckinProjectionMutationStore.markMutation(action: "create", checkinID: checkin.id)
            NotificationCenter.default.post(name: .raverCheckinsDidMutate, object: checkin.id)
        }
        return checkin
    }

    func updateCheckin(id: String, input: UpdateCheckinInput) async throws -> WebCheckin {
        let path = input.selections == nil ? "/v1/checkins/\(id)" : "/v2/checkins/\(id)"
        let projectionMode = path.hasPrefix("/v2") ? "write-after-refresh" : "legacy-v1"
        print("[CheckinProjection] update request checkinId=\(id) path=\(path) projectionMode=\(projectionMode) eventId=\(input.eventId ?? "nil") djId=\(input.djId ?? "nil")")
        let response: BFFEnvelope<WebCheckin> = try await request(path: path, method: "PATCH", body: input)
        let checkin = localizedCheckin(response.data)
        print("[CheckinProjection] update success checkinId=\(checkin.id) path=\(path) projectionMode=\(projectionMode); posting raverCheckinsDidMutate")
        await MainActor.run {
            CheckinProjectionMutationStore.markMutation(action: "update", checkinID: checkin.id)
            NotificationCenter.default.post(name: .raverCheckinsDidMutate, object: checkin.id)
        }
        return checkin
    }

    func deleteCheckin(id: String) async throws {
        let path = "/v2/checkins/\(id)"
        print("[CheckinProjection] delete request checkinId=\(id) path=\(path) projectionMode=write-after-refresh")
        let _: BFFEnvelope<GenericSuccess> = try await request(path: path, method: "DELETE")
        print("[CheckinProjection] delete success checkinId=\(id) path=\(path) projectionMode=write-after-refresh; posting raverCheckinsDidMutate")
        await MainActor.run {
            CheckinProjectionMutationStore.markMutation(action: "delete", checkinID: id)
            NotificationCenter.default.post(name: .raverCheckinsDidMutate, object: id)
        }
    }

    func fetchRatingEvents() async throws -> [WebRatingEvent] {
        var page = 1
        var merged: [WebRatingEvent] = []

        while true {
            let result = try await fetchRatingEvents(page: page, limit: 100)
            merged.append(contentsOf: result.items)
            guard let pagination = result.pagination, page < pagination.totalPages else { break }
            page += 1
        }

        return merged
    }

    func fetchRatingEvents(page: Int, limit: Int) async throws -> RatingEventListPage {
        let response: BFFEnvelope<BFFItems<WebRatingEvent>> = try await request(
            path: "/v1/rating-events",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "page", value: "\(max(1, page))"),
                URLQueryItem(name: "limit", value: "\(max(1, min(100, limit)))")
            ]
        )
        return RatingEventListPage(items: response.data.items, pagination: response.pagination)
    }

    func fetchEventRatingEvents(eventID: String) async throws -> [WebRatingEvent] {
        var page = 1
        var merged: [WebRatingEvent] = []

        while true {
            let result = try await fetchEventRatingEvents(eventID: eventID, page: page, limit: 100)
            merged.append(contentsOf: result.items)
            guard let pagination = result.pagination, page < pagination.totalPages else { break }
            page += 1
        }

        return merged
    }

    func fetchEventRatingEvents(eventID: String, page: Int, limit: Int) async throws -> RatingEventListPage {
        let response: BFFEnvelope<BFFItems<WebRatingEvent>> = try await request(
            path: "/v1/events/\(eventID)/rating-events",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "page", value: "\(max(1, page))"),
                URLQueryItem(name: "limit", value: "\(max(1, min(100, limit)))")
            ]
        )
        return RatingEventListPage(items: response.data.items, pagination: response.pagination)
    }

    func fetchRatingEvent(id: String) async throws -> WebRatingEvent {
        let response: BFFEnvelope<WebRatingEvent> = try await request(path: "/v1/rating-events/\(id)", method: "GET")
        return response.data
    }

    func fetchDJRatingUnits(djID: String) async throws -> [WebRatingUnit] {
        var page = 1
        var merged: [WebRatingUnit] = []

        while true {
            let result = try await fetchDJRatingUnits(djID: djID, page: page, limit: 100)
            merged.append(contentsOf: result.items)
            guard let pagination = result.pagination, page < pagination.totalPages else { break }
            page += 1
        }

        return merged
    }

    func fetchDJRatingUnits(djID: String, page: Int, limit: Int) async throws -> RatingUnitListPage {
        let response: BFFEnvelope<BFFItems<WebRatingUnit>> = try await request(
            path: "/v1/djs/\(djID)/rating-units",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "page", value: "\(max(1, page))"),
                URLQueryItem(name: "limit", value: "\(max(1, min(100, limit)))")
            ]
        )
        return RatingUnitListPage(items: response.data.items, pagination: response.pagination)
    }

    func createRatingEvent(input: CreateRatingEventInput) async throws -> CreateContentResult<WebRatingEvent> {
        let response: BFFEnvelope<CreateContentResult<WebRatingEvent>> = try await request(path: "/v1/rating-events", method: "POST", body: input)
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

    func createRatingUnit(eventID: String, input: CreateRatingUnitInput) async throws -> CreateContentResult<WebRatingUnit> {
        let response: BFFEnvelope<CreateContentResult<WebRatingUnit>> = try await request(path: "/v1/rating-events/\(eventID)/units", method: "POST", body: input)
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

    func fetchLearnGenreTreeSummary() async throws -> [LearnGenreTreeSummaryNode] {
        let response: BFFEnvelope<[LearnGenreTreeSummaryNode]> = try await request(path: "/v1/learn/genres/tree-summary", method: "GET")
        return response.data
    }

    func fetchLearnGenreDetail(id: String) async throws -> LearnGenreDetail {
        let response: BFFEnvelope<LearnGenreDetail> = try await request(path: "/v1/learn/genres/\(id)", method: "GET")
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

    func fetchLearnFestivalPage(page: Int, limit: Int, search: String?) async throws -> LearnFestivalListPage {
        var queryItems = [
            URLQueryItem(name: "page", value: "\(max(1, page))"),
            URLQueryItem(name: "limit", value: "\(max(1, min(100, limit)))")
        ]
        if let search, !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            queryItems.append(URLQueryItem(name: "search", value: search))
        }
        let response: BFFEnvelope<BFFItems<WebLearnFestival>> = try await request(
            path: "/v1/learn/festivals",
            method: "GET",
            queryItems: queryItems
        )
        return LearnFestivalListPage(items: response.data.items.map(localizedLearnFestival), pagination: response.pagination)
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

    func fetchLearnFestival(id: String) async throws -> WebLearnFestival {
        let response: BFFEnvelope<WebLearnFestival> = try await request(
            path: "/v1/learn/festivals/\(id)",
            method: "GET"
        )
        return localizedLearnFestival(response.data)
    }

    func fetchLearnLabel(id: String) async throws -> LearnLabel {
        let response: BFFEnvelope<LearnLabel> = try await request(
            path: "/v1/learn/labels/\(id)",
            method: "GET"
        )
        return response.data
    }

    func createLearnLabel(input: CreateLearnLabelInput) async throws -> CreateContentResult<LearnLabel> {
        let response: BFFEnvelope<CreateContentResult<LearnLabel>> = try await request(
            path: "/v1/learn/labels",
            method: "POST",
            body: input
        )
        return response.data
    }

    func createLearnFestival(input: CreateLearnFestivalInput) async throws -> CreateContentResult<WebLearnFestival> {
        let response: BFFEnvelope<CreateContentResult<WebLearnFestival>> = try await request(
            path: "/v1/learn/festivals",
            method: "POST",
            body: input
        )
        switch response.data {
        case .created(let festival):
            return .created(localizedLearnFestival(festival))
        case .submittedForReview(let payload):
            return .submittedForReview(payload)
        }
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

    func searchGlobal(query: String, tab: GlobalSearchTab, limit: Int) async throws -> GlobalSearchResponse {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let language = AppLanguagePreference.current.effectiveLanguage
        var queryItems = [
            URLQueryItem(name: "q", value: keyword),
            URLQueryItem(name: "tab", value: tab.rawValue),
            URLQueryItem(name: "limit", value: "\(max(1, min(80, limit)))"),
            URLQueryItem(name: "locale", value: language.rawValue)
        ]
        if keyword.isEmpty {
            queryItems.removeAll { $0.name == "q" }
        }
        let response: BFFEnvelope<GlobalSearchResponse> = try await request(
            path: "/v1/search",
            method: "GET",
            queryItems: queryItems
        )
        return response.data
    }

    func fetchMyPublishes() async throws -> MyPublishes {
        let response: BFFEnvelope<MyPublishes> = try await request(path: "/v1/publishes/me", method: "GET")
        return response.data
    }

    func fetchMyContentSubmissions() async throws -> [ContentSubmissionSummary] {
        var page = 1
        var merged: [ContentSubmissionSummary] = []

        while true {
            let result = try await fetchMyContentSubmissions(page: page, limit: 100)
            merged.append(contentsOf: result.items)
            guard let pagination = result.pagination, page < pagination.totalPages else { break }
            page += 1
        }

        return merged
    }

    func fetchMyContentSubmissions(page: Int, limit: Int) async throws -> ContentSubmissionListPage {
        let response: BFFEnvelope<BFFItems<ContentSubmissionSummary>> = try await request(
            path: "/api/content-submissions/mine",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "page", value: "\(max(1, page))"),
                URLQueryItem(name: "limit", value: "\(max(1, min(200, limit)))")
            ]
        )
        return ContentSubmissionListPage(items: response.data.items, pagination: response.pagination)
    }

    func fetchMyContentSubmission(id: String) async throws -> ContentSubmissionDetail {
        let response: ContentSubmissionDetailResponse = try await request(
            path: "/api/content-submissions/mine/\(id)",
            method: "GET"
        )
        return response.submission
    }

    func createContentSubmission(
        entityType: String,
        payload: [String: ContentSubmissionJSONValue]
    ) async throws -> ContentSubmissionDetail {
        let input = ContentSubmissionCreateInput(entityType: entityType, payload: payload)
        let response: ContentSubmissionCreateResponse = try await request(
            path: "/api/content-submissions",
            method: "POST",
            body: input
        )
        return response.submission
    }

    func resubmitMyContentSubmission(
        id: String,
        payload: [String: ContentSubmissionJSONValue],
        changeNote: String?
    ) async throws -> ContentSubmissionDetail {
        let input = ContentSubmissionResubmitInput(payload: payload, changeNote: changeNote)
        let response: ContentSubmissionResubmitResponse = try await request(
            path: "/api/content-submissions/mine/\(id)",
            method: "PATCH",
            body: input
        )
        return response.submission
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
        request.setValue(AppLanguagePreference.current.effectiveLanguage.localeIdentifier, forHTTPHeaderField: "Accept-Language")
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
        if let festival = event.wikiFestival, let nameI18n = festival.nameI18n {
            let next = nameI18n.text(for: language).trimmingCharacters(in: .whitespacesAndNewlines)
            if !next.isEmpty {
                var localizedFestival = festival
                localizedFestival.name = next
                localized.wikiFestival = localizedFestival
            }
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

    private func localizedMyCheckinsOverview(_ overview: MyCheckinsOverviewResponse) -> MyCheckinsOverviewResponse {
        var localized = overview
        let language = AppLanguagePreference.current.effectiveLanguage

        localized.timeline.items = overview.timeline.items.map { item in
            var next = item
            if let nameI18n = next.event.nameI18n {
                let localizedName = nameI18n.text(for: language).trimmingCharacters(in: .whitespacesAndNewlines)
                if !localizedName.isEmpty {
                    next.event.name = localizedName
                }
            }
            return next
        }

        localized.gallerySummary.topEvents = overview.gallerySummary.topEvents.map { event in
            var next = event
            if let match = localized.timeline.items.first(where: { $0.event.id == event.eventId }),
               let localizedName = match.event.name?.trimmingCharacters(in: .whitespacesAndNewlines),
               !localizedName.isEmpty {
                next.name = localizedName
            }
            return next
        }

        return localized
    }

    private func localizedMyCheckinsGalleryEvents(
        _ events: [MyCheckinsOverviewGalleryEvent]
    ) -> [MyCheckinsOverviewGalleryEvent] {
        events.map { event in
            var next = event
            let trimmedName = event.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if trimmedName.isEmpty {
                next.name = nil
            }
            return next
        }
    }

    private func localizedMyCheckinsTimelineItems(
        _ items: [MyCheckinsOverviewTimelineItem]
    ) -> [MyCheckinsOverviewTimelineItem] {
        let language = AppLanguagePreference.current.effectiveLanguage
        return items.map { item in
            var next = item
            if let nameI18n = next.event.nameI18n {
                let localizedName = nameI18n.text(for: language).trimmingCharacters(in: .whitespacesAndNewlines)
                if !localizedName.isEmpty {
                    next.event.name = localizedName
                }
            }
            return next
        }
    }

    private func checkinsPaginationQueryItems(page: Int, limit: Int) -> [URLQueryItem] {
        [
            URLQueryItem(name: "page", value: "\(max(1, page))"),
            URLQueryItem(name: "limit", value: "\(max(1, min(100, limit)))")
        ]
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
            if let enforcementRestriction = try? JSONDecoder.raver.decode(AccountEnforcementRestrictionEnvelope.self, from: data),
               enforcementRestriction.error == "account_enforcement_restricted" {
                throw ServiceError.accountEnforcementRestricted(enforcementRestriction.toRestriction())
            }
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
    var authorName: String?
}

private struct BFFErrorResponse: Decodable {
    var error: String
}

private struct AccountEnforcementRestrictionEnvelope: Decodable {
    var error: String
    var scope: String
    var accountStatus: AccountEnforcementStatus?
    var blockingEnforcements: [AccountEnforcement]

    func toRestriction() -> AccountEnforcementRestriction {
        AccountEnforcementRestriction(
            scope: scope,
            accountStatus: accountStatus,
            blockingEnforcements: blockingEnforcements
        )
    }
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
