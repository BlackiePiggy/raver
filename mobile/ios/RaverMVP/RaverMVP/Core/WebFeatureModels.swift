import Foundation
import Combine

struct BFFPagination: Codable {
    let page: Int
    let limit: Int
    let total: Int
    let totalPages: Int
}

struct EventListPage: Codable {
    var items: [WebEvent]
    var pagination: BFFPagination?
}

struct DJListPage: Codable {
    var items: [WebDJ]
    var pagination: BFFPagination?
}

struct DJSetListPage: Codable {
    var items: [WebDJSet]
    var pagination: BFFPagination?
}

struct CheckinListPage: Codable {
    var items: [WebCheckin]
    var pagination: BFFPagination?
}

struct LearnLabelListPage: Codable {
    var items: [LearnLabel]
    var pagination: BFFPagination?
}

struct WebBiText: Codable, Hashable {
    var en: String
    var zh: String
    var enFull: String? = nil

    func text(for language: AppLanguage) -> String {
        switch language.effectiveLanguage {
        case .zh:
            let zhText = zh.trimmingCharacters(in: .whitespacesAndNewlines)
            if !zhText.isEmpty { return zhText }
            let enFullText = (enFull ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !enFullText.isEmpty { return enFullText }
            return en
        case .en, .system:
            let enFullText = (enFull ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !enFullText.isEmpty { return enFullText }
            let enText = en.trimmingCharacters(in: .whitespacesAndNewlines)
            if !enText.isEmpty { return enText }
            return zh
        }
    }
}

struct LearnFestivalLinkPayload: Codable, Hashable {
    var title: String
    var icon: String
    var url: String
}

struct WebLearnFestival: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var nameI18n: WebBiText? = nil
    var sourceRowId: Int? = nil
    var abbreviation: String? = nil
    var aliases: [String]
    var country: String
    var countryI18n: WebBiText? = nil
    var city: String
    var cityI18n: WebBiText? = nil
    var foundedYear: String
    var frequency: String
    var frequencyI18n: WebBiText? = nil
    var tagline: String
    var introduction: String
    var descriptionI18n: WebBiText? = nil
    var officialWebsite: String? = nil
    var facebookUrl: String? = nil
    var instagramUrl: String? = nil
    var twitterUrl: String? = nil
    var youtubeUrl: String? = nil
    var tiktokUrl: String? = nil
    var avatarUrl: String?
    var backgroundUrl: String?
    var links: [LearnFestivalLinkPayload]
    var contributors: [WebUserLite]
    var canEdit: Bool?
    var createdAt: Date?
    var updatedAt: Date?
}

struct UpdateLearnFestivalInput: Codable {
    var name: String?
    var nameI18n: WebBiText? = nil
    var sourceRowId: Int? = nil
    var abbreviation: String? = nil
    var aliases: [String]?
    var country: String?
    var countryI18n: WebBiText? = nil
    var city: String?
    var cityI18n: WebBiText? = nil
    var foundedYear: String?
    var frequency: String?
    var frequencyI18n: WebBiText? = nil
    var tagline: String?
    var introduction: String?
    var descriptionI18n: WebBiText? = nil
    var officialWebsite: String? = nil
    var facebookUrl: String? = nil
    var instagramUrl: String? = nil
    var twitterUrl: String? = nil
    var youtubeUrl: String? = nil
    var tiktokUrl: String? = nil
    var avatarUrl: String?
    var backgroundUrl: String?
    var links: [LearnFestivalLinkPayload]?
}

struct CreateLearnFestivalInput: Codable {
    var name: String
    var nameI18n: WebBiText? = nil
    var sourceRowId: Int? = nil
    var abbreviation: String? = nil
    var aliases: [String]?
    var country: String?
    var countryI18n: WebBiText? = nil
    var city: String?
    var cityI18n: WebBiText? = nil
    var foundedYear: String?
    var frequency: String?
    var frequencyI18n: WebBiText? = nil
    var tagline: String?
    var introduction: String?
    var descriptionI18n: WebBiText? = nil
    var officialWebsite: String? = nil
    var facebookUrl: String? = nil
    var instagramUrl: String? = nil
    var twitterUrl: String? = nil
    var youtubeUrl: String? = nil
    var tiktokUrl: String? = nil
    var avatarUrl: String?
    var backgroundUrl: String?
    var links: [LearnFestivalLinkPayload]?
}

struct WebUserLite: Codable, Identifiable, Hashable {
    let id: String
    var username: String
    var displayName: String?
    var avatarUrl: String?

