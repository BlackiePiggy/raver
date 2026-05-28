import Foundation

enum RaverWidgetConstants {
    static let appGroupIdentifier = "group.com.raver.mvp"
    static let countdownDirectoryName = "WidgetCountdown"
    static let countdownSnapshotFilename = "events.json"
    static let countdownSchemaVersion = 2
    static let eventDeeplinkScheme = "raver"
}

enum WidgetCountdownLayoutStyle: String, Codable, CaseIterable, Hashable, Identifiable {
    case original
    case distance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .original:
            return "原始方案"
        case .distance:
            return "距离方案"
        }
    }
}

struct WidgetCountdownDateRange: Codable, Hashable, Identifiable {
    let id: String
    let weekIndex: Int
    let label: String?
    let startDate: Date
    let endDate: Date
}

struct WidgetCountdownEvent: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let customDisplayName: String?
    let city: String?
    let venueName: String?
    let startDate: Date
    let endDate: Date
    let dateRanges: [WidgetCountdownDateRange]
    let preferredBackgroundURL: String?
    let cachedBackgroundImageRelativePath: String?
    let addedAt: Date

    init(
        id: String,
        name: String,
        customDisplayName: String?,
        city: String?,
        venueName: String?,
        startDate: Date,
        endDate: Date,
        dateRanges: [WidgetCountdownDateRange] = [],
        preferredBackgroundURL: String?,
        cachedBackgroundImageRelativePath: String?,
        addedAt: Date
    ) {
        self.id = id
        self.name = name
        self.customDisplayName = widgetTrimmed(customDisplayName)
        self.city = city
        self.venueName = venueName
        self.startDate = startDate
        self.endDate = endDate < startDate ? startDate : endDate
        self.dateRanges = dateRanges.isEmpty ? [
            WidgetCountdownDateRange(
                id: "\(id)-default-range",
                weekIndex: 1,
                label: nil,
                startDate: startDate,
                endDate: endDate < startDate ? startDate : endDate
            )
        ] : dateRanges
        self.preferredBackgroundURL = preferredBackgroundURL
        self.cachedBackgroundImageRelativePath = cachedBackgroundImageRelativePath
        self.addedAt = addedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case customDisplayName
        case city
        case venueName
        case startDate
        case endDate
        case dateRanges
        case preferredBackgroundURL
        case cachedBackgroundImageRelativePath
        case addedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        let name = try container.decode(String.self, forKey: .name)
        let startDate = try container.decodeIfPresent(Date.self, forKey: .startDate) ?? Date()
        let decodedEndDate = try container.decodeIfPresent(Date.self, forKey: .endDate) ?? startDate

        self.init(
            id: id,
            name: name,
            customDisplayName: try container.decodeIfPresent(String.self, forKey: .customDisplayName),
            city: try container.decodeIfPresent(String.self, forKey: .city),
            venueName: try container.decodeIfPresent(String.self, forKey: .venueName),
            startDate: startDate,
            endDate: decodedEndDate,
            dateRanges: try container.decodeIfPresent([WidgetCountdownDateRange].self, forKey: .dateRanges) ?? [],
            preferredBackgroundURL: try container.decodeIfPresent(String.self, forKey: .preferredBackgroundURL),
            cachedBackgroundImageRelativePath: try container.decodeIfPresent(String.self, forKey: .cachedBackgroundImageRelativePath),
            addedAt: try container.decodeIfPresent(Date.self, forKey: .addedAt) ?? Date()
        )
    }
}

extension WidgetCountdownEvent {
    var displayName: String {
        customDisplayName ?? name
    }

    var normalizedDateRanges: [WidgetCountdownDateRange] {
        let fallbackRange = WidgetCountdownDateRange(
            id: "\(id)-fallback-range",
            weekIndex: 1,
            label: nil,
            startDate: startDate,
            endDate: endDate < startDate ? startDate : endDate
        )
        let ranges = dateRanges.isEmpty ? [fallbackRange] : dateRanges
        return ranges.sorted {
            if $0.startDate != $1.startDate { return $0.startDate < $1.startDate }
            if $0.weekIndex != $1.weekIndex { return $0.weekIndex < $1.weekIndex }
            return $0.id < $1.id
        }
    }
}

struct WidgetCountdownSnapshot: Codable, Hashable {
    let schemaVersion: Int
    let selectedLayoutStyleID: String
    let events: [WidgetCountdownEvent]
    let generatedAt: Date

    init(
        schemaVersion: Int = RaverWidgetConstants.countdownSchemaVersion,
        selectedLayoutStyleID: String = WidgetCountdownLayoutStyle.original.rawValue,
        events: [WidgetCountdownEvent],
        generatedAt: Date
    ) {
        self.schemaVersion = schemaVersion
        self.selectedLayoutStyleID = selectedLayoutStyleID
        self.events = events
        self.generatedAt = generatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case selectedLayoutStyleID
        case events
        case generatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 0
        selectedLayoutStyleID = try container.decodeIfPresent(String.self, forKey: .selectedLayoutStyleID)
            ?? WidgetCountdownLayoutStyle.original.rawValue
        events = try container.decode([WidgetCountdownEvent].self, forKey: .events)
        generatedAt = try container.decodeIfPresent(Date.self, forKey: .generatedAt) ?? Date()
    }
}

extension WidgetCountdownSnapshot {
    static let empty = WidgetCountdownSnapshot(events: [], generatedAt: Date())

    var selectedLayoutStyle: WidgetCountdownLayoutStyle {
        WidgetCountdownLayoutStyle(rawValue: selectedLayoutStyleID) ?? .original
    }
}

enum WidgetCountdownError: LocalizedError {
    case imageEncodingFailed

    var errorDescription: String? {
        switch self {
        case .imageEncodingFailed:
            return "Failed to encode countdown list image."
        }
    }
}

typealias WidgetSelectableEvent = WidgetCountdownEvent
typealias WidgetSelectableEventsSnapshot = WidgetCountdownSnapshot
typealias WidgetSelectableEventsError = WidgetCountdownError
