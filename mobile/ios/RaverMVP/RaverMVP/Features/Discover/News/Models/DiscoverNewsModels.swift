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