    var shownName: String {
        let trimmed = displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? username : trimmed
    }
}

struct WebEventTicketTier: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var price: Double?
    var currency: String?
    var sortOrder: Int
}

struct WebEventLineupSlotDJ: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var avatarUrl: String?
    var avatarOriginalUrl: String? = nil
    var avatarMediumUrl: String? = nil
    var avatarSmallUrl: String? = nil
    var bannerUrl: String?
    var country: String?
    var followerCount: Int? = nil
    var soundCloudFollowers: Int? = nil
}

struct WebEventLineupSlot: Codable, Identifiable, Hashable {
    let id: String
    var eventId: String?
    var djId: String?
    var djIds: [String]? = nil
    var festivalDayIndex: Int? = nil
    var djName: String
    var stageName: String?
    var sortOrder: Int
    var startTime: Date
    var endTime: Date
    var dj: WebEventLineupSlotDJ?
}

struct EventLineupSlotInput: Codable, Hashable {
    var djId: String?
    var festivalDayIndex: Int? = nil
    var djName: String
    var stageName: String?
    var sortOrder: Int?
    var startTime: Date?
    var endTime: Date?
}

struct EventTicketTierInput: Codable, Hashable {
    var name: String
    var price: Double
    var currency: String?
    var sortOrder: Int?
}

struct WebEventImageAsset: Codable, Hashable, Identifiable {
    var id: String {
        let typePart = type?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "other"
        return "\(typePart)|\(url)"
    }

    var url: String
    var type: String?
    var label: String?
    var sort: Int?
    var order: Int?
    var source: String?
    var fileName: String?
}

struct WebEventLocationCoordinate: Codable, Hashable {
    var lng: Double
    var lat: Double
}

struct WebEventLocationPoint: Codable, Hashable {
    var provider: String? = nil
    var sourceMode: String? = nil
    var providerPlaceId: String? = nil
    var poiId: String? = nil
    var location: WebEventLocationCoordinate? = nil
    var nameI18n: WebBiText? = nil
    var addressI18n: WebBiText? = nil
    var formattedAddressI18n: WebBiText? = nil
    var city: String? = nil
    var district: String? = nil
    var province: String? = nil
    var countryCode: String? = nil
}

struct WebEventManualLocation: Codable, Hashable {
    var detailAddressI18n: WebBiText? = nil
    var formattedAddressI18n: WebBiText? = nil
    var selectedAt: Date? = nil
}

private func normalizedAddressText(_ value: String?) -> String? {
    let text = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return text.isEmpty ? nil : text
}

private func localizedAddressText(_ value: WebBiText?, language: AppLanguage) -> String? {
    let localized = value?.text(for: language).trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if !localized.isEmpty { return localized }
    let zh = value?.zh.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if !zh.isEmpty { return zh }
    let en = value?.en.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return en.isEmpty ? nil : en
}

private func joinAddressComponents(_ values: [String?]) -> String {
    var seen = Set<String>()
    var items: [String] = []
    for value in values {
        guard let text = normalizedAddressText(value) else { continue }
        let key = text.lowercased()
        if seen.contains(key) { continue }
        seen.insert(key)
        items.append(text)
    }
    return items.joined(separator: " · ")
}

private func resolveEventUnifiedAddress(
    language: AppLanguage,
    manualLocation: WebEventManualLocation?,
    locationPoint: WebEventLocationPoint?,
    cityI18n: WebBiText?,
    city: String?,
    countryI18n: WebBiText?,
    country: String?
) -> String {
    if let manualFormatted = localizedAddressText(manualLocation?.formattedAddressI18n, language: language) {
        return manualFormatted
    }

    if let pointFormatted = localizedAddressText(locationPoint?.formattedAddressI18n, language: language) {
        return pointFormatted
    }

    // Fallback for old records missing formattedAddressI18n.
    if let manualDetailText = localizedAddressText(manualLocation?.detailAddressI18n, language: language) {
        return manualDetailText
    }

    // Last fallback (legacy): still avoid multi-part composition.
    if let cityText = localizedAddressText(cityI18n, language: language) ?? normalizedAddressText(city) {
        return cityText
    }
    if let countryText = localizedAddressText(countryI18n, language: language) ?? normalizedAddressText(country) {
        return countryText
    }
    return ""
}

