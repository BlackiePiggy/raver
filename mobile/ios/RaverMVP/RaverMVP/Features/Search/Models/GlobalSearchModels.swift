import Foundation
import SwiftUI

enum GlobalSearchTab: String, CaseIterable, Codable, Hashable, Identifiable {
    case all
    case events
    case news
    case djs
    case sets
    case rankings
    case ratings
    case posts
    case wiki
    case peopleSquads

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return L("全部", "All")
        case .events: return L("活动", "Events")
        case .news: return L("资讯", "News")
        case .djs: return "DJ"
        case .sets: return "Sets"
        case .rankings: return L("榜单", "Rankings")
        case .ratings: return L("打分", "Ratings")
        case .posts: return L("圈子", "Posts")
        case .wiki: return "Wiki"
        case .peopleSquads: return L("用户/小队", "People & Squads")
        }
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
            GlobalSearchScopeHint(id: "wiki", title: "Wiki", systemImage: "book", tint: Color(red: 0.62, green: 0.50, blue: 0.92)),
            GlobalSearchScopeHint(id: "peopleSquads", title: L("用户/小队", "People & Squads"), systemImage: "person.2", tint: Color(red: 0.96, green: 0.45, blue: 0.28))
        ]
    }
}

