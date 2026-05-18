import Foundation

struct RegistrationRegionCatalog: Decodable {
    let version: String
    let countries: [RegistrationCountryRegion]

    static let fallback = RegistrationRegionCatalog(
        version: "fallback",
        countries: [
            RegistrationCountryRegion(
                code: "CN",
                name: "中国",
                enName: "China",
                regionLabel: "省/直辖市",
                cityLabel: "城市",
                children: [
                    RegistrationAdministrativeRegion(
                        code: "310000",
                        name: "上海市",
                        enName: nil,
                        children: [RegistrationAdministrativeArea(code: "310000", name: "上海市")]
                    )
                ]
            ),
            RegistrationCountryRegion(
                code: "JP",
                name: "日本",
                enName: "Japan",
                regionLabel: "都道府县",
                cityLabel: "市区町村",
                children: [
                    RegistrationAdministrativeRegion(
                        code: "13",
                        name: "東京都",
                        enName: "tokyo",
                        children: [RegistrationAdministrativeArea(code: "13-0012", name: "港区")]
                    )
                ]
            ),
        ]
    )

    static func load() -> RegistrationRegionCatalog {
        guard
            let url = Bundle.main.url(forResource: "registration-region-catalog", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let catalog = try? JSONDecoder().decode(RegistrationRegionCatalog.self, from: data),
            !catalog.countries.isEmpty
        else {
            return fallback
        }
        return catalog
    }

    func country(for code: String) -> RegistrationCountryRegion {
        countries.first(where: { $0.code == code }) ?? countries[0]
    }

    func displayText(for location: String) -> String {
        let parts = location.split(separator: ":").map(String.init)
        guard parts.count >= 3 else { return location }
        let country = country(for: parts[0])
        let region = country.children.first(where: { $0.code == parts[1] })
        let city = region?.children.first(where: { $0.code == parts[2] })
        return [country.displayName, region?.displayName, city?.displayName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty }
            .reduce(into: [String]()) { result, item in
                if result.last != item {
                    result.append(item)
                }
            }
            .joined(separator: " · ")
            .nilIfEmpty
        ?? location
    }
}

struct RegistrationCountryRegion: Decodable, Identifiable, Hashable {
    let code: String
    let name: String
    let enName: String?
    let regionLabel: String
    let cityLabel: String
    let children: [RegistrationAdministrativeRegion]

    var id: String { code }

    var displayName: String {
        Locale.preferredLanguages.first?.hasPrefix("zh") == true ? name : (enName ?? name)
    }
}

struct RegistrationAdministrativeRegion: Decodable, Identifiable, Hashable {
    let code: String
    let name: String
    let enName: String?
    let children: [RegistrationAdministrativeArea]

    var id: String { code }

    var displayName: String {
        Locale.preferredLanguages.first?.hasPrefix("en") == true ? (enName ?? name) : name
    }
}

struct RegistrationAdministrativeArea: Decodable, Identifiable, Hashable {
    let code: String
    let name: String

    var id: String { code }
    var displayName: String { name }
}