struct WebEventFestivalLite: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var nameI18n: WebBiText? = nil
    var country: String?
    var countryI18n: WebBiText? = nil
    var city: String?
    var cityI18n: WebBiText? = nil
    var avatarUrl: String?
    var backgroundUrl: String?
}

struct WebEvent: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var nameI18n: WebBiText? = nil
    var wikiFestivalId: String? = nil
    var slug: String
    var description: String?
    var descriptionI18n: WebBiText? = nil
    var countryI18n: WebBiText? = nil
    var cityI18n: WebBiText? = nil
    var coverImageUrl: String?
    var lineupImageUrl: String?
    var imageAssets: [WebEventImageAsset]? = nil
    var eventType: String?
    var organizerName: String?
    var city: String?
    var country: String?
    var manualLocation: WebEventManualLocation? = nil
    var locationPoint: WebEventLocationPoint? = nil
    var latitude: Double?
    var longitude: Double?
    var startDate: Date
    var endDate: Date
    var startTime: String? = nil
    var endTime: String? = nil
    var dayRolloverHour: Int? = nil
    var stageOrder: [String]? = nil
    var ticketUrl: String?
    var ticketPriceMin: Double?
    var ticketPriceMax: Double?
    var ticketCurrency: String?
    var ticketNotes: String?
    var officialWebsite: String?
    var status: String?
    var isVerified: Bool?
    var createdAt: Date
    var updatedAt: Date
    var organizer: WebUserLite?
    var wikiFestival: WebEventFestivalLite? = nil
    var ticketTiers: [WebEventTicketTier]
    var lineupSlots: [WebEventLineupSlot]

    var unifiedAddress: String {
        resolveEventUnifiedAddress(
            language: AppLanguagePreference.current.effectiveLanguage,
            manualLocation: manualLocation,
            locationPoint: locationPoint,
            cityI18n: cityI18n,
            city: city,
            countryI18n: countryI18n,
            country: country
        )
    }

    var summaryLocation: String {
        unifiedAddress
    }
}

struct CreateEventInput: Codable {
    var name: String
    var wikiFestivalId: String? = nil
    var description: String?
    var eventType: String? = nil
    var city: String?
    var cityI18n: WebBiText? = nil
    var country: String?
    var countryI18n: WebBiText? = nil
    var manualLocation: WebEventManualLocation? = nil
    var locationPoint: WebEventLocationPoint? = nil
    var latitude: Double? = nil
    var longitude: Double? = nil
    var ticketUrl: String? = nil
    var ticketCurrency: String? = nil
    var ticketNotes: String? = nil
    var officialWebsite: String? = nil
    var startDate: Date
    var endDate: Date
    var startTime: String? = nil
    var endTime: String? = nil
    var dayRolloverHour: Int? = nil
    var stageOrder: [String]? = nil
    var coverImageUrl: String?
    var lineupImageUrl: String?
    var ticketTiers: [EventTicketTierInput]? = nil
    var lineupSlots: [EventLineupSlotInput]? = nil
    var status: String?
}

struct UpdateEventInput: Encodable {
    var name: String?
    var wikiFestivalId: String? = nil
    var description: String?
    var eventType: String? = nil
    var city: String?
    var cityI18n: WebBiText? = nil
    var country: String?
    var countryI18n: WebBiText? = nil
    var manualLocation: WebEventManualLocation? = nil
    var locationPoint: WebEventLocationPoint? = nil
    var latitude: Double? = nil
    var longitude: Double? = nil
    var ticketUrl: String? = nil
    var ticketCurrency: String? = nil
    var ticketNotes: String? = nil
    var officialWebsite: String? = nil
    var startDate: Date?
    var endDate: Date?
    var startTime: String? = nil
    var endTime: String? = nil
    var dayRolloverHour: Int? = nil
    var stageOrder: [String]? = nil
    var coverImageUrl: String?
    var lineupImageUrl: String?
    var ticketTiers: [EventTicketTierInput]? = nil
    var lineupSlots: [EventLineupSlotInput]? = nil
    var status: String?
    var clearCityI18n: Bool = false
    var clearCountryI18n: Bool = false
    var clearManualLocation: Bool = false

