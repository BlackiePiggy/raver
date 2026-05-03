import Foundation

struct WidgetSelectableEvent: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let city: String?
    let venueName: String?
    let preferredBackgroundURL: String?
    let cachedBackgroundImageRelativePath: String?
    let addedAt: Date
}

struct WidgetSelectableEventsSnapshot: Codable, Hashable {
    let events: [WidgetSelectableEvent]
    let generatedAt: Date
}

extension WidgetSelectableEventsSnapshot {
    static let empty = WidgetSelectableEventsSnapshot(events: [], generatedAt: Date())
}

enum WidgetSelectableEventsError: LocalizedError {
    case imageEncodingFailed

    var errorDescription: String? {
        switch self {
        case .imageEncodingFailed:
            return "Failed to encode countdown list image."
        }
    }
}
