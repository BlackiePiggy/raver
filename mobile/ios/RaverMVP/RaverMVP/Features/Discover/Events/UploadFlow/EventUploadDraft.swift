import Foundation

enum EventUploadImageZone: String, CaseIterable, Identifiable, Codable {
    case poster
    case lineup
    case timetable
    case cover
    case map
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .poster: return LT("海报", "Poster", "ポスター")
        case .lineup: return LT("阵容图", "Lineup", "ラインナップ")
        case .timetable: return LT("时间表", "Timetable", "タイムテーブル")
        case .cover: return LT("封面", "Cover", "カバー")
        case .map: return LT("地图", "Map", "地図")
        case .other: return LT("其他相关", "Other", "その他")
        }
    }

    var backendType: String {
        switch self {
        case .cover: return "cover"
        case .lineup: return "luall"
        case .timetable: return "tt"
        case .poster: return "poster"
        case .map, .other: return "other"
        }
    }

    var defaultLabel: String {
        switch self {
        case .poster: return "POSTER"
        case .lineup: return "LINE-UP"
        case .timetable: return "TIMETABLE"
        case .cover: return "COVER"
        case .map: return "MAP"
        case .other: return "OTHER"
        }
    }
}

struct EventUploadImageDraft: Identifiable, Hashable, Codable {
    enum Ownership: String, Codable {
        case pendingLocal
        case createDraftUploaded
        case editDraftUploaded
        case persistedEvent
    }

    var id: UUID = UUID()
    var zone: EventUploadImageZone
    var localFileURL: URL?
    var remoteURL: String?
    var fileName: String
    var mimeType: String
    var sortOrder: Int
    var ownership: Ownership = .pendingLocal
}

struct EventUploadPickedImageData {
    var data: Data
    var fileExtension: String
    var mimeType: String
}

struct EventUploadLocalizedFields: Hashable, Codable {
    var zh: String = ""
    var en: String = ""
    var ja: String = ""
    var enFull: String = ""

    var hasAnyValue: Bool {
        [zh, en, ja, enFull].contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    func primaryValue(preferredLanguage: EventUploadPreferredLanguage) -> String {
        switch preferredLanguage {
        case .zh: return zh.eventUploadNilIfBlank ?? en.eventUploadNilIfBlank ?? ja.eventUploadNilIfBlank ?? enFull
        case .en: return en.eventUploadNilIfBlank ?? enFull.eventUploadNilIfBlank ?? zh.eventUploadNilIfBlank ?? ja
        case .ja: return ja.eventUploadNilIfBlank ?? en.eventUploadNilIfBlank ?? zh.eventUploadNilIfBlank ?? enFull
        }
    }

    func value(for language: EventUploadPreferredLanguage) -> String {
        switch language {
        case .zh: return zh
        case .en: return en
        case .ja: return ja
        }
    }

    func currentValue(preferredLanguage: EventUploadPreferredLanguage) -> String {
        value(for: preferredLanguage)
    }

    mutating func setCurrentValue(_ value: String, preferredLanguage: EventUploadPreferredLanguage) {
        setValue(value, for: preferredLanguage)
    }

    mutating func setValue(_ value: String, for language: EventUploadPreferredLanguage) {
        switch language {
        case .zh:
            zh = value
        case .en:
            en = value
        case .ja:
            ja = value
        }
    }

    func secondaryValueCount(excluding preferredLanguage: EventUploadPreferredLanguage, includeEnglishFull: Bool = false) -> Int {
        var count = 0
        if preferredLanguage != .zh, !zh.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { count += 1 }
        if preferredLanguage != .en, !en.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { count += 1 }
        if preferredLanguage != .ja, !ja.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { count += 1 }
        if includeEnglishFull, !enFull.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { count += 1 }
        return count
    }
}

enum EventUploadPreferredLanguage: String, Codable {
    case zh
    case en
    case ja

    static var current: EventUploadPreferredLanguage {
        let languageCode = Locale.current.language.languageCode?.identifier.lowercased() ?? ""
        if languageCode.hasPrefix("zh") { return .zh }
        if languageCode.hasPrefix("ja") { return .ja }
        return .en
    }
}

struct EventUploadTicketTierDraft: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var name: String = ""
    var price: String = ""
}

struct EventUploadTicketDraft: Hashable, Codable {
    var currency: String = "CNY"
    var ticketURL: String = ""
    var tiers: [EventUploadTicketTierDraft] = []

