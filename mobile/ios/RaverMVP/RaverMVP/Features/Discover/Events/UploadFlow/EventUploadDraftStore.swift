import Foundation

final class EventUploadDraftStore {
    static let shared = EventUploadDraftStore()

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let defaults: UserDefaults
    private let draftTTL: TimeInterval = 14 * 24 * 60 * 60

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func load(mode: EventUploadMode, userID: String) -> EventUploadDraft? {
        guard let data = defaults.data(forKey: storageKey(mode: mode, userID: userID)) else { return nil }
        guard let draft = try? decoder.decode(EventUploadDraft.self, from: data) else { return nil }
        if let updatedAt = draft.updatedAt, Date().timeIntervalSince(updatedAt) > draftTTL {
            clear(mode: mode, userID: userID, draftID: draft.id)
            return nil
        }
        return draft
    }

    func save(_ draft: EventUploadDraft, userID: String) {
        var next = draft
        next.updatedAt = Date()
        guard let data = try? encoder.encode(next) else { return }
        defaults.set(data, forKey: storageKey(mode: draft.mode, userID: userID))
    }

    func clear(mode: EventUploadMode, userID: String) {
        let draftID = load(mode: mode, userID: userID)?.id
        clear(mode: mode, userID: userID, draftID: draftID)
    }

    func saveImageData(_ data: Data, draftID: UUID, zone: EventUploadImageZone, fileExtension: String) throws -> URL {
        let directory = try draftImageDirectory(draftID: draftID, zone: zone)
        let safeExtension = fileExtension.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "jpg" : fileExtension
        let fileURL = directory.appendingPathComponent("\(UUID().uuidString).\(safeExtension)")
        try data.write(to: fileURL, options: [.atomic])
        return fileURL
    }

    private func storageKey(mode: EventUploadMode, userID: String) -> String {
        "eventUploadDraft.\(mode.storageKeyPart).\(userID)"
    }

    private func draftImageDirectory(draftID: UUID, zone: EventUploadImageZone) throws -> URL {
        let baseURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = baseURL
            .appendingPathComponent("EventUploadDrafts", isDirectory: true)
            .appendingPathComponent(draftID.uuidString, isDirectory: true)
            .appendingPathComponent(zone.rawValue, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func clear(mode: EventUploadMode, userID: String, draftID: UUID?) {
        defaults.removeObject(forKey: storageKey(mode: mode, userID: userID))
        guard let draftID else { return }
        let baseURL = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        let directory = baseURL?
            .appendingPathComponent("EventUploadDrafts", isDirectory: true)
            .appendingPathComponent(draftID.uuidString, isDirectory: true)
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
    }
}