    enum CodingKeys: String, CodingKey {
        case name
        case wikiFestivalId
        case description
        case eventType
        case city
        case cityI18n
        case country
        case countryI18n
        case manualLocation
        case locationPoint
        case latitude
        case longitude
        case ticketUrl
        case ticketCurrency
        case ticketNotes
        case officialWebsite
        case startDate
        case endDate
        case startTime
        case endTime
        case dayRolloverHour
        case stageOrder
        case coverImageUrl
        case lineupImageUrl
        case ticketTiers
        case lineupSlots
        case status
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(wikiFestivalId, forKey: .wikiFestivalId)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(eventType, forKey: .eventType)
        try container.encodeIfPresent(city, forKey: .city)
        if clearCityI18n {
            try container.encodeNil(forKey: .cityI18n)
        } else {
            try container.encodeIfPresent(cityI18n, forKey: .cityI18n)
        }
        try container.encodeIfPresent(country, forKey: .country)
        if clearCountryI18n {
            try container.encodeNil(forKey: .countryI18n)
        } else {
            try container.encodeIfPresent(countryI18n, forKey: .countryI18n)
        }
        if clearManualLocation {
            try container.encodeNil(forKey: .manualLocation)
        } else {
            try container.encodeIfPresent(manualLocation, forKey: .manualLocation)
        }
        try container.encodeIfPresent(locationPoint, forKey: .locationPoint)
        try container.encodeIfPresent(latitude, forKey: .latitude)
        try container.encodeIfPresent(longitude, forKey: .longitude)
        try container.encodeIfPresent(ticketUrl, forKey: .ticketUrl)
        try container.encodeIfPresent(ticketCurrency, forKey: .ticketCurrency)
        try container.encodeIfPresent(ticketNotes, forKey: .ticketNotes)
        try container.encodeIfPresent(officialWebsite, forKey: .officialWebsite)
        try container.encodeIfPresent(startDate, forKey: .startDate)
        try container.encodeIfPresent(endDate, forKey: .endDate)
        try container.encodeIfPresent(startTime, forKey: .startTime)
        try container.encodeIfPresent(endTime, forKey: .endTime)
        try container.encodeIfPresent(dayRolloverHour, forKey: .dayRolloverHour)
        try container.encodeIfPresent(stageOrder, forKey: .stageOrder)
        try container.encodeIfPresent(coverImageUrl, forKey: .coverImageUrl)
        try container.encodeIfPresent(lineupImageUrl, forKey: .lineupImageUrl)
        try container.encodeIfPresent(ticketTiers, forKey: .ticketTiers)
        try container.encodeIfPresent(lineupSlots, forKey: .lineupSlots)
        try container.encodeIfPresent(status, forKey: .status)
    }
}

struct WebDJ: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var nameI18n: WebBiText? = nil
    var aliases: [String]?
    var genres: [String]? = nil
    var slug: String?
    var bio: String?
    var bioI18n: WebBiText? = nil
    var avatarUrl: String?
    var avatarOriginalUrl: String? = nil
    var avatarMediumUrl: String? = nil
    var avatarSmallUrl: String? = nil
    var avatarSourceUrl: String? = nil
    var bannerUrl: String?
    var country: String?
    var countryI18n: WebBiText? = nil
    var spotifyId: String?
    var appleMusicId: String?
    var soundcloudUrl: String?
    var instagramUrl: String?
    var twitterUrl: String?
    var isVerified: Bool?
    var followerCount: Int?
    var soundCloudFollowers: Int? = nil
    var eventCount: Int? = nil
    var eventsCount: Int? = nil
    var upcomingShows: Int? = nil
    var setCount: Int? = nil
    var setsCount: Int? = nil
    var djSetCount: Int? = nil
    var sourceDataSource: String? = nil
    var contributors: [WebUserLite]? = nil
    var contributorUsernames: [String]? = nil
    var uploadedByUsername: String? = nil
    var isContributor: Bool? = nil
    var canEdit: Bool? = nil
    var createdAt: Date?
    var updatedAt: Date?
    var isFollowing: Bool?
}

