import Foundation

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
    var bannerUrl: String?
    var country: String?
}

struct WebEventLineupSlot: Codable, Identifiable, Hashable {
    let id: String
    var eventId: String?
    var djId: String?
    var djName: String
    var stageName: String?
    var sortOrder: Int
    var startTime: Date
    var endTime: Date
    var dj: WebEventLineupSlotDJ?
}

struct EventLineupSlotInput: Codable, Hashable {
    var djId: String?
    var djName: String
    var stageName: String?
    var sortOrder: Int?
    var startTime: Date?
    var endTime: Date?
}

struct WebEvent: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var slug: String
    var description: String?
    var coverImageUrl: String?
    var lineupImageUrl: String?
    var eventType: String?
    var organizerName: String?
    var venueName: String?
    var venueAddress: String?
    var city: String?
    var country: String?
    var latitude: Double?
    var longitude: Double?
    var startDate: Date
    var endDate: Date
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
    var ticketTiers: [WebEventTicketTier]
    var lineupSlots: [WebEventLineupSlot]

    var summaryLocation: String {
        [city, country].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

struct CreateEventInput: Codable {
    var name: String
    var description: String?
    var eventType: String? = nil
    var city: String?
    var country: String?
    var venueName: String?
    var startDate: Date
    var endDate: Date
    var coverImageUrl: String?
    var lineupImageUrl: String?
    var lineupSlots: [EventLineupSlotInput]? = nil
    var status: String?
}

struct UpdateEventInput: Codable {
    var name: String?
    var description: String?
    var eventType: String? = nil
    var city: String?
    var country: String?
    var venueName: String?
    var startDate: Date?
    var endDate: Date?
    var coverImageUrl: String?
    var lineupImageUrl: String?
    var lineupSlots: [EventLineupSlotInput]? = nil
    var status: String?
}

struct WebDJ: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var aliases: [String]?
    var slug: String?
    var bio: String?
    var avatarUrl: String?
    var bannerUrl: String?
    var country: String?
    var spotifyId: String?
    var appleMusicId: String?
    var soundcloudUrl: String?
    var instagramUrl: String?
    var twitterUrl: String?
    var isVerified: Bool?
    var followerCount: Int?
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

struct CheckinEventLite: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var coverImageUrl: String?
    var city: String?
    var country: String?
    var startDate: Date?
    var endDate: Date?
}

struct CheckinDJLite: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var avatarUrl: String?
    var country: String?
}

struct CreateCheckinInput: Codable {
    var type: String
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

    var id: String {
        "\(rank)-\(name)"
    }
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
    var coverImageUrl: String?
    var city: String?
    var country: String?
    var startDate: Date
    var createdAt: Date
    var lineupSlotCount: Int
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
