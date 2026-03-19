import Foundation

actor MockWebFeatureService: WebFeatureService {
    private let currentUser = WebUserLite(id: "u_me", username: "blackie", displayName: "Blackie", avatarUrl: nil)
    private let currentContributor = WebContributorProfile(
        id: "u_me",
        username: "blackie",
        displayName: "Blackie",
        avatarUrl: nil,
        bio: "Mock account",
        location: "Shanghai",
        favoriteGenres: ["house", "techno"],
        favoriteDJs: ["Amelie Lens", "Charlotte de Witte"]
    )

    private var events: [WebEvent]
    private var djs: [WebDJ]
    private var sets: [WebDJSet]
    private var tracklistsBySetID: [String: [WebTracklistDetail]]
    private var commentsBySetID: [String: [WebSetComment]]
    private var checkins: [WebCheckin]

    init() {
        let now = Date()
        let djA = WebDJ(
            id: "dj_amelie",
            name: "Amelie Lens",
            slug: "amelie-lens",
            bio: "Hard techno headliner.",
            avatarUrl: nil,
            bannerUrl: nil,
            country: "BE",
            spotifyId: nil,
            appleMusicId: nil,
            soundcloudUrl: nil,
            instagramUrl: nil,
            twitterUrl: nil,
            isVerified: true,
            followerCount: 120300,
            createdAt: now.addingTimeInterval(-1000000),
            updatedAt: now,
            isFollowing: false
        )
        let djB = WebDJ(
            id: "dj_charlotte",
            name: "Charlotte de Witte",
            slug: "charlotte-de-witte",
            bio: "Dark peak-time techno.",
            avatarUrl: nil,
            bannerUrl: nil,
            country: "BE",
            spotifyId: nil,
            appleMusicId: nil,
            soundcloudUrl: nil,
            instagramUrl: nil,
            twitterUrl: nil,
            isVerified: true,
            followerCount: 99800,
            createdAt: now.addingTimeInterval(-900000),
            updatedAt: now,
            isFollowing: true
        )

        djs = [djA, djB]

        let mockEvent = WebEvent(
            id: "evt_shanghai_001",
            name: "Raver Night Shanghai",
            slug: "raver-night-shanghai",
            description: "Warehouse techno special.",
            coverImageUrl: nil,
            lineupImageUrl: nil,
            eventType: "club",
            organizerName: "Raver Crew",
            venueName: "Warehouse 01",
            venueAddress: "No.88 Xuhui",
            city: "Shanghai",
            country: "CN",
            latitude: nil,
            longitude: nil,
            startDate: now.addingTimeInterval(86400 * 6),
            endDate: now.addingTimeInterval(86400 * 6 + 36000),
            ticketUrl: nil,
            ticketPriceMin: 120,
            ticketPriceMax: 320,
            ticketCurrency: "CNY",
            ticketNotes: nil,
            officialWebsite: nil,
            status: "upcoming",
            isVerified: true,
            createdAt: now.addingTimeInterval(-86400 * 2),
            updatedAt: now.addingTimeInterval(-86400),
            organizer: currentUser,
            ticketTiers: [],
            lineupSlots: []
        )

        events = [mockEvent]

        let defaultTracks: [WebDJSetTrack] = [
            WebDJSetTrack(
                id: "track_default_1",
                position: 1,
                startTime: 0,
                endTime: 92,
                title: "Opening Pressure",
                artist: "Amelie Lens",
                status: "released",
                spotifyUrl: nil,
                spotifyId: nil,
                spotifyUri: nil,
                neteaseUrl: nil,
                neteaseId: nil,
                createdAt: now.addingTimeInterval(-86400 * 8),
                updatedAt: now.addingTimeInterval(-86400 * 8)
            ),
            WebDJSetTrack(
                id: "track_default_2",
                position: 2,
                startTime: 92,
                endTime: 238,
                title: "Dark Warehouse",
                artist: "Charlotte de Witte",
                status: "released",
                spotifyUrl: nil,
                spotifyId: nil,
                spotifyUri: nil,
                neteaseUrl: nil,
                neteaseId: nil,
                createdAt: now.addingTimeInterval(-86400 * 8),
                updatedAt: now.addingTimeInterval(-86400 * 8)
            ),
            WebDJSetTrack(
                id: "track_default_3",
                position: 3,
                startTime: 238,
                endTime: nil,
                title: "Peak Rave ID",
                artist: "Unknown",
                status: "id",
                spotifyUrl: nil,
                spotifyId: nil,
                spotifyUri: nil,
                neteaseUrl: nil,
                neteaseId: nil,
                createdAt: now.addingTimeInterval(-86400 * 8),
                updatedAt: now.addingTimeInterval(-86400 * 8)
            )
        ]

        let setA = WebDJSet(
            id: "set_001",
            djId: djA.id,
            title: "Amelie Lens @ Time Warp",
            slug: "amelie-lens-time-warp",
            description: "Peak-time set.",
            thumbnailUrl: nil,
            videoUrl: "https://storage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
            platform: "native",
            videoId: "BigBuckBunny",
            duration: 5400,
            recordedAt: now.addingTimeInterval(-86400 * 20),
            venue: "Mannheim",
            eventName: "Time Warp",
            viewCount: 10234,
            likeCount: 1200,
            isVerified: true,
            createdAt: now.addingTimeInterval(-86400 * 10),
            updatedAt: now.addingTimeInterval(-86400 * 2),
            uploadedById: currentUser.id,
            coDjIds: [],
            customDjNames: [],
            dj: djA,
            lineupDjs: [djA],
            tracks: defaultTracks,
            trackCount: defaultTracks.count,
            uploader: currentUser,
            videoContributor: currentContributor,
            tracklistContributor: currentContributor
        )

        sets = [setA]

        let userTracklist = WebTracklistDetail(
            id: "tl_user_ana",
            setId: setA.id,
            title: "Ana 的版本",
            isDefault: false,
            createdAt: now.addingTimeInterval(-86400),
            updatedAt: now.addingTimeInterval(-86400),
            contributor: WebContributorProfile(
                id: "u_ana",
                username: "ana",
                displayName: "Ana",
                avatarUrl: nil,
                bio: nil,
                location: "Berlin",
                favoriteGenres: ["techno"],
                favoriteDJs: ["Amelie Lens"]
            ),
            tracks: [
                WebDJSetTrack(
                    id: "track_ana_1",
                    position: 1,
                    startTime: 0,
                    endTime: 90,
                    title: "Opening Pressure",
                    artist: "Amelie Lens",
                    status: "released",
                    spotifyUrl: nil,
                    spotifyId: nil,
                    spotifyUri: nil,
                    neteaseUrl: nil,
                    neteaseId: nil,
                    createdAt: now.addingTimeInterval(-86400),
                    updatedAt: now.addingTimeInterval(-86400)
                ),
                WebDJSetTrack(
                    id: "track_ana_2",
                    position: 2,
                    startTime: 90,
                    endTime: 225,
                    title: "Acid Storm (Edit)",
                    artist: "Charlotte de Witte",
                    status: "edit",
                    spotifyUrl: nil,
                    spotifyId: nil,
                    spotifyUri: nil,
                    neteaseUrl: nil,
                    neteaseId: nil,
                    createdAt: now.addingTimeInterval(-86400),
                    updatedAt: now.addingTimeInterval(-86400)
                ),
                WebDJSetTrack(
                    id: "track_ana_3",
                    position: 3,
                    startTime: 225,
                    endTime: nil,
                    title: "Unknown Weapon",
                    artist: "Unknown",
                    status: "id",
                    spotifyUrl: nil,
                    spotifyId: nil,
                    spotifyUri: nil,
                    neteaseUrl: nil,
                    neteaseId: nil,
                    createdAt: now.addingTimeInterval(-86400),
                    updatedAt: now.addingTimeInterval(-86400)
                )
            ]
        )

        tracklistsBySetID = [
            setA.id: [userTracklist]
        ]

        commentsBySetID = [
            setA.id: [
                WebSetComment(
                    id: "cmt_001",
                    setId: setA.id,
                    userId: "u_ana",
                    content: "Drop at 43:20 is insane.",
                    parentId: nil,
                    createdAt: now.addingTimeInterval(-6000),
                    updatedAt: now.addingTimeInterval(-6000),
                    user: WebUserLite(id: "u_ana", username: "ana", displayName: "Ana", avatarUrl: nil),
                    replies: []
                )
            ]
        ]

        checkins = []
    }

    func fetchEvents(page: Int, limit: Int, search: String?, eventType: String?) async throws -> EventListPage {
        let normalized = search?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        let normalizedType = eventType?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let filtered = events.filter { event in
            let matchesSearch =
                normalized.isEmpty ||
                event.name.lowercased().contains(normalized) ||
                (event.description ?? "").lowercased().contains(normalized)
            let matchesType = normalizedType.isEmpty || event.eventType == normalizedType
            return matchesSearch && matchesType
        }
        let sorted = filtered.sorted(by: { $0.startDate < $1.startDate })
        return paginateEvents(sorted, page: page, limit: limit)
    }

    func fetchEvent(id: String) async throws -> WebEvent {
        guard let item = events.first(where: { $0.id == id }) else {
            throw ServiceError.message("活动不存在")
        }
        return item
    }

    func fetchMyEvents() async throws -> [WebEvent] {
        events.filter { $0.organizer?.id == currentUser.id }.sorted(by: { $0.createdAt > $1.createdAt })
    }

    func createEvent(input: CreateEventInput) async throws -> WebEvent {
        let now = Date()
        let event = WebEvent(
            id: "evt_\(UUID().uuidString)",
            name: input.name,
            slug: slugify(input.name),
            description: input.description,
            coverImageUrl: input.coverImageUrl,
            lineupImageUrl: nil,
            eventType: "club",
            organizerName: currentUser.displayName,
            venueName: input.venueName,
            venueAddress: nil,
            city: input.city,
            country: input.country,
            latitude: nil,
            longitude: nil,
            startDate: input.startDate,
            endDate: input.endDate,
            ticketUrl: nil,
            ticketPriceMin: nil,
            ticketPriceMax: nil,
            ticketCurrency: nil,
            ticketNotes: nil,
            officialWebsite: nil,
            status: input.status ?? "upcoming",
            isVerified: false,
            createdAt: now,
            updatedAt: now,
            organizer: currentUser,
            ticketTiers: [],
            lineupSlots: []
        )
        events.insert(event, at: 0)
        return event
    }

    func updateEvent(id: String, input: UpdateEventInput) async throws -> WebEvent {
        guard let idx = events.firstIndex(where: { $0.id == id }) else {
            throw ServiceError.message("活动不存在")
        }
        if events[idx].organizer?.id != currentUser.id {
            throw ServiceError.message("Forbidden")
        }
        if let name = input.name { events[idx].name = name }
        if let description = input.description { events[idx].description = description }
        if let city = input.city { events[idx].city = city }
        if let country = input.country { events[idx].country = country }
        if let venueName = input.venueName { events[idx].venueName = venueName }
        if let startDate = input.startDate { events[idx].startDate = startDate }
        if let endDate = input.endDate { events[idx].endDate = endDate }
        if let coverImageUrl = input.coverImageUrl { events[idx].coverImageUrl = coverImageUrl }
        if let status = input.status { events[idx].status = status }
        events[idx].updatedAt = Date()
        return events[idx]
    }

    func deleteEvent(id: String) async throws {
        guard let idx = events.firstIndex(where: { $0.id == id }) else {
            throw ServiceError.message("活动不存在")
        }
        if events[idx].organizer?.id != currentUser.id {
            throw ServiceError.message("Forbidden")
        }
        events.remove(at: idx)
    }

    func uploadEventImage(imageData: Data, fileName: String, mimeType: String) async throws -> UploadMediaResponse {
        _ = imageData
        return UploadMediaResponse(url: "/uploads/events/mock-\(fileName)", fileName: fileName, mimeType: mimeType, size: 1)
    }

    func fetchDJs(page: Int, limit: Int, search: String?, sortBy: String) async throws -> DJListPage {
        let normalized = search?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        var filtered = djs.filter { item in
            normalized.isEmpty || item.name.lowercased().contains(normalized)
        }

        switch sortBy {
        case "name":
            filtered.sort(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })
        case "createdAt":
            filtered.sort(by: { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) })
        default:
            filtered.sort(by: { ($0.followerCount ?? 0) > ($1.followerCount ?? 0) })
        }

        let normalizedPage = max(1, page)
        let normalizedLimit = max(1, min(100, limit))
        let start = (normalizedPage - 1) * normalizedLimit
        let end = min(start + normalizedLimit, filtered.count)
        let slice = start < end ? Array(filtered[start..<end]) : []

        return DJListPage(
            items: slice,
            pagination: BFFPagination(
                page: normalizedPage,
                limit: normalizedLimit,
                total: filtered.count,
                totalPages: max(1, Int(ceil(Double(filtered.count) / Double(normalizedLimit))))
            )
        )
    }

    func fetchDJ(id: String) async throws -> WebDJ {
        guard let dj = djs.first(where: { $0.id == id }) else {
            throw ServiceError.message("DJ 不存在")
        }
        return dj
    }

    func fetchDJSets(djID: String) async throws -> [WebDJSet] {
        sets.filter { $0.djId == djID }.sorted(by: { $0.createdAt > $1.createdAt })
    }

    func fetchDJFollowStatus(djID: String) async throws -> Bool {
        djs.first(where: { $0.id == djID })?.isFollowing ?? false
    }

    func toggleDJFollow(djID: String, shouldFollow: Bool) async throws -> WebDJ {
        guard let idx = djs.firstIndex(where: { $0.id == djID }) else {
            throw ServiceError.message("DJ 不存在")
        }
        if djs[idx].isFollowing != shouldFollow {
            djs[idx].isFollowing = shouldFollow
            let currentCount = djs[idx].followerCount ?? 0
            djs[idx].followerCount = max(0, currentCount + (shouldFollow ? 1 : -1))
            djs[idx].updatedAt = Date()
        }
        return djs[idx]
    }

    func fetchDJSets(page: Int, limit: Int, sortBy: String, djID: String?) async throws -> DJSetListPage {
        var filtered = sets
        if let djID, !djID.isEmpty {
            filtered = filtered.filter { $0.djId == djID }
        }

        switch sortBy {
        case "popular":
            filtered.sort(by: { $0.viewCount > $1.viewCount })
        case "tracks":
            filtered.sort(by: { $0.trackCount > $1.trackCount })
        default:
            filtered.sort(by: { $0.createdAt > $1.createdAt })
        }

        let normalizedPage = max(1, page)
        let normalizedLimit = max(1, min(100, limit))
        let start = (normalizedPage - 1) * normalizedLimit
        let end = min(start + normalizedLimit, filtered.count)
        let slice = start < end ? Array(filtered[start..<end]) : []

        return DJSetListPage(
            items: slice,
            pagination: BFFPagination(
                page: normalizedPage,
                limit: normalizedLimit,
                total: filtered.count,
                totalPages: max(1, Int(ceil(Double(filtered.count) / Double(normalizedLimit))))
            )
        )
    }

    func fetchDJSet(id: String) async throws -> WebDJSet {
        guard let item = sets.first(where: { $0.id == id }) else {
            throw ServiceError.message("Set 不存在")
        }
        return item
    }

    func fetchMyDJSets() async throws -> [WebDJSet] {
        sets.filter { $0.uploadedById == currentUser.id }.sorted(by: { $0.createdAt > $1.createdAt })
    }

    func createDJSet(input: CreateDJSetInput) async throws -> WebDJSet {
        guard let dj = djs.first(where: { $0.id == input.djId }) else {
            throw ServiceError.message("DJ 不存在")
        }

        let parsed = parseVideo(input.videoUrl)
        let set = WebDJSet(
            id: "set_\(UUID().uuidString)",
            djId: input.djId,
            title: input.title,
            slug: slugify(input.title),
            description: input.description,
            thumbnailUrl: input.thumbnailUrl,
            videoUrl: input.videoUrl,
            platform: parsed.platform,
            videoId: parsed.videoId,
            duration: 0,
            recordedAt: input.recordedAt,
            venue: input.venue,
            eventName: input.eventName,
            viewCount: 0,
            likeCount: 0,
            isVerified: false,
            createdAt: Date(),
            updatedAt: Date(),
            uploadedById: currentUser.id,
            coDjIds: [],
            customDjNames: [],
            dj: dj,
            lineupDjs: [dj],
            tracks: [],
            trackCount: 0,
            uploader: currentUser,
            videoContributor: currentContributor,
            tracklistContributor: nil
        )

        sets.insert(set, at: 0)
        tracklistsBySetID[set.id] = []
        return set
    }

    func updateDJSet(id: String, input: UpdateDJSetInput) async throws -> WebDJSet {
        guard let idx = sets.firstIndex(where: { $0.id == id }) else {
            throw ServiceError.message("Set 不存在")
        }
        if sets[idx].uploadedById != currentUser.id {
            throw ServiceError.message("Forbidden")
        }

        if let djId = input.djId {
            guard let dj = djs.first(where: { $0.id == djId }) else {
                throw ServiceError.message("DJ 不存在")
            }
            sets[idx].djId = dj.id
            sets[idx].dj = dj
            sets[idx].lineupDjs = [dj]
        }
        if let title = input.title { sets[idx].title = title }
        if let description = input.description { sets[idx].description = description }
        if let videoUrl = input.videoUrl {
            sets[idx].videoUrl = videoUrl
            let parsed = parseVideo(videoUrl)
            sets[idx].platform = parsed.platform
            sets[idx].videoId = parsed.videoId
        }
        if let thumbnail = input.thumbnailUrl { sets[idx].thumbnailUrl = thumbnail }
        if let venue = input.venue { sets[idx].venue = venue }
        if let eventName = input.eventName { sets[idx].eventName = eventName }
        if let recordedAt = input.recordedAt { sets[idx].recordedAt = recordedAt }
        sets[idx].updatedAt = Date()
        return sets[idx]
    }

    func deleteDJSet(id: String) async throws {
        guard let idx = sets.firstIndex(where: { $0.id == id }) else {
            throw ServiceError.message("Set 不存在")
        }
        if sets[idx].uploadedById != currentUser.id {
            throw ServiceError.message("Forbidden")
        }
        sets.remove(at: idx)
        commentsBySetID.removeValue(forKey: id)
        tracklistsBySetID.removeValue(forKey: id)
    }

    func replaceTracks(setID: String, tracks: [CreateTrackInput]) async throws -> WebDJSet {
        guard let idx = sets.firstIndex(where: { $0.id == setID }) else {
            throw ServiceError.message("Set 不存在")
        }
        if sets[idx].uploadedById != currentUser.id {
            throw ServiceError.message("Forbidden")
        }

        let now = Date()
        sets[idx].tracks = tracks.enumerated().map { index, track in
            WebDJSetTrack(
                id: "track_\(UUID().uuidString)",
                position: track.position == 0 ? index + 1 : track.position,
                startTime: track.startTime,
                endTime: track.endTime,
                title: track.title,
                artist: track.artist,
                status: track.status,
                spotifyUrl: track.spotifyUrl,
                spotifyId: nil,
                spotifyUri: nil,
                neteaseUrl: track.neteaseUrl,
                neteaseId: nil,
                createdAt: now,
                updatedAt: now
            )
        }
        sets[idx].trackCount = sets[idx].tracks.count
        sets[idx].tracklistContributor = currentContributor
        sets[idx].updatedAt = Date()
        return sets[idx]
    }

    func fetchTracklists(setID: String) async throws -> [WebTracklistSummary] {
        guard sets.contains(where: { $0.id == setID }) else {
            throw ServiceError.message("Set 不存在")
        }

        let details = tracklistsBySetID[setID, default: []].sorted(by: { $0.createdAt > $1.createdAt })
        return details.map { detail in
            WebTracklistSummary(
                id: detail.id,
                setId: detail.setId,
                title: detail.title,
                isDefault: detail.isDefault,
                createdAt: detail.createdAt,
                updatedAt: detail.updatedAt,
                contributor: detail.contributor,
                trackCount: detail.tracks.count
            )
        }
    }

    func fetchTracklistDetail(setID: String, tracklistID: String) async throws -> WebTracklistDetail {
        guard sets.contains(where: { $0.id == setID }) else {
            throw ServiceError.message("Set 不存在")
        }
        guard let detail = tracklistsBySetID[setID, default: []].first(where: { $0.id == tracklistID }) else {
            throw ServiceError.message("Tracklist 不存在")
        }
        return detail
    }

    func createTracklist(setID: String, input: CreateTracklistInput) async throws -> WebTracklistDetail {
        guard sets.contains(where: { $0.id == setID }) else {
            throw ServiceError.message("Set 不存在")
        }

        let tracks = input.tracks.enumerated().map { index, item in
            WebDJSetTrack(
                id: "tracklist_track_\(UUID().uuidString)",
                position: item.position == 0 ? index + 1 : item.position,
                startTime: max(0, item.startTime),
                endTime: item.endTime,
                title: item.title,
                artist: item.artist,
                status: item.status,
                spotifyUrl: item.spotifyUrl,
                spotifyId: nil,
                spotifyUri: nil,
                neteaseUrl: item.neteaseUrl,
                neteaseId: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
        }.sorted(by: { $0.startTime < $1.startTime })

        guard !tracks.isEmpty else {
            throw ServiceError.message("Tracklist 至少包含 1 条有效曲目")
        }

        let detail = WebTracklistDetail(
            id: "tracklist_\(UUID().uuidString)",
            setId: setID,
            title: input.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? input.title : nil,
            isDefault: false,
            createdAt: Date(),
            updatedAt: Date(),
            contributor: currentContributor,
            tracks: tracks
        )
        tracklistsBySetID[setID, default: []].insert(detail, at: 0)
        return detail
    }

    func autoLinkTracks(setID: String) async throws {
        guard let idx = sets.firstIndex(where: { $0.id == setID }) else {
            throw ServiceError.message("Set 不存在")
        }
        var value = sets[idx]
        value.tracks = value.tracks.map { track in
            var updated = track
            if updated.spotifyUrl == nil {
                updated.spotifyUrl = "https://open.spotify.com/search/\(updated.artist)%20\(updated.title)"
            }
            return updated
        }
        sets[idx] = value
    }

    func previewVideo(videoURL: String) async throws -> [String : String] {
        let parsed = parseVideo(videoURL)
        return [
            "platform": parsed.platform,
            "videoId": parsed.videoId,
            "title": "Preview for \(parsed.videoId)",
            "description": "Auto parsed preview",
            "thumbnailUrl": ""
        ]
    }

    func uploadSetThumbnail(imageData: Data, fileName: String, mimeType: String) async throws -> UploadMediaResponse {
        _ = imageData
        return UploadMediaResponse(url: "/uploads/dj-sets/mock-\(fileName)", fileName: fileName, mimeType: mimeType, size: 1)
    }

    func uploadSetVideo(videoData: Data, fileName: String, mimeType: String) async throws -> UploadMediaResponse {
        _ = videoData
        let normalizedName = fileName.isEmpty ? "video-\(UUID().uuidString).mp4" : fileName
        return UploadMediaResponse(url: "/uploads/dj-sets/mock-\(normalizedName)", fileName: normalizedName, mimeType: mimeType, size: 1)
    }

    func fetchSetComments(setID: String) async throws -> [WebSetComment] {
        commentsBySetID[setID, default: []].sorted(by: { $0.createdAt > $1.createdAt })
    }

    func addSetComment(setID: String, input: CreateSetCommentInput) async throws -> WebSetComment {
        let content = input.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else {
            throw ServiceError.message("评论不能为空")
        }

        let item = WebSetComment(
            id: "cmt_\(UUID().uuidString)",
            setId: setID,
            userId: currentUser.id,
            content: content,
            parentId: input.parentId,
            createdAt: Date(),
            updatedAt: Date(),
            user: currentUser,
            replies: []
        )
        commentsBySetID[setID, default: []].insert(item, at: 0)
        return item
    }

    func updateSetComment(commentID: String, content: String) async throws -> WebSetComment {
        for key in commentsBySetID.keys {
            guard var items = commentsBySetID[key] else { continue }
            if let index = items.firstIndex(where: { $0.id == commentID && $0.userId == currentUser.id }) {
                items[index].content = content
                items[index].updatedAt = Date()
                commentsBySetID[key] = items
                return items[index]
            }
        }
        throw ServiceError.message("评论不存在")
    }

    func deleteSetComment(commentID: String) async throws {
        for key in commentsBySetID.keys {
            guard var items = commentsBySetID[key] else { continue }
            if let index = items.firstIndex(where: { $0.id == commentID && $0.userId == currentUser.id }) {
                items.remove(at: index)
                commentsBySetID[key] = items
                return
            }
        }
        throw ServiceError.message("评论不存在")
    }

    func fetchMyCheckins(page: Int, limit: Int, type: String?) async throws -> CheckinListPage {
        let normalizedType = type?.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = checkins.filter { item in
            normalizedType == nil || normalizedType == "" || item.type == normalizedType
        }.sorted(by: { $0.createdAt > $1.createdAt })

        let normalizedPage = max(1, page)
        let normalizedLimit = max(1, min(100, limit))
        let start = (normalizedPage - 1) * normalizedLimit
        let end = min(start + normalizedLimit, filtered.count)
        let slice = start < end ? Array(filtered[start..<end]) : []

        return CheckinListPage(
            items: slice,
            pagination: BFFPagination(
                page: normalizedPage,
                limit: normalizedLimit,
                total: filtered.count,
                totalPages: max(1, Int(ceil(Double(filtered.count) / Double(normalizedLimit))))
            )
        )
    }

    func createCheckin(input: CreateCheckinInput) async throws -> WebCheckin {
        guard input.type == "event" || input.type == "dj" else {
            throw ServiceError.message("type 必须是 event 或 dj")
        }

        let event = input.eventId.flatMap { id in events.first(where: { $0.id == id }) }
        let dj = input.djId.flatMap { id in djs.first(where: { $0.id == id }) }

        if input.type == "event" && event == nil {
            throw ServiceError.message("活动不存在")
        }
        if input.type == "dj" && dj == nil {
            throw ServiceError.message("DJ 不存在")
        }

        let item = WebCheckin(
            id: "chk_\(UUID().uuidString)",
            userId: currentUser.id,
            eventId: event?.id,
            djId: dj?.id,
            type: input.type,
            note: input.note,
            photoUrl: nil,
            rating: input.rating,
            createdAt: Date(),
            event: event.map { CheckinEventLite(id: $0.id, name: $0.name, coverImageUrl: $0.coverImageUrl, city: $0.city, country: $0.country) },
            dj: dj.map { CheckinDJLite(id: $0.id, name: $0.name, avatarUrl: $0.avatarUrl, country: $0.country) }
        )
        checkins.insert(item, at: 0)
        return item
    }

    func deleteCheckin(id: String) async throws {
        guard let idx = checkins.firstIndex(where: { $0.id == id }) else {
            throw ServiceError.message("打卡不存在")
        }
        checkins.remove(at: idx)
    }

    func fetchLearnGenres() async throws -> [LearnGenreNode] {
        [
            LearnGenreNode(
                id: "house",
                name: "House",
                description: "四拍地板鼓点为核心。",
                children: [
                    LearnGenreNode(id: "deep-house", name: "Deep House", description: "柔和、氛围化。", children: nil),
                    LearnGenreNode(id: "tech-house", name: "Tech House", description: "节奏简洁、律动强。", children: nil)
                ]
            ),
            LearnGenreNode(
                id: "techno",
                name: "Techno",
                description: "工业感与重复推进。",
                children: [
                    LearnGenreNode(id: "melodic-techno", name: "Melodic Techno", description: "旋律驱动。", children: nil),
                    LearnGenreNode(id: "hard-techno", name: "Hard Techno", description: "更快更硬。", children: nil)
                ]
            )
        ]
    }

    func fetchRankingBoards() async throws -> [RankingBoard] {
        [
            RankingBoard(
                id: "djmag",
                title: "DJ MAG TOP 100",
                subtitle: "全球电子音乐最有影响力榜单之一",
                coverImageUrl: nil,
                years: [2022, 2023, 2024, 2025]
            ),
            RankingBoard(
                id: "dongye",
                title: "东野 DJ 榜",
                subtitle: "中文圈 DJ 热度与影响力榜单",
                coverImageUrl: nil,
                years: [2024, 2025]
            )
        ]
    }

    func fetchRankingBoardDetail(boardID: String, year: Int?) async throws -> RankingBoardDetail {
        let boards = try await fetchRankingBoards()
        guard let board = boards.first(where: { $0.id == boardID }) else {
            throw ServiceError.message("榜单不存在")
        }
        let selectedYear = year ?? board.years.last ?? 2025
        let entries = djs.enumerated().map { index, dj in
            RankingEntry(rank: index + 1, name: dj.name, delta: Int.random(in: -3...3), dj: dj)
        }
        return RankingBoardDetail(boardId: board.id, title: board.title, years: board.years, year: selectedYear, entries: entries)
    }

    func fetchMyPublishes() async throws -> MyPublishes {
        let mySets = sets
            .filter { $0.uploadedById == currentUser.id }
            .sorted(by: { $0.createdAt > $1.createdAt })
            .map {
                MyPublishSet(
                    id: $0.id,
                    title: $0.title,
                    thumbnailUrl: $0.thumbnailUrl,
                    createdAt: $0.createdAt,
                    trackCount: $0.trackCount,
                    dj: $0.dj
                )
            }

        let myEvents = events
            .filter { $0.organizer?.id == currentUser.id }
            .sorted(by: { $0.createdAt > $1.createdAt })
            .map {
                MyPublishEvent(
                    id: $0.id,
                    name: $0.name,
                    coverImageUrl: $0.coverImageUrl,
                    city: $0.city,
                    country: $0.country,
                    startDate: $0.startDate,
                    createdAt: $0.createdAt,
                    lineupSlotCount: $0.lineupSlots.count
                )
            }

        return MyPublishes(djSets: mySets, events: myEvents)
    }

    private func slugify(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    private func paginateEvents(_ source: [WebEvent], page: Int, limit: Int) -> EventListPage {
        let normalizedPage = max(1, page)
        let normalizedLimit = max(1, min(100, limit))
        let start = (normalizedPage - 1) * normalizedLimit
        let end = min(start + normalizedLimit, source.count)
        let slice = start < end ? Array(source[start..<end]) : []

        return EventListPage(
            items: slice,
            pagination: BFFPagination(
                page: normalizedPage,
                limit: normalizedLimit,
                total: source.count,
                totalPages: max(1, Int(ceil(Double(source.count) / Double(normalizedLimit))))
            )
        )
    }

    private func parseVideo(_ url: String) -> (platform: String, videoId: String) {
        let lower = url.lowercased()
        let nativeExtensions = [".mp4", ".mov", ".m4v", ".webm", ".m3u8"]
        if lower.contains("/uploads/") || nativeExtensions.contains(where: { lower.contains($0) }) {
            let last = url.split(separator: "/").last.map(String.init) ?? UUID().uuidString
            let videoId = last.replacingOccurrences(of: "\\.[^.]+$", with: "", options: .regularExpression)
            return ("native", videoId.isEmpty ? UUID().uuidString : videoId)
        }

        if let match = url.range(of: "v=") {
            let id = String(url[match.upperBound...].split(separator: "&").first ?? "")
            return ("youtube", id.isEmpty ? UUID().uuidString : id)
        }
        if let last = url.split(separator: "/").last {
            return ("youtube", String(last))
        }
        return ("youtube", UUID().uuidString)
    }
}
