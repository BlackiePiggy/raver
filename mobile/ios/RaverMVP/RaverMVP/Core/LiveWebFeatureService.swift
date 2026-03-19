import Foundation

final class LiveWebFeatureService: WebFeatureService {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func fetchEvents(page: Int, limit: Int, search: String?, eventType: String?) async throws -> EventListPage {
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
        let response: BFFEnvelope<BFFItems<WebEvent>> = try await request(path: "/v1/events", method: "GET", queryItems: queryItems)
        return EventListPage(items: response.data.items, pagination: response.pagination)
    }

    func fetchEvent(id: String) async throws -> WebEvent {
        let response: BFFEnvelope<WebEvent> = try await request(path: "/v1/events/\(id)", method: "GET")
        return response.data
    }

    func fetchMyEvents() async throws -> [WebEvent] {
        let response: BFFEnvelope<BFFItems<WebEvent>> = try await request(path: "/v1/events/my", method: "GET")
        return response.data.items
    }

    func createEvent(input: CreateEventInput) async throws -> WebEvent {
        let response: BFFEnvelope<WebEvent> = try await request(path: "/v1/events", method: "POST", body: input)
        return response.data
    }

    func updateEvent(id: String, input: UpdateEventInput) async throws -> WebEvent {
        let response: BFFEnvelope<WebEvent> = try await request(path: "/v1/events/\(id)", method: "PATCH", body: input)
        return response.data
    }

    func deleteEvent(id: String) async throws {
        let _: BFFEnvelope<GenericSuccess> = try await request(path: "/v1/events/\(id)", method: "DELETE")
    }

    func uploadEventImage(imageData: Data, fileName: String, mimeType: String) async throws -> UploadMediaResponse {
        let response: BFFEnvelope<UploadMediaResponse> = try await uploadMultipart(
            path: "/v1/events/upload-image",
            data: imageData,
            fileName: fileName,
            mimeType: mimeType,
            fieldName: "image"
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
        return DJListPage(items: response.data.items, pagination: response.pagination)
    }

    func fetchDJ(id: String) async throws -> WebDJ {
        let response: BFFEnvelope<WebDJ> = try await request(path: "/v1/djs/\(id)", method: "GET")
        return response.data
    }

    func fetchDJSets(djID: String) async throws -> [WebDJSet] {
        let response: BFFEnvelope<BFFItems<WebDJSet>> = try await request(path: "/v1/djs/\(djID)/sets", method: "GET")
        return response.data.items
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
        return response.data
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
        return DJSetListPage(items: response.data.items, pagination: response.pagination)
    }

    func fetchDJSet(id: String) async throws -> WebDJSet {
        let response: BFFEnvelope<WebDJSet> = try await request(path: "/v1/dj-sets/\(id)", method: "GET")
        return response.data
    }

    func fetchMyDJSets() async throws -> [WebDJSet] {
        let response: BFFEnvelope<BFFItems<WebDJSet>> = try await request(path: "/v1/dj-sets/mine", method: "GET")
        return response.data.items
    }

    func createDJSet(input: CreateDJSetInput) async throws -> WebDJSet {
        let response: BFFEnvelope<WebDJSet> = try await request(path: "/v1/dj-sets", method: "POST", body: input)
        return response.data
    }

    func updateDJSet(id: String, input: UpdateDJSetInput) async throws -> WebDJSet {
        let response: BFFEnvelope<WebDJSet> = try await request(path: "/v1/dj-sets/\(id)", method: "PATCH", body: input)
        return response.data
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
        return response.data
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
        var queryItems = [
            URLQueryItem(name: "page", value: "\(max(1, page))"),
            URLQueryItem(name: "limit", value: "\(max(1, min(100, limit)))")
        ]
        if let type, !type.isEmpty {
            queryItems.append(URLQueryItem(name: "type", value: type))
        }
        let response: BFFEnvelope<BFFItems<WebCheckin>> = try await request(path: "/v1/checkins", method: "GET", queryItems: queryItems)
        return CheckinListPage(items: response.data.items, pagination: response.pagination)
    }

    func createCheckin(input: CreateCheckinInput) async throws -> WebCheckin {
        let response: BFFEnvelope<WebCheckin> = try await request(path: "/v1/checkins", method: "POST", body: input)
        return response.data
    }

    func deleteCheckin(id: String) async throws {
        let _: BFFEnvelope<GenericSuccess> = try await request(path: "/v1/checkins/\(id)", method: "DELETE")
    }

    func fetchLearnGenres() async throws -> [LearnGenreNode] {
        let response: BFFEnvelope<[LearnGenreNode]> = try await request(path: "/v1/learn/genres", method: "GET")
        return response.data
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
        fieldName: String
    ) async throws -> T {
        let url = try buildURL(path: path, queryItems: [])
        let boundary = "Boundary-\(UUID().uuidString)"

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        if let token = SessionTokenStore.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()
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
