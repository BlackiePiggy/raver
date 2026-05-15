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
        case .all: return LT("全部", "All", "すべて")
        case .events: return LT("活动", "Events", "イベント")
        case .djs: return "DJ"
        case .peopleSquads: return LT("用户/小队", "User & Team", "ユーザー/Squad")
        case .posts: return LT("圈子", "Posts", "投稿")
        case .news: return LT("资讯", "News", "ニュース")
        case .sets: return "Sets"
        case .rankings: return LT("榜单", "Rankings", "ランキング")
        case .ratings: return LT("打分", "Ratings", "評価")
        case .festivals: return LT("品牌", "Brand", "ブランド")
        case .labels: return LT("厂牌", "Labels", "レーベル")
        case .genreTree: return LT("风格树", "Genre Tree", "ジャンルツリー")
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
        case .event: return LT("活动", "Event", "イベント")
        case .news: return LT("资讯", "News", "ニュース")
        case .dj: return "DJ"
        case .set: return "Set"
        case .rankingBoard: return LT("榜单", "Ranking", "ランキング")
        case .rankingEntry: return LT("榜单条目", "Ranking Entry", "ランキング項目")
        case .ratingEvent: return LT("打分活动", "Rating Event", "評価イベント")
        case .ratingUnit: return LT("打分单位", "Rating Unit", "評価ユニット")
        case .post: return LT("圈子", "Post", "投稿")
        case .label: return LT("厂牌", "Label", "レーベル")
        case .festival: return LT("音乐节", "Festival", "フェス")
        case .genre: return LT("风格", "Genre", "ジャンル")
        case .user: return LT("用户", "User", "ユーザー")
        case .squad: return LT("小队", "Squad", "Squad")
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
            GlobalSearchScopeHint(id: "events", title: LT("活动", "Events", "イベント"), systemImage: "calendar", tint: Color(red: 0.95, green: 0.30, blue: 0.38)),
            GlobalSearchScopeHint(id: "news", title: LT("资讯", "News", "ニュース"), systemImage: "newspaper", tint: Color(red: 0.28, green: 0.58, blue: 0.95)),
            GlobalSearchScopeHint(id: "djs", title: "DJ", systemImage: "headphones", tint: RaverTheme.accent),
            GlobalSearchScopeHint(id: "sets", title: "Sets", systemImage: "play.rectangle", tint: Color(red: 0.24, green: 0.70, blue: 0.78)),
            GlobalSearchScopeHint(id: "rankings", title: LT("榜单", "Rankings", "ランキング"), systemImage: "list.number", tint: Color(red: 0.98, green: 0.71, blue: 0.22)),
            GlobalSearchScopeHint(id: "ratings", title: LT("打分", "Ratings", "評価"), systemImage: "star", tint: Color(red: 0.92, green: 0.42, blue: 0.80)),
            GlobalSearchScopeHint(id: "posts", title: LT("圈子", "Posts", "投稿"), systemImage: "bubble.left.and.bubble.right", tint: Color(red: 0.52, green: 0.76, blue: 0.34)),
            GlobalSearchScopeHint(id: "festivals", title: LT("品牌", "Brand", "ブランド"), systemImage: "sparkles", tint: Color(red: 0.76, green: 0.47, blue: 0.95)),
            GlobalSearchScopeHint(id: "labels", title: LT("厂牌", "Labels", "レーベル"), systemImage: "tag", tint: Color(red: 0.62, green: 0.50, blue: 0.92)),
            GlobalSearchScopeHint(id: "genreTree", title: LT("风格树", "Genre Tree", "ジャンルツリー"), systemImage: "tree", tint: Color(red: 0.24, green: 0.70, blue: 0.78)),
            GlobalSearchScopeHint(id: "peopleSquads", title: LT("用户/小队", "People & Squads", "ユーザー/Squad"), systemImage: "person.2", tint: Color(red: 0.96, green: 0.45, blue: 0.28))
        ]
    }
}

struct GlobalSearchPlatformStatHint: Identifiable, Hashable {
    let id: String
    let title: String
    let systemImage: String
    let tint: Color

    static var all: [GlobalSearchPlatformStatHint] {
        [
            GlobalSearchPlatformStatHint(
                id: "events",
                title: LT("探索 1000+ 场电音活动", "Explore 1,000+ electronic music events", "1,000件以上の電子音楽イベントを探索"),
                systemImage: "calendar",
                tint: Color(red: 0.95, green: 0.30, blue: 0.38)
            ),
            GlobalSearchPlatformStatHint(
                id: "djs",
                title: LT("探索 10000+ 位 DJ", "Explore 10,000+ DJs", "10,000人以上のDJを探索"),
                systemImage: "headphones",
                tint: RaverTheme.accent
            ),
            GlobalSearchPlatformStatHint(
                id: "sets",
                title: LT("探索 100+ 个现场 Set", "Explore 100+ live sets", "100件以上のライブSetを探索"),
                systemImage: "play.rectangle",
                tint: Color(red: 0.24, green: 0.70, blue: 0.78)
            ),
            GlobalSearchPlatformStatHint(
                id: "rankings",
                title: LT("发现热门榜单与年度排名", "Discover charts and yearly rankings", "人気ランキングと年間順位を発見"),
                systemImage: "list.number",
                tint: Color(red: 0.98, green: 0.71, blue: 0.22)
            ),
            GlobalSearchPlatformStatHint(
                id: "ratings",
                title: LT("查看打分活动与打分单位", "Browse rating events and rating units", "評価イベントと評価ユニットを見る"),
                systemImage: "star",
                tint: Color(red: 0.92, green: 0.42, blue: 0.80)
            ),
            GlobalSearchPlatformStatHint(
                id: "wiki",
                title: LT("探索音乐节、厂牌与风格树", "Explore festivals, labels, and genre trees", "フェス、レーベル、ジャンルツリーを探索"),
                systemImage: "sparkles",
                tint: Color(red: 0.76, green: 0.47, blue: 0.95)
            ),
            GlobalSearchPlatformStatHint(
                id: "posts",
                title: LT("浏览圈子动态与玩家内容", "Browse circle posts and community content", "投稿とコミュニティコンテンツを見る"),
                systemImage: "bubble.left.and.bubble.right",
                tint: Color(red: 0.52, green: 0.76, blue: 0.34)
            ),
            GlobalSearchPlatformStatHint(
                id: "peopleSquads",
                title: LT("找到用户与小队", "Find users and squads", "ユーザーとSquadを見つける"),
                systemImage: "person.2",
                tint: Color(red: 0.96, green: 0.45, blue: 0.28)
            )
        ]
    }
}
