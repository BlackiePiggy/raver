import Foundation

#if canImport(UIKit)
import UIKit
#endif

enum WidgetEventAddResult {
    case added
    case refreshed
}

enum WidgetEventRemoveResult {
    case removed
    case notFound
}

@MainActor
final class WidgetSelectableEventsSyncService {
    static let shared = WidgetSelectableEventsSyncService()

    private let store: WidgetSelectableEventsStore
    private let session: URLSession

    init(
        store: WidgetSelectableEventsStore = .shared,
        session: URLSession = .shared
    ) {
        self.store = store
        self.session = session
    }

    func add(event: WebEvent) async throws -> WidgetEventAddResult {
        var snapshot = try store.loadSnapshot()
        let existing = snapshot.events.first(where: { $0.id == event.id })
        let imagePath = try await cacheImageIfNeeded(for: event)

        let selectable = WidgetSelectableEvent(
            id: event.id,
            name: event.name,
            city: widgetTrimmed(event.city),
            venueName: widgetTrimmed(event.summaryLocation),
            preferredBackgroundURL: preferredBackgroundURL(for: event),
            cachedBackgroundImageRelativePath: imagePath ?? existing?.cachedBackgroundImageRelativePath,
            addedAt: existing?.addedAt ?? Date()
        )

        var events = snapshot.events.filter { $0.id != event.id }
        events.append(selectable)
        events.sort { lhs, rhs in
            if lhs.addedAt != rhs.addedAt {
                return lhs.addedAt > rhs.addedAt
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }

        snapshot = WidgetSelectableEventsSnapshot(events: events, generatedAt: Date())
        try store.saveSnapshot(snapshot)
        return existing == nil ? .added : .refreshed
    }

    func remove(eventID: String) throws -> WidgetEventRemoveResult {
        let snapshot = try store.loadSnapshot()
        guard let existing = snapshot.events.first(where: { $0.id == eventID }) else {
            return .notFound
        }

        let events = snapshot.events.filter { $0.id != eventID }
        try store.saveSnapshot(.init(events: events, generatedAt: Date()))
        store.removeImage(relativePath: existing.cachedBackgroundImageRelativePath)
        return .removed
    }

    func contains(eventID: String) -> Bool {
        (try? store.loadSnapshot().events.contains(where: { $0.id == eventID })) ?? false
    }

    private func preferredBackgroundURL(for event: WebEvent) -> String? {
        if let cover = widgetTrimmed(AppConfig.resolvedURLString(event.coverAssetURL)) {
            return cover
        }
        if let lineup = widgetTrimmed(AppConfig.resolvedURLString(event.lineupAssetURLs.first)) {
            return lineup
        }
        return nil
    }

    #if canImport(UIKit)
    private func cacheImageIfNeeded(for event: WebEvent) async throws -> String? {
        guard
            let urlString = preferredBackgroundURL(for: event),
            let url = URL(string: urlString)
        else {
            return nil
        }

        let (data, response) = try await session.data(from: url)
        guard
            let http = response as? HTTPURLResponse,
            (200...299).contains(http.statusCode),
            let image = UIImage(data: data)
        else {
            return nil
        }

        return try store.saveImage(centerCroppedSquare(image), eventID: event.id)
    }

    private func centerCroppedSquare(_ image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }

        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let edge = min(width, height)
        let cropRect = CGRect(
            x: (width - edge) / 2,
            y: (height - edge) / 2,
            width: edge,
            height: edge
        ).integral

        guard let cropped = cgImage.cropping(to: cropRect) else { return image }

        let targetSize = CGSize(width: 720, height: 720)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            UIImage(cgImage: cropped).draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
    #else
    private func cacheImageIfNeeded(for event: WebEvent) async throws -> String? {
        _ = event
        return nil
    }
    #endif
}
