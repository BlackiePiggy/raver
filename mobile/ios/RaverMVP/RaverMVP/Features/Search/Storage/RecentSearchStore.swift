import Foundation

@MainActor
final class RecentSearchStore: ObservableObject {
    @Published private(set) var queries: [String] = []

    private let defaults: UserDefaults
    private let key: String
    private let maxCount: Int

    init(
        defaults: UserDefaults = .standard,
        key: String = "globalSearch.recentQueries.v1",
        maxCount: Int = 10
    ) {
        self.defaults = defaults
        self.key = key
        self.maxCount = max(1, maxCount)
        self.queries = Self.normalizedList(defaults.stringArray(forKey: key) ?? [], maxCount: max(1, maxCount))
    }

    func record(_ rawQuery: String) {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        var next = queries.filter { $0.caseInsensitiveCompare(query) != .orderedSame }
        next.insert(query, at: 0)
        queries = Self.normalizedList(next, maxCount: maxCount)
        defaults.set(queries, forKey: key)
    }

    func clear() {
        queries = []
        defaults.removeObject(forKey: key)
    }

    private static func normalizedList(_ items: [String], maxCount: Int) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for item in items {
            let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(trimmed)
            if result.count >= maxCount {
                break
            }
        }
        return result
    }
}

