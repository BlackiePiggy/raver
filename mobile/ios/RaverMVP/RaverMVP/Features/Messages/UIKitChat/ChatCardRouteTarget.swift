import Foundation

enum ChatCardRouteTarget: Equatable {
    case event(eventID: String)
    case post(postID: String)
    case ratingEvent(eventID: String)
    case ratingUnit(unitID: String)
    case dj(djID: String)
    case set(setID: String)
    case festival(festivalID: String)
    case label(labelID: String)
    case rankingBoard(board: RankingBoard, year: Int)
    case circleID(entryID: String)
    case myCheckins(
        targetUserID: String,
        title: String,
        ownerDisplayName: String
    )
    case eventRoute(
        eventID: String,
        ownerUserID: String?,
        ownerDisplayName: String?,
        selectedDayID: String?,
        selectedSlotIDs: [String]?
    )
    case squadOfflineActivityHistory(squadID: String)
    case news(articleID: String)

    var dedupeKey: String {
        switch self {
        case .event(let eventID):
            return "event_or_rating_event:\(eventID)"
        case .post(let postID):
            return "post:\(postID)"
        case .ratingEvent(let eventID):
            return "event_or_rating_event:\(eventID)"
        case .ratingUnit(let unitID):
            return "rating_unit:\(unitID)"
        case .dj(let djID):
            return "dj:\(djID)"
        case .set(let setID):
            return "set:\(setID)"
        case .festival(let festivalID):
            return "festival:\(festivalID)"
        case .label(let labelID):
            return "label:\(labelID)"
        case .rankingBoard(let board, let year):
            return "ranking:\(board.id):\(year)"
        case .circleID(let entryID):
            return "circle_id:\(entryID)"
        case .myCheckins(let targetUserID, let title, let ownerDisplayName):
            return "my_checkins:\(targetUserID):\(title):\(ownerDisplayName)"
        case .eventRoute(let eventID, let ownerUserID, let ownerDisplayName, let selectedDayID, let selectedSlotIDs):
            return [
                "event_route",
                eventID,
                ownerUserID ?? "",
                ownerDisplayName ?? "",
                selectedDayID ?? "",
                selectedSlotIDs?.joined(separator: ",") ?? ""
            ].joined(separator: ":")
        case .squadOfflineActivityHistory(let squadID):
            return "squad_offline_activity_history:\(squadID)"
        case .news(let articleID):
            return "news:\(articleID)"
        }
    }
}

struct RecentChatCardRoute {
    let target: ChatCardRouteTarget
    let timestamp: Date
}
