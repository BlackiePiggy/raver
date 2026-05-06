import Foundation

enum ChatCustomCardType: String, CaseIterable, Codable, Hashable {
    case event
    case eventSchedule
    case dj
    case set
    case news
    case post
    case festival
    case brand
    case label
    case genreStyle
    case rankingBoard
    case user
    case idCard
    case contributor
    case newsAuthor
    case groupMemberRecommendation
    case squad
    case squadInvite
    case ratingUnit
    case ratingEvent
    case score
    case timetable
    case routeDJSlot
    case tracklist
    case myCheckin
    case goCheckin
    case comment
    case repost
    case followedBrandUpdate
}

enum ChatCustomCardDisplayStyle: String, Codable, Hashable {
    case coverMeta
    case profile
    case group
    case score
    case timeline
    case miniLink
    case checkin
    case socialSnippet
}

enum ChatCustomCardImplementationStatus: String, Codable, Hashable {
    case notStarted
    case planning
    case schema
    case renderer
    case shareEntry
    case route
    case done
}

struct ChatCustomCardDefinition: Codable, Hashable, Identifiable {
    var id: String { type.rawValue }

    let type: ChatCustomCardType
    let displayNameCN: String
    let displayNameEN: String
    let displayStyle: ChatCustomCardDisplayStyle
    let routeHint: String
    let requiredFields: [String]
    let status: ChatCustomCardImplementationStatus
}

