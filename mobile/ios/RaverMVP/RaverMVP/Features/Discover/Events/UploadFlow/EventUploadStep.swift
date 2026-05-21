import Foundation

enum EventUploadStep: String, CaseIterable, Identifiable, Codable {
    case media
    case basic
    case time
    case timetable
    case lineup
    case review

    var id: String { rawValue }

    var title: String {
        switch self {
        case .media: return LT("媒体", "Media", "メディア")
        case .basic: return LT("信息", "Info", "情報")
        case .time: return LT("周期", "Schedule", "日程")
        case .timetable: return LT("时间表", "Timetable", "タイムテーブル")
        case .lineup: return LT("阵容", "Lineup", "ラインナップ")
        case .review: return LT("票务", "Tickets", "チケット")
        }
    }

    var next: EventUploadStep? {
        guard let index = Self.allCases.firstIndex(of: self) else { return nil }
        let nextIndex = Self.allCases.index(after: index)
        return nextIndex < Self.allCases.endIndex ? Self.allCases[nextIndex] : nil
    }

    var previous: EventUploadStep? {
        guard let index = Self.allCases.firstIndex(of: self), index > Self.allCases.startIndex else { return nil }
        return Self.allCases[Self.allCases.index(before: index)]
    }
}

enum EventUploadScheduleMode: String, CaseIterable, Identifiable, Codable {
    case singleDay
    case multiDay
    case multiWeek

    var id: String { rawValue }

    var title: String {
        switch self {
        case .singleDay: return LT("单日", "Single Day", "1日")
        case .multiDay: return LT("多日", "Multi-day", "複数日")
        case .multiWeek: return LT("多 Week", "Multi-week", "複数Week")
        }
    }
}