    var hasTicketInfo: Bool {
        !ticketURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || tiers.contains { !$0.price.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}

struct EventUploadWeekRangeDraft: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var startDate: Date
    var endDate: Date
}

enum EventUploadSlotDayOffset: Int, CaseIterable, Identifiable, Codable {
    case sameDay = 0
    case nextDay = 1

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .sameDay: return LT("当日", "Same Day", "当日")
        case .nextDay: return LT("次日", "Next Day", "翌日")
        }
    }
}

struct EventUploadLineupSlotDraft: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var canonicalSlotId: String? = nil
    var actType: EventLineupActType = .solo
    var performerNames: [String] = [""]
    var performerDJIDs: [String?] = [nil]
    var performerAvatarURLs: [String?] = [nil]
    var stageName: String = ""
    var dayIndex: Int = 1
    var startDayOffset: EventUploadSlotDayOffset = .sameDay
    var endDayOffset: EventUploadSlotDayOffset = .sameDay
    var startTime: Date?
    var endTime: Date?

    mutating func normalizePerformers() {
        let count = actType.performerCount
        if performerNames.count < count {
            performerNames.append(contentsOf: Array(repeating: "", count: count - performerNames.count))
        }
        if performerDJIDs.count < count {
            performerDJIDs.append(contentsOf: Array(repeating: nil, count: count - performerDJIDs.count))
        }
        if performerAvatarURLs.count < count {
            performerAvatarURLs.append(contentsOf: Array(repeating: nil, count: count - performerAvatarURLs.count))
        }
        if performerNames.count > count {
            performerNames = Array(performerNames.prefix(count))
        }
        if performerDJIDs.count > count {
            performerDJIDs = Array(performerDJIDs.prefix(count))
        }
        if performerAvatarURLs.count > count {
            performerAvatarURLs = Array(performerAvatarURLs.prefix(count))
        }
    }
}

struct EventUploadLineupOnlySlotDraft: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var canonicalArtistId: String? = nil
    var actType: EventLineupActType = .solo
    var performerNames: [String] = [""]
    var performerDJIDs: [String?] = [nil]
    var performerAvatarURLs: [String?] = [nil]

    mutating func normalizePerformers() {
        let count = actType.performerCount
        if performerNames.count < count {
            performerNames.append(contentsOf: Array(repeating: "", count: count - performerNames.count))
        }
        if performerDJIDs.count < count {
            performerDJIDs.append(contentsOf: Array(repeating: nil, count: count - performerDJIDs.count))
        }
        if performerAvatarURLs.count < count {
            performerAvatarURLs.append(contentsOf: Array(repeating: nil, count: count - performerAvatarURLs.count))
        }
        if performerNames.count > count {
            performerNames = Array(performerNames.prefix(count))
        }
        if performerDJIDs.count > count {
            performerDJIDs = Array(performerDJIDs.prefix(count))
        }
        if performerAvatarURLs.count > count {
            performerAvatarURLs = Array(performerAvatarURLs.prefix(count))
        }
    }
}

struct EventUploadTimetableAIEditableSlot: Identifiable, Hashable {
    var id: UUID = UUID()
    var weekIndex: Int
    var dayIndex: Int
    var dayLabel: String
    var stageName: String
    var actType: EventLineupActType
    var performerNamesText: String
    var performerDJIDs: [String?] = []
    var performerAvatarURLs: [String?] = []
    var startTimeText: String
    var endTimeText: String
    var startDayOffset: EventUploadSlotDayOffset = .sameDay
    var endDayOffset: EventUploadSlotDayOffset = .sameDay
    var confidence: Double?
    var notes: [String]
}

struct EventUploadTimetableAIImportResult: Hashable {
    var slots: [EventUploadTimetableAIEditableSlot]
    var warnings: [String]
    var unparsedTexts: [String]
}

struct EventUploadLineupAIEditableItem: Identifiable, Hashable {
    var id: UUID = UUID()
    var actType: EventLineupActType
    var performerNamesText: String
    var performerDJIDs: [String?] = []
    var performerAvatarURLs: [String?] = []
    var confidence: Double?
    var notes: [String]
}

struct EventUploadLineupAIImportResult: Hashable {
    var items: [EventUploadLineupAIEditableItem]
    var warnings: [String]
    var unparsedTexts: [String]
}

