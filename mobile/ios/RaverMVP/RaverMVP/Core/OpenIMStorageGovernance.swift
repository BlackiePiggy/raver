import Foundation
import OSLog

enum OpenIMStorageGovernance {
    private struct Snapshot {
        let openIMDataBytes: Int64
        let mediaCacheBytes: Int64
        let probeLogBytes: Int64
    }

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.raver.mvp",
        category: "OpenIMStorageGovernance"
    )
    private static let queue = DispatchQueue(
        label: "com.raver.mvp.openim-storage-governance",
        qos: .utility
    )
    private static let stateLock = NSLock()
    private static var lastAuditAt = Date.distantPast

    private static let auditInterval: TimeInterval = 10 * 60
    private static let openIMDataWarnBytes: Int64 = 1024 * 1024 * 1024
    private static let openIMDataCriticalBytes: Int64 = 2 * 1024 * 1024 * 1024
    private static let probeLogMaxBytes: Int64 = 4 * 1024 * 1024
    private static let probeLogTrimToBytes: Int64 = 1 * 1024 * 1024

    static func runAuditIfNeeded(trigger: String, force: Bool = false) {
        queue.async {
            guard shouldRunAudit(force: force) else { return }
            ChatMediaTempFileStore.performMaintenance(force: true)
            trimProbeLogIfNeeded()
            let snapshot = collectSnapshot()
            log(snapshot: snapshot, trigger: trigger)
        }
    }

    private static func shouldRunAudit(force: Bool) -> Bool {
        let now = Date()
        stateLock.lock()
        defer { stateLock.unlock() }
        guard force || now.timeIntervalSince(lastAuditAt) >= auditInterval else {
            return false
        }
        lastAuditAt = now
        return true
    }

    private static func collectSnapshot() -> Snapshot {
        let openIMDataBytes = directorySize(at: openIMDataDirectoryURL())
        let mediaCacheBytes = directorySize(at: ChatMediaTempFileStore.managedRootURL())
        let probeLogBytes = fileSize(at: probeLogFileURL())
        return Snapshot(
            openIMDataBytes: openIMDataBytes,
            mediaCacheBytes: mediaCacheBytes,
            probeLogBytes: probeLogBytes
        )
    }

    private static func log(snapshot: Snapshot, trigger: String) {
        let totalBytes = snapshot.openIMDataBytes + snapshot.mediaCacheBytes + snapshot.probeLogBytes
        let level: String
        if snapshot.openIMDataBytes >= openIMDataCriticalBytes {
            level = "critical"
        } else if snapshot.openIMDataBytes >= openIMDataWarnBytes {
            level = "warn"
        } else {
            level = "ok"
        }

        let line = "[OpenIMStorageGovernance] trigger=\(trigger) level=\(level) openim=\(formatted(snapshot.openIMDataBytes)) media=\(formatted(snapshot.mediaCacheBytes)) probe=\(formatted(snapshot.probeLogBytes)) total=\(formatted(totalBytes))"
        logger.debug("\(line, privacy: .public)")
        OpenIMProbeLogger.log(line)
    }

    private static func trimProbeLogIfNeeded() {
        guard let url = probeLogFileURL() else { return }
        let size = fileSize(at: url)
        guard size > probeLogMaxBytes else { return }

        do {
            let data = try Data(contentsOf: url)
            let trimmed = Data(data.suffix(Int(probeLogTrimToBytes)))
            try trimmed.write(to: url, options: .atomic)
            let line = "[OpenIMStorageGovernance] probe-log-trimmed before=\(formatted(size)) after=\(formatted(Int64(trimmed.count)))"
            logger.debug("\(line, privacy: .public)")
            OpenIMProbeLogger.log(line)
        } catch {
            let line = "[OpenIMStorageGovernance] probe-log-trim-failed error=\(error.localizedDescription)"
            logger.error("\(line, privacy: .public)")
            OpenIMProbeLogger.log(line)
        }
    }

    private static func openIMDataDirectoryURL() -> URL? {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return root?.appendingPathComponent("OpenIM", isDirectory: true)
    }

    private static func probeLogFileURL() -> URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("openim-probe.log", isDirectory: false)
    }

    private static func fileSize(at url: URL?) -> Int64 {
        guard let url else { return 0 }
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) else {
            return 0
        }
        return (attrs[.size] as? NSNumber)?.int64Value ?? 0
    }

    private static func directorySize(at url: URL?) -> Int64 {
        guard let url else { return 0 }
        guard FileManager.default.fileExists(atPath: url.path) else { return 0 }

        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey]
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var total: Int64 = 0
        while let fileURL = enumerator.nextObject() as? URL {
            guard let values = try? fileURL.resourceValues(forKeys: keys),
                  values.isRegularFile == true else {
                continue
            }
            if let allocated = values.totalFileAllocatedSize ?? values.fileAllocatedSize {
                total += Int64(allocated)
            } else if let fileSize = values.fileSize {
                total += Int64(fileSize)
            }
        }
        return total
    }

    private static func formatted(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: max(0, bytes))
    }
}
