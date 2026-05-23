import Foundation

final class DJUploadDraftStore {
    static let shared = DJUploadDraftStore()

    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {}

    func load(mode: DJUploadMode, userID: String) -> DJUploadDraft? {
        guard let data = defaults.data(forKey: storageKey(mode: mode, userID: userID)) else { return nil }
        return try? decoder.decode(DJUploadDraft.self, from: data)
    }

    func save(_ draft: DJUploadDraft, userID: String) {
        var next = draft
        next.lastSavedAt = Date()
        guard let data = try? encoder.encode(next) else { return }
        defaults.set(data, forKey: storageKey(mode: next.mode, userID: userID))
    }

    func clear(mode: DJUploadMode, userID: String) {
        defaults.removeObject(forKey: storageKey(mode: mode, userID: userID))
    }

    private func storageKey(mode: DJUploadMode, userID: String) -> String {
        "raver.dj-upload-flow.\(userID).\(mode.storageKey)"
    }
}