struct WebDJSetTrack: Codable, Identifiable, Hashable {
    let id: String
    var position: Int
    var startTime: Int
    var endTime: Int?
    var title: String
    var artist: String
    var status: String
    var spotifyUrl: String?
    var spotifyId: String?
    var spotifyUri: String?
    var neteaseUrl: String?
    var neteaseId: String?
    var createdAt: Date
    var updatedAt: Date
}

struct WebTracklistSummary: Codable, Identifiable, Hashable {
    let id: String
    var setId: String
    var title: String?
    var isDefault: Bool
    var createdAt: Date
    var updatedAt: Date
    var contributor: WebContributorProfile?
    var trackCount: Int
}

struct WebTracklistDetail: Codable, Identifiable, Hashable {
    let id: String
    var setId: String
    var title: String?
    var isDefault: Bool
    var createdAt: Date
    var updatedAt: Date
    var contributor: WebContributorProfile?
    var tracks: [WebDJSetTrack]
}

struct WebDJSet: Codable, Identifiable, Hashable {
    let id: String
    var djId: String
    var title: String
    var slug: String
    var description: String?
    var thumbnailUrl: String?
    var videoUrl: String
    var platform: String
    var videoId: String
    var duration: Int?
    var recordedAt: Date?
    var venue: String?
    var eventName: String?
    var viewCount: Int
    var likeCount: Int
    var isVerified: Bool
    var createdAt: Date
    var updatedAt: Date
    var uploadedById: String
    var coDjIds: [String]
    var customDjNames: [String]
    var dj: WebDJ?
    var lineupDjs: [WebDJ]
    var tracks: [WebDJSetTrack]
    var trackCount: Int
    var uploader: WebUserLite?
    var videoContributor: WebContributorProfile?
    var tracklistContributor: WebContributorProfile?
}

struct WebContributorProfile: Codable, Identifiable, Hashable {
    let id: String
    var username: String
    var displayName: String?
    var avatarUrl: String?
    var bio: String?
    var location: String?
    var favoriteGenres: [String]
    var favoriteDJs: [String]

    var shownName: String {
        let trimmed = displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? username : trimmed
    }
}

struct CreateDJSetInput: Codable {
    var djId: String
    var title: String
    var videoUrl: String
    var thumbnailUrl: String?
    var description: String?
    var venue: String?
    var eventName: String?
    var recordedAt: Date?
}

struct UpdateDJSetInput: Codable {
    var djId: String?
    var title: String?
    var videoUrl: String?
    var thumbnailUrl: String?
    var description: String?
    var venue: String?
    var eventName: String?
    var recordedAt: Date?
}

struct ReplaceTracksInput: Codable {
    var tracks: [CreateTrackInput]
}

struct CreateTracklistInput: Codable {
    var title: String?
    var tracks: [CreateTrackInput]
}

struct CreateTrackInput: Codable, Hashable {
    var position: Int
    var startTime: Int
    var endTime: Int?
    var title: String
    var artist: String
    var status: String
    var spotifyUrl: String?
    var neteaseUrl: String?
}

struct WebSetComment: Codable, Identifiable, Hashable {
    let id: String
    var setId: String
    var userId: String
    var content: String
    var parentId: String?
    var createdAt: Date
    var updatedAt: Date
    var user: WebUserLite
    var replies: [WebSetComment]?
}

struct CreateSetCommentInput: Codable {
    var content: String
    var parentId: String?
}

struct WebCheckin: Codable, Identifiable, Hashable {
    let id: String
    var userId: String
    var eventId: String?
    var djId: String?
    var type: String
    var note: String?
    var photoUrl: String?
    var rating: Int?
    var attendedAt: Date
    var createdAt: Date
    var event: CheckinEventLite?
    var dj: CheckinDJLite?
}

struct EventAttendanceDJSelection: Codable, Hashable, Identifiable {
    let id: String
    var name: String
    var avatarUrl: String?
    var country: String?
}

struct EventAttendanceDaySelectionPayload: Codable, Hashable, Identifiable {
    var id: String { dayID }
    var dayID: String
    var dayIndex: Int
    var djSelections: [EventAttendanceDJSelection]
}

extension WebCheckin {
    private static let eventAttendanceNotePrefix = "event_checkin_v1:"

    var normalizedNote: String {
        note?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
    }

    var isMarkedCheckin: Bool {
        normalizedNote == "marked"
    }

