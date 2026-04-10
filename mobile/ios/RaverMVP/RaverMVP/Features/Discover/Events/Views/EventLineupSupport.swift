import Foundation

enum EventLineupActType: String, CaseIterable, Hashable, Codable, Identifiable {
    case solo
    case b2b
    case b3b

    var id: String { rawValue }

    var title: String {
        switch self {
        case .solo: return "Solo"
        case .b2b: return "B2B"
        case .b3b: return "B3B"
        }
    }

    var performerCount: Int {
        switch self {
        case .solo: return 1
        case .b2b: return 2
        case .b3b: return 3
        }
    }

    var separator: String {
        switch self {
        case .solo: return ""
        case .b2b: return " B2B "
        case .b3b: return " B3B "
        }
    }
}

struct EventLineupPerformer: Identifiable, Hashable {
    var id: String
    var name: String
    var djID: String?
    var avatarUrl: String?
}

struct EventLineupResolvedAct: Hashable {
    var type: EventLineupActType
    var performers: [EventLineupPerformer]

    var displayName: String {
        EventLineupActCodec.composeName(type: type, performerNames: performers.map(\.name))
    }

    var isCollaborative: Bool {
        type != .solo
    }
}

enum EventLineupActCodec {
    static func parse(slot: WebEventLineupSlot) -> EventLineupResolvedAct {
        let preferredName = slot.djName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackName = slot.dj?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let rawName = preferredName.isEmpty ? fallbackName : preferredName
        return parse(
            name: rawName,
            djID: slot.dj?.id ?? slot.djId,
            avatarUrl: slot.dj?.avatarUrl,
            performerIDPrefix: "slot-\(slot.id)-p"
        )
    }

    static func parse(
        name: String,
        djID: String? = nil,
        avatarUrl: String? = nil,
        performerIDPrefix: String = "performer"
    ) -> EventLineupResolvedAct {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if let parts = split(trimmedName, keyword: "B3B"), parts.count >= 3 {
            var performers = parts.enumerated().map { index, item in
                EventLineupPerformer(
                    id: "\(performerIDPrefix)-\(index)",
                    name: item,
                    djID: nil,
                    avatarUrl: nil
                )
            }
            if let normalized = normalizedID(djID), !performers.isEmpty {
                performers[0].djID = normalized
                performers[0].avatarUrl = avatarUrl
            }
            return EventLineupResolvedAct(type: .b3b, performers: performers)
        }

        if let parts = split(trimmedName, keyword: "B2B"), parts.count >= 2 {
            var performers = parts.enumerated().map { index, item in
                EventLineupPerformer(
                    id: "\(performerIDPrefix)-\(index)",
                    name: item,
                    djID: nil,
                    avatarUrl: nil
                )
            }
            if let normalized = normalizedID(djID), !performers.isEmpty {
                performers[0].djID = normalized
                performers[0].avatarUrl = avatarUrl
            }
            return EventLineupResolvedAct(type: .b2b, performers: performers)
        }

        return EventLineupResolvedAct(
            type: .solo,
            performers: [
                EventLineupPerformer(
                    id: "\(performerIDPrefix)-0",
                    name: trimmedName,
                    djID: normalizedID(djID),
                    avatarUrl: avatarUrl
                )
            ]
        )
    }

    static func composeName(type: EventLineupActType, performerNames: [String]) -> String {
        let normalized = performerNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !normalized.isEmpty else { return "" }
        switch type {
        case .solo:
            return normalized[0]
        case .b2b:
            return normalized.prefix(2).joined(separator: EventLineupActType.b2b.separator)
        case .b3b:
            return normalized.prefix(3).joined(separator: EventLineupActType.b3b.separator)
        }
    }

    static func normalizePerformers(
        _ performers: [EventLineupPerformer],
        type: EventLineupActType,
        prefix: String
    ) -> [EventLineupPerformer] {
        let expectedCount = type.performerCount
        var normalized = Array(performers.prefix(expectedCount))
        while normalized.count < expectedCount {
            normalized.append(
                EventLineupPerformer(
                    id: "\(prefix)-\(normalized.count)",
                    name: "",
                    djID: nil,
                    avatarUrl: nil
                )
            )
        }
        for index in normalized.indices {
            normalized[index].id = "\(prefix)-\(index)"
            if type != .solo {
                normalized[index].djID = nil
                normalized[index].avatarUrl = nil
            }
        }
        return normalized
    }