struct EventUploadPosterAIImportResult: Hashable {
    var name: EventUploadLocalizedFields
    var city: EventUploadLocalizedFields
    var detailAddress: EventUploadLocalizedFields
    var country: EventUploadLocalizedFields
    var timeZoneIdentifier: String?
    var timeZoneDisplayName: String
    var scheduleMode: EventUploadScheduleMode
    var startDate: Date?
    var endDate: Date?
    var weekRanges: [EventUploadWeekRangeDraft]
    var ticketURL: String
    var ticketCurrency: String
    var ticketTiers: [EventUploadTicketTierDraft]
    var warnings: [String]
    var unparsedTexts: [String]
}

struct EventUploadPosterAIEditableResult: Hashable {
    var name: EventUploadLocalizedFields
    var city: EventUploadLocalizedFields
    var detailAddress: EventUploadLocalizedFields
    var country: EventUploadLocalizedFields
    var timeZoneIdentifier: String?
    var timeZoneDisplayName: String
    var selectedTimeZoneLookup: EventTimezoneLookupItem?
    var timeZoneSearchQuery: String
    var scheduleMode: EventUploadScheduleMode
    var startDate: Date?
    var endDate: Date?
    var weekRanges: [EventUploadWeekRangeDraft]
    var ticketURL: String
    var ticketCurrency: String
    var ticketTiers: [EventUploadTicketTierDraft]
    var warnings: [String]
    var unparsedTexts: [String]
}

struct EventUploadDraft: Hashable, Codable {
    struct IncrementalBaseline: Hashable, Codable {
        var eventRevision: Int? = nil
        var lineupArtists: [EventLineupArtistInput] = []
        var lineupSlots: [EventLineupSlotInput] = []
        var stageOrder: [String] = []
    }

    var id: UUID = UUID()
    var mode: EventUploadMode = .create
    var currentStep: EventUploadStep = .media
    var preferredLanguage: EventUploadPreferredLanguage = .current
    var imageZones: [EventUploadImageZone: [EventUploadImageDraft]] = EventUploadDraft.emptyImageZones()
    var name = EventUploadLocalizedFields()
    var abbreviation = ""
    var eventType = ""
    var organizerFestivalID: String?
    var organizerName = ""
    var sourceURL = ""
    var city = EventUploadLocalizedFields()
    var country = EventUploadLocalizedFields()
    var detailAddress = EventUploadLocalizedFields()
    var startDate = Date()
    var endDate = Date()
    var weekRanges: [EventUploadWeekRangeDraft] = [
        EventUploadWeekRangeDraft(startDate: Date(), endDate: Date())
    ]
    var timeZoneIdentifier = "Asia/Shanghai"
    var timeZoneSearchQuery = ""
    var selectedTimeZoneLookup: EventTimezoneLookupItem?
    var scheduleMode: EventUploadScheduleMode = .singleDay
    var dayRolloverHour = 6
    var latitude: Double?
    var longitude: Double?
    var pickedMapAddress = ""
    var pickedPlaceName = ""
    var stageEntries: [String] = []
    var timetableSlots: [EventUploadLineupSlotDraft] = []
    var lineupOnlySlots: [EventUploadLineupOnlySlotDraft] = []
    var incrementalBaseline: IncrementalBaseline? = nil
    var pendingSubmissionIdempotencyKey: String? = nil
    var ticket = EventUploadTicketDraft()
    var dirty = false
    var updatedAt: Date? = Date()

    static func create() -> EventUploadDraft {
        EventUploadDraft()
    }