    var isEventAttendanceCheckin: Bool {
        type == "event" && !isMarkedCheckin
    }

    var eventAttendanceSelections: [EventAttendanceDaySelectionPayload] {
        guard let note else { return [] }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix(Self.eventAttendanceNotePrefix) else { return [] }
        let payloadString = String(trimmed.dropFirst(Self.eventAttendanceNotePrefix.count))
        guard let data = payloadString.data(using: .utf8) else { return [] }
        if let payloads = try? JSONDecoder().decode([EventAttendanceDaySelectionPayload].self, from: data) {
            return payloads
        }
        if let payload = try? JSONDecoder().decode(EventAttendanceDaySelectionPayload.self, from: data) {
            return [payload]
        }
        return []
    }

    var eventAttendanceSelection: EventAttendanceDaySelectionPayload? {
        eventAttendanceSelections.first
    }

    static func makeEventAttendanceNote(selections: [EventAttendanceDaySelectionPayload]) -> String? {
        guard let data = try? JSONEncoder().encode(selections),
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }
        return "\(eventAttendanceNotePrefix)\(json)"
    }

    static func makeEventAttendanceNote(payload: EventAttendanceDaySelectionPayload) -> String? {
        makeEventAttendanceNote(selections: [payload])
    }
}

struct CheckinEventLite: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var nameI18n: WebBiText? = nil
    var cityI18n: WebBiText? = nil
    var countryI18n: WebBiText? = nil
    var manualLocation: WebEventManualLocation? = nil
    var locationPoint: WebEventLocationPoint? = nil
    var coverImageUrl: String?
    var city: String?
    var country: String?
    var startDate: Date?
    var endDate: Date?

    var unifiedAddress: String {
        resolveEventUnifiedAddress(
            language: AppLanguagePreference.current.effectiveLanguage,
            manualLocation: manualLocation,
            locationPoint: locationPoint,
            cityI18n: cityI18n,
            city: city,
            countryI18n: countryI18n,
            country: country
        )
    }
}

struct CheckinDJLite: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var nameI18n: WebBiText? = nil
    var avatarUrl: String?
    var country: String?
    var countryI18n: WebBiText? = nil
    var followerCount: Int? = nil
    var soundCloudFollowers: Int? = nil
}

struct CreateCheckinInput: Codable {
    var type: String
    var eventId: String?
    var djId: String?
    var note: String?
    var rating: Int?
    var attendedAt: Date? = nil
}

struct UpdateCheckinInput: Codable {
    var eventId: String?
    var djId: String?
    var note: String?
    var rating: Int?
    var attendedAt: Date? = nil
}

struct WebRatingComment: Codable, Identifiable, Hashable {
    let id: String
    var unitId: String
    var userId: String
    var score: Double
    var content: String
    var createdAt: Date
    var updatedAt: Date
    var user: WebUserLite?
}

struct WebRatingUnitEventLite: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var description: String?
    var imageUrl: String?
}

struct WebRatingUnit: Codable, Identifiable, Hashable {
    let id: String
    var eventId: String
    var name: String
    var description: String?
    var imageUrl: String?
    var linkedDJs: [WebEventLineupSlotDJ]? = nil
    var createdAt: Date
    var updatedAt: Date
    var rating: Double
    var ratingCount: Int
    var comments: [WebRatingComment]
    var event: WebRatingUnitEventLite?
    var createdBy: WebUserLite?
}

struct WebRatingEvent: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var description: String?
    var imageUrl: String?
    var sourceEventId: String? = nil
    var createdAt: Date
    var updatedAt: Date
    var createdBy: WebUserLite?
    var units: [WebRatingUnit]
}

struct CreateRatingEventInput: Codable {
    var name: String
    var description: String?
    var imageUrl: String?
}

struct CreateRatingUnitInput: Codable {
    var name: String
    var description: String?
    var imageUrl: String?
}

struct UpdateRatingEventInput: Codable {
    var name: String?
    var description: String?
    var imageUrl: String?
}

struct UpdateRatingUnitInput: Codable {
    var name: String?
    var description: String?
    var imageUrl: String?
}

struct CreateRatingCommentInput: Codable {
    var score: Double
    var content: String
}

struct LearnGenreNode: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var description: String
    var children: [LearnGenreNode]?
}

