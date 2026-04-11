import SwiftUI

enum DiscoverNewsCategory: String, CaseIterable, Identifiable {
    case all = "all"
    case festival = "festival"
    case scene = "scene"
    case gear = "gear"
    case industry = "industry"
    case community = "community"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return L("全部", "All")
        case .festival: return L("电音节", "Festival")
        case .scene: return L("现场观察", "Live Scene")
        case .gear: return L("设备玩法", "Gear")
        case .industry: return L("行业动态", "Industry")
        case .community: return L("社区话题", "Community")
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

struct DiscoverNewsDraft {
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

struct DiscoverNewsArticle: Identifiable, Hashable {
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

struct DiscoverNewsPage {
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
    func fetchArticlesBoundToEvent(eventID: String, maxPages: Int) async throws -> [DiscoverNewsArticle]
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
        let page = try await socialService.searchFeed(query: query)
        return page.posts
            .compactMap { DiscoverNewsCodec.decode(post: $0) }
            .sorted(by: { $0.publishedAt > $1.publishedAt })
    }

    func fetchFeedPage(cursor: String?) async throws -> DiscoverNewsPage {
        let page = try await socialService.fetchFeed(cursor: cursor)
        let items = page.posts.compactMap { DiscoverNewsCodec.decode(post: $0) }
        return DiscoverNewsPage(items: items, nextCursor: page.nextCursor)
    }

    func fetchArticle(id: String) async throws -> DiscoverNewsArticle {
        let post = try await socialService.fetchPost(postID: id)
        guard let article = DiscoverNewsCodec.decode(post: post) else {
            throw ServiceError.invalidResponse
        }
        return article
    }

    func publish(draft: DiscoverNewsDraft) async throws -> DiscoverNewsArticle? {
        let content = DiscoverNewsCodec.encode(draft)
        let imageURLs = draft.coverImageURL.flatMap { $0.isEmpty ? nil : [$0] } ?? []
        let created = try await socialService.createPost(
            input: CreatePostInput(
                content: content,
                images: imageURLs,
                boundDjIDs: draft.boundDjIDs,
                boundBrandIDs: draft.boundBrandIDs,
                boundEventIDs: draft.boundEventIDs
            )
        )
        return DiscoverNewsCodec.decode(post: created)
    }

    func fetchComments(postID: String) async throws -> [Comment] {
        try await socialService.fetchComments(postID: postID)
    }

    func addComment(postID: String, content: String) async throws -> Comment {
        try await socialService.addComment(postID: postID, content: content)
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

        let allArticles = try await fetchDiscoverNewsArticles(
            socialService: socialService,
            maxPages: maxPages
        )
        return allArticles.filter { article in
            article.boundEventIDs.contains(trimmedEventID)
        }
    }

    func fetchArticlesBoundToDJ(djID: String, maxPages: Int = 8) async throws -> [DiscoverNewsArticle] {
        let trimmedDJID = djID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDJID.isEmpty else { return [] }

        let allArticles = try await fetchDiscoverNewsArticles(
            socialService: socialService,
            maxPages: maxPages
        )
        return allArticles.filter { article in
            article.boundDjIDs.contains(trimmedDJID)
        }
    }

    func fetchArticlesBoundToFestival(festivalID: String, maxPages: Int = 8) async throws -> [DiscoverNewsArticle] {
        let trimmedFestivalID = festivalID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedFestivalID.isEmpty else { return [] }

        let allArticles = try await fetchDiscoverNewsArticles(
            socialService: socialService,
            maxPages: maxPages
        )
        return allArticles.filter { article in
            article.boundBrandIDs.contains(trimmedFestivalID)
        }
    }

    func searchUsers(query: String) async throws -> [UserSummary] {
        try await socialService.searchUsers(query: query)
    }

    func fetchUserProfile(userID: String) async throws -> UserProfile {
        try await socialService.fetchUserProfile(userID: userID)
    }
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