    static func edit(event: WebEvent) -> EventUploadDraft {
        var draft = EventUploadDraft(mode: .edit(eventID: event.id))
        draft.name = EventUploadLocalizedFields(
            zh: event.nameI18n?.zh ?? "",
            en: event.nameI18n?.en ?? event.name,
            ja: event.nameI18n?.ja ?? ""
        )
        draft.abbreviation = event.abbreviation ?? ""
        draft.eventType = event.eventType ?? ""
        draft.organizerFestivalID = event.wikiFestivalId ?? event.wikiFestival?.id
        draft.organizerName = event.wikiFestival?.nameI18n?.text(for: AppLanguagePreference.current.effectiveLanguage)
            ?? event.wikiFestival?.name
            ?? event.organizerName
            ?? ""
        draft.sourceURL = event.sourceEventUrl ?? event.officialWebsite ?? ""
        draft.city = EventUploadLocalizedFields(
            zh: event.cityI18n?.zh ?? "",
            en: event.cityI18n?.en ?? event.city ?? "",
            ja: event.cityI18n?.ja ?? ""
        )
        draft.country = EventUploadLocalizedFields(
            zh: event.countryI18n?.zh ?? "",
            en: event.countryI18n?.en ?? event.country ?? "",
            ja: event.countryI18n?.ja ?? "",
            enFull: event.countryI18n?.enFull ?? ""
        )
        let detailAddressText = event.manualLocation?.detailAddressI18n ?? event.manualLocation?.formattedAddressI18n
        draft.detailAddress = EventUploadLocalizedFields(
            zh: detailAddressText?.zh ?? "",
            en: detailAddressText?.en ?? "",
            ja: detailAddressText?.ja ?? "",
            enFull: detailAddressText?.enFull ?? ""
        )
        draft.timeZoneIdentifier = event.timeZone ?? draft.timeZoneIdentifier
        let eventTimeZone = TimeZone(identifier: draft.timeZoneIdentifier) ?? .current
        let normalizedStartDate = event.startDate.normalizedEventArchiveDate(in: eventTimeZone)
        let normalizedEndDate = event.endDate.normalizedEventArchiveDate(in: eventTimeZone)
        draft.startDate = normalizedStartDate
        draft.endDate = normalizedEndDate
        draft.weekRanges = [EventUploadWeekRangeDraft(startDate: normalizedStartDate, endDate: normalizedEndDate)]
        var eventCalendar = Calendar(identifier: .gregorian)
        eventCalendar.timeZone = eventTimeZone
        draft.scheduleMode = eventCalendar.isDate(normalizedStartDate, inSameDayAs: normalizedEndDate) ? .singleDay : .multiDay
        if let eventTimeZoneID = event.timeZone?.trimmingCharacters(in: .whitespacesAndNewlines), !eventTimeZoneID.isEmpty {
            let localizedCityEn = event.cityI18n?.en.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let rawCity = event.city?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let fallbackCityFromTimeZone = eventTimeZoneID
                .split(separator: "/")
                .last
                .map { String($0).replacingOccurrences(of: "_", with: " ") } ?? ""
            let cityNameCandidate = localizedCityEn.isEmpty ? rawCity : localizedCityEn
            let cityName = cityNameCandidate.canBeConverted(to: .ascii) || cityNameCandidate.isEmpty
                ? cityNameCandidate
                : fallbackCityFromTimeZone
            let countryName = event.countryI18n?.en.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? (event.countryI18n?.en ?? event.country ?? "")
                : (event.country ?? "")
            let effectiveCityName = cityName.isEmpty ? fallbackCityFromTimeZone : cityName
            draft.timeZoneSearchQuery = effectiveCityName.isEmpty ? eventTimeZoneID : effectiveCityName
            draft.selectedTimeZoneLookup = EventTimezoneLookupItem(
                city: effectiveCityName,
                cityAscii: effectiveCityName,
                province: "",
                exactProvince: "",
                stateAnsi: "",
                country: countryName,
                iso2: "",
                iso3: "",
                timezone: eventTimeZoneID,
                lat: nil,
                lng: nil,
                population: nil,
                label: [effectiveCityName, countryName].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.joined(separator: ", "),
                matchSource: "event-edit-hydrate"
            )
        }
        draft.dayRolloverHour = event.dayRolloverHour ?? 6
        draft.latitude = event.latitude ?? event.locationPoint?.location?.lat
        draft.longitude = event.longitude ?? event.locationPoint?.location?.lng
        draft.pickedMapAddress = event.locationPoint?.formattedAddressI18n?.text(for: AppLanguagePreference.current.effectiveLanguage)
            ?? event.locationPoint?.addressI18n?.text(for: AppLanguagePreference.current.effectiveLanguage)
            ?? ""
        draft.pickedPlaceName = event.locationPoint?.nameI18n?.text(for: AppLanguagePreference.current.effectiveLanguage) ?? ""
        let hydratedTicketTiers = event.ticketTiers
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { tier in
                EventUploadTicketTierDraft(
                    name: tier.name,
                    price: tier.price.map { String($0) } ?? ""
                )
            }
        let fallbackTicketTiers: [EventUploadTicketTierDraft]
        if hydratedTicketTiers.isEmpty {
            fallbackTicketTiers = [event.ticketPriceMin, event.ticketPriceMax]
                .compactMap { price in
                    price.map { EventUploadTicketTierDraft(price: String($0)) }
                }
        } else {
            fallbackTicketTiers = hydratedTicketTiers
        }
        draft.ticket = EventUploadTicketDraft(
            currency: event.ticketCurrency ?? "CNY",
            ticketURL: event.ticketUrl ?? "",
            tiers: fallbackTicketTiers
        )
        draft.hydrateTimetableSlots(from: event)
        draft.hydrateLineupOnlySlots(from: event)
        draft.incrementalBaseline = IncrementalBaseline(
            eventRevision: event.revision,
            lineupArtists: EventUploadDraft.incrementalBaselineArtists(from: event),
            lineupSlots: EventUploadDraft.incrementalBaselineSlots(from: event),
            stageOrder: event.stageOrder ?? []
        )
        draft.hydrateRemoteImages(from: event)
        return draft
    }

