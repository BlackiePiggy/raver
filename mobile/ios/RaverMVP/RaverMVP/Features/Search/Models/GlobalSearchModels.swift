import Foundation
import SwiftUI

enum GlobalSearchTab: String, CaseIterable, Codable, Hashable, Identifiable {
    case all
    case events
    case djs
    case peopleSquads
    case posts
    case news
    case sets
    case rankings
    case ratings
    case festivals
    case labels
    case genreTree

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return L("全部", "All")
        case .events: return L("活动", "Events")
        case .djs: return "DJ"
        case .peopleSquads: return L("用户/小队", "User & Team")
        case .posts: return L("圈子", "Posts")
        case .news: return L("资讯", "News")
        case .sets: return "Sets"
        case .rankings: return L("榜单", "Rankings")
        case .ratings: return L("打分", "Ratings")
        case .festivals: return L("音乐节(品牌)", "Festivals (Brand)")
        case .labels: return L("厂牌", "Labels")
        case .genreTree: return L("风格树", "Genre Tree")
        }
    }

    var themeColor: Color {
        switch self {
        case .all: return RaverTheme.accent
        case .events: return Color(red: 0.97, green: 0.54, blue: 0.21)
        case .djs: return Color(red: 0.44, green: 0.78, blue: 0.33)
        case .peopleSquads: return Color(red: 0.96, green: 0.45, blue: 0.28)
        case .posts: return Color(red: 0.95, green: 0.30, blue: 0.38)
        case .news: return Color(red: 0.98, green: 0.62, blue: 0.22)
        case .sets: return Color(red: 0.30, green: 0.67, blue: 0.97)
        case .rankings: return Color(red: 0.98, green: 0.71, blue: 0.22)
        case .ratings: return Color(red: 0.92, green: 0.42, blue: 0.80)
        case .festivals: return Color(red: 0.76, green: 0.47, blue: 0.95)
        case .labels: return Color(red: 0.62, green: 0.50, blue: 0.92)
        case .genreTree: return Color(red: 0.24, green: 0.70, blue: 0.78)
        }
    }

    var searchableItemTypes: Set<GlobalSearchItemType> {
        switch self {
        case .all:
            return Set(GlobalSearchItemType.allCases)
        case .events:
            return [.event]
        case .djs:
            return [.dj]
        case .peopleSquads:
            return [.user, .squad]
        case .posts:
            return [.post]
        case .news:
            return [.news]
        case .sets:
            return [.set]
        case .rankings:
            return [.rankingBoard, .rankingEntry]
        case .ratings:
            return [.ratingEvent, .ratingUnit]
        case .festivals:
            return [.festival]
        case .labels:
            return [.label]
        case .genreTree:
            return [.genre]
        }
    }
}

enum GlobalSearchItemType: String, CaseIterable, Codable, Hashable {
    case event
    case news
    case dj
    case set
    case rankingBoard = "ranking_board"
    case rankingEntry = "ranking_entry"
    case ratingEvent = "rating_event"
    case ratingUnit = "rating_unit"
    case post
    case label
    case festival
    case genre
    case user
    case squad

    var tab: GlobalSearchTab {
        switch self {
        case .event: return .events
        case .news: return .news
        case .dj: return .djs
        case .set: return .sets
        case .rankingBoard, .rankingEntry: return .rankings
        case .ratingEvent, .ratingUnit: return .ratings
        case .post: return .posts
        case .label: return .labels
        case .festival: return .festivals
        case .genre: return .genreTree
        case .user, .squad: return .peopleSquads
        }
    }

    var title: String {
        switch self {
        case .event: return L("活动", "Event")
        case .news: return L("资讯", "News")
        case .dj: return "DJ"
        case .set: return "Set"
        case .rankingBoard: return L("榜单", "Ranking")
        case .rankingEntry: return L("榜单条目", "Ranking Entry")
        case .ratingEvent: return L("打分活动", "Rating Event")
        case .ratingUnit: return L("打分单位", "Rating Unit")
        case .post: return L("圈子", "Post")
        case .label: return L("厂牌", "Label")
        case .festival: return L("音乐节", "Festival")
        case .genre: return L("风格", "Genre")
        case .user: return L("用户", "User")
        case .squad: return L("小队", "Squad")
        }
    }

    var systemImage: String {
        switch self {
        case .event: return "calendar"
        case .news: return "newspaper"
        case .dj: return "headphones"
        case .set: return "play.rectangle"
        case .rankingBoard, .rankingEntry: return "list.number"
        case .ratingEvent, .ratingUnit: return "star"
        case .post: return "bubble.left.and.bubble.right"
        case .label: return "tag"
        case .festival: return "sparkles"
        case .genre: return "tree"
        case .user: return "person"
        case .squad: return "person.2"
        }
    }
}

