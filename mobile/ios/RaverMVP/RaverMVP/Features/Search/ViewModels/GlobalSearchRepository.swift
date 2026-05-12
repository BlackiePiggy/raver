import Foundation

protocol GlobalSearchRepository {
    func searchGlobal(query: String, tab: GlobalSearchTab, limit: Int) async throws -> GlobalSearchResponse
}

struct GlobalSearchRepositoryAdapter: GlobalSearchRepository {
    private let service: WebFeatureService

    init(service: WebFeatureService) {
        self.service = service
    }

    func searchGlobal(query: String, tab: GlobalSearchTab, limit: Int) async throws -> GlobalSearchResponse {
        try await service.searchGlobal(query: query, tab: tab, limit: limit)
    }
}