    var posterImages: [EventUploadImageDraft] {
        imageZones[.poster] ?? []
    }

    var lineupImages: [EventUploadImageDraft] {
        imageZones[.lineup] ?? []
    }

    var coverImages: [EventUploadImageDraft] {
        imageZones[.cover] ?? []
    }

    var requiredEntryImages: [EventUploadImageDraft] {
        posterImages + lineupImages + coverImages
    }

    var hasRequiredEntryImage: Bool {
        !requiredEntryImages.isEmpty
    }

    static func emptyImageZones() -> [EventUploadImageZone: [EventUploadImageDraft]] {
        Dictionary(uniqueKeysWithValues: EventUploadImageZone.allCases.map { ($0, []) })
    }

    mutating func appendImage(_ image: EventUploadImageDraft) {
        var list = imageZones[image.zone] ?? []
        list.append(image)
        imageZones[image.zone] = list
        dirty = true
    }

    private mutating func hydrateRemoteImages(from event: WebEvent) {
        let assets = event.imageAssets ?? []
        var next = Self.emptyImageZones()
        for (index, asset) in assets.enumerated() {
            let zone = EventUploadImageZone.zone(type: asset.type ?? "", label: asset.label ?? "")
            next[zone, default: []].append(
                EventUploadImageDraft(
                    zone: zone,
                    remoteURL: asset.url,
                    fileName: asset.fileName ?? "\(zone.rawValue)-\(index + 1).jpg",
                    mimeType: "image/jpeg",
                    sortOrder: asset.sort ?? index + 1,
                    ownership: .persistedEvent
                )
            )
        }
        imageZones = next
    }

