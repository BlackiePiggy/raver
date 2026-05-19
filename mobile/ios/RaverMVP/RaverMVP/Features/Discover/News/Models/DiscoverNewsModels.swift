import SwiftUI

enum DiscoverNewsCategory: String, CaseIterable, Identifiable, Codable {
    case all = "all"
    case festival = "festival"
    case scene = "scene"
    case gear = "gear"
    case industry = "industry"
    case community = "community"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return LT("全部", "All", "すべて")
        case .festival: return LT("电音节", "Festival", "フェス")
        case .scene: return LT("现场观察", "Live Scene", "現場観察")
        case .gear: return LT("设备玩法", "Gear", "機材")
        case .industry: return LT("行业动态", "Industry", "業界動向")
        case .community: return LT("社区话题", "Community", "コミュニティ")
        }
    }

    var badgeColor: Color {
        switch self {
        case .all: return RaverTheme.secondaryText
        case .festival: return Color(red: 0.96, green: 0.52, blue: 0.20)
        case .scene: return Color(red: 0.35, green: 0.67, blue: 0.96)
        case .gear: return Color(red: 0.40, green: 0.79, blue: 0.38)
        case .industry: return Color(red: 0.87, green: 0.53, blue: 0.29)
        case .community: return Color(red: 0.70, green: 0.55, blue: 0.92)
        }
    }

    static func mapFromRaw(_ raw: String) -> DiscoverNewsCategory {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let exact = DiscoverNewsCategory.allCases.first(where: {
            $0.rawValue.caseInsensitiveCompare(normalized) == .orderedSame
                || $0.title.caseInsensitiveCompare(normalized) == .orderedSame
        }) {
            return exact
        }
        if normalized.contains("电音") || normalized.contains("活动") {
            return .festival
        }
        if normalized.contains("现场") || normalized.contains("演出") {
            return .scene
        }
        if normalized.contains("设备") || normalized.contains("插件") {
            return .gear
        }
        if normalized.contains("行业") || normalized.contains("厂牌") {
            return .industry
        }
        return .community
    }
}

struct DiscoverNewsDraft: Codable {
    var category: DiscoverNewsCategory
    var source: String
    var title: String
    var summary: String
    var body: String
    var link: String?
    var coverImageURL: String?
    var boundDjIDs: [String] = []
    var boundBrandIDs: [String] = []
    var boundEventIDs: [String] = []
}

struct DiscoverNewsArticle: Identifiable, Hashable, Codable {
    let id: String
    let category: DiscoverNewsCategory
    let source: String
    let title: String
    let summary: String
    let body: String
    let link: String?
    let coverImageURL: String?
    let publishedAt: Date
    let replyCount: Int
    let authorID: String
    let authorUsername: String
    let authorName: String
    let authorAvatarURL: String?
    let legacyEventID: String?
    let boundDjIDs: [String]
    let boundBrandIDs: [String]
    let boundEventIDs: [String]
}

struct DiscoverNewsPage: Codable {
    let items: [DiscoverNewsArticle]
    let nextCursor: String?
}

protocol DiscoverNewsRepository {
    func searchArticles(query: String) async throws -> [DiscoverNewsArticle]
    func fetchFeedPage(cursor: String?) async throws -> DiscoverNewsPage
    func fetchArticle(id: String) async throws -> DiscoverNewsArticle
    func publish(draft: DiscoverNewsDraft) async throws -> DiscoverNewsArticle?
    func fetchComments(postID: String) async throws -> [Comment]
    func addComment(postID: String, content: String) async throws -> Comment
    func fetchDJ(id: String) async throws -> WebDJ
    func fetchEvent(id: String) async throws -> WebEvent
    func fetchLearnFestivals(search: String?) async throws -> [WebLearnFestival]
    func searchDJs(query: String, limit: Int) async throws -> [WebDJ]
    func searchEvents(query: String, limit: Int) async throws -> [WebEvent]
    func uploadNewsCoverImage(imageData: Data, fileName: String, mimeType: String) async throws -> String
    func fetchArticlesBoundToEvent(eventID: String, cursor: String?) async throws -> DiscoverNewsPage
    func fetchArticlesBoundToEvent(eventID: String, maxPages: Int) async throws -> [DiscoverNewsArticle]
    func fetchArticlesBoundToDJ(djID: String, cursor: String?) async throws -> DiscoverNewsPage
    func fetchArticlesBoundToDJ(djID: String, maxPages: Int) async throws -> [DiscoverNewsArticle]
    func fetchArticlesBoundToFestival(festivalID: String, maxPages: Int) async throws -> [DiscoverNewsArticle]
    func searchUsers(query: String) async throws -> [UserSummary]
    func fetchUserProfile(userID: String) async throws -> UserProfile
}

struct DiscoverNewsRepositoryAdapter: DiscoverNewsRepository {
    private let socialService: SocialService
    private let webService: WebFeatureService

    init(
        socialService: SocialService,
        webService: WebFeatureService
    ) {
        self.socialService = socialService
        self.webService = webService
    }

    func searchArticles(query: String) async throws -> [DiscoverNewsArticle] {
        try await socialService.searchNews(query: query)
    }

