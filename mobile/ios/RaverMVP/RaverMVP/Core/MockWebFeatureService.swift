import Foundation

actor MockWebFeatureService: WebFeatureService {
    private static func seededAvatarURL(for seed: String) -> String {
        let encoded = seed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? seed
        return "https://api.dicebear.com/9.x/adventurer-neutral/png?seed=\(encoded)&backgroundType=gradientLinear"
    }

    private let currentUser = WebUserLite(
        id: "u_me",
        username: "blackie",
        displayName: "Blackie",
        avatarUrl: MockWebFeatureService.seededAvatarURL(for: "u_me")
    )
    private let currentContributor = WebContributorProfile(
        id: "u_me",
        username: "blackie",
        displayName: "Blackie",
        avatarUrl: MockWebFeatureService.seededAvatarURL(for: "u_me"),
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
    private var ratingEvents: [WebRatingEvent]

    init() {
        let now = Date()
        let djA = WebDJ(
            id: "dj_amelie",
            name: "Amelie Lens",
            aliases: ["莲姐", "硬核女王"],
            slug: "amelie-lens",
            bio: "Hard techno headliner.",
            avatarUrl: Self.seededAvatarURL(for: "dj_amelie"),
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
            aliases: ["CDW", "夏洛特"],
            slug: "charlotte-de-witte",
            bio: "Dark peak-time techno.",
            avatarUrl: Self.seededAvatarURL(for: "dj_charlotte"),
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
            lineupSlots: [
                WebEventLineupSlot(
                    id: "slot_evt_shanghai_001_1",
                    eventId: "evt_shanghai_001",
                    djId: "dj_amelie",
                    djName: "Amelie Lens",
                    stageName: "Main Stage",
                    sortOrder: 1,
                    startTime: now.addingTimeInterval(86400 * 6 + 3600),
                    endTime: now.addingTimeInterval(86400 * 6 + 7200),
                    dj: WebEventLineupSlotDJ(
                        id: "dj_amelie",
                        name: "Amelie Lens",
                        avatarUrl: Self.seededAvatarURL(for: "dj_amelie"),
                        bannerUrl: nil,
                        country: "BE"
                    )
                )
            ]
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
                username: "acid_ana",
                displayName: "Ana",
                avatarUrl: Self.seededAvatarURL(for: "u_ana"),
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
                    user: WebUserLite(
                        id: "u_ana",
                        username: "acid_ana",
                        displayName: "Ana",
                        avatarUrl: Self.seededAvatarURL(for: "u_ana")
                    ),
                    replies: []
                )
            ]
        ]

        checkins = []

        ratingEvents = [
            WebRatingEvent(
                id: "rating_event_vac_2026_spring",
                name: "VAC 电音节 2026 春季",
                description: "两天多舞台活动，包含主舞台、仓库舞台与 afterparty。",
                imageUrl: nil,
                createdAt: now.addingTimeInterval(-86400 * 6),
                updatedAt: now.addingTimeInterval(-86400 * 2),
                createdBy: currentUser,
                units: [
                    WebRatingUnit(
                        id: "rating_unit_vac_main_stage_day1",
                        eventId: "rating_event_vac_2026_spring",
                        name: "主舞台 Day1",
                        description: "灯光编排、音响、观演体验",
                        imageUrl: nil,
                        createdAt: now.addingTimeInterval(-86400 * 6),
                        updatedAt: now.addingTimeInterval(-86400 * 2),
                        rating: 9.0,
                        ratingCount: 1,
                        comments: [
                            WebRatingComment(
                                id: "rating_comment_1",
                                unitId: "rating_unit_vac_main_stage_day1",
                                userId: "u_ana",
                                score: 9,
                                content: "开场节奏很好，低频很稳。",
                                createdAt: now.addingTimeInterval(-7200),
                                updatedAt: now.addingTimeInterval(-7200),
                                user: WebUserLite(
                                    id: "u_ana",
                                    username: "acid_ana",
                                    displayName: "Ana",
                                    avatarUrl: Self.seededAvatarURL(for: "u_ana")
                                )
                            )
                        ],
                        event: nil,
                        createdBy: currentUser
                    ),
                    WebRatingUnit(
                        id: "rating_unit_vac_warehouse_day1",
                        eventId: "rating_event_vac_2026_spring",
                        name: "仓库舞台 Day1",
                        description: "Techno 专场",
                        imageUrl: nil,
                        createdAt: now.addingTimeInterval(-86400 * 5),
                        updatedAt: now.addingTimeInterval(-86400 * 3),
                        rating: 0,
                        ratingCount: 0,
                        comments: [],
                        event: nil,
                        createdBy: currentUser
                    )
                ]
            )
        ]
    }

    func fetchEvents(page: Int, limit: Int, search: String?, eventType: String?, status: String?) async throws -> EventListPage {
        let normalized = search?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        let normalizedType = eventType?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let normalizedStatus = status?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        let filtered = events.filter { event in
            let matchesSearch =
                normalized.isEmpty ||
                event.name.lowercased().contains(normalized) ||
                (event.description ?? "").lowercased().contains(normalized)
            let matchesType = normalizedType.isEmpty || event.eventType == normalizedType
            let resolvedStatus = resolveEventStatus(for: event)
            let matchesStatus = normalizedStatus.isEmpty || normalizedStatus == "all" || resolvedStatus == normalizedStatus
            return matchesSearch && matchesType && matchesStatus
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
        let eventID = "evt_\(UUID().uuidString)"
        let lineupSlots = buildLineupSlots(
            from: input.lineupSlots ?? [],
            eventID: eventID,
            eventStartDate: input.startDate
        )
        let event = WebEvent(
            id: eventID,
            name: input.name,
            slug: slugify(input.name),
            description: input.description,
            coverImageUrl: input.coverImageUrl,
            lineupImageUrl: input.lineupImageUrl,
            eventType: {
                let trimmed = input.eventType?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return trimmed.isEmpty ? nil : trimmed
            }(),
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
            lineupSlots: lineupSlots
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
        if let lineupImageUrl = input.lineupImageUrl { events[idx].lineupImageUrl = lineupImageUrl }
        if let eventType = input.eventType {
            let trimmed = eventType.trimmingCharacters(in: .whitespacesAndNewlines)
            events[idx].eventType = trimmed.isEmpty ? nil : trimmed
        }
        if let status = input.status { events[idx].status = status }
        if let lineupSlots = input.lineupSlots {
            events[idx].lineupSlots = buildLineupSlots(
                from: lineupSlots,
                eventID: events[idx].id,
                eventStartDate: events[idx].startDate
            )
        }
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
            normalized.isEmpty
                || item.name.lowercased().contains(normalized)
                || (item.aliases?.contains(where: { $0.lowercased().contains(normalized) }) ?? false)
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

    func fetchDJEvents(djID: String) async throws -> [WebEvent] {
        events
            .filter { event in
                event.lineupSlots.contains(where: { $0.djId == djID })
            }
            .sorted(by: { $0.startDate > $1.startDate })
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
        try await fetchUserCheckins(userID: currentUser.id, page: page, limit: limit, type: type)
    }

    func fetchUserCheckins(userID: String, page: Int, limit: Int, type: String?) async throws -> CheckinListPage {
        let normalizedType = type?.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = checkins.filter { item in
            item.userId == userID
                && (normalizedType == nil || normalizedType == "" || item.type == normalizedType)
        }.sorted(by: { $0.attendedAt > $1.attendedAt })

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

    func fetchMyDJCheckinCount(djID: String) async throws -> Int {
        checkins.filter { item in
            item.userId == currentUser.id
                && item.type == "dj"
                && item.djId == djID
        }.count
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
            attendedAt: input.attendedAt ?? Date(),
            createdAt: Date(),
            event: event.map {
                CheckinEventLite(
                    id: $0.id,
                    name: $0.name,
                    coverImageUrl: $0.coverImageUrl,
                    city: $0.city,
                    country: $0.country,
                    startDate: $0.startDate,
                    endDate: $0.endDate
                )
            },
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

    func fetchRatingEvents() async throws -> [WebRatingEvent] {
        ratingEvents
            .sorted(by: { $0.createdAt > $1.createdAt })
            .map { event in
                var normalized = event
                normalized.units = event.units.map(normalizeRatingUnit)
                return normalized
            }
    }

    func fetchRatingEvent(id: String) async throws -> WebRatingEvent {
        guard let event = ratingEvents.first(where: { $0.id == id }) else {
            throw ServiceError.message("打分事件不存在")
        }
        var normalized = event
        normalized.units = event.units.map(normalizeRatingUnit)
        return normalized
    }

    func createRatingEvent(input: CreateRatingEventInput) async throws -> WebRatingEvent {
        let name = input.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            throw ServiceError.message("事件名称不能为空")
        }

        let now = Date()
        let created = WebRatingEvent(
            id: "rating_event_\(UUID().uuidString)",
            name: name,
            description: input.description?.trimmingCharacters(in: .whitespacesAndNewlines),
            imageUrl: input.imageUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: now,
            updatedAt: now,
            createdBy: currentUser,
            units: []
        )
        ratingEvents.insert(created, at: 0)
        return created
    }

    func createRatingUnit(eventID: String, input: CreateRatingUnitInput) async throws -> WebRatingUnit {
        guard let eventIndex = ratingEvents.firstIndex(where: { $0.id == eventID }) else {
            throw ServiceError.message("打分事件不存在")
        }
        let name = input.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            throw ServiceError.message("打分单位名称不能为空")
        }

        let now = Date()
        let created = WebRatingUnit(
            id: "rating_unit_\(UUID().uuidString)",
            eventId: eventID,
            name: name,
            description: input.description?.trimmingCharacters(in: .whitespacesAndNewlines),
            imageUrl: input.imageUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: now,
            updatedAt: now,
            rating: 0,
            ratingCount: 0,
            comments: [],
            event: nil,
            createdBy: currentUser
        )
        ratingEvents[eventIndex].units.append(created)
        ratingEvents[eventIndex].updatedAt = now
        return created
    }

    func updateRatingEvent(id: String, input: UpdateRatingEventInput) async throws -> WebRatingEvent {
        guard let eventIndex = ratingEvents.firstIndex(where: { $0.id == id }) else {
            throw ServiceError.message("打分事件不存在")
        }
        guard ratingEvents[eventIndex].createdBy?.id == currentUser.id else {
            throw ServiceError.message("Forbidden")
        }

        if let name = input.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            ratingEvents[eventIndex].name = name
        }
        if let description = input.description {
            let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
            ratingEvents[eventIndex].description = trimmed.isEmpty ? nil : trimmed
        }
        if let imageUrl = input.imageUrl {
            let trimmed = imageUrl.trimmingCharacters(in: .whitespacesAndNewlines)
            ratingEvents[eventIndex].imageUrl = trimmed.isEmpty ? nil : trimmed
        }
        ratingEvents[eventIndex].updatedAt = Date()
        return ratingEvents[eventIndex]
    }

    func deleteRatingEvent(id: String) async throws {
        guard let eventIndex = ratingEvents.firstIndex(where: { $0.id == id }) else {
            throw ServiceError.message("打分事件不存在")
        }
        guard ratingEvents[eventIndex].createdBy?.id == currentUser.id else {
            throw ServiceError.message("Forbidden")
        }
        ratingEvents.remove(at: eventIndex)
    }

    func updateRatingUnit(id: String, input: UpdateRatingUnitInput) async throws -> WebRatingUnit {
        for eventIndex in ratingEvents.indices {
            guard let unitIndex = ratingEvents[eventIndex].units.firstIndex(where: { $0.id == id }) else { continue }
            guard ratingEvents[eventIndex].units[unitIndex].createdBy?.id == currentUser.id else {
                throw ServiceError.message("Forbidden")
            }

            if let name = input.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
                ratingEvents[eventIndex].units[unitIndex].name = name
            }
            if let description = input.description {
                let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
                ratingEvents[eventIndex].units[unitIndex].description = trimmed.isEmpty ? nil : trimmed
            }
            if let imageUrl = input.imageUrl {
                let trimmed = imageUrl.trimmingCharacters(in: .whitespacesAndNewlines)
                ratingEvents[eventIndex].units[unitIndex].imageUrl = trimmed.isEmpty ? nil : trimmed
            }
            let now = Date()
            ratingEvents[eventIndex].units[unitIndex].updatedAt = now
            ratingEvents[eventIndex].updatedAt = now
            return normalizeRatingUnit(ratingEvents[eventIndex].units[unitIndex])
        }
        throw ServiceError.message("打分单位不存在")
    }

    func deleteRatingUnit(id: String) async throws {
        for eventIndex in ratingEvents.indices {
            guard let unitIndex = ratingEvents[eventIndex].units.firstIndex(where: { $0.id == id }) else { continue }
            guard ratingEvents[eventIndex].units[unitIndex].createdBy?.id == currentUser.id else {
                throw ServiceError.message("Forbidden")
            }
            ratingEvents[eventIndex].units.remove(at: unitIndex)
            ratingEvents[eventIndex].updatedAt = Date()
            return
        }
        throw ServiceError.message("打分单位不存在")
    }

    func fetchRatingUnit(id: String) async throws -> WebRatingUnit {
        for event in ratingEvents {
            if let unit = event.units.first(where: { $0.id == id }) {
                var normalized = normalizeRatingUnit(unit)
                normalized.event = WebRatingUnitEventLite(
                    id: event.id,
                    name: event.name,
                    description: event.description,
                    imageUrl: event.imageUrl
                )
                return normalized
            }
        }
        throw ServiceError.message("打分单位不存在")
    }

    func addRatingComment(unitID: String, input: CreateRatingCommentInput) async throws -> WebRatingComment {
        let content = input.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let score = min(10, max(1, round(input.score)))
        guard !content.isEmpty else {
            throw ServiceError.message("评论不能为空")
        }
        guard input.score >= 1 else {
            throw ServiceError.message("请先评分")
        }

        for eventIndex in ratingEvents.indices {
            guard let unitIndex = ratingEvents[eventIndex].units.firstIndex(where: { $0.id == unitID }) else { continue }
            let now = Date()
            let created = WebRatingComment(
                id: "rating_comment_\(UUID().uuidString)",
                unitId: unitID,
                userId: currentUser.id,
                score: score,
                content: content,
                createdAt: now,
                updatedAt: now,
                user: currentUser
            )
            ratingEvents[eventIndex].units[unitIndex].comments.insert(created, at: 0)
            ratingEvents[eventIndex].units[unitIndex] = normalizeRatingUnit(ratingEvents[eventIndex].units[unitIndex])
            ratingEvents[eventIndex].units[unitIndex].updatedAt = now
            ratingEvents[eventIndex].updatedAt = now
            return created
        }

        throw ServiceError.message("打分单位不存在")
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

        let myRatingEvents = ratingEvents
            .filter { $0.createdBy?.id == currentUser.id }
            .sorted(by: { $0.createdAt > $1.createdAt })
            .map {
                MyPublishRatingEvent(
                    id: $0.id,
                    name: $0.name,
                    imageUrl: $0.imageUrl,
                    description: $0.description,
                    unitCount: $0.units.count,
                    createdAt: $0.createdAt
                )
            }

        let myRatingUnits = ratingEvents
            .flatMap { event in
                event.units
                    .filter { $0.createdBy?.id == currentUser.id }
                    .map { unit in
                        MyPublishRatingUnit(
                            id: unit.id,
                            eventId: event.id,
                            eventName: event.name,
                            name: unit.name,
                            imageUrl: unit.imageUrl,
                            description: unit.description,
                            createdAt: unit.createdAt
                        )
                    }
            }
            .sorted(by: { $0.createdAt > $1.createdAt })

        return MyPublishes(djSets: mySets, events: myEvents, ratingEvents: myRatingEvents, ratingUnits: myRatingUnits)
    }

    private func slugify(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    private func resolveEventStatus(for event: WebEvent, now: Date = Date()) -> String {
        if now < event.startDate {
            return "upcoming"
        }
        if now > event.endDate {
            return "ended"
        }
        return "ongoing"
    }

    private func buildLineupSlots(
        from inputSlots: [EventLineupSlotInput],
        eventID: String,
        eventStartDate: Date
    ) -> [WebEventLineupSlot] {
        inputSlots.enumerated().compactMap { index, slot in
            let trimmedName = slot.djName.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchedDJ = djs.first(where: { $0.id == slot.djId }) ??
                djs.first(where: { $0.name.compare(trimmedName, options: .caseInsensitive) == .orderedSame })
            let finalDJName = trimmedName.isEmpty ? (matchedDJ?.name ?? "Unknown DJ") : trimmedName
            guard !finalDJName.isEmpty else { return nil }

            let fallbackBase = eventStartDate.addingTimeInterval(Double(index) * 60)
            let startCandidate = slot.startTime
            let endCandidate = slot.endTime

            let startTime: Date
            let endTime: Date
            if let startCandidate, let endCandidate {
                startTime = startCandidate
                endTime = endCandidate >= startCandidate ? endCandidate : startCandidate.addingTimeInterval(3600)
            } else if let startCandidate {
                startTime = startCandidate
                endTime = startCandidate.addingTimeInterval(3600)
            } else if let endCandidate {
                startTime = endCandidate.addingTimeInterval(-3600)
                endTime = endCandidate
            } else {
                startTime = fallbackBase
                endTime = fallbackBase
            }

            return WebEventLineupSlot(
                id: "slot_\(UUID().uuidString)",
                eventId: eventID,
                djId: {
                    if let resolvedID = matchedDJ?.id {
                        return resolvedID
                    }
                    let fallbackID = slot.djId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    return fallbackID.isEmpty ? nil : fallbackID
                }(),
                djName: finalDJName,
                stageName: {
                    let trimmed = slot.stageName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    return trimmed.isEmpty ? nil : trimmed
                }(),
                sortOrder: slot.sortOrder ?? (index + 1),
                startTime: startTime,
                endTime: endTime,
                dj: matchedDJ.map {
                    WebEventLineupSlotDJ(
                        id: $0.id,
                        name: $0.name,
                        avatarUrl: $0.avatarUrl,
                        bannerUrl: $0.bannerUrl,
                        country: $0.country
                    )
                }
            )
        }
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

    private func normalizeRatingUnit(_ unit: WebRatingUnit) -> WebRatingUnit {
        var normalized = unit
        let scores = unit.comments.map(\.score)
        if scores.isEmpty {
            normalized.rating = 0
            normalized.ratingCount = 0
            return normalized
        }
        normalized.ratingCount = scores.count
        normalized.rating = scores.reduce(0, +) / Double(scores.count)
        return normalized
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
