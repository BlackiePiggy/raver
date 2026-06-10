import Foundation

@MainActor
final class LearnLabelsRootViewModel: ObservableObject {
    @Published private(set) var allLabels: [LearnLabel] = []
    @Published private(set) var labels: [LearnLabel] = []
    @Published private(set) var pagination: BFFPagination?
    @Published private(set) var phase: LoadPhase = .idle
    @Published private(set) var isLoading = false
    @Published private(set) var isRefreshing = false
    @Published private(set) var isLoadingMore = false
    @Published var bannerMessage: String?

    @Published var selectedSort: LearnLabelsSortOption = .soundcloudFollowers
    @Published var sortOrder: LearnLabelsSortOrder = .desc
    @Published var selectedGenreFilters: Set<String> = []
    @Published var selectedNationFilters: Set<String> = []

    private let pageSize = 10
    private var hasTriggeredInitialLoad = false

    func triggerInitialLoadIfNeeded(isActive: Bool, repository: DiscoverWikiRepository) async {
        guard isActive else { return }
        guard !hasTriggeredInitialLoad else { return }
        hasTriggeredInitialLoad = true
        await reload(repository: repository, force: false)
    }

    func updateSort(_ option: LearnLabelsSortOption, repository: DiscoverWikiRepository) async {
        guard selectedSort != option else { return }
        selectedSort = option
        sortOrder = option.defaultOrder
        await reload(repository: repository, force: true)
    }

    func toggleSortOrder(repository: DiscoverWikiRepository) async {
        sortOrder = sortOrder == .desc ? .asc : .desc
        await reload(repository: repository, force: true)
    }

    func toggleGenreFilter(_ genre: String, repository: DiscoverWikiRepository) async {
        if selectedGenreFilters.contains(genre) {
            selectedGenreFilters.remove(genre)
        } else {
            selectedGenreFilters.insert(genre)
        }
        await reload(repository: repository, force: true)
    }

    func toggleNationFilter(_ nation: String, repository: DiscoverWikiRepository) async {
        if selectedNationFilters.contains(nation) {
            selectedNationFilters.remove(nation)
        } else {
            selectedNationFilters.insert(nation)
        }
        await reload(repository: repository, force: true)
    }

    func clearGenreFilters(repository: DiscoverWikiRepository) async {
        guard !selectedGenreFilters.isEmpty else { return }
        selectedGenreFilters.removeAll()
        await reload(repository: repository, force: true)
    }

    func clearNationFilters(repository: DiscoverWikiRepository) async {
        guard !selectedNationFilters.isEmpty else { return }
        selectedNationFilters.removeAll()
        await reload(repository: repository, force: true)
    }

    func clearAllFilters(repository: DiscoverWikiRepository) async {
        guard !selectedGenreFilters.isEmpty || !selectedNationFilters.isEmpty else { return }
        selectedGenreFilters.removeAll()
        selectedNationFilters.removeAll()
        await reload(repository: repository, force: true)
    }

    func reload(repository: DiscoverWikiRepository, force: Bool = true) async {
        if isLoading, !force { return }

        let hadContent = !labels.isEmpty
        isLoading = true
        if hadContent {
            isRefreshing = true
        } else {
            phase = .initialLoading
        }
        defer {
            isLoading = false
            isRefreshing = false
        }

        do {
            let page = try await repository.fetchLearnLabels(
                page: 1,
                limit: pageSize,
                sortBy: selectedSort.apiValue,
                order: sortOrder.rawValue,
                search: nil,
                nation: currentNationFilterQuery,
                genre: currentGenreFilterQuery
            )
            allLabels = page.items
            labels = page.items
            pagination = page.pagination
            phase = labels.isEmpty ? .empty : .success
            bannerMessage = nil
        } catch {
            let message = error.userFacingMessage ?? LT(
                "厂牌加载失败，请稍后重试",
                "Failed to load labels. Please try again later.",
                "レーベルを読み込めませんでした。時間をおいて再試行してください。"
            )
            if hadContent {
                bannerMessage = message
                phase = .success
            } else {
                phase = .failure(message: message)
            }
        }
    }

    func loadMoreIfNeeded(repository: DiscoverWikiRepository) async {
        guard !isLoading, !isLoadingMore else { return }
        guard let pagination, pagination.page < pagination.totalPages else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let response = try await repository.fetchLearnLabels(
                page: pagination.page + 1,
                limit: pageSize,
                sortBy: selectedSort.apiValue,
                order: sortOrder.rawValue,
                search: nil,
                nation: currentNationFilterQuery,
                genre: currentGenreFilterQuery
            )
            let existingIDs = Set(allLabels.map(\.id))
            let appended = response.items.filter { !existingIDs.contains($0.id) }
            allLabels.append(contentsOf: appended)
            labels.append(contentsOf: appended)
            self.pagination = response.pagination
            phase = labels.isEmpty ? .empty : .success
        } catch {
            bannerMessage = error.userFacingMessage ?? LT(
                "厂牌加载失败，请稍后重试",
                "Failed to load labels. Please try again later.",
                "レーベルを読み込めませんでした。時間をおいて再試行してください。"
            )
        }
    }

    var availableGenreFilters: [String] {
        let genres = allLabels.flatMap { labelGenres(for: $0) }
        return Array(Set(genres)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var availableNationFilters: [String] {
        let nations = allLabels.compactMap { label -> String? in
            let trimmed = label.nation?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? nil : trimmed
        }
        return Array(Set(nations)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var currentGenreFilterQuery: String? {
        let values = selectedGenreFilters
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted()
        return values.isEmpty ? nil : values.joined(separator: ",")
    }

    private var currentNationFilterQuery: String? {
        let values = selectedNationFilters
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted()
        return values.isEmpty ? nil : values.joined(separator: ",")
    }

    private func labelGenres(for label: LearnLabel) -> [String] {
        if !label.genres.isEmpty {
            return label.genres.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        }
        return (label.genresPreview ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