struct GlobalSearchItem: Identifiable, Codable, Hashable {
    let id: String
    let type: GlobalSearchItemType
    let entityID: String
    let title: String
    let subtitle: String?
    let summary: String?
    let imageUrl: String?
    let badgeText: String?
    let deeplink: String
    let relevanceScore: Double
    let publishedAt: Date?
    let updatedAt: Date?
    let rankingYear: Int?

    var tab: GlobalSearchTab {
        type.tab
    }

    func appRoute() -> AppRoute? {
        switch type {
        case .event:
            return .eventDetail(eventID: entityID)
        case .news:
            return .newsDetail(articleID: entityID)
        case .dj:
            return .djDetail(djID: entityID)
        case .set:
            return .setDetail(setID: entityID)
        case .rankingBoard, .rankingEntry:
            let board = RankingBoard(
                id: entityID,
                title: title,
                subtitle: subtitle,
                coverImageUrl: imageUrl,
                years: rankingYear.map { [$0] } ?? []
            )
            return .rankingBoardDetail(board: board, year: rankingYear)
        case .ratingEvent:
            return .ratingEventDetail(eventID: entityID)
        case .ratingUnit:
            return .ratingUnitDetail(unitID: entityID)
        case .post:
            return .postDetail(postID: entityID)
        case .label:
            return .labelDetail(labelID: entityID)
        case .festival:
            return .festivalDetail(festivalID: entityID)
        case .genre:
            return nil
        case .user:
            return .userProfile(userID: entityID)
        case .squad:
            return .squadProfile(squadID: entityID)
        }
    }
}

struct GlobalSearchPartialError: Codable, Hashable {
    let tab: GlobalSearchTab
    let message: String
}

struct GlobalSearchResponse: Codable, Hashable {
    let query: String
    let tab: GlobalSearchTab
    let limit: Int
    let totalCount: Int
    let items: [GlobalSearchItem]
    let countsByTab: [String: Int]
    let partialErrors: [GlobalSearchPartialError]
    let generatedAt: Date

    func count(for tab: GlobalSearchTab) -> Int {
        countsByTab[tab.rawValue] ?? 0
    }
}

struct GlobalSearchScopeHint: Identifiable, Hashable {
    let id: String
    let title: String
    let systemImage: String
    let tint: Color

    static var all: [GlobalSearchScopeHint] {
        [
            GlobalSearchScopeHint(id: "events", title: L("活动", "Events"), systemImage: "calendar", tint: Color(red: 0.95, green: 0.30, blue: 0.38)),
            GlobalSearchScopeHint(id: "news", title: L("资讯", "News"), systemImage: "newspaper", tint: Color(red: 0.28, green: 0.58, blue: 0.95)),
            GlobalSearchScopeHint(id: "djs", title: "DJ", systemImage: "headphones", tint: RaverTheme.accent),
            GlobalSearchScopeHint(id: "sets", title: "Sets", systemImage: "play.rectangle", tint: Color(red: 0.24, green: 0.70, blue: 0.78)),
            GlobalSearchScopeHint(id: "rankings", title: L("榜单", "Rankings"), systemImage: "list.number", tint: Color(red: 0.98, green: 0.71, blue: 0.22)),
            GlobalSearchScopeHint(id: "ratings", title: L("打分", "Ratings"), systemImage: "star", tint: Color(red: 0.92, green: 0.42, blue: 0.80)),
            GlobalSearchScopeHint(id: "posts", title: L("圈子", "Posts"), systemImage: "bubble.left.and.bubble.right", tint: Color(red: 0.52, green: 0.76, blue: 0.34)),
            GlobalSearchScopeHint(id: "festivals", title: L("音乐节(品牌)", "Festivals (Brand)"), systemImage: "sparkles", tint: Color(red: 0.76, green: 0.47, blue: 0.95)),
            GlobalSearchScopeHint(id: "labels", title: L("厂牌", "Labels"), systemImage: "tag", tint: Color(red: 0.62, green: 0.50, blue: 0.92)),
            GlobalSearchScopeHint(id: "genreTree", title: L("风格树", "Genre Tree"), systemImage: "tree", tint: Color(red: 0.24, green: 0.70, blue: 0.78)),
            GlobalSearchScopeHint(id: "peopleSquads", title: L("用户/小队", "People & Squads"), systemImage: "person.2", tint: Color(red: 0.96, green: 0.45, blue: 0.28))
        ]
    }
}
