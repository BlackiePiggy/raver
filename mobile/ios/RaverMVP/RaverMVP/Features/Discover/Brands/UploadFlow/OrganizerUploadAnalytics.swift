import Foundation

enum OrganizerUploadAnalytics {
    static func track(_ name: String, properties: [String: String] = [:]) {
        #if DEBUG
        print("[OrganizerUploadAnalytics] \(name) \(properties)")
        #endif
    }
}