enum ChatCustomCardRegistry {
    static let all: [ChatCustomCardDefinition] = [
        .init(type: .event, displayNameCN: "活动卡片", displayNameEN: "Event Card", displayStyle: .coverMeta, routeHint: "eventDetail(eventID:)", requiredFields: ["eventID", "eventName", "venueName", "startAt"], status: .shareEntry),
        .init(type: .eventSchedule, displayNameCN: "活动时间表卡片", displayNameEN: "Event Schedule Card", displayStyle: .timeline, routeHint: "eventSchedule(eventID:)", requiredFields: ["eventID", "eventName", "scheduleSummary"], status: .planning),
        .init(type: .dj, displayNameCN: "DJ 卡片", displayNameEN: "DJ Card", displayStyle: .coverMeta, routeHint: "djDetail(djID:)", requiredFields: ["djID", "djName", "badgeText"], status: .shareEntry),
        .init(type: .set, displayNameCN: "Set 卡片", displayNameEN: "Set Card", displayStyle: .coverMeta, routeHint: "setDetail(setID:)", requiredFields: ["setID", "setTitle"], status: .shareEntry),
        .init(type: .news, displayNameCN: "资讯卡片", displayNameEN: "News Card", displayStyle: .coverMeta, routeHint: "newsDetail(articleID:)", requiredFields: ["articleID", "headline"], status: .shareEntry),
        .init(type: .post, displayNameCN: "动态卡片", displayNameEN: "Post Card", displayStyle: .coverMeta, routeHint: "postDetail(postID:)", requiredFields: ["postID", "contentPreview"], status: .planning),
        .init(type: .festival, displayNameCN: "Festival 卡片", displayNameEN: "Festival Card", displayStyle: .coverMeta, routeHint: "festivalDetail(festivalID:)", requiredFields: ["festivalID", "festivalName"], status: .shareEntry),
        .init(type: .brand, displayNameCN: "Brand 卡片", displayNameEN: "Brand Card", displayStyle: .coverMeta, routeHint: "festivalDetail(festivalID:)", requiredFields: ["brandID", "brandName"], status: .shareEntry),
        .init(type: .label, displayNameCN: "Label 卡片", displayNameEN: "Label Card", displayStyle: .coverMeta, routeHint: "labelDetail(labelID:)", requiredFields: ["labelID", "labelName"], status: .shareEntry),
        .init(type: .genreStyle, displayNameCN: "风格卡片", displayNameEN: "Genre / Style Card", displayStyle: .miniLink, routeHint: "genre/style detail route pending", requiredFields: ["styleID", "styleName"], status: .planning),
        .init(type: .rankingBoard, displayNameCN: "榜单卡片", displayNameEN: "Ranking Board Card", displayStyle: .coverMeta, routeHint: "rankingBoardDetail(board:year:)", requiredFields: ["boardID", "boardName", "year"], status: .shareEntry),
        .init(type: .user, displayNameCN: "用户卡片", displayNameEN: "User Card", displayStyle: .profile, routeHint: "userProfile(userID:)", requiredFields: ["userID", "displayName"], status: .planning),
        .init(type: .idCard, displayNameCN: "ID 卡片", displayNameEN: "ID Card", displayStyle: .miniLink, routeHint: "id detail route pending", requiredFields: ["cardID", "title"], status: .planning),
        .init(type: .contributor, displayNameCN: "投稿者卡片", displayNameEN: "Contributor Card", displayStyle: .profile, routeHint: "userProfile(userID:) or contributor route", requiredFields: ["contributorID", "displayName"], status: .planning),
        .init(type: .newsAuthor, displayNameCN: "资讯作者卡片", displayNameEN: "News Author Card", displayStyle: .profile, routeHint: "userProfile(userID:) or author route", requiredFields: ["authorID", "authorName"], status: .planning),
        .init(type: .groupMemberRecommendation, displayNameCN: "成员推荐卡片", displayNameEN: "Group Member Recommendation Card", displayStyle: .profile, routeHint: "userProfile(userID:)", requiredFields: ["userID", "displayName"], status: .planning),
        .init(type: .squad, displayNameCN: "小队卡片", displayNameEN: "Squad Card", displayStyle: .group, routeHint: "squadProfile(squadID:)", requiredFields: ["squadID", "squadName"], status: .planning),
        .init(type: .squadInvite, displayNameCN: "小队邀请卡片", displayNameEN: "Squad Invite Card", displayStyle: .group, routeHint: "squad invite flow", requiredFields: ["squadID", "squadName", "inviterName"], status: .planning),
        .init(type: .ratingUnit, displayNameCN: "单元打分卡片", displayNameEN: "Rating Unit Card", displayStyle: .score, routeHint: "ratingUnitDetail(unitID:)", requiredFields: ["unitID", "title", "scoreValue"], status: .planning),
        .init(type: .ratingEvent, displayNameCN: "活动打分卡片", displayNameEN: "Rating Event Card", displayStyle: .score, routeHint: "ratingEventDetail(eventID:) or eventDetail(eventID:)", requiredFields: ["eventID", "eventName", "scoreValue"], status: .planning),
        .init(type: .score, displayNameCN: "评分卡片", displayNameEN: "Score Card", displayStyle: .score, routeHint: "score detail route pending", requiredFields: ["scoreID", "title", "scoreValue"], status: .planning),
        .init(type: .timetable, displayNameCN: "时间表卡片", displayNameEN: "Timetable Card", displayStyle: .timeline, routeHint: "timetable route pending", requiredFields: ["timetableID", "title", "rows"], status: .planning),
        .init(type: .routeDJSlot, displayNameCN: "演出时段卡片", displayNameEN: "Route DJ Slot Card", displayStyle: .timeline, routeHint: "eventSchedule(eventID:)", requiredFields: ["slotID", "djName", "startAt", "endAt"], status: .planning),
        .init(type: .tracklist, displayNameCN: "Tracklist 卡片", displayNameEN: "Tracklist Card", displayStyle: .timeline, routeHint: "tracklist route pending", requiredFields: ["tracklistID", "title"], status: .planning),
        .init(type: .myCheckin, displayNameCN: "我的打卡卡片", displayNameEN: "My Check-in Card", displayStyle: .checkin, routeHint: "check-in route pending", requiredFields: ["checkinID", "targetID", "targetName"], status: .planning),
        .init(type: .goCheckin, displayNameCN: "一起打卡卡片", displayNameEN: "Go Check-in Card", displayStyle: .checkin, routeHint: "check-in route pending", requiredFields: ["targetID", "targetName"], status: .planning),
        .init(type: .comment, displayNameCN: "评论卡片", displayNameEN: "Comment Card", displayStyle: .socialSnippet, routeHint: "comment target route", requiredFields: ["commentID", "bodyPreview", "targetID"], status: .planning),
        .init(type: .repost, displayNameCN: "转发卡片", displayNameEN: "Repost Card", displayStyle: .socialSnippet, routeHint: "postDetail(postID:)", requiredFields: ["repostID", "sourcePostID"], status: .planning),
        .init(type: .followedBrandUpdate, displayNameCN: "厂牌动态卡片", displayNameEN: "Followed Brand Update Card", displayStyle: .coverMeta, routeHint: "brand or post route", requiredFields: ["brandID", "brandName", "summary"], status: .planning)
    ]

    static func definition(for type: ChatCustomCardType) -> ChatCustomCardDefinition? {
        all.first(where: { $0.type == type })
    }
}
