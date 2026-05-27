import Foundation

enum OrganizerUploadMappers {
    static func localizedFields(name: String, i18n: WebBiText?) -> EventUploadLocalizedFields {
        EventUploadLocalizedFields(
            zh: i18n?.zh ?? name,
            en: i18n?.en ?? name,
            ja: i18n?.ja ?? "",
            enFull: i18n?.enFull ?? ""
        )
    }

    static func summary(for draft: OrganizerUploadDraft) -> [String] {
        [
            draft.primaryName,
            draft.country.trimmingCharacters(in: .whitespacesAndNewlines),
            draft.city.trimmingCharacters(in: .whitespacesAndNewlines),
        ].filter { !$0.isEmpty }
    }
}
