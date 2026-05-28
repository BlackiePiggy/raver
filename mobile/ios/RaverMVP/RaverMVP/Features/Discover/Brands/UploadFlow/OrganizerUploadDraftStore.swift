import Foundation

final class OrganizerUploadDraftStore {
    static let shared = OrganizerUploadDraftStore()

    private static let draftTTL: TimeInterval = 14 * 24 * 60 * 60
    private static let draftDirectoryName = "OrganizerUploadDrafts"

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func load(mode: OrganizerUploadMode, userID: String) -> OrganizerUploadDraft? {
        cleanupExpiredDraftsIfNeeded()
        guard let data = defaults.data(forKey: storageKey(mode: mode, userID: userID)) else { return nil }
        guard let draft = try? decoder.decode(OrganizerUploadDraft.self, from: data) else {
            clear(mode: mode, userID: userID)
            return nil
        }
        guard !isExpired(draft) else {
            clear(mode: mode, userID: userID)
            return nil
        }
        return draft
    }

    func save(_ draft: OrganizerUploadDraft, userID: String) {
        cleanupExpiredDraftsIfNeeded()
        var next = draft
        next.lastSavedAt = Date()
        guard let data = try? encoder.encode(next) else { return }
        defaults.set(data, forKey: storageKey(mode: draft.mode, userID: userID))
    }

    func clear(mode: OrganizerUploadMode, userID: String) {
        let draftID = loadWithoutCleanup(mode: mode, userID: userID)?.id
        clear(mode: mode, userID: userID, draftID: draftID)
    }

    func saveImageData(_ data: Data, draftID: UUID, zone: OrganizerUploadImageZone, fileExtension: String) throws -> URL {
        let directory = try draftImageDirectory(draftID: draftID, zone: zone)
        let safeExtension = fileExtension.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank ?? "jpg"
        let fileURL = directory.appendingPathComponent("\(UUID().uuidString).\(safeExtension)")
        try data.write(to: fileURL, options: [.atomic])
        return fileURL
    }

    func deleteImageFileIfNeeded(_ fileURL: URL?) {
        guard let fileURL else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func storageKey(mode: OrganizerUploadMode, userID: String) -> String {
        "organizerUploadDraft.\(mode.storageKey).\(userID)"
    }

    private func loadWithoutCleanup(mode: OrganizerUploadMode, userID: String) -> OrganizerUploadDraft? {
        guard let data = defaults.data(forKey: storageKey(mode: mode, userID: userID)) else { return nil }
        return try? decoder.decode(OrganizerUploadDraft.self, from: data)
    }

    private func isExpired(_ draft: OrganizerUploadDraft) -> Bool {
        guard let lastSavedAt = draft.lastSavedAt else { return false }
        return Date().timeIntervalSince(lastSavedAt) > Self.draftTTL
    }

    private func cleanupExpiredDraftsIfNeeded() {
        for (key, value) in defaults.dictionaryRepresentation() where key.hasPrefix("organizerUploadDraft.") {
            guard let data = value as? Data,
                  let draft = try? decoder.decode(OrganizerUploadDraft.self, from: data),
                  isExpired(draft)
            else { continue }
            defaults.removeObject(forKey: key)
            removeDraftDirectory(draftID: draft.id)
        }
    }

    private func draftImageDirectory(draftID: UUID, zone: OrganizerUploadImageZone) throws -> URL {
        let baseURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = baseURL
            .appendingPathComponent(Self.draftDirectoryName, isDirectory: true)
            .appendingPathComponent(draftID.uuidString, isDirectory: true)
            .appendingPathComponent(zone.rawValue, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func clear(mode: OrganizerUploadMode, userID: String, draftID: UUID?) {
        defaults.removeObject(forKey: storageKey(mode: mode, userID: userID))
        guard let draftID else { return }
        removeDraftDirectory(draftID: draftID)
    }

    private func removeDraftDirectory(draftID: UUID) {
        let baseURL = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        let directory = baseURL?
            .appendingPathComponent(Self.draftDirectoryName, isDirectory: true)
            .appendingPathComponent(draftID.uuidString, isDirectory: true)
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
    }
}
