import Foundation
import SDWebImage

enum ImageCacheBootstrap {
    private static var hasConfigured = false

    static func configureIfNeeded() {
        guard !hasConfigured else { return }
        hasConfigured = true

        let cache = SDImageCache.shared
        cache.config.maxMemoryCost = 80 * 1024 * 1024
        cache.config.maxDiskSize = 600 * 1024 * 1024
        cache.config.maxDiskAge = 60 * 60 * 24 * 30
        cache.config.shouldUseWeakMemoryCache = true

        SDWebImageDownloader.shared.config.downloadTimeout = 15
        SDWebImageDownloader.shared.config.executionOrder = .lifoExecutionOrder
    }
}
