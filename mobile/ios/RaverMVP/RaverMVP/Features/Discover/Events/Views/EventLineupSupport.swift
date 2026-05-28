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
    static func parse(artist: WebEventLineupArtist) -> EventLineupResolvedAct {
        let memberPerformers = normalizedMemberPerformers(from: artist)
        if !memberPerformers.isEmpty {
            let type = actType(forPerformerCount: memberPerformers.count)
            return EventLineupResolvedAct(type: type, performers: Array(memberPerformers.prefix(type.performerCount)))
        }

        let boundDJs = normalizedBoundDJs(from: artist)
        if !boundDJs.isEmpty {
            let type = actType(forPerformerCount: boundDJs.count)
            let performers = boundDJs.prefix(type.performerCount).enumerated().map { index, dj in
                EventLineupPerformer(
                    id: "artist-\(artist.id)-p-\(index)",
                    name: dj.name,
                    djID: dj.id,
                    avatarUrl: firstNonEmpty(dj.avatarSmallUrl, dj.avatarUrl, dj.avatarMediumUrl, dj.avatarOriginalUrl)
                )
            }
            return EventLineupResolvedAct(type: type, performers: performers)
        }

        let avatarUrl = firstNonEmpty(
            artist.dj?.avatarSmallUrl,
            artist.dj?.avatarUrl,
            artist.dj?.avatarMediumUrl,
            artist.dj?.avatarOriginalUrl
        )
        let preferredName = artist.djName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackName = artist.dj?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return parse(
            name: preferredName.isEmpty ? fallbackName : preferredName,
            djID: artist.dj?.id ?? artist.djId,
            avatarUrl: avatarUrl,
            performerIDPrefix: "artist-\(artist.id)-p"
        )
    }

    static func parse(slot: WebEventLineupSlot) -> EventLineupResolvedAct {
        let explicitNames = slot.memberNames?
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []
        if !explicitNames.isEmpty {
            let djsByID = Dictionary(uniqueKeysWithValues: (slot.djs ?? []).map { ($0.id, $0) })
            let memberIDs = slot.memberDjIds ?? []
            let performers = explicitNames.enumerated().map { index, name in
                let resolvedDJID = memberIDs.indices.contains(index) ? Self.normalizedID(memberIDs[index]) : nil
                let dj = resolvedDJID.flatMap { djsByID[$0] } ?? (slot.dj?.id == resolvedDJID ? slot.dj : nil)
                return EventLineupPerformer(
                    id: "slot-\(slot.id)-p-\(index)",
                    name: firstNonEmpty(dj?.name, name) ?? name,
                    djID: resolvedDJID,
                    avatarUrl: firstNonEmpty(dj?.avatarSmallUrl, dj?.avatarUrl, dj?.avatarMediumUrl, dj?.avatarOriginalUrl)
                )
            }
            let type = actType(forPerformerCount: performers.count)
            return EventLineupResolvedAct(type: type, performers: Array(performers.prefix(type.performerCount)))
        }

        let boundDJs = normalizedBoundDJs(from: slot)
        if !boundDJs.isEmpty {
            let type = actType(forPerformerCount: boundDJs.count)
            let performers = boundDJs.prefix(type.performerCount).enumerated().map { index, dj in
                EventLineupPerformer(
                    id: "slot-\(slot.id)-p-\(index)",
                    name: dj.name,
                    djID: dj.id,
                    avatarUrl: firstNonEmpty(dj.avatarSmallUrl, dj.avatarUrl, dj.avatarMediumUrl, dj.avatarOriginalUrl)
                )
            }
            return EventLineupResolvedAct(type: type, performers: performers)
        }

        let preferredName = slot.djName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackName = slot.dj?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let rawName = preferredName.isEmpty ? fallbackName : preferredName
        let normalizedID = normalizedID(slot.dj?.id ?? slot.djId)
        return EventLineupResolvedAct(
            type: .solo,
            performers: [
                EventLineupPerformer(
                    id: "slot-\(slot.id)-p-0",
                    name: fallbackName.isEmpty ? rawName : fallbackName,
                    djID: normalizedID,
                    avatarUrl: normalizedID == nil ? nil : firstNonEmpty(
                        slot.dj?.avatarSmallUrl,
                        slot.dj?.avatarMediumUrl,
                        slot.dj?.avatarUrl,
                        slot.dj?.avatarOriginalUrl
                    )
                )
            ]
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
        let performerKeys = act.performers
            .map { performer in
                if let djID = normalizedID(performer.djID) {
                    return "id:\(djID)"
                }
                return "unbound:\(performer.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
            }
            .filter { !$0.isEmpty }
            .joined(separator: "|")
        return "\(act.type.rawValue)-\(performerKeys)"
    }

    private static func normalizedBoundDJs(from slot: WebEventLineupSlot) -> [WebEventLineupSlotDJ] {
        let source = slot.djs ?? []
        var result: [WebEventLineupSlotDJ] = []
        var seen = Set<String>()

        for dj in source {
            let id = normalizedID(dj.id)
            guard let id, seen.insert(id).inserted else { continue }
            result.append(dj)
        }

        if result.isEmpty,
           let dj = slot.dj,
           let id = normalizedID(dj.id),
           seen.insert(id).inserted {
            result.append(dj)
        }

        let orderedIDs = (slot.memberDjIds ?? []).compactMap(normalizedID)
        guard !orderedIDs.isEmpty else { return result }
        let byID = Dictionary(uniqueKeysWithValues: result.map { ($0.id, $0) })
        let ordered = orderedIDs.compactMap { byID[$0] }
        return ordered.isEmpty ? result : ordered
    }

    private static func normalizedBoundDJs(from artist: WebEventLineupArtist) -> [WebEventLineupSlotDJ] {
        let source = artist.djs ?? []
        var result: [WebEventLineupSlotDJ] = []
        var seen = Set<String>()

        for dj in source {
            let id = normalizedID(dj.id)
            guard let id, seen.insert(id).inserted else { continue }
            result.append(dj)
        }

        for member in artist.members ?? [] {
            guard let dj = member.dj else { continue }
            let id = normalizedID(dj.id)
            guard let id, seen.insert(id).inserted else { continue }
            result.append(dj)
        }

        for id in artist.memberDjIds ?? [] {
            guard let id = normalizedID(id), seen.insert(id).inserted else { continue }
            if let dj = (artist.djs ?? []).first(where: { $0.id == id }) ?? (artist.dj?.id == id ? artist.dj : nil) {
                result.append(dj)
            }
        }

        if result.isEmpty,
           let dj = artist.dj,
           let id = normalizedID(dj.id),
           seen.insert(id).inserted {
            result.append(dj)
        }

        let orderedIDs = (artist.memberDjIds ?? []).compactMap(normalizedID)
        guard !orderedIDs.isEmpty else { return result }
        let byID = Dictionary(uniqueKeysWithValues: result.map { ($0.id, $0) })
        let ordered = orderedIDs.compactMap { byID[$0] }
        return ordered.isEmpty ? result : ordered
    }

    private static func normalizedMemberPerformers(from artist: WebEventLineupArtist) -> [EventLineupPerformer] {
        let explicitMembers = (artist.members ?? [])
            .sorted { lhs, rhs in
                (lhs.memberOrder ?? Int.max) < (rhs.memberOrder ?? Int.max)
            }
            .enumerated()
            .compactMap { pair -> EventLineupPerformer? in
                let index = pair.offset
                let member = pair.element
                let name = firstNonEmpty(member.memberNameSnapshot, member.dj?.name) ?? ""
                guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
                return EventLineupPerformer(
                    id: "artist-\(artist.id)-p-\(index)",
                    name: name,
                    djID: normalizedID(member.djId ?? member.dj?.id),
                    avatarUrl: firstNonEmpty(
                        member.dj?.avatarSmallUrl,
                        member.dj?.avatarUrl,
                        member.dj?.avatarMediumUrl,
                        member.dj?.avatarOriginalUrl
                    )
                )
            }
        if !explicitMembers.isEmpty { return explicitMembers }

        let names = artist.memberNames?.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            ?? split(artist.djName, keyword: "B3B")
            ?? split(artist.djName, keyword: "B2B")
            ?? []
        guard names.count > 1 else { return [] }
        let djsByID = Dictionary(uniqueKeysWithValues: (artist.djs ?? []).map { ($0.id, $0) })
        let memberIDs = artist.memberDjIds ?? []
        return names.enumerated().map { index, name in
            let djID = memberIDs.indices.contains(index) ? normalizedID(memberIDs[index]) : nil
            let dj = djID.flatMap { djsByID[$0] } ?? (artist.dj?.id == djID ? artist.dj : nil)
            return EventLineupPerformer(
                id: "artist-\(artist.id)-p-\(index)",
                name: firstNonEmpty(dj?.name, name) ?? name,
                djID: djID,
                avatarUrl: firstNonEmpty(dj?.avatarSmallUrl, dj?.avatarUrl, dj?.avatarMediumUrl, dj?.avatarOriginalUrl)
            )
        }
    }

    private static func actType(forPerformerCount count: Int) -> EventLineupActType {
        if count >= 3 { return .b3b }
        if count == 2 { return .b2b }
        return .solo
    }

    private static func firstNonEmpty(_ values: String?...) -> String? {
        for value in values {
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !trimmed.isEmpty { return trimmed }
        }
        return nil
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
    static let editorDaysPerWeek = 4

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

extension WebEvent {
    var usesStructuredWeekMode: Bool {
        if schedule?.mode == "multi_week" {
            return true
        }
        if weeks.count > 1 {
            return true
        }
        return Set(eventDays.map(\.weekIndex)).count > 1
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
