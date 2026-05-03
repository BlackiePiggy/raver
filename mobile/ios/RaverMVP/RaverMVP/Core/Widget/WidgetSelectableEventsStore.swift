import Foundation

#if canImport(UIKit)
import ImageIO
import UIKit
#endif

enum WidgetBackgroundImageCache {
    static func loadImageData(relativePath: String?) -> Data? {
        guard
            let relativePath = widgetTrimmed(relativePath),
            let baseURL = WidgetCountdownStore.shared.baseDirectoryURL
        else {
            return nil
        }

        return try? Data(contentsOf: baseURL.appendingPathComponent(relativePath, isDirectory: false))
    }

    #if canImport(UIKit)
    static func loadDisplayImage(relativePath: String?, maxPixelSize: CGFloat = 900) -> UIImage? {
        guard
            let relativePath = widgetTrimmed(relativePath),
            let baseURL = WidgetCountdownStore.shared.baseDirectoryURL
        else {
            return nil
        }

        let fileURL = baseURL.appendingPathComponent(relativePath, isDirectory: false)
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(max(1, maxPixelSize))
        ]

        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        return UIImage(cgImage: thumbnail)
    }
    #endif
}

final class WidgetCountdownStore {
    static let shared = WidgetCountdownStore()

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
        let sharedApplicationSupport = fileManager
            .containerURL(forSecurityApplicationGroupIdentifier: RaverWidgetConstants.appGroupIdentifier)?
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)

        let applicationSupport = sharedApplicationSupport ?? (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ))

        return applicationSupport?.appendingPathComponent(
            RaverWidgetConstants.countdownDirectoryName,
            isDirectory: true
        )
    }

    private var snapshotURL: URL? {
        baseDirectoryURL?.appendingPathComponent(
            RaverWidgetConstants.countdownSnapshotFilename,
            isDirectory: false
        )
    }

    private var imagesDirectoryURL: URL? {
        baseDirectoryURL?.appendingPathComponent("images", isDirectory: true)
    }

    func loadSnapshot() throws -> WidgetCountdownSnapshot {
        guard
            let snapshotURL,
            fileManager.fileExists(atPath: snapshotURL.path)
        else {
            return .empty
        }

        let data = try Data(contentsOf: snapshotURL)
        return try decoder.decode(WidgetCountdownSnapshot.self, from: data)
    }

    func saveSnapshot(_ snapshot: WidgetCountdownSnapshot) throws {
        try ensureDirectories()
        guard let snapshotURL else { return }
        let data = try encoder.encode(snapshot)
        try data.write(to: snapshotURL, options: .atomic)
    }

    #if canImport(UIKit)
    func saveImage(_ image: UIImage, eventID: String) throws -> String {
        try ensureDirectories()
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw WidgetCountdownError.imageEncodingFailed
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

typealias WidgetSelectableEventsStore = WidgetCountdownStore

func widgetTrimmed(_ value: String?) -> String? {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
        return nil
    }
    return trimmed
}
