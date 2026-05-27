import Foundation

final class OrganizerUploadDraftStore {
    static let shared = OrganizerUploadDraftStore()

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func load(mode: OrganizerUploadMode, userID: String) -> OrganizerUploadDraft? {
        guard let data = defaults.data(forKey: storageKey(mode: mode, userID: userID)) else { return nil }
        return try? decoder.decode(OrganizerUploadDraft.self, from: data)
    }

    func save(_ draft: OrganizerUploadDraft, userID: String) {
        var next = draft
        next.lastSavedAt = Date()
        guard let data = try? encoder.encode(next) else { return }
        defaults.set(data, forKey: storageKey(mode: draft.mode, userID: userID))
    }

    func clear(mode: OrganizerUploadMode, userID: String) {
        defaults.removeObject(forKey: storageKey(mode: mode, userID: userID))
    }

    private func storageKey(mode: OrganizerUploadMode, userID: String) -> String {
        "organizerUploadDraft.\(mode.storageKey).\(userID)"
    }
}
