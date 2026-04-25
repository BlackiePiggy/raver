import Foundation

enum OpenIMProbeLogger {
    #if DEBUG
    private static let queue = DispatchQueue(
        label: "com.raver.mvp.openim-probe-log",
        qos: .utility
    )
    private static let maxFileSizeBytes: UInt64 = 2 * 1024 * 1024
    private static let filename = "openim-probe.log"
    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static var resolvedURL: URL?
    private static var hasResetForCurrentProcess = false

    static func resetForCurrentProcessIfNeeded() {
        queue.async {
            guard !hasResetForCurrentProcess else { return }
            hasResetForCurrentProcess = true
            guard let url = logFileURL() else { return }
            try? Data().write(to: url, options: .atomic)
        }
    }

    static func log(_ message: String) {
        print(message)
        queue.async {
            guard let url = logFileURL() else { return }
            rotateIfNeeded(url: url)
            let line = "\(formatter.string(from: Date())) \(message)\n"
            guard let data = line.data(using: .utf8) else { return }
            append(data: data, to: url)
        }
    }

    private static func logFileURL() -> URL? {
        if let resolvedURL {
            return resolvedURL
        }

        guard let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }

        let url = cachesDir.appendingPathComponent(filename, isDirectory: false)
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        resolvedURL = url
        return url
    }

    private static func rotateIfNeeded(url: URL) {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = attrs?[.size] as? UInt64 ?? 0
        guard size > maxFileSizeBytes else { return }
        try? Data().write(to: url, options: .atomic)
    }

    private static func append(data: Data, to url: URL) {
        guard let handle = try? FileHandle(forWritingTo: url) else {
            FileManager.default.createFile(atPath: url.path, contents: data)
            return
        }

        defer { try? handle.close() }
        handle.seekToEndOfFile()
        handle.write(data)
    }
    #else
    static func resetForCurrentProcessIfNeeded() {}
    static func log(_ message: String) {}
    #endif
}
