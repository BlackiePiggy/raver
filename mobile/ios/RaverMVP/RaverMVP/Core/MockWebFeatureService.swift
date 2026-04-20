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
    private var learnFestivals: [WebLearnFestival]

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
            countryI18n: WebBiText(en: "China", zh: "中国"),
            cityI18n: WebBiText(en: "Shanghai", zh: "上海"),
            coverImageUrl: nil,
            lineupImageUrl: nil,
            eventType: "club",
            organizerName: "Raver Crew",
            city: "Shanghai",
            country: "CN",
            manualLocation: WebEventManualLocation(
                detailAddressI18n: WebBiText(en: "No.88 Xuhui", zh: "徐汇区 88 号"),
                formattedAddressI18n: WebBiText(en: "CN · Shanghai · No.88 Xuhui", zh: "中国 · 上海 · 徐汇区 88 号"),
                selectedAt: now.addingTimeInterval(-86400 * 2)
            ),
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

        learnFestivals = [
            WebLearnFestival(
                id: "tomorrowland",
                name: "Tomorrowland",
                aliases: ["明日世界", "TL"],
                country: "比利时",
                city: "Boom",
                foundedYear: "2005",
                frequency: "每年 7 月",
                tagline: "全球最具辨识度的沉浸式 EDM 电音节之一。",
                introduction: "Tomorrowland 以大型主舞台叙事、超高制作和多舞台联动著称。",
                avatarUrl: "https://logo.clearbit.com/tomorrowland.com",
                backgroundUrl: "https://images.unsplash.com/photo-1459749411175-04bf5292ceea?auto=format&fit=crop&w=1800&q=80",
                links: [
                    LearnFestivalLinkPayload(title: "官网", icon: "globe", url: "https://www.tomorrowland.com")
                ],
                contributors: [currentUser],
                canEdit: true,
                createdAt: now,
                updatedAt: now
            ),
            WebLearnFestival(
                id: "edc",
                name: "Electric Daisy Carnival",
                aliases: ["EDC", "EDC Las Vegas"],
                country: "美国",
                city: "Las Vegas",
                foundedYear: "1997",
                frequency: "每年 5 月",
                tagline: "Insomniac 旗下头部 IP。",
                introduction: "EDC 在北美和全球拥有多站点，核心站点为 EDC Las Vegas。",
                avatarUrl: "https://logo.clearbit.com/electricdaisycarnival.com",
                backgroundUrl: "https://images.unsplash.com/photo-1470229722913-7c0e2dbbafd3?auto=format&fit=crop&w=1800&q=80",
                links: [
                    LearnFestivalLinkPayload(title: "官网", icon: "globe", url: "https://lasvegas.electricdaisycarnival.com/")
                ],
                contributors: [currentUser],
                canEdit: true,
                createdAt: now,
                updatedAt: now
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

    func fetchRecommendedEvents(limit: Int, statuses: [String]?) async throws -> [WebEvent] {
        let normalizedStatuses = (statuses ?? ["ongoing", "upcoming", "ended"])
            .map { value -> String in
                let lowered = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return lowered == "canceled" ? "cancelled" : lowered
            }
            .filter { ["ongoing", "upcoming", "ended", "cancelled"].contains($0) }
        let requestedStatuses: [String] = {
            if normalizedStatuses.isEmpty {
                return ["ongoing", "upcoming", "ended"]
            }
            var seen = Set<String>()
            var ordered: [String] = []
            for status in normalizedStatuses where seen.insert(status).inserted {
                ordered.append(status)
            }
            return ordered
        }()

        var poolByStatus: [String: [WebEvent]] = [:]
        for status in requestedStatuses {
            poolByStatus[status] = events.filter { resolveEventStatus(for: $0) == status }
        }

        var selected: [WebEvent] = []
        var selectedIDs = Set<String>()
        let cappedLimit = max(1, min(20, limit))

        // Pick at least one event from each available status bucket.
        for status in requestedStatuses where selected.count < cappedLimit {
            guard var pool = poolByStatus[status], !pool.isEmpty else { continue }
            pool.shuffle()
            if let candidate = pool.first, selectedIDs.insert(candidate.id).inserted {
                selected.append(candidate)
            }
            poolByStatus[status] = Array(pool.dropFirst())
        }

        var remainingPool = requestedStatuses
            .flatMap { poolByStatus[$0] ?? [] }
            .filter { !selectedIDs.contains($0.id) }
        remainingPool.shuffle()
        for item in remainingPool where selected.count < cappedLimit {
            guard selectedIDs.insert(item.id).inserted else { continue }
            selected.append(item)
        }

        return selected
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
        let normalizedTicketCurrency = normalizedOptional(input.ticketCurrency)
        let normalizedTicketNotes = normalizedOptional(input.ticketNotes)
        let normalizedOfficialWebsite = normalizedOptional(input.officialWebsite)
        let normalizedTicketTiers: [WebEventTicketTier] = (input.ticketTiers ?? []).enumerated().map { index, tier in
            WebEventTicketTier(
                id: "tier_\(UUID().uuidString)",
                name: tier.name.trimmingCharacters(in: .whitespacesAndNewlines),
                price: tier.price,
                currency: normalizedOptional(tier.currency) ?? normalizedTicketCurrency,
                sortOrder: tier.sortOrder ?? (index + 1)
            )
        }
        let ticketPrices = normalizedTicketTiers.compactMap(\.price)
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
            countryI18n: input.countryI18n,
            cityI18n: input.cityI18n,
            coverImageUrl: input.coverImageUrl,
            lineupImageUrl: input.lineupImageUrl,
            eventType: {
                let trimmed = input.eventType?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return trimmed.isEmpty ? nil : trimmed
            }(),
            organizerName: currentUser.displayName,
            city: input.city,
            country: input.country,
            manualLocation: input.manualLocation,
            locationPoint: input.locationPoint,
            latitude: input.latitude,
            longitude: input.longitude,
            startDate: input.startDate,
            endDate: input.endDate,
            stageOrder: input.stageOrder,
            ticketUrl: {
                let trimmed = input.ticketUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return trimmed.isEmpty ? nil : trimmed
            }(),
            ticketPriceMin: ticketPrices.min(),
            ticketPriceMax: ticketPrices.max(),
            ticketCurrency: normalizedTicketCurrency,
            ticketNotes: normalizedTicketNotes,
            officialWebsite: normalizedOfficialWebsite,
            status: input.status ?? "upcoming",
            isVerified: false,
            createdAt: now,
            updatedAt: now,
            organizer: currentUser,
            ticketTiers: normalizedTicketTiers,
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
        if input.clearCityI18n {
            events[idx].cityI18n = nil
            events[idx].city = nil
        } else if let cityI18n = input.cityI18n {
            events[idx].cityI18n = cityI18n
        }
        if let country = input.country { events[idx].country = country }
        if input.clearCountryI18n {
            events[idx].countryI18n = nil
            events[idx].country = nil
        } else if let countryI18n = input.countryI18n {
            events[idx].countryI18n = countryI18n
        }
        if input.clearManualLocation {
            events[idx].manualLocation = nil
        } else if let manualLocation = input.manualLocation {
            events[idx].manualLocation = manualLocation
        }
        if let locationPoint = input.locationPoint {
            events[idx].locationPoint = locationPoint
        }
        if let latitude = input.latitude { events[idx].latitude = latitude }
        if let longitude = input.longitude { events[idx].longitude = longitude }
        if let ticketUrl = input.ticketUrl { events[idx].ticketUrl = ticketUrl }
        if let ticketCurrency = input.ticketCurrency {
            events[idx].ticketCurrency = normalizedOptional(ticketCurrency)
        }
        if let ticketNotes = input.ticketNotes {
            events[idx].ticketNotes = normalizedOptional(ticketNotes)
        }
        if let officialWebsite = input.officialWebsite {
            events[idx].officialWebsite = normalizedOptional(officialWebsite)
        }
        if let startDate = input.startDate { events[idx].startDate = startDate }
        if let endDate = input.endDate { events[idx].endDate = endDate }
        if let stageOrder = input.stageOrder { events[idx].stageOrder = stageOrder }
        if let coverImageUrl = input.coverImageUrl { events[idx].coverImageUrl = coverImageUrl }
        if let lineupImageUrl = input.lineupImageUrl { events[idx].lineupImageUrl = lineupImageUrl }
        if let eventType = input.eventType {
            let trimmed = eventType.trimmingCharacters(in: .whitespacesAndNewlines)
            events[idx].eventType = trimmed.isEmpty ? nil : trimmed
        }
        if let status = input.status { events[idx].status = status }
        if let ticketTiers = input.ticketTiers {
            let fallbackCurrency = normalizedOptional(events[idx].ticketCurrency)
            events[idx].ticketTiers = ticketTiers.enumerated().map { index, tier in
                WebEventTicketTier(
                    id: "tier_\(UUID().uuidString)",
                    name: tier.name.trimmingCharacters(in: .whitespacesAndNewlines),
                    price: tier.price,
                    currency: normalizedOptional(tier.currency) ?? fallbackCurrency,
                    sortOrder: tier.sortOrder ?? (index + 1)
                )
            }
            let prices = events[idx].ticketTiers.compactMap(\.price)
            events[idx].ticketPriceMin = prices.min()
            events[idx].ticketPriceMax = prices.max()
        }
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

    func uploadEventImage(
        imageData: Data,
        fileName: String,
        mimeType: String,
        eventID: String?,
        usage: String?
    ) async throws -> UploadMediaResponse {
        _ = imageData
        _ = usage
        if let eventID, !eventID.isEmpty {
            return UploadMediaResponse(
                url: "/uploads/events/\(eventID)/mock-\(fileName)",
                fileName: fileName,
                mimeType: mimeType,
                size: 1
            )
        }
        return UploadMediaResponse(url: "/uploads/events/mock-\(fileName)", fileName: fileName, mimeType: mimeType, size: 1)
    }

    func uploadRatingImage(
        imageData: Data,
        fileName: String,
        mimeType: String,
        ratingEventID: String?,
        ratingUnitID: String?,
        usage: String?
    ) async throws -> UploadMediaResponse {
        _ = imageData
        _ = usage
        if let ratingUnitID, !ratingUnitID.isEmpty {
            return UploadMediaResponse(
                url: "/uploads/ratings/units/\(ratingUnitID)/mock-\(fileName)",
                fileName: fileName,
                mimeType: mimeType,
                size: 1
            )
        }
        if let ratingEventID, !ratingEventID.isEmpty {
            return UploadMediaResponse(
                url: "/uploads/ratings/events/\(ratingEventID)/mock-\(fileName)",
                fileName: fileName,
                mimeType: mimeType,
                size: 1
            )
        }
        return UploadMediaResponse(url: "/uploads/ratings/mock-\(fileName)", fileName: fileName, mimeType: mimeType, size: 1)
    }

    func importEventLineupFromImage(
        imageData: Data,
        fileName: String,
        mimeType: String,
        startDate: Date?,
        endDate: Date?
    ) async throws -> EventLineupImageImportResponse {
        _ = imageData
        _ = fileName
        _ = mimeType
        _ = startDate
        _ = endDate
        return EventLineupImageImportResponse(
            normalizedText: """
            {
              "lineup_info": [
                {"musician":"ARTBAT","time":"17:00-18:00","stage":"Main Stage","date":"Day1"},
                {"musician":"ANYMA B2B MRAK","time":"18:30-19:30","stage":"Main Stage","date":"Day1"},
                {"musician":"未知","time":"未知","stage":"未知","date":"未知"}
              ]
            }
            """,
            lineupInfo: [
                EventLineupImageImportItem(
                    id: UUID().uuidString,
                    musician: "ARTBAT",
                    time: "17:00-18:00",
                    stage: "Main Stage",
                    date: "Day1"
                ),
                EventLineupImageImportItem(
                    id: UUID().uuidString,
                    musician: "ANYMA B2B MRAK",
                    time: "18:30-19:30",
                    stage: "Main Stage",
                    date: "Day1"
                )
            ]
        )
    }

    func uploadPostImage(imageData: Data, fileName: String, mimeType: String) async throws -> UploadMediaResponse {
        _ = imageData
        return UploadMediaResponse(url: "/uploads/feed/mock-\(fileName)", fileName: fileName, mimeType: mimeType, size: 1)
    }

    func uploadPostVideo(videoData: Data, fileName: String, mimeType: String) async throws -> UploadMediaResponse {
        _ = videoData
        let normalizedName = fileName.isEmpty ? "video-\(UUID().uuidString).mp4" : fileName
        return UploadMediaResponse(url: "/uploads/feed/mock-\(normalizedName)", fileName: normalizedName, mimeType: mimeType, size: 1)
    }

    func uploadWikiBrandImage(
        imageData: Data,
        fileName: String,
        mimeType: String,
        brandID: String?,
        usage: String?
    ) async throws -> UploadMediaResponse {
        _ = imageData
        let safeBrand = brandID?.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeUsage = usage?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedBrand = (safeBrand?.isEmpty == false) ? (safeBrand ?? "unknown-brand") : "unknown-brand"
        let resolvedUsage = (safeUsage?.isEmpty == false) ? (safeUsage ?? "image") : "image"
        return UploadMediaResponse(
            url: "/uploads/wiki/brands/\(resolvedBrand)/\(resolvedUsage)-mock-\(fileName)",
            fileName: fileName,
            mimeType: mimeType,
            size: 1
        )
    }

    func uploadDJImage(
        imageData: Data,
        fileName: String,
        mimeType: String,
        djID: String,
        usage: String
    ) async throws -> UploadMediaResponse {
        _ = imageData
        guard let index = djs.firstIndex(where: { $0.id == djID }) else {
            throw ServiceError.message("DJ 不存在")
        }
        let safeUsage = usage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "image" : usage
        let url = "/uploads/djs/\(djID)/\(safeUsage)-mock-\(fileName)"
        if safeUsage == "avatar" {
            djs[index].avatarUrl = url
        } else if safeUsage == "banner" {
            djs[index].bannerUrl = url
        }
        djs[index].updatedAt = Date()
        return UploadMediaResponse(url: url, fileName: fileName, mimeType: mimeType, size: 1)
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

    func searchSpotifyDJs(query: String, limit: Int) async throws -> [SpotifyDJCandidate] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let normalized = trimmed.lowercased()
        let matched = djs.filter { $0.name.lowercased().contains(normalized) }
        let maxCount = max(1, min(20, limit))

        if matched.isEmpty {
            return [
                SpotifyDJCandidate(
                    spotifyId: "spotify_\(UUID().uuidString)",
                    name: trimmed,
                    uri: "spotify:artist:\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))",
                    url: "https://open.spotify.com/search/\(trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed)",
                    popularity: 50,
                    followers: 10000,
                    genres: [],
                    imageUrl: nil,
                    existingDJId: nil,
                    existingDJName: nil,
                    existingMatchType: nil
                )
            ]
        }

        return Array(matched.prefix(maxCount)).map { dj in
            SpotifyDJCandidate(
                spotifyId: dj.spotifyId ?? "spotify_\(dj.id)",
                name: dj.name,
                uri: "spotify:artist:\(dj.spotifyId ?? dj.id)",
                url: dj.spotifyId.flatMap { "https://open.spotify.com/artist/\($0)" },
                popularity: 70,
                followers: dj.followerCount ?? 0,
                genres: [],
                imageUrl: dj.avatarUrl,
                existingDJId: dj.id,
                existingDJName: dj.name,
                existingMatchType: "name_case_insensitive"
            )
        }
    }

    func searchDiscogsDJs(query: String, limit: Int) async throws -> [DiscogsDJCandidate] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let normalized = trimmed.lowercased()
        let maxCount = max(1, min(20, limit))

        let matched = djs.filter { $0.name.lowercased().contains(normalized) }
        if matched.isEmpty {
            return [
                DiscogsDJCandidate(
                    artistId: Int.random(in: 10_000...99_999),
                    name: trimmed,
                    thumbUrl: nil,
                    coverImageUrl: nil,
                    resourceUrl: nil,
                    uri: nil,
                    existingDJId: nil,
                    existingDJName: nil,
                    existingMatchType: nil
                )
            ]
        }

        return Array(matched.prefix(maxCount)).enumerated().map { index, dj in
            DiscogsDJCandidate(
                artistId: 50_000 + index,
                name: dj.name,
                thumbUrl: dj.avatarUrl,
                coverImageUrl: dj.bannerUrl ?? dj.avatarUrl,
                resourceUrl: "https://api.discogs.com/artists/\(50_000 + index)",
                uri: "https://www.discogs.com/artist/\(50_000 + index)",
                existingDJId: dj.id,
                existingDJName: dj.name,
                existingMatchType: "name_case_insensitive"
            )
        }
    }

    func fetchDiscogsDJArtist(id: Int) async throws -> DiscogsDJArtistDetail {
        let fallbackName = djs.first?.name ?? "Discogs Artist \(id)"
        return DiscogsDJArtistDetail(
            artistId: id,
            name: fallbackName,
            realName: nil,
            profile: "Discogs imported artist profile.",
            urls: [],
            nameVariations: [],
            aliases: [],
            groups: [],
            primaryImageUrl: nil,
            thumbnailImageUrl: nil,
            resourceUrl: "https://api.discogs.com/artists/\(id)",
            uri: "https://www.discogs.com/artist/\(id)",
            existingDJId: nil,
            existingDJName: nil,
            existingMatchType: nil
        )
    }

    func importSpotifyDJ(input: ImportSpotifyDJInput) async throws -> ImportSpotifyDJResponse {
        let spotifyId = input.spotifyId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !spotifyId.isEmpty else {
            throw ServiceError.message("spotifyId 不能为空")
        }

        let finalName = (input.name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? input.name!.trimmingCharacters(in: .whitespacesAndNewlines)
            : "Spotify Artist"
        let normalizedName = finalName.lowercased()

        let existingBySpotify = djs.firstIndex { ($0.spotifyId ?? "").caseInsensitiveCompare(spotifyId) == .orderedSame }
        let existingByName = djs.firstIndex { $0.name.lowercased() == normalizedName }
        let targetIndex = existingBySpotify ?? existingByName

        let aliases = input.aliases?.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty } ?? []
        let bio = normalizedOptional(input.bio)

        if let index = targetIndex {
            var updated = djs[index]
            updated.spotifyId = spotifyId
            updated.name = updated.name.isEmpty ? finalName : updated.name
            updated.aliases = Array(Set((updated.aliases ?? []) + aliases)).sorted()
            updated.bio = bio ?? updated.bio
            updated.country = normalizedOptional(input.country) ?? updated.country
            updated.instagramUrl = normalizedOptional(input.instagramUrl) ?? updated.instagramUrl
            updated.soundcloudUrl = normalizedOptional(input.soundcloudUrl) ?? updated.soundcloudUrl
            updated.twitterUrl = normalizedOptional(input.twitterUrl) ?? updated.twitterUrl
            updated.isVerified = input.isVerified ?? updated.isVerified ?? true
            updated.updatedAt = Date()
            djs[index] = updated
            return ImportSpotifyDJResponse(
                action: "updated",
                avatarUploadedToOss: false,
                replacedExistingAvatar: false,
                dj: updated
            )
        }

        let created = WebDJ(
            id: "dj_\(UUID().uuidString)",
            name: finalName,
            aliases: aliases,
            slug: slugify(finalName),
            bio: bio,
            avatarUrl: nil,
            bannerUrl: nil,
            country: normalizedOptional(input.country),
            spotifyId: spotifyId,
            appleMusicId: nil,
            soundcloudUrl: normalizedOptional(input.soundcloudUrl),
            instagramUrl: normalizedOptional(input.instagramUrl),
            twitterUrl: normalizedOptional(input.twitterUrl),
            isVerified: input.isVerified ?? true,
            followerCount: 0,
            createdAt: Date(),
            updatedAt: Date(),
            isFollowing: false
        )
        djs.insert(created, at: 0)
        return ImportSpotifyDJResponse(
            action: "created",
            avatarUploadedToOss: false,
            replacedExistingAvatar: false,
            dj: created
        )
    }

    func importDiscogsDJ(input: ImportDiscogsDJInput) async throws -> ImportDiscogsDJResponse {
        let discogsArtistId = input.discogsArtistId
        guard discogsArtistId > 0 else {
            throw ServiceError.message("discogsArtistId 不能为空")
        }

        let finalName = (input.name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? input.name!.trimmingCharacters(in: .whitespacesAndNewlines)
            : "Discogs Artist \(discogsArtistId)"
        let normalizedName = finalName.lowercased()
        let spotifyId = normalizedOptional(input.spotifyId)

        let existingBySpotify = spotifyId.flatMap { value in
            djs.firstIndex(where: { ($0.spotifyId ?? "").caseInsensitiveCompare(value) == .orderedSame })
        }
        let existingByName = djs.firstIndex { $0.name.lowercased() == normalizedName }
        let targetIndex = existingBySpotify ?? existingByName

        let aliases = input.aliases?.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty } ?? []
        let bio = normalizedOptional(input.bio)

        if let index = targetIndex {
            var updated = djs[index]
            updated.name = updated.name.isEmpty ? finalName : updated.name
            updated.spotifyId = spotifyId ?? updated.spotifyId
            updated.aliases = Array(Set((updated.aliases ?? []) + aliases)).sorted()
            updated.bio = bio ?? updated.bio
            updated.country = normalizedOptional(input.country) ?? updated.country
            updated.instagramUrl = normalizedOptional(input.instagramUrl) ?? updated.instagramUrl
            updated.soundcloudUrl = normalizedOptional(input.soundcloudUrl) ?? updated.soundcloudUrl
            updated.twitterUrl = normalizedOptional(input.twitterUrl) ?? updated.twitterUrl
            updated.isVerified = input.isVerified ?? updated.isVerified ?? true
            updated.updatedAt = Date()
            djs[index] = updated
            return ImportDiscogsDJResponse(
                action: "updated",
                avatarUploadedToOss: false,
                replacedExistingAvatar: false,
                dj: updated
            )
        }

        let created = WebDJ(
            id: "dj_\(UUID().uuidString)",
            name: finalName,
            aliases: aliases,
            slug: slugify(finalName),
            bio: bio,
            avatarUrl: nil,
            bannerUrl: nil,
            country: normalizedOptional(input.country),
            spotifyId: spotifyId,
            appleMusicId: nil,
            soundcloudUrl: normalizedOptional(input.soundcloudUrl),
            instagramUrl: normalizedOptional(input.instagramUrl),
            twitterUrl: normalizedOptional(input.twitterUrl),
            isVerified: input.isVerified ?? true,
            followerCount: 0,
            createdAt: Date(),
            updatedAt: Date(),
            isFollowing: false
        )
        djs.insert(created, at: 0)
        return ImportDiscogsDJResponse(
            action: "created",
            avatarUploadedToOss: false,
            replacedExistingAvatar: false,
            dj: created
        )
    }

    func importManualDJ(input: ImportManualDJInput) async throws -> ImportManualDJResponse {
        let finalName = input.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalName.isEmpty else {
            throw ServiceError.message("DJ 名称不能为空")
        }

        let normalizedName = finalName.lowercased()
        let spotifyId = normalizedOptional(input.spotifyId)
        let existingBySpotify = spotifyId.flatMap { value in
            djs.firstIndex(where: { ($0.spotifyId ?? "").caseInsensitiveCompare(value) == .orderedSame })
        }
        let existingByName = djs.firstIndex { $0.name.lowercased() == normalizedName }
        let targetIndex = existingBySpotify ?? existingByName

        let aliases = input.aliases?.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty } ?? []
        let bio = normalizedOptional(input.bio)

        if let index = targetIndex {
            var updated = djs[index]
            updated.name = updated.name.isEmpty ? finalName : updated.name
            updated.spotifyId = spotifyId ?? updated.spotifyId
            updated.aliases = Array(Set((updated.aliases ?? []) + aliases)).sorted()
            updated.bio = bio ?? updated.bio
            updated.country = normalizedOptional(input.country) ?? updated.country
            updated.instagramUrl = normalizedOptional(input.instagramUrl) ?? updated.instagramUrl
            updated.soundcloudUrl = normalizedOptional(input.soundcloudUrl) ?? updated.soundcloudUrl
            updated.twitterUrl = normalizedOptional(input.twitterUrl) ?? updated.twitterUrl
            updated.isVerified = input.isVerified ?? updated.isVerified ?? true
            updated.updatedAt = Date()
            djs[index] = updated
            return ImportManualDJResponse(action: "updated", dj: updated)
        }

        let created = WebDJ(
            id: "dj_\(UUID().uuidString)",
            name: finalName,
            aliases: aliases,
            slug: slugify(finalName),
            bio: bio,
            avatarUrl: nil,
            bannerUrl: nil,
            country: normalizedOptional(input.country),
            spotifyId: spotifyId,
            appleMusicId: nil,
            soundcloudUrl: normalizedOptional(input.soundcloudUrl),
            instagramUrl: normalizedOptional(input.instagramUrl),
            twitterUrl: normalizedOptional(input.twitterUrl),
            isVerified: input.isVerified ?? true,
            followerCount: 0,
            createdAt: Date(),
            updatedAt: Date(),
            isFollowing: false
        )
        djs.insert(created, at: 0)
        return ImportManualDJResponse(action: "created", dj: created)
    }

    func updateDJ(id: String, input: UpdateDJInput) async throws -> WebDJ {
        guard let index = djs.firstIndex(where: { $0.id == id }) else {
            throw ServiceError.message("DJ 不存在")
        }

        var updated = djs[index]

        if let name = input.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            if updated.name.lowercased() != name.lowercased() {
                var aliases = updated.aliases ?? []
                aliases.append(updated.name)
                updated.aliases = Array(Set(aliases)).sorted()
            }
            updated.name = name
        }

        if let aliases = input.aliases {
            updated.aliases = aliases
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        if let bio = input.bio {
            let trimmed = bio.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.bio = trimmed.isEmpty ? nil : trimmed
        }
        if let country = input.country {
            let trimmed = country.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.country = trimmed.isEmpty ? nil : trimmed
        }
        if let spotifyId = input.spotifyId {
            let trimmed = spotifyId.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.spotifyId = trimmed.isEmpty ? nil : trimmed
        }
        if let appleMusicId = input.appleMusicId {
            let trimmed = appleMusicId.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.appleMusicId = trimmed.isEmpty ? nil : trimmed
        }
        if let instagramUrl = input.instagramUrl {
            let trimmed = instagramUrl.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.instagramUrl = trimmed.isEmpty ? nil : trimmed
        }
        if let soundcloudUrl = input.soundcloudUrl {
            let trimmed = soundcloudUrl.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.soundcloudUrl = trimmed.isEmpty ? nil : trimmed
        }
        if let twitterUrl = input.twitterUrl {
            let trimmed = twitterUrl.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.twitterUrl = trimmed.isEmpty ? nil : trimmed
        }
        if let isVerified = input.isVerified {
            updated.isVerified = isVerified
        }

        updated.updatedAt = Date()
        djs[index] = updated
        return updated
    }

    func fetchDJSets(djID: String) async throws -> [WebDJSet] {
        sets.filter { $0.djId == djID }.sorted(by: { $0.createdAt > $1.createdAt })
    }

    func fetchDJEvents(djID: String) async throws -> [WebEvent] {
        events
            .filter { event in
                event.lineupSlots.contains(where: { slot in
                    slot.djId == djID || (slot.djIds ?? []).contains(djID)
                })
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

    func fetchEventDJSets(eventName: String) async throws -> [WebDJSet] {
        let normalized = eventName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return [] }
        return sets
            .filter { set in
                let value = (set.eventName ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return !value.isEmpty && value == normalized
            }
            .sorted(by: { $0.createdAt > $1.createdAt })
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
        try await fetchMyCheckins(page: page, limit: limit, type: type, eventID: nil, djID: nil)
    }

    func fetchMyCheckins(page: Int, limit: Int, type: String?, eventID: String?, djID: String?) async throws -> CheckinListPage {
        try await fetchUserCheckins(userID: currentUser.id, page: page, limit: limit, type: type, eventID: eventID, djID: djID)
    }

    func fetchUserCheckins(userID: String, page: Int, limit: Int, type: String?) async throws -> CheckinListPage {
        try await fetchUserCheckins(userID: userID, page: page, limit: limit, type: type, eventID: nil, djID: nil)
    }

    func fetchUserCheckins(userID: String, page: Int, limit: Int, type: String?, eventID: String?, djID: String?) async throws -> CheckinListPage {
        let normalizedType = type?.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = checkins.filter { item in
            item.userId == userID
                && (normalizedType == nil || normalizedType == "" || item.type == normalizedType)
                && (eventID == nil || eventID == "" || item.eventId == eventID)
                && (djID == nil || djID == "" || item.djId == djID)
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
        if input.type == "event",
           let eventID = input.eventId,
           let normalizedNote = input.note?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           normalizedNote != "marked",
           checkins.contains(where: {
               $0.userId == currentUser.id
                   && $0.type == "event"
                   && $0.eventId == eventID
                   && $0.isEventAttendanceCheckin
           }) {
            throw ServiceError.message("该活动已打卡，请直接编辑原有记录")
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

    func updateCheckin(id: String, input: UpdateCheckinInput) async throws -> WebCheckin {
        guard let idx = checkins.firstIndex(where: { $0.id == id }) else {
            throw ServiceError.message("打卡不存在")
        }

        var item = checkins[idx]
        if let eventID = input.eventId {
            item.eventId = eventID
            if let event = events.first(where: { $0.id == eventID }) {
                item.event = CheckinEventLite(
                    id: event.id,
                    name: event.name,
                    coverImageUrl: event.coverImageUrl,
                    city: event.city,
                    country: event.country,
                    startDate: event.startDate,
                    endDate: event.endDate
                )
            }
        }
        if let djID = input.djId {
            item.djId = djID
            item.dj = djs.first(where: { $0.id == djID }).map {
                CheckinDJLite(id: $0.id, name: $0.name, avatarUrl: $0.avatarUrl, country: $0.country)
            }
        }
        if let note = input.note {
            item.note = note
        }
        if let rating = input.rating {
            item.rating = rating
        }
        if let attendedAt = input.attendedAt {
            item.attendedAt = attendedAt
        }

        checkins[idx] = item
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
                normalized.sourceEventId = normalized.sourceEventId ?? inferSourceEventID(for: event)
                normalized.units = event.units.map(normalizeRatingUnit)
                return normalized
            }
    }

    func fetchEventRatingEvents(eventID: String) async throws -> [WebRatingEvent] {
        guard let sourceEvent = events.first(where: { $0.id == eventID }) else {
            throw ServiceError.message("活动不存在")
        }

        let sourceActNames = Set(
            sourceEvent.lineupSlots.map { normalizedActName($0.djName) }
        )

        return ratingEvents
            .filter { ratingEvent in
                if ratingEvent.name.compare(sourceEvent.name, options: .caseInsensitive) != .orderedSame {
                    return false
                }
                if sourceActNames.isEmpty { return true }
                return ratingEvent.units.contains(where: { unit in
                    sourceActNames.contains(normalizedActName(unit.name))
                })
            }
            .sorted(by: { $0.createdAt > $1.createdAt })
            .map { event in
                var normalized = event
                normalized.sourceEventId = sourceEvent.id
                normalized.units = event.units.map(normalizeRatingUnit)
                return normalized
            }
    }

    func fetchRatingEvent(id: String) async throws -> WebRatingEvent {
        guard let event = ratingEvents.first(where: { $0.id == id }) else {
            throw ServiceError.message("打分事件不存在")
        }
        var normalized = event
        normalized.sourceEventId = normalized.sourceEventId ?? inferSourceEventID(for: event)
        normalized.units = event.units.map(normalizeRatingUnit)
        return normalized
    }

    func fetchDJRatingUnits(djID: String) async throws -> [WebRatingUnit] {
        guard let sourceDJ = djs.first(where: { $0.id == djID }) else {
            throw ServiceError.message("DJ 不存在")
        }
        let normalizedName = sourceDJ.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return ratingEvents
            .flatMap { event in
                event.units.compactMap { unit in
                    let performerNames = parseDJActNames(from: unit.name)
                    let contains = performerNames.contains { performer in
                        performer.lowercased() == normalizedName
                    }
                    guard contains else { return nil }
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
            .sorted(by: { $0.createdAt > $1.createdAt })
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

    func createRatingEventFromEvent(eventID: String) async throws -> WebRatingEvent {
        guard let sourceEvent = events.first(where: { $0.id == eventID }) else {
            throw ServiceError.message("活动不存在")
        }

        let now = Date()
        let ratingEventID = "rating_event_\(UUID().uuidString)"
        let baseUnitTimeFormatter = DateFormatter()
        baseUnitTimeFormatter.dateFormat = "MM-dd HH:mm"
        baseUnitTimeFormatter.locale = Locale(identifier: "en_US_POSIX")

        let units = sourceEvent.lineupSlots
            .sorted(by: { $0.startTime < $1.startTime })
            .enumerated()
            .map { index, slot in
                let firstPerformerName = parseDJActNames(from: slot.djName).first ?? slot.djName
                let firstDJ = djs.first(where: { $0.name.compare(firstPerformerName, options: .caseInsensitive) == .orderedSame })
                    ?? slot.dj.flatMap { embedded in
                        djs.first(where: { $0.id == embedded.id })
                    }

                return WebRatingUnit(
                    id: "rating_unit_\(UUID().uuidString)",
                    eventId: ratingEventID,
                    name: slot.djName,
                    description: ratingUnitDescription(
                        slot: slot,
                        formatter: baseUnitTimeFormatter
                    ),
                    imageUrl: firstDJ?.avatarUrl ?? slot.dj?.avatarUrl,
                    createdAt: now.addingTimeInterval(Double(index)),
                    updatedAt: now.addingTimeInterval(Double(index)),
                    rating: 0,
                    ratingCount: 0,
                    comments: [],
                    event: nil,
                    createdBy: currentUser
                )
            }

        let created = WebRatingEvent(
            id: ratingEventID,
            name: sourceEvent.name,
            description: sourceEvent.description,
            imageUrl: sourceEvent.coverImageUrl,
            sourceEventId: sourceEvent.id,
            createdAt: now,
            updatedAt: now,
            createdBy: currentUser,
            units: units
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

    func fetchLearnLabels(
        page: Int,
        limit: Int,
        sortBy: String,
        order: String,
        search: String?,
        nation: String?,
        genre: String?
    ) async throws -> LearnLabelListPage {
        var labels: [LearnLabel] = [
            LearnLabel(
                id: "label-monstercat",
                name: "Monstercat",
                slug: "monstercat",
                profileUrl: "https://labelsbase.net/monstercat",
                profileSlug: "monstercat",
                avatarUrl: "https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/labels/monstercat/avatar.jpg",
                backgroundUrl: "https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/labels/monstercat/background.jpg",
                nation: "CA",
                soundcloudFollowers: 1_070_718,
                likes: 385,
                genres: ["Dubstep", "House", "Dance"],
                genresPreview: "Dubstep, House",
                latestReleaseListing: "2 years ago",
                locationPeriod: "Vancouver, Canada. 2011 – present",
                introduction: "Empowering a creative and passionate community through innovation.",
                generalContactEmail: "support@monstercat.com",
                demoSubmissionUrl: "https://www.labelradar.com",
                demoSubmissionDisplay: "www.labelradar.com",
                facebookUrl: "https://facebook.com/monstercat",
                soundcloudUrl: "https://soundcloud.com/monstercat",
                musicPurchaseUrl: "https://www.beatport.com/label/monstercat/12345",
                officialWebsiteUrl: "https://www.monstercat.com",
                founderName: "Amelie Lens",
                foundedAt: "2011",
                founderDj: djs.first(where: { $0.id == "dj_amelie" })
            ),
            LearnLabel(
                id: "label-foolsgold",
                name: "Fool's Gold Records",
                slug: "fools-gold-records",
                profileUrl: "https://labelsbase.net/fools-gold-records",
                profileSlug: "fools-gold-records",
                avatarUrl: "https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/labels/fools-gold-records-2903ddc1/avatar.jpg",
                backgroundUrl: "https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/labels/fools-gold-records-2903ddc1/background.jpg",
                nation: "US",
                soundcloudFollowers: 7_931_905,
                likes: 167,
                genres: ["Electronica", "Nu Disco", "Hip-Hop"],
                genresPreview: "Electronica, Indie Dance, Nu Disco, Hip-Hop",
                latestReleaseListing: nil,
                locationPeriod: nil,
                introduction: "Founded by DJs A-Trak and Nick Catchdubs.",
                generalContactEmail: "info@foolsgoldrecs.com",
                demoSubmissionUrl: "mailto:demos@foolsgoldrecs.com",
                demoSubmissionDisplay: "demos@foolsgoldrecs.com",
                facebookUrl: "https://www.facebook.com/foolsgoldrecords/",
                soundcloudUrl: "https://soundcloud.com/foolsgoldrecs",
                musicPurchaseUrl: "https://www.beatport.com/label/fools-gold-records/5550",
                officialWebsiteUrl: "http://foolsgoldrecs.com",
                founderName: "A-Trak",
                foundedAt: "2007",
                founderDj: nil
            ),
            LearnLabel(
                id: "label-mad-decent",
                name: "Mad Decent",
                slug: "mad-decent",
                profileUrl: "https://labelsbase.net/mad-decent",
                profileSlug: "mad-decent",
                avatarUrl: "https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/labels/mad-decent-47e320a5/avatar.jpg",
                backgroundUrl: "https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/labels/mad-decent-47e320a5/background.jpg",
                nation: "US",
                soundcloudFollowers: 5_129_845,
                likes: 212,
                genres: ["Bass", "Trap", "House"],
                genresPreview: "Bass, Trap, House",
                latestReleaseListing: "1 year ago",
                locationPeriod: nil,
                introduction: "Global dance music label founded by Diplo.",
                generalContactEmail: nil,
                demoSubmissionUrl: nil,
                demoSubmissionDisplay: nil,
                facebookUrl: "https://www.facebook.com/maddecent",
                soundcloudUrl: "https://soundcloud.com/maddecent",
                musicPurchaseUrl: "https://www.beatport.com/label/mad-decent/414",
                officialWebsiteUrl: "https://www.maddecent.com",
                founderName: "Diplo",
                foundedAt: "2005",
                founderDj: djs.first(where: { $0.name.lowercased() == "diplo" })
            )
        ]

        if let search, !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let keyword = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            labels = labels.filter { label in
                label.name.lowercased().contains(keyword)
                    || (label.introduction?.lowercased().contains(keyword) ?? false)
                    || (label.genresPreview?.lowercased().contains(keyword) ?? false)
            }
        }

        if let nation, !nation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let keyword = nation.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            labels = labels.filter { ($0.nation ?? "").lowercased() == keyword }
        }

        if let genre, !genre.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let keyword = genre.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            labels = labels.filter { label in
                label.genres.contains(where: { $0.lowercased() == keyword })
            }
        }

        let isAscending = order.lowercased() == "asc"
        let comparator: (LearnLabel, LearnLabel) -> Bool = { lhs, rhs in
            switch sortBy {
            case "likes":
                return isAscending ? (lhs.likes ?? 0) < (rhs.likes ?? 0) : (lhs.likes ?? 0) > (rhs.likes ?? 0)
            case "name":
                return isAscending ? lhs.name.localizedCompare(rhs.name) == .orderedAscending : lhs.name.localizedCompare(rhs.name) == .orderedDescending
            case "nation":
                return isAscending
                    ? (lhs.nation ?? "").localizedCompare(rhs.nation ?? "") == .orderedAscending
                    : (lhs.nation ?? "").localizedCompare(rhs.nation ?? "") == .orderedDescending
            case "latestRelease":
                return isAscending
                    ? (lhs.latestReleaseListing ?? "") < (rhs.latestReleaseListing ?? "")
                    : (lhs.latestReleaseListing ?? "") > (rhs.latestReleaseListing ?? "")
            default:
                return isAscending
                    ? (lhs.soundcloudFollowers ?? 0) < (rhs.soundcloudFollowers ?? 0)
                    : (lhs.soundcloudFollowers ?? 0) > (rhs.soundcloudFollowers ?? 0)
            }
        }
        labels.sort(by: comparator)

        let safePage = max(1, page)
        let safeLimit = max(1, min(500, limit))
        let total = labels.count
        let start = min(total, (safePage - 1) * safeLimit)
        let end = min(total, start + safeLimit)
        let items = Array(labels[start..<end])
        let pagination = BFFPagination(
            page: safePage,
            limit: safeLimit,
            total: total,
            totalPages: max(1, Int(ceil(Double(max(total, 1)) / Double(safeLimit))))
        )
        return LearnLabelListPage(items: items, pagination: pagination)
    }

    func fetchLearnFestivals(search: String?) async throws -> [WebLearnFestival] {
        let keyword = search?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        guard !keyword.isEmpty else {
            return learnFestivals
        }
        return learnFestivals.filter { festival in
            [
                festival.name,
                festival.aliases.joined(separator: " "),
                festival.country,
                festival.city,
                festival.tagline,
                festival.introduction
            ]
            .joined(separator: " ")
            .lowercased()
            .contains(keyword)
        }
    }

    func createLearnFestival(input: CreateLearnFestivalInput) async throws -> WebLearnFestival {
        let finalName = input.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalName.isEmpty else {
            throw ServiceError.message("电音节名称不能为空")
        }

        let rawBase = finalName
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9\\u4e00-\\u9fa5]+", with: "-", options: .regularExpression)
            .replacingOccurrences(of: "^-+|-+$", with: "", options: .regularExpression)
        let baseID = rawBase.isEmpty ? "festival-\(UUID().uuidString.prefix(8))" : rawBase

        var candidateID = baseID
        var suffix = 1
        while learnFestivals.contains(where: { $0.id == candidateID }) {
            suffix += 1
            candidateID = "\(baseID)-\(suffix)"
        }

        let aliases = (input.aliases ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let links = (input.links ?? [])
            .map { LearnFestivalLinkPayload(title: $0.title, icon: $0.icon, url: $0.url) }
        let now = Date()

        let festival = WebLearnFestival(
            id: candidateID,
            name: finalName,
            aliases: aliases,
            country: input.country?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            city: input.city?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            foundedYear: input.foundedYear?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            frequency: input.frequency?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            tagline: input.tagline?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            introduction: input.introduction?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            avatarUrl: {
                let trimmed = input.avatarUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return trimmed.isEmpty ? nil : trimmed
            }(),
            backgroundUrl: {
                let trimmed = input.backgroundUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return trimmed.isEmpty ? nil : trimmed
            }(),
            links: links,
            contributors: [currentUser],
            canEdit: true,
            createdAt: now,
            updatedAt: now
        )

        learnFestivals.insert(festival, at: 0)
        return festival
    }

    func updateLearnFestival(id: String, input: UpdateLearnFestivalInput) async throws -> WebLearnFestival {
        guard let index = learnFestivals.firstIndex(where: { $0.id == id }) else {
            throw ServiceError.message("电音节不存在")
        }

        var festival = learnFestivals[index]
        if let name = input.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            festival.name = name
        }
        if let aliases = input.aliases {
            festival.aliases = aliases.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        }
        if let country = input.country {
            festival.country = country.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let city = input.city {
            festival.city = city.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let foundedYear = input.foundedYear {
            festival.foundedYear = foundedYear.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let frequency = input.frequency {
            festival.frequency = frequency.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let tagline = input.tagline {
            festival.tagline = tagline.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let introduction = input.introduction {
            festival.introduction = introduction.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let avatarUrl = input.avatarUrl {
            let trimmed = avatarUrl.trimmingCharacters(in: .whitespacesAndNewlines)
            festival.avatarUrl = trimmed.isEmpty ? nil : trimmed
        }
        if let backgroundUrl = input.backgroundUrl {
            let trimmed = backgroundUrl.trimmingCharacters(in: .whitespacesAndNewlines)
            festival.backgroundUrl = trimmed.isEmpty ? nil : trimmed
        }
        if let links = input.links {
            festival.links = links
        }

        festival.updatedAt = Date()
        festival.canEdit = true
        if !festival.contributors.contains(where: { $0.id == currentUser.id }) {
            festival.contributors.append(currentUser)
        }
        learnFestivals[index] = festival
        return festival
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

    private func normalizedOptional(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
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

    private func parseDJActNames(from rawName: String) -> [String] {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let separated = trimmed
            .replacingOccurrences(
                of: "\\s*[bB]\\s*[23]\\s*[bB]\\s*",
                with: "|",
                options: .regularExpression
            )
            .split(separator: "|")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return separated.isEmpty ? [trimmed] : separated
    }

    private func normalizedActName(_ name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func inferSourceEventID(for ratingEvent: WebRatingEvent) -> String? {
        let trimmedName = ratingEvent.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }

        let candidates = events.filter {
            $0.name.compare(trimmedName, options: .caseInsensitive) == .orderedSame
        }
        guard !candidates.isEmpty else { return nil }

        let ratingUnitNames = Set(ratingEvent.units.map { normalizedActName($0.name) }.filter { !$0.isEmpty })
        if ratingUnitNames.isEmpty {
            return candidates.first?.id
        }

        var bestEventID: String?
        var bestScore = 0
        for candidate in candidates {
            let lineupNames = Set(candidate.lineupSlots.map { normalizedActName($0.djName) }.filter { !$0.isEmpty })
            let score = ratingUnitNames.reduce(into: 0) { partial, name in
                if lineupNames.contains(name) {
                    partial += 1
                }
            }
            if score > bestScore {
                bestScore = score
                bestEventID = candidate.id
            }
        }

        if let bestEventID {
            return bestEventID
        }
        return candidates.count == 1 ? candidates[0].id : nil
    }

    private func ratingUnitDescription(slot: WebEventLineupSlot, formatter: DateFormatter) -> String? {
        let stage = slot.stageName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasStage = stage?.isEmpty == false
        let timeText = "\(formatter.string(from: slot.startTime)) - \(formatter.string(from: slot.endTime))"

        if hasStage, let stage {
            return "\(stage) · \(timeText)"
        }
        return timeText
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