    static func canonicalKey(for act: EventLineupResolvedAct) -> String {
        let names = act.performers
            .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
            .joined(separator: "|")
        return "\(act.type.rawValue)-\(names)"
    }

    private static func split(_ raw: String, keyword: String) -> [String]? {
        guard !raw.isEmpty else { return nil }
        let token = "__EVENT_LINEUP_SPLIT_TOKEN__"
        let pattern = "(?i)\\s*\(keyword)\\s*"
        let replaced = raw.replacingOccurrences(
            of: pattern,
            with: token,
            options: .regularExpression
        )
        let pieces = replaced
            .components(separatedBy: token)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return pieces.count > 1 ? pieces : nil
    }

    private static func normalizedID(_ raw: String?) -> String? {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

func normalizedDJLookupKey(_ raw: String) -> String {
    raw
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
}

func fetchExactDJMatches(
    names: [String],
    fetchCandidates: (String) async throws -> [WebDJ]
) async -> [String: WebDJ] {
    var resolved: [String: WebDJ] = [:]
    var queue: [String] = []

    for name in names {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { continue }
        let key = normalizedDJLookupKey(trimmed)
        guard resolved[key] == nil, !queue.contains(where: { normalizedDJLookupKey($0) == key }) else { continue }
        queue.append(trimmed)
    }

    for name in queue {
        if Task.isCancelled { break }
        do {
            let candidates = try await fetchCandidates(name)
            if Task.isCancelled { break }
            let key = normalizedDJLookupKey(name)
            if let exact = candidates.first(where: { normalizedDJLookupKey($0.name) == key }) {
                resolved[key] = exact
                continue
            }
            if let aliasMatched = candidates.first(where: { dj in
                (dj.aliases ?? []).contains { normalizedDJLookupKey($0) == key }
            }) {
                resolved[key] = aliasMatched
            }
        } catch {
            continue
        }
    }

    return resolved
}

enum EventWeekScheduleMode {
    static let marker = "[[raver_schedule_mode:week]]"
    static let editorDaysPerWeek = 4

    static func isEnabled(in rawDescription: String?) -> Bool {
        guard let rawDescription else { return false }
        return rawDescription.contains(marker)
    }

    static func stripMarker(from rawDescription: String?) -> String {
        guard let rawDescription else { return "" }
        return rawDescription
            .replacingOccurrences(of: marker, with: "")
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func embedMarker(into userDescription: String, enabled: Bool) -> String? {
        let cleaned = stripMarker(from: userDescription)
        guard enabled else { return cleaned.nilIfEmpty }
        if cleaned.isEmpty {
            return marker
        }
        return "\(cleaned)\n\n\(marker)"
    }

    static func weekDayIndex(for date: Date, anchorDate: Date) -> (week: Int, day: Int)? {
        let calendar = Calendar.current
        let anchorDay = calendar.startOfDay(for: anchorDate)
        let targetDay = calendar.startOfDay(for: date)
        let offset = calendar.dateComponents([.day], from: anchorDay, to: targetDay).day ?? 0
        guard offset >= 0 else { return nil }
        return (week: offset / 7 + 1, day: offset % 7 + 1)
    }

    static func weekDayTitle(week: Int, day: Int) -> String {
        "Week\(week)·Day\(day)"
    }
}

struct EventCheckinDayOption: Identifiable, Hashable {
    let id: String
    let dayIndex: Int
    let dayDate: Date
    let attendedAt: Date
    let weekIndex: Int?
    let dayInWeek: Int?

    var usesWeekLabel: Bool {
        weekIndex != nil && dayInWeek != nil
    }

    var title: String {
        if let weekIndex, let dayInWeek {
            return EventWeekScheduleMode.weekDayTitle(week: weekIndex, day: dayInWeek)
        }
        return "Day\(dayIndex)"
    }
    var subtitle: String { dayDate.appLocalizedYMDText() }
}

struct EventCheckinDJOption: Identifiable, Hashable {
    let id: String
    let djID: String
    let name: String
    let avatarUrl: String?
    let actType: EventLineupActType
    let performers: [EventLineupPerformer]
}