    private mutating func hydrateTimetableSlots(from event: WebEvent) {
        let parsedSlots = event.lineupSlots.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            return lhs.startTime < rhs.startTime
        }
        let eventTimeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
        timetableSlots = parsedSlots.map { slot in
            let act = EventLineupActCodec.parse(slot: slot)
            var draftSlot = EventUploadLineupSlotDraft(
                canonicalSlotId: slot.id,
                actType: act.type,
                performerNames: act.performers.map(\.name),
                performerDJIDs: act.performers.map(\.djID),
                performerAvatarURLs: act.performers.map(\.avatarUrl),
                stageName: slot.stageName ?? "",
                dayIndex: slot.festivalDayIndex ?? 1,
                startDayOffset: EventUploadDraft.slotDayOffset(for: slot.startTime, dayIndex: slot.festivalDayIndex ?? 1, eventStartDate: startDate, timeZone: eventTimeZone),
                endDayOffset: EventUploadDraft.slotDayOffset(for: slot.endTime, dayIndex: slot.festivalDayIndex ?? 1, eventStartDate: startDate, timeZone: eventTimeZone),
                startTime: slot.startTime,
                endTime: slot.endTime
            )
            draftSlot.normalizePerformers()
            return draftSlot
        }
        let stagesFromSlots = parsedSlots.compactMap { slot in
            slot.stageName?.trimmingCharacters(in: .whitespacesAndNewlines).eventUploadNilIfBlank
        }
        let stageOrderFromEvent = (event.stageOrder ?? []).compactMap { stage in
            stage.trimmingCharacters(in: .whitespacesAndNewlines).eventUploadNilIfBlank
        }
        let mergedStages = stageOrderFromEvent + stagesFromSlots.filter { !stageOrderFromEvent.contains($0) }
        if !mergedStages.isEmpty {
            stageEntries = Array(NSOrderedSet(array: mergedStages)) as? [String] ?? mergedStages
        } else if !parsedSlots.isEmpty {
            stageEntries = [""]
        }
    }

    private static func slotDayOffset(for date: Date, dayIndex: Int, eventStartDate: Date, timeZone: TimeZone) -> EventUploadSlotDayOffset {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let logicalDay = calendar.date(byAdding: .day, value: max(dayIndex - 1, 0), to: calendar.startOfDay(for: eventStartDate)) ?? eventStartDate
        let offset = calendar.dateComponents([.day], from: calendar.startOfDay(for: logicalDay), to: calendar.startOfDay(for: date)).day ?? 0
        return offset > 0 ? .nextDay : .sameDay
    }

    private mutating func hydrateLineupOnlySlots(from event: WebEvent) {
        let artists: [WebEventLineupArtist] = event.lineupArtists ?? []
        let parsedArtists = artists.sorted(by: { (lhs: WebEventLineupArtist, rhs: WebEventLineupArtist) in
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            return lhs.djName < rhs.djName
        })
        lineupOnlySlots = parsedArtists.map { artist in
            let act = EventLineupActCodec.parse(artist: artist)
            var draftSlot = EventUploadLineupOnlySlotDraft(
                canonicalArtistId: artist.id,
                actType: act.type,
                performerNames: act.performers.map(\.name),
                performerDJIDs: act.performers.map(\.djID),
                performerAvatarURLs: act.performers.map(\.avatarUrl)
            )
            draftSlot.normalizePerformers()
            return draftSlot
        }
    }

    private static func incrementalBaselineArtists(from event: WebEvent) -> [EventLineupArtistInput] {
        (event.lineupArtists ?? [])
            .sorted(by: { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
                return lhs.djName < rhs.djName
            })
            .map { artist in
                EventLineupArtistInput(
                    id: artist.id,
                    djId: artist.djId,
                    memberDjIds: artist.memberDjIds,
                    memberNames: artist.memberNames,
                    djName: artist.djName,
                    sortOrder: artist.sortOrder
                )
            }
    }

    private static func incrementalBaselineSlots(from event: WebEvent) -> [EventLineupSlotInput] {
        var artistIDsByKey: [String: String] = [:]
        for artist in event.lineupArtists ?? [] {
            let key = EventUploadDraft.incrementalArtistIdentityKey(
                djName: artist.djName,
                djId: artist.djId,
                memberDjIds: artist.memberDjIds,
                memberNames: artist.memberNames
            )
            artistIDsByKey[key] = artistIDsByKey[key] ?? artist.id
        }
        return event.lineupSlots
            .sorted(by: { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
                return lhs.startTime < rhs.startTime
            })
            .map { slot in
                EventLineupSlotInput(
                    id: slot.id,
                    lineupArtistId: artistIDsByKey[EventUploadDraft.incrementalArtistIdentityKey(
                        djName: slot.djName,
                        djId: slot.djId,
                        memberDjIds: slot.memberDjIds,
                        memberNames: slot.memberNames
                    )] ?? nil,
                    djId: slot.djId,
                    memberDjIds: slot.memberDjIds,
                    memberNames: slot.memberNames,
                    festivalDayIndex: slot.festivalDayIndex,
                    djName: slot.djName,
                    stageName: slot.stageName,
                    sortOrder: slot.sortOrder,
                    startTime: slot.startTime,
                    endTime: slot.endTime
                )
            }
    }

    private static func incrementalArtistIdentityKey(
        djName: String,
        djId: String?,
        memberDjIds: [String?]?,
        memberNames: [String]?
    ) -> String {
        let primaryDjID = djId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !primaryDjID.isEmpty {
            return "dj:\(primaryDjID)"
        }
        let normalizedMemberDJIDs = (memberDjIds ?? [])
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted()
        if !normalizedMemberDJIDs.isEmpty {
            return "members:\(normalizedMemberDJIDs.joined(separator: "|"))"
        }
        let normalizedMemberNames = (memberNames ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
            .sorted()
        if !normalizedMemberNames.isEmpty {
            return "names:\(normalizedMemberNames.joined(separator: "|"))"
        }
        return "name:\(djName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
    }
}

enum EventUploadMode: Hashable, Codable {
    case create
    case edit(eventID: String)

    var storageKeyPart: String {
        switch self {
        case .create: return "create"
        case .edit(let eventID): return "edit.\(eventID)"
        }
    }
}

private extension EventUploadImageZone {
    static func zone(type: String, label: String) -> EventUploadImageZone {
        let normalizedType = type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if normalizedType == "cover" { return .cover }
        if normalizedType == "luall" || normalizedType == "lineup" { return .lineup }
        if normalizedType == "tt" || normalizedType == "timetable" { return .timetable }
        if normalizedLabel.contains("POSTER") { return .poster }
        if normalizedLabel.contains("MAP") { return .map }
        return .other
    }
}

private extension String {
    var eventUploadNilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
