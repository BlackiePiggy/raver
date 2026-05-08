import Foundation

enum GlobalSearchTelemetry {
    static func overlayOpened(source: String) {
        log("overlay-open source=\(source)")
    }

    static func submitted(query: String, source: String) {
        log("submit source=\(source) queryLength=\(query.count)")
    }

    static func loadStarted(query: String, tab: GlobalSearchTab) -> Date {
        let startedAt = Date()
        log("load-start tab=\(tab.rawValue) queryLength=\(query.count)")
        return startedAt
    }

    static func loadSucceeded(query: String, tab: GlobalSearchTab, itemCount: Int, partialErrorCount: Int, startedAt: Date) {
        let durationMs = Int(Date().timeIntervalSince(startedAt) * 1000)
        log("load-success tab=\(tab.rawValue) queryLength=\(query.count) items=\(itemCount) partialErrors=\(partialErrorCount) durationMs=\(durationMs)")
    }

    static func loadFailed(query: String, tab: GlobalSearchTab, error: Error, startedAt: Date) {
        let durationMs = Int(Date().timeIntervalSince(startedAt) * 1000)
        log("load-failed tab=\(tab.rawValue) queryLength=\(query.count) durationMs=\(durationMs) error=\(error.localizedDescription)")
    }

    static func resultOpened(_ item: GlobalSearchItem) {
        log("result-open type=\(item.type.rawValue) entityID=\(item.entityID) score=\(item.relevanceScore)")
    }

    private static func log(_ message: String) {
        IMProbeLogger.log("[GlobalSearch] \(message)")
    }
}
