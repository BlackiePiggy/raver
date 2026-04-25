import Foundation
import OSLog

enum ChatMediaTempFileStore {
    enum MediaKind: String {
        case image
        case video
        case voice
        case file
        case other

        fileprivate var folderName: String {
            switch self {
            case .image:
                return "image"
            case .video:
                return "video"
            case .voice:
                return "voice"
            case .file:
                return "file"
            case .other:
                return "other"
            }
        }
    }

    private struct CachedFile {
        let url: URL
        let sizeBytes: Int64
        let lastAccessAt: Date
    }

    private static let rootFolderName = "raver-chat-media-cache"
    private static let maxCacheSizeBytes: Int64 = 512 * 1024 * 1024
    private static let fileTTL: TimeInterval = 7 * 24 * 60 * 60
    private static let cleanupInterval: TimeInterval = 10 * 60
    private static let stateLock = NSLock()
    private static var lastCleanupAt = Date.distantPast
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.raver.mvp",
        category: "ChatMediaCache"
    )

    static func writeData(
        _ data: Data,
        fileExtension: String,
        prefix: String,
        kind: MediaKind = .other
    ) throws -> URL {
        let folder = try prepareFolder(kind: kind)
        let safeExtension = normalizedExtension(fileExtension, fallback: "bin")
        let targetURL = folder.appendingPathComponent("\(prefix)-\(UUID().uuidString).\(safeExtension)")
        try data.write(to: targetURL, options: .atomic)
        markWrite(url: targetURL, kind: kind)
        cleanupIfNeeded()
        return targetURL
    }

    static func copyFile(
        from sourceURL: URL,
        defaultExtension: String,
        prefix: String,
        kind: MediaKind = .other
    ) throws -> URL {
        let folder = try prepareFolder(kind: kind)
        let extensionName = sourceURL.pathExtension.isEmpty
            ? normalizedExtension(defaultExtension, fallback: "bin")
            : normalizedExtension(sourceURL.pathExtension, fallback: "bin")
        let targetURL = folder.appendingPathComponent("\(prefix)-\(UUID().uuidString).\(extensionName)")
        try? FileManager.default.removeItem(at: targetURL)
        try FileManager.default.copyItem(at: sourceURL, to: targetURL)
        markWrite(url: targetURL, kind: kind)
        cleanupIfNeeded()
        return targetURL
    }

    static func resolveExistingFileURL(from rawValue: String?) -> URL? {
        guard let raw = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            markMiss(reason: "empty")
            return nil
        }

        let candidateURL: URL?
        if raw.hasPrefix("file://") {
            candidateURL = URL(string: raw)
        } else if raw.hasPrefix("/") {
            candidateURL = URL(fileURLWithPath: raw)
        } else {
            candidateURL = nil
        }

        guard let candidateURL else {
            markMiss(reason: "unsupported_raw")
            return nil
        }

        let normalized = candidateURL.standardizedFileURL
        guard FileManager.default.fileExists(atPath: normalized.path) else {
            markMiss(reason: "missing_file")
            return nil
        }

        noteAccess(for: normalized)
        return normalized
    }

    static func noteAccess(for fileURL: URL) {
        let normalized = fileURL.standardizedFileURL
        guard isManagedFile(normalized) else { return }
        try? FileManager.default.setAttributes(
            [.modificationDate: Date()],
            ofItemAtPath: normalized.path
        )
        #if DEBUG
        logger.debug("[ChatMediaCache] hit path=\(normalized.path, privacy: .public)")
        OpenIMProbeLogger.log("[ChatMediaCache] hit path=\(normalized.path)")
        #endif
    }

    static func managedRootURL() -> URL? {
        try? prepareRootFolder()
    }

    static func performMaintenance(force: Bool = false) {
        cleanupIfNeeded(force: force)
    }

    private static func prepareFolder(kind: MediaKind) throws -> URL {
        let folder = try prepareRootFolder().appendingPathComponent(kind.folderName, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private static func prepareRootFolder() throws -> URL {
        guard let cacheRoot = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "ChatMediaTempFileStore", code: 1001)
        }
        let root = cacheRoot.appendingPathComponent(rootFolderName, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private static func cleanupIfNeeded(force: Bool = false) {
        let now = Date()
        let shouldCleanup: Bool = {
            stateLock.lock()
            defer { stateLock.unlock() }
            guard force || now.timeIntervalSince(lastCleanupAt) >= cleanupInterval else {
                return false
            }
            lastCleanupAt = now
            return true
        }()

        guard shouldCleanup else { return }

        do {
            try performCleanup(now: now)
        } catch {
            #if DEBUG
            logger.error("[ChatMediaCache] cleanup failed error=\(error.localizedDescription, privacy: .public)")
            OpenIMProbeLogger.log("[ChatMediaCache] cleanup failed error=\(error.localizedDescription)")
            #endif
        }
    }

    private static func performCleanup(now: Date) throws {
        let root = try prepareRootFolder()
        var files = try cachedFiles(in: root)
        var totalSize = files.reduce(Int64(0)) { $0 + $1.sizeBytes }

        for file in files where now.timeIntervalSince(file.lastAccessAt) > fileTTL {
            try? FileManager.default.removeItem(at: file.url)
            totalSize -= file.sizeBytes
            markEviction(reason: "expired", file: file.url)
        }

        files = try cachedFiles(in: root).sorted { $0.lastAccessAt < $1.lastAccessAt }
        for file in files where totalSize > maxCacheSizeBytes {
            try? FileManager.default.removeItem(at: file.url)
            totalSize -= file.sizeBytes
            markEviction(reason: "oversize", file: file.url)
        }
    }

    private static func cachedFiles(in root: URL) throws -> [CachedFile] {
        let values: Set<URLResourceKey> = [.isRegularFileKey, .contentModificationDateKey, .creationDateKey, .fileSizeKey]
        let urls = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: Array(values),
            options: [.skipsHiddenFiles]
        )

        var files: [CachedFile] = []
        while let item = urls?.nextObject() as? URL {
            let resourceValues = try item.resourceValues(forKeys: values)
            guard resourceValues.isRegularFile == true else { continue }
            let size = Int64(resourceValues.fileSize ?? 0)
            let access = resourceValues.contentModificationDate
                ?? resourceValues.creationDate
                ?? Date.distantPast
            files.append(CachedFile(url: item, sizeBytes: size, lastAccessAt: access))
        }
        return files
    }

    private static func isManagedFile(_ fileURL: URL) -> Bool {
        guard let root = try? prepareRootFolder() else { return false }
        return fileURL.standardizedFileURL.path.hasPrefix(root.standardizedFileURL.path)
    }

    private static func markWrite(url: URL, kind: MediaKind) {
        #if DEBUG
        logger.debug("[ChatMediaCache] write kind=\(kind.rawValue, privacy: .public) path=\(url.path, privacy: .public)")
        OpenIMProbeLogger.log("[ChatMediaCache] write kind=\(kind.rawValue) path=\(url.path)")
        #endif
    }

    private static func markMiss(reason: String) {
        #if DEBUG
        logger.debug("[ChatMediaCache] miss reason=\(reason, privacy: .public)")
        OpenIMProbeLogger.log("[ChatMediaCache] miss reason=\(reason)")
        #endif
    }

    private static func markEviction(reason: String, file: URL) {
        #if DEBUG
        logger.debug("[ChatMediaCache] evict reason=\(reason, privacy: .public) path=\(file.path, privacy: .public)")
        OpenIMProbeLogger.log("[ChatMediaCache] evict reason=\(reason) path=\(file.path)")
        #endif
    }

    private static func normalizedExtension(_ raw: String, fallback: String) -> String {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.isEmpty ? fallback : normalized
    }
}
