import Foundation

enum EventUploadAnalytics {
    static func track(_ name: String, properties: [String: String] = [:]) {
        #if DEBUG
        print("[EventUploadV2Analytics] \(name) \(properties)")
        #endif
    }
}