struct RankingBoard: Codable, Identifiable, Hashable {
    let id: String
    var title: String
    var subtitle: String?
    var coverImageUrl: String?
    var years: [Int]
}

struct RankingBoardDetail: Codable, Hashable {
    var boardId: String
    var title: String
    var years: [Int]
    var year: Int
    var entries: [RankingEntry]
}

struct RankingEntry: Codable, Identifiable, Hashable {
    var rank: Int
    var name: String
    var delta: Int?
    var dj: WebDJ?
    var festival: RankingFestivalLite? = nil

    var id: String {
        "\(rank)-\(name)"
    }
}

struct RankingFestivalLite: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var avatarUrl: String?
    var backgroundUrl: String?
    var country: String?
    var city: String?
    var tagline: String?
}

struct LearnLabel: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var slug: String
    var profileUrl: String
    var profileSlug: String?
    var avatarUrl: String?
    var backgroundUrl: String?
    var nation: String?
    var soundcloudFollowers: Int?
    var likes: Int?
    var genres: [String]
    var genresPreview: String?
    var latestReleaseListing: String?
    var locationPeriod: String?
    var introduction: String?
    var generalContactEmail: String?
    var demoSubmissionUrl: String?
    var demoSubmissionDisplay: String?
    var facebookUrl: String?
    var soundcloudUrl: String?
    var musicPurchaseUrl: String?
    var officialWebsiteUrl: String?
    var founderName: String?
    var foundedAt: String?
    var founderDj: WebDJ?
}

struct MyPublishes: Codable, Hashable {
    var djSets: [MyPublishSet]
    var events: [MyPublishEvent]
    var ratingEvents: [MyPublishRatingEvent]
    var ratingUnits: [MyPublishRatingUnit]
}

struct MyPublishSet: Codable, Identifiable, Hashable {
    let id: String
    var title: String
    var thumbnailUrl: String?
    var createdAt: Date
    var trackCount: Int
    var dj: WebDJ?
}

struct MyPublishEvent: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var nameI18n: WebBiText? = nil
    var cityI18n: WebBiText? = nil
    var countryI18n: WebBiText? = nil
    var manualLocation: WebEventManualLocation? = nil
    var locationPoint: WebEventLocationPoint? = nil
    var coverImageUrl: String?
    var city: String?
    var country: String?
    var startDate: Date
    var createdAt: Date
    var lineupSlotCount: Int

    var unifiedAddress: String {
        resolveEventUnifiedAddress(
            language: AppLanguagePreference.current.effectiveLanguage,
            manualLocation: manualLocation,
            locationPoint: locationPoint,
            cityI18n: cityI18n,
            city: city,
            countryI18n: countryI18n,
            country: country
        )
    }
}

struct MyPublishRatingEvent: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var imageUrl: String?
    var description: String?
    var unitCount: Int
    var createdAt: Date
}

struct MyPublishRatingUnit: Codable, Identifiable, Hashable {
    let id: String
    var eventId: String
    var eventName: String
    var name: String
    var imageUrl: String?
    var description: String?
    var createdAt: Date
}

struct UploadMediaResponse: Codable, Hashable {
    var url: String
    var fileName: String
    var mimeType: String
    var size: Int
}

struct EventLineupImageImportItem: Codable, Hashable, Identifiable {
    let id: String
    var musician: String
    var time: String?
    var stage: String?
    var date: String?
}

struct EventLineupImageImportResponse: Codable, Hashable {
    var normalizedText: String
    var lineupInfo: [EventLineupImageImportItem]
}

struct SpotifyDJCandidate: Codable, Hashable, Identifiable {
    var id: String { spotifyId }
    var spotifyId: String
    var name: String
    var uri: String
    var url: String?
    var popularity: Int
    var followers: Int
    var genres: [String]
    var imageUrl: String?
    var existingDJId: String?
    var existingDJName: String?
    var existingMatchType: String?
}

struct DiscogsDJCandidate: Codable, Hashable, Identifiable {
    var id: Int { artistId }
    var artistId: Int
    var name: String
    var thumbUrl: String?
    var coverImageUrl: String?
    var resourceUrl: String?
    var uri: String?
    var existingDJId: String?
    var existingDJName: String?
    var existingMatchType: String?
}

