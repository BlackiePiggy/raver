import Foundation

#if canImport(UIKit)
import UIKit
#endif

enum WidgetBackgroundImageCache {
    static func loadImageData(relativePath: String?) -> Data? {
        guard
            let relativePath = widgetTrimmed(relativePath),
            let baseURL = WidgetSelectableEventsStore.shared.baseDirectoryURL
        else {
            return nil
        }

        return try? Data(contentsOf: baseURL.appendingPathComponent(relativePath, isDirectory: false))
    }
}

final class WidgetSelectableEventsStore {
    static let shared = WidgetSelectableEventsStore()

    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    var baseDirectoryURL: URL? {
        let applicationSupport = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        return applicationSupport?.appendingPathComponent("WidgetCountdownList", isDirectory: true)
    }

    private var snapshotURL: URL? {
        baseDirectoryURL?.appendingPathComponent("widget-countdown-list.json", isDirectory: false)
    }

    private var imagesDirectoryURL: URL? {
        baseDirectoryURL?.appendingPathComponent("images", isDirectory: true)
    }

    func loadSnapshot() throws -> WidgetSelectableEventsSnapshot {
        guard
            let snapshotURL,
            fileManager.fileExists(atPath: snapshotURL.path)
        else {
            return .empty
        }

        let data = try Data(contentsOf: snapshotURL)
        return try decoder.decode(WidgetSelectableEventsSnapshot.self, from: data)
    }

    func saveSnapshot(_ snapshot: WidgetSelectableEventsSnapshot) throws {
        try ensureDirectories()
        guard let snapshotURL else { return }
        let data = try encoder.encode(snapshot)
        try data.write(to: snapshotURL, options: .atomic)
    }

    #if canImport(UIKit)
    func saveImage(_ image: UIImage, eventID: String) throws -> String {
        try ensureDirectories()
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw WidgetSelectableEventsError.imageEncodingFailed
        }
        guard let imagesDirectoryURL else { return "images/\(eventID).jpg" }
        let filename = "\(eventID).jpg"
        let fileURL = imagesDirectoryURL.appendingPathComponent(filename, isDirectory: false)
        try data.write(to: fileURL, options: .atomic)
        return "images/\(filename)"
    }
    #endif

    func removeImage(relativePath: String?) {
        guard
            let relativePath = widgetTrimmed(relativePath),
            let baseDirectoryURL
        else {
            return
        }

        try? fileManager.removeItem(at: baseDirectoryURL.appendingPathComponent(relativePath, isDirectory: false))
    }

    private func ensureDirectories() throws {
        guard let baseDirectoryURL, let imagesDirectoryURL else { return }

        if !fileManager.fileExists(atPath: baseDirectoryURL.path) {
            try fileManager.createDirectory(at: baseDirectoryURL, withIntermediateDirectories: true)
        }

        if !fileManager.fileExists(atPath: imagesDirectoryURL.path) {
            try fileManager.createDirectory(at: imagesDirectoryURL, withIntermediateDirectories: true)
        }
    }
}

func widgetTrimmed(_ value: String?) -> String? {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
        return nil
    }
    return trimmed
}
