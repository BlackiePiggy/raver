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
        case .poster, .map, .other: return "other"
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
    var id: UUID = UUID()
    var zone: EventUploadImageZone
    var localFileURL: URL?
    var remoteURL: String?
    var fileName: String
    var mimeType: String
    var sortOrder: Int
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

    func primaryValue(preferredLanguage: EventUploadPreferredLanguage) -> String {
        switch preferredLanguage {
        case .zh: return zh.eventUploadNilIfBlank ?? en.eventUploadNilIfBlank ?? ja.eventUploadNilIfBlank ?? enFull
        case .en: return en.eventUploadNilIfBlank ?? enFull.eventUploadNilIfBlank ?? zh.eventUploadNilIfBlank ?? ja
        case .ja: return ja.eventUploadNilIfBlank ?? en.eventUploadNilIfBlank ?? zh.eventUploadNilIfBlank ?? enFull
        }
    }

    func currentValue(preferredLanguage: EventUploadPreferredLanguage) -> String {
        switch preferredLanguage {
        case .zh: return zh
        case .en: return en
        case .ja: return ja
        }
    }

    mutating func setCurrentValue(_ value: String, preferredLanguage: EventUploadPreferredLanguage) {
        switch preferredLanguage {
        case .zh:
            zh = value
        case .en:
            en = value
        case .ja:
            ja = value
        }
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

struct EventUploadTicketDraft: Hashable, Codable {
    var priceMin: String = ""
    var priceMax: String = ""
    var currency: String = "CNY"
    var ticketURL: String = ""
}

struct EventUploadWeekRangeDraft: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var startDate: Date
    var endDate: Date
}

struct EventUploadLineupSlotDraft: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var actType: EventLineupActType = .solo
    var performerNames: [String] = [""]
    var performerDJIDs: [String?] = [nil]
    var performerAvatarURLs: [String?] = [nil]
    var stageName: String = ""
    var dayIndex: Int = 1
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

struct EventUploadDraft: Hashable, Codable {
    var id: UUID = UUID()
    var mode: EventUploadMode = .create
    var currentStep: EventUploadStep = .media
    var preferredLanguage: EventUploadPreferredLanguage = .current
    var imageZones: [EventUploadImageZone: [EventUploadImageDraft]] = EventUploadDraft.emptyImageZones()
    var name = EventUploadLocalizedFields()
    var description = EventUploadLocalizedFields()
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
        draft.eventType = event.eventType ?? ""
        draft.organizerFestivalID = event.wikiFestivalId ?? event.wikiFestival?.id
        draft.organizerName = event.wikiFestival?.nameI18n?.text(for: AppLanguagePreference.current.effectiveLanguage)
            ?? event.wikiFestival?.name
            ?? event.organizerName
            ?? ""
        draft.sourceURL = event.officialWebsite ?? ""
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
        draft.detailAddress = EventUploadLocalizedFields(
            zh: event.manualLocation?.detailAddressI18n?.zh ?? "",
            en: event.manualLocation?.detailAddressI18n?.en ?? "",
            ja: event.manualLocation?.detailAddressI18n?.ja ?? "",
            enFull: event.manualLocation?.detailAddressI18n?.enFull ?? ""
        )
        draft.startDate = event.startDate
        draft.endDate = event.endDate
        draft.weekRanges = [EventUploadWeekRangeDraft(startDate: event.startDate, endDate: event.endDate)]
        draft.timeZoneIdentifier = event.timeZone ?? draft.timeZoneIdentifier
        if let eventTimeZone = event.timeZone?.trimmingCharacters(in: .whitespacesAndNewlines), !eventTimeZone.isEmpty {
            let localizedCityEn = event.cityI18n?.en.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let rawCity = event.city?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let fallbackCityFromTimeZone = eventTimeZone
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
            draft.timeZoneSearchQuery = effectiveCityName.isEmpty ? eventTimeZone : effectiveCityName
            draft.selectedTimeZoneLookup = EventTimezoneLookupItem(
                city: effectiveCityName,
                cityAscii: effectiveCityName,
                province: "",
                exactProvince: "",
                stateAnsi: "",
                country: countryName,
                iso2: "",
                iso3: "",
                timezone: eventTimeZone,
                lat: event.latitude,
                lng: event.longitude,
                population: nil,
                label: [effectiveCityName, countryName].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.joined(separator: ", "),
                matchSource: "event-edit-hydrate"
            )
        }
        draft.dayRolloverHour = event.dayRolloverHour ?? 6
        draft.latitude = event.latitude
        draft.longitude = event.longitude
        draft.pickedMapAddress = event.locationPoint?.formattedAddressI18n?.text(for: AppLanguagePreference.current.effectiveLanguage)
            ?? event.locationPoint?.addressI18n?.text(for: AppLanguagePreference.current.effectiveLanguage)
            ?? ""
        draft.pickedPlaceName = event.locationPoint?.nameI18n?.text(for: AppLanguagePreference.current.effectiveLanguage) ?? ""
        draft.ticket = EventUploadTicketDraft(
            priceMin: event.ticketPriceMin.map { String($0) } ?? "",
            priceMax: event.ticketPriceMax.map { String($0) } ?? "",
            currency: event.ticketCurrency ?? "CNY",
            ticketURL: event.ticketUrl ?? ""
        )
        draft.hydrateTimetableSlots(from: event)
        draft.hydrateLineupOnlySlots(from: event)
        draft.hydrateRemoteImages(from: event)
        return draft
    }

    var posterImages: [EventUploadImageDraft] {
        imageZones[.poster] ?? []
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
                    sortOrder: asset.sort ?? index + 1
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
        timetableSlots = parsedSlots.map { slot in
            let act = EventLineupActCodec.parse(slot: slot)
            var draftSlot = EventUploadLineupSlotDraft(
                actType: act.type,
                performerNames: act.performers.map(\.name),
                performerDJIDs: act.performers.map(\.djID),
                performerAvatarURLs: act.performers.map(\.avatarUrl),
                stageName: slot.stageName ?? "",
                dayIndex: slot.festivalDayIndex ?? 1,
                startTime: slot.startTime,
                endTime: slot.endTime
            )
            draftSlot.normalizePerformers()
            return draftSlot
        }
        let stagesFromSlots = parsedSlots.compactMap { slot in
            slot.stageName?.trimmingCharacters(in: .whitespacesAndNewlines).eventUploadNilIfBlank
        }
        if !stagesFromSlots.isEmpty {
            stageEntries = Array(NSOrderedSet(array: stagesFromSlots)) as? [String] ?? stagesFromSlots
        }
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
                actType: act.type,
                performerNames: act.performers.map(\.name),
                performerDJIDs: act.performers.map(\.djID),
                performerAvatarURLs: act.performers.map(\.avatarUrl)
            )
            draftSlot.normalizePerformers()
            return draftSlot
        }
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