struct DiscogsDJArtistDetail: Codable, Hashable {
    var artistId: Int
    var name: String
    var realName: String?
    var profile: String?
    var urls: [String]
    var nameVariations: [String]
    var aliases: [String]
    var groups: [String]
    var primaryImageUrl: String?
    var thumbnailImageUrl: String?
    var resourceUrl: String?
    var uri: String?
    var existingDJId: String?
    var existingDJName: String?
    var existingMatchType: String?
}

struct ImportSpotifyDJInput: Codable, Hashable {
    var spotifyId: String
    var name: String?
    var aliases: [String]?
    var bio: String?
    var country: String?
    var instagramUrl: String?
    var soundcloudUrl: String?
    var twitterUrl: String?
    var isVerified: Bool?
}

struct ImportSpotifyDJResponse: Codable, Hashable {
    var action: String
    var avatarUploadedToOss: Bool
    var replacedExistingAvatar: Bool
    var dj: WebDJ
}

struct ImportDiscogsDJInput: Codable, Hashable {
    var discogsArtistId: Int
    var name: String?
    var aliases: [String]?
    var bio: String?
    var country: String?
    var instagramUrl: String?
    var soundcloudUrl: String?
    var twitterUrl: String?
    var spotifyId: String?
    var isVerified: Bool?
}

struct ImportDiscogsDJResponse: Codable, Hashable {
    var action: String
    var avatarUploadedToOss: Bool
    var replacedExistingAvatar: Bool
    var dj: WebDJ
}

struct ImportManualDJInput: Codable, Hashable {
    var name: String
    var spotifyId: String?
    var aliases: [String]?
    var bio: String?
    var country: String?
    var instagramUrl: String?
    var soundcloudUrl: String?
    var twitterUrl: String?
    var isVerified: Bool?
}

struct ImportManualDJResponse: Codable, Hashable {
    var action: String
    var dj: WebDJ
}

struct UpdateDJInput: Codable, Hashable {
    var name: String?
    var nameI18n: WebBiText? = nil
    var aliases: [String]?
    var bio: String?
    var bioI18n: WebBiText? = nil
    var country: String?
    var countryI18n: WebBiText? = nil
    var spotifyId: String?
    var appleMusicId: String?
    var instagramUrl: String?
    var soundcloudUrl: String?
    var twitterUrl: String?
    var isVerified: Bool?
}

struct SavedEventRoute: Codable, Identifiable, Hashable {
    var id: String { eventID }

    let eventID: String
    var eventName: String
    var coverImageUrl: String?
    var startDate: Date
    var endDate: Date
    var selectedSlotIDs: [String]
    var savedAt: Date

    var selectedSlotIDSet: Set<String> {
        Set(selectedSlotIDs)
    }
}

final class EventRouteStore: ObservableObject {
    static let shared = EventRouteStore()

    @Published private(set) var routes: [SavedEventRoute] = []

    private let storageKey = "raver.savedEventRoutes.v1"
    private let userDefaults: UserDefaults

    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        routes = Self.loadRoutes(from: userDefaults, key: storageKey)
    }

    func route(for eventID: String) -> SavedEventRoute? {
        routes.first { $0.eventID == eventID }
    }

    func save(event: WebEvent, selectedSlotIDs: Set<String>) {
        let route = SavedEventRoute(
            eventID: event.id,
            eventName: event.name,
            coverImageUrl: event.coverImageUrl,
            startDate: event.startDate,
            endDate: event.endDate,
            selectedSlotIDs: selectedSlotIDs.sorted(),
            savedAt: Date()
        )

        if let index = routes.firstIndex(where: { $0.eventID == event.id }) {
            routes[index] = route
        } else {
            routes.append(route)
        }
        routes.sort { $0.savedAt > $1.savedAt }
        persist()
    }

    func delete(eventID: String) {
        routes.removeAll { $0.eventID == eventID }
        persist()
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(routes)
            userDefaults.set(data, forKey: storageKey)
        } catch {
            assertionFailure("Failed to persist saved event routes: \(error)")
        }
    }

    private static func loadRoutes(from userDefaults: UserDefaults, key: String) -> [SavedEventRoute] {
        guard let data = userDefaults.data(forKey: key) else { return [] }
        do {
            return try JSONDecoder().decode([SavedEventRoute].self, from: data)
                .sorted { $0.savedAt > $1.savedAt }
        } catch {
            return []
        }
    }
}