    func fetchFeedPage(cursor: String?) async throws -> DiscoverNewsPage {
        try await socialService.fetchNewsPage(cursor: cursor)
    }

    func fetchArticle(id: String) async throws -> DiscoverNewsArticle {
        try await socialService.fetchNewsArticle(articleID: id)
    }

    func publish(draft: DiscoverNewsDraft) async throws -> DiscoverNewsArticle? {
        let result = try await socialService.publishNews(draft: draft)
        switch result {
        case .created(let created):
            return created
        case .submittedForReview:
            return nil
        }
    }

    func fetchComments(postID: String) async throws -> [Comment] {
        try await socialService.fetchNewsComments(articleID: postID)
    }

    func addComment(postID: String, content: String) async throws -> Comment {
        try await socialService.addNewsComment(articleID: postID, content: content, parentCommentID: nil)
    }

    func fetchDJ(id: String) async throws -> WebDJ {
        try await webService.fetchDJ(id: id)
    }

    func fetchEvent(id: String) async throws -> WebEvent {
        try await webService.fetchEvent(id: id)
    }

    func fetchLearnFestivals(search: String?) async throws -> [WebLearnFestival] {
        try await webService.fetchLearnFestivals(search: search)
    }

    func searchDJs(query: String, limit: Int) async throws -> [WebDJ] {
        let page = try await webService.fetchDJs(
            page: 1,
            limit: limit,
            search: query,
            sortBy: "name"
        )
        return page.items
    }

    func searchEvents(query: String, limit: Int) async throws -> [WebEvent] {
        let page = try await webService.fetchEvents(
            page: 1,
            limit: limit,
            search: query,
            eventType: nil,
            status: nil
        )
        return page.items
    }

    func uploadNewsCoverImage(imageData: Data, fileName: String, mimeType: String) async throws -> String {
        let upload = try await webService.uploadEventImage(
            imageData: imageData,
            fileName: fileName,
            mimeType: mimeType
        )
        return upload.url
    }

    func fetchArticlesBoundToEvent(eventID: String, maxPages: Int = 8) async throws -> [DiscoverNewsArticle] {
        let trimmedEventID = eventID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEventID.isEmpty else { return [] }
        return try await fetchBoundDiscoverNewsArticles(
            socialService: socialService,
            eventID: trimmedEventID,
            djID: nil,
            festivalID: nil,
            maxPages: maxPages
        )
    }

    func fetchArticlesBoundToEvent(eventID: String, cursor: String?) async throws -> DiscoverNewsPage {
        let trimmedEventID = eventID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEventID.isEmpty else { return DiscoverNewsPage(items: [], nextCursor: nil) }
        return try await socialService.fetchBoundNewsArticles(
            eventID: trimmedEventID,
            djID: nil,
            festivalID: nil,
            cursor: cursor
        )
    }

    func fetchArticlesBoundToDJ(djID: String, maxPages: Int = 8) async throws -> [DiscoverNewsArticle] {
        let trimmedDJID = djID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDJID.isEmpty else { return [] }
        return try await fetchBoundDiscoverNewsArticles(
            socialService: socialService,
            eventID: nil,
            djID: trimmedDJID,
            festivalID: nil,
            maxPages: maxPages
        )
    }

    func fetchArticlesBoundToDJ(djID: String, cursor: String?) async throws -> DiscoverNewsPage {
        let trimmedDJID = djID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDJID.isEmpty else { return DiscoverNewsPage(items: [], nextCursor: nil) }
        return try await socialService.fetchBoundNewsArticles(
            eventID: nil,
            djID: trimmedDJID,
            festivalID: nil,
            cursor: cursor
        )
    }

    func fetchArticlesBoundToFestival(festivalID: String, maxPages: Int = 8) async throws -> [DiscoverNewsArticle] {
        let trimmedFestivalID = festivalID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedFestivalID.isEmpty else { return [] }
        return try await fetchBoundDiscoverNewsArticles(
            socialService: socialService,
            eventID: nil,
            djID: nil,
            festivalID: trimmedFestivalID,
            maxPages: maxPages
        )
    }

    func searchUsers(query: String) async throws -> [UserSummary] {
        try await socialService.searchUsers(query: query)
    }

    func fetchUserProfile(userID: String) async throws -> UserProfile {
        try await socialService.fetchUserProfile(userID: userID)
    }
}

private func fetchBoundDiscoverNewsArticles(
    socialService: SocialService,
    eventID: String?,
    djID: String?,
    festivalID: String?,
    maxPages: Int
) async throws -> [DiscoverNewsArticle] {
    var cursor: String?
    var pageCount = 0
    var articles: [DiscoverNewsArticle] = []

    repeat {
        let page = try await socialService.fetchBoundNewsArticles(
            eventID: eventID,
            djID: djID,
            festivalID: festivalID,
            cursor: cursor
        )
        articles.append(contentsOf: page.items)
        cursor = page.nextCursor
        pageCount += 1
    } while cursor != nil && pageCount < maxPages

    return articles
}

struct SearchDiscoverNewsUseCase {
    private let repository: DiscoverNewsRepository

    init(repository: DiscoverNewsRepository) {
        self.repository = repository
    }

    func execute(query: String) async throws -> [DiscoverNewsArticle] {
        try await repository.searchArticles(query: query)
    }
}
