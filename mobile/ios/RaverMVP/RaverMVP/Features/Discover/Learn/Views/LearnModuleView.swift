import SwiftUI
import PhotosUI
import AVKit
import AVFoundation
import UIKit
import Photos
import CoreImage.CIFilterBuiltins
import MapKit
import CoreLocation
import CoreText

struct LearnModuleView: View {
    @Environment(\.discoverPush) private var discoverPush
    @Environment(\.appPush) private var appPush
    @Environment(\.raverTabBarReservedHeight) private var tabBarReservedHeight
    @EnvironmentObject private var appContainer: AppContainer

    private var wikiRepository: DiscoverWikiRepository {
        appContainer.discoverWikiRepository
    }

    private var djsRepository: DiscoverDJsRepository {
        appContainer.discoverDJsRepository
    }

    @State private var genres: [LearnGenreNode] = []
    @State private var allLabels: [LearnLabel] = []
    @State private var labels: [LearnLabel] = []
    @State private var allFestivals: [LearnFestival] = []
    @State private var festivals: [LearnFestival] = []
    @State private var rankingBoards: [RankingBoard] = []
    @State private var labelsPagination: BFFPagination?
    @State private var selectedSection: LearnModuleSection = .rankings
    @State private var selectedSort: LearnLabelSortOption = .soundcloudFollowers
    @State private var sortOrder: LearnLabelSortOrder = .desc
    @State private var searchKeyword = ""
    @State private var selectedGenreFilters: Set<String> = []
    @State private var selectedNationFilters: Set<String> = []
    @State private var activeFilterPanel: LearnLabelFilterPanelType?
    @State private var isLoadingRankings = false
    @State private var isLoadingGenres = false
    @State private var isLoadingLabels = false
    @State private var isLoadingFestivals = false
    @State private var selectedFestivalRankingBoard: LearnFestivalRankingBoard?
    @State private var showFestivalCreateSheet = false
    @State private var isCreatingFestival = false
    @State private var createFestivalName = ""
    @State private var createFestivalAliases = ""
    @State private var createFestivalCountry = ""
    @State private var createFestivalCity = ""
    @State private var createFestivalFoundedYear = ""
    @State private var createFestivalFrequency = ""
    @State private var createFestivalTagline = ""
    @State private var createFestivalIntroduction = ""
    @State private var createFestivalWebsite = ""
    @State private var createFestivalAvatarItem: PhotosPickerItem?
    @State private var createFestivalBackgroundItem: PhotosPickerItem?
    @State private var createFestivalAvatarData: Data?
    @State private var createFestivalBackgroundData: Data?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
                headerTabs
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                if selectedSection == .labels {
                    labelsToolbar
                        .padding(.horizontal, 16)
                        .padding(.bottom, 6)
                } else if selectedSection == .festivals {
                    festivalsToolbar
                        .padding(.horizontal, 16)
                        .padding(.bottom, 6)
                }

                Group {
                    switch selectedSection {
                    case .rankings:
                        rankingsContent
                    case .genres:
                        genresContent
                    case .labels:
                        labelsContent
                    case .festivals:
                        festivalsContent
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(RaverTheme.background)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadInitial()
            }
            .onChange(of: selectedSort) { _, next in
                sortOrder = next.defaultOrder
                Task { await loadLabels() }
            }
            .onChange(of: sortOrder) { _, _ in
                Task { await loadLabels() }
            }
            .onChange(of: selectedGenreFilters) { _, _ in
                applyLabelFilters()
            }
            .onChange(of: selectedNationFilters) { _, _ in
                applyLabelFilters()
            }
            .onChange(of: createFestivalAvatarItem) { _, item in
                Task { await loadFestivalCreatePhoto(item, target: .avatar) }
            }
            .onChange(of: createFestivalBackgroundItem) { _, item in
                Task { await loadFestivalCreatePhoto(item, target: .background) }
            }
            .navigationDestination(item: $selectedFestivalRankingBoard) { board in
                LearnFestivalRankingDetailView(
                    board: board,
                    rankedFestivals: festivalRankedEntries(for: board)
                ) { updated in
                    updateFestival(updated)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .discoverFestivalDidSave)) { _ in
                Task { await loadFestivals() }
            }
            .alert(L("提示", "Notice"), isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button(L("确定", "OK"), role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
    }

    @ViewBuilder
    private var headerTabs: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(LearnModuleSection.allCases) { item in
                        Button(item.title) {
                            withAnimation(.interactiveSpring(response: 0.26, dampingFraction: 0.84)) {
                                selectedSection = item
                            }
                        }
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selectedSection == item ? RaverTheme.accent : RaverTheme.card)
                        .foregroundStyle(selectedSection == item ? Color.white : RaverTheme.primaryText)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                switch selectedSection {
                case .rankings:
                    discoverPush(
                        .searchInput(
                            domain: .djs,
                            initialQuery: searchKeyword
                        )
                    )
                case .genres, .labels, .festivals:
                    discoverPush(
                        .searchInput(
                            domain: .wiki,
                            initialQuery: searchKeyword,
                            preferredWikiSectionRaw: selectedSection.rawValue
                        )
                    )
                }
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .frame(width: 32, height: 32)
                    .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var labelsToolbar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    discoverPush(
                        .searchInput(
                            domain: .wiki,
                            initialQuery: searchKeyword,
                            preferredWikiSectionRaw: LearnModuleSection.labels.rawValue
                        )
                    )
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(RaverTheme.secondaryText)
                        Text(LL("搜索厂牌名 / 简介"))
                            .font(.subheadline)
                            .foregroundStyle(RaverTheme.secondaryText)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(RaverTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)

                Menu {
                    ForEach(LearnLabelSortOption.allCases) { option in
                        Button {
                            selectedSort = option
                        } label: {
                            if option == selectedSort {
                                Label(option.title, systemImage: "checkmark")
                            } else {
                                Text(option.title)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(selectedSort.title)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.semibold))
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(RaverTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                Button {
                    sortOrder = sortOrder == .desc ? .asc : .desc
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: sortOrder == .desc ? "arrow.down" : "arrow.up")
                        Text(sortOrder == .desc ? L("降序", "Desc") : L("升序", "Asc"))
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(RaverTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }

            HStack(spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        activeFilterPanel = activeFilterPanel == .genres ? nil : .genres
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: activeFilterPanel == .genres ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        Text(selectedGenreFilters.isEmpty ? L("筛选风格", "Filter Genres") : L("风格 \(selectedGenreFilters.count)", "Genres \(selectedGenreFilters.count)"))
                            .lineLimit(1)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(RaverTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        activeFilterPanel = activeFilterPanel == .nations ? nil : .nations
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: activeFilterPanel == .nations ? "flag.fill" : "flag")
                        Text(selectedNationFilters.isEmpty ? L("筛选国家", "Filter Countries") : L("国家 \(selectedNationFilters.count)", "Countries \(selectedNationFilters.count)"))
                            .lineLimit(1)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(RaverTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)

                if !selectedGenreFilters.isEmpty || !selectedNationFilters.isEmpty {
                    Button(LL("清空全部")) {
                        selectedGenreFilters.removeAll()
                        selectedNationFilters.removeAll()
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
                }

                Spacer(minLength: 0)
            }

            if activeFilterPanel == .genres {
                LearnLabelMultiSelectPanel(
                    title: L("筛选风格", "Filter Genres"),
                    options: availableGenreFilters,
                    selectedValues: selectedGenreFilters,
                    emptyText: L("暂无可筛选风格", "No genres available for filtering"),
                    onToggle: toggleGenreFilter,
                    onClear: {
                        selectedGenreFilters.removeAll()
                    },
                    onClose: {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            activeFilterPanel = nil
                        }
                    }
                )
            } else if activeFilterPanel == .nations {
                LearnLabelMultiSelectPanel(
                    title: L("筛选国家", "Filter Countries"),
                    options: availableNationFilters,
                    selectedValues: selectedNationFilters,
                    emptyText: L("暂无可筛选国家", "No countries available for filtering"),
                    onToggle: toggleNationFilter,
                    onClear: {
                        selectedNationFilters.removeAll()
                    },
                    onClose: {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            activeFilterPanel = nil
                        }
                    }
                )
            }

            if let total = labelsPagination?.total {
                Text(L("筛选后 \(labels.count) / 共 \(total) 个厂牌", "Filtered \(labels.count) / Total \(total) labels"))
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var festivalsToolbar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    discoverPush(
                        .searchInput(
                            domain: .wiki,
                            initialQuery: searchKeyword,
                            preferredWikiSectionRaw: LearnModuleSection.festivals.rawValue
                        )
                    )
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(RaverTheme.secondaryText)
                        Text(LL("搜索电音节名 / 城市 / 国家"))
                            .font(.subheadline)
                            .foregroundStyle(RaverTheme.secondaryText)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(RaverTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                Text(L("筛选后 \(festivals.count) / 共 \(allFestivals.count) 个电音节 IP", "Filtered \(festivals.count) / Total \(allFestivals.count) festival IPs"))
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)

                Spacer(minLength: 0)

                Button {
                    prepareFestivalCreateDraft()
                    discoverPush(.learnFestivalCreate)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.caption.weight(.bold))
                        Text(LL("新增电音节"))
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(RaverTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var rankingsContent: some View {
        if isLoadingRankings && rankingBoards.isEmpty {
            ProgressView(L("加载榜单中...", "Loading rankings..."))
                .frame(maxWidth: .infinity, minHeight: 220)
        } else if rankingBoards.isEmpty {
            ContentUnavailableView(LL("暂无榜单"), systemImage: "list.number")
                .frame(maxWidth: .infinity, minHeight: 220)
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(rankingBoards) { board in
                        Button {
                            appPush(.rankingBoardDetail(board: board))
                        } label: {
                            RankingBoardCoverCard(board: board)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                        .frame(height: 254)
                        .clipped()
                        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, max(0, tabBarReservedHeight) + 12)
            }
            .refreshable {
                await refreshAll()
            }
        }
    }

    @ViewBuilder
    private var genresContent: some View {
        if isLoadingGenres && genres.isEmpty {
            ProgressView(LL("学习内容加载中..."))
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !genres.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(LL("流派树"))
                                .font(.title3.weight(.bold))
                                .foregroundStyle(RaverTheme.primaryText)
                            ForEach(genres) { node in
                                GenreNodeView(node: node)
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(RaverTheme.card)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, max(0, tabBarReservedHeight) + 14)
            }
            .refreshable {
                await refreshAll()
            }
        }
    }

    @ViewBuilder
    private var labelsContent: some View {
        if isLoadingLabels && labels.isEmpty {
            ProgressView(LL("厂牌加载中..."))
        } else if labels.isEmpty {
            ContentUnavailableView(LL("暂无厂牌"), systemImage: "building.2")
        } else {
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(labels) { label in
                        LearnLabelCard(label: label)
                            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .onTapGesture {
                                discoverPush(.labelDetail(labelID: label.id))
                            }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, max(0, tabBarReservedHeight) + 12)
            }
            .refreshable {
                await refreshAll()
            }
            .simultaneousGesture(
                TapGesture().onEnded {
                    if activeFilterPanel != nil {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            activeFilterPanel = nil
                        }
                    }
                }
            )
        }
    }

    @ViewBuilder
    private var festivalsContent: some View {
        if isLoadingFestivals && allFestivals.isEmpty {
            ProgressView(LL("电音节加载中..."))
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if festivals.isEmpty {
                        ContentUnavailableView(LL("暂无匹配电音节"), systemImage: "music.quarternote.3")
                            .frame(maxWidth: .infinity, minHeight: 220)
                    } else {
                        LazyVStack(spacing: 14) {
                            ForEach(festivals) { festival in
                                LearnFestivalCard(festival: festival)
                                    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .onTapGesture {
                                        discoverPush(.festivalDetail(festivalID: festival.id))
                                    }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, max(0, tabBarReservedHeight) + 12)
            }
            .refreshable {
                await refreshAll()
            }
        }
    }

    private func loadInitial() async {
        async let rankingsTask: Void = loadRankingBoards()
        async let genresTask: Void = loadGenres()
        async let labelsTask: Void = loadLabels()
        async let festivalsTask: Void = loadFestivals()
        _ = await (rankingsTask, genresTask, labelsTask, festivalsTask)
    }

    private func refreshAll() async {
        async let rankingsTask: Void = loadRankingBoards()
        async let genresTask: Void = loadGenres()
        async let labelsTask: Void = loadLabels()
        async let festivalsTask: Void = loadFestivals()
        _ = await (rankingsTask, genresTask, labelsTask, festivalsTask)
    }

    private func loadRankingBoards() async {
        isLoadingRankings = true
        defer { isLoadingRankings = false }

        do {
            rankingBoards = try await djsRepository.fetchRankingBoards()
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    private func loadGenres() async {
        isLoadingGenres = true
        defer { isLoadingGenres = false }
        do {
            genres = try await wikiRepository.fetchLearnGenres()
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    private func loadLabels() async {
        isLoadingLabels = true
        defer { isLoadingLabels = false }

        do {
            let page = try await wikiRepository.fetchLearnLabels(
                page: 1,
                limit: 500,
                sortBy: selectedSort.apiValue,
                order: sortOrder.rawValue,
                search: nil,
                nation: nil,
                genre: nil
            )
            allLabels = page.items
            applyLabelFilters()
            labelsPagination = page.pagination
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    private func loadFestivals() async {
        isLoadingFestivals = true
        defer { isLoadingFestivals = false }

        do {
            let fetched = try await wikiRepository.fetchLearnFestivals(search: nil)
            allFestivals = fetched.map { LearnFestival(web: $0) }
            applyFestivalFilters()
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    private var availableGenreFilters: [String] {
        let genres = allLabels.flatMap { labelGenres(for: $0) }
        return Array(Set(genres)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var availableNationFilters: [String] {
        let nations = allLabels.compactMap { label -> String? in
            let trimmed = label.nation?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? nil : trimmed
        }
        return Array(Set(nations)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func applyLabelFilters() {
        let normalizedGenreFilters = Set(selectedGenreFilters.map(normalizeFilterToken))
        let normalizedNationFilters = Set(selectedNationFilters.map(normalizeFilterToken))

        labels = allLabels.filter { label in
            let nationPass: Bool = {
                guard !normalizedNationFilters.isEmpty else { return true }
                let nation = normalizeFilterToken(label.nation ?? "")
                return normalizedNationFilters.contains(nation)
            }()

            guard nationPass else { return false }

            guard !normalizedGenreFilters.isEmpty else { return true }
            let genrePool = Set(labelGenres(for: label).map(normalizeFilterToken))
            return normalizedGenreFilters.allSatisfy { genrePool.contains($0) }
        }
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

    private func toggleGenreFilter(_ genre: String) {
        if selectedGenreFilters.contains(genre) {
            selectedGenreFilters.remove(genre)
        } else {
            selectedGenreFilters.insert(genre)
        }
    }

    private func toggleNationFilter(_ nation: String) {
        if selectedNationFilters.contains(nation) {
            selectedNationFilters.remove(nation)
        } else {
            selectedNationFilters.insert(nation)
        }
    }

    private func normalizeFilterToken(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func applyFestivalFilters() {
        festivals = allFestivals
    }

    private func updateFestival(_ updated: LearnFestival) {
        if let index = allFestivals.firstIndex(where: { $0.id == updated.id }) {
            allFestivals[index] = updated
        } else {
            allFestivals.insert(updated, at: 0)
        }
        applyFestivalFilters()
    }

    private var festivalRankingBoards: [LearnFestivalRankingBoard] {
        [
            .djMagTop100Festival2025
        ]
    }

    @ViewBuilder
    private var festivalRankingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LL("榜单分区"))
                .font(.headline.weight(.bold))
                .foregroundStyle(RaverTheme.primaryText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(festivalRankingBoards) { board in
                        let rankedCount = festivalRankedEntries(for: board).count
                        Button {
                            selectedFestivalRankingBoard = board
                        } label: {
                            LearnFestivalRankingBoardCard(
                                board: board,
                                rankedCount: rankedCount
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func festivalRankedEntries(for board: LearnFestivalRankingBoard) -> [LearnFestivalRankedFestival] {
        var entries: [LearnFestivalRankedFestival] = []
        let allByID = Dictionary(uniqueKeysWithValues: allFestivals.map { ($0.id, $0) })

        for (index, festivalID) in board.rankedFestivalIDs.enumerated() {
            if let festival = allByID[festivalID] {
                entries.append(
                    LearnFestivalRankedFestival(
                        rank: index + 1,
                        festival: festival
                    )
                )
            }
        }

        if entries.isEmpty {
            entries = allFestivals.enumerated().map { index, festival in
                LearnFestivalRankedFestival(rank: index + 1, festival: festival)
            }
        }
        return entries
    }

    private enum FestivalCreatePhotoTarget {
        case avatar
        case background
    }

    private var festivalCreateSheet: some View {
        NavigationStack {
            Form {
                Section(LL("基础信息")) {
                    TextField(LL("电音节名称"), text: $createFestivalName)
                    TextField(LL("别名（英文逗号分隔）"), text: $createFestivalAliases)
                    TextField(LL("国家"), text: $createFestivalCountry)
                    TextField(LL("城市"), text: $createFestivalCity)
                    TextField(LL("首办时间"), text: $createFestivalFoundedYear)
                    TextField(LL("举办频次"), text: $createFestivalFrequency)
                    TextField(LL("定位"), text: $createFestivalTagline)
                    TextField(LL("简介"), text: $createFestivalIntroduction, axis: .vertical)
                    TextField(LL("官网链接"), text: $createFestivalWebsite)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                }

                Section(LL("媒体")) {
                    HStack(spacing: 12) {
                        PhotosPicker(selection: $createFestivalAvatarItem, matching: .images) {
                            Label(LL("选择头像"), systemImage: "person.crop.square")
                        }
                        .buttonStyle(.bordered)

                        if let createFestivalAvatarData, let image = UIImage(data: createFestivalAvatarData) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }

                    HStack(spacing: 12) {
                        PhotosPicker(selection: $createFestivalBackgroundItem, matching: .images) {
                            Label(LL("选择背景"), systemImage: "photo.rectangle")
                        }
                        .buttonStyle(.bordered)

                        if let createFestivalBackgroundData, let image = UIImage(data: createFestivalBackgroundData) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 88, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                }

                Section {
                    Button(isCreatingFestival ? L("创建中...", "Creating...") : "创建电音节") {
                        Task { await createFestival() }
                    }
                    .disabled(isCreatingFestival || createFestivalName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .raverSystemNavigation(title: LL("新增电音节"))
            .scrollDismissesKeyboard(.interactively)
        }
        .raverEnableCustomSwipeBack(edgeRatio: 0.2)
    }

    private func prepareFestivalCreateDraft() {
        createFestivalName = ""
        createFestivalAliases = ""
        createFestivalCountry = ""
        createFestivalCity = ""
        createFestivalFoundedYear = ""
        createFestivalFrequency = ""
        createFestivalTagline = ""
        createFestivalIntroduction = ""
        createFestivalWebsite = ""
        createFestivalAvatarItem = nil
        createFestivalBackgroundItem = nil
        createFestivalAvatarData = nil
        createFestivalBackgroundData = nil
    }

    @MainActor
    private func loadFestivalCreatePhoto(_ item: PhotosPickerItem?, target: FestivalCreatePhotoTarget) async {
        guard let item else {
            switch target {
            case .avatar:
                createFestivalAvatarData = nil
            case .background:
                createFestivalBackgroundData = nil
            }
            return
        }

        do {
            let loaded = try await item.loadTransferable(type: Data.self)
            switch target {
            case .avatar:
                createFestivalAvatarData = loaded
            case .background:
                createFestivalBackgroundData = loaded
            }
        } catch {
            errorMessage = L("读取图片失败，请重试", "Failed to read image. Please try again.")
        }
    }

    @MainActor
    private func createFestival() async {
        let finalName = createFestivalName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalName.isEmpty else {
            errorMessage = L("电音节名称不能为空", "Festival name cannot be empty.")
            return
        }

        isCreatingFestival = true
        defer { isCreatingFestival = false }

        do {
            let website = normalizeFestivalURL(createFestivalWebsite)
            let links: [LearnFestivalLinkPayload] = {
                guard let website else { return [] }
                return [LearnFestivalLinkPayload(title: L("官网", "Official"), icon: "globe", url: website)]
            }()

            var created = try await wikiRepository.createLearnFestival(
                input: CreateLearnFestivalInput(
                    name: finalName,
                    aliases: parseFestivalAliasTokens(createFestivalAliases),
                    country: createFestivalCountry.trimmingCharacters(in: .whitespacesAndNewlines),
                    city: createFestivalCity.trimmingCharacters(in: .whitespacesAndNewlines),
                    foundedYear: createFestivalFoundedYear.trimmingCharacters(in: .whitespacesAndNewlines),
                    frequency: createFestivalFrequency.trimmingCharacters(in: .whitespacesAndNewlines),
                    tagline: createFestivalTagline.trimmingCharacters(in: .whitespacesAndNewlines),
                    introduction: createFestivalIntroduction.trimmingCharacters(in: .whitespacesAndNewlines),
                    avatarUrl: nil,
                    backgroundUrl: nil,
                    links: links
                )
            )

            var uploadedAvatarURL: String?
            if let createFestivalAvatarData {
                let uploadedAvatar = try await wikiRepository.uploadWikiBrandImage(
                    imageData: jpegDataForFestivalImport(from: createFestivalAvatarData),
                    fileName: "wiki-brand-avatar-\(UUID().uuidString).jpg",
                    mimeType: "image/jpeg",
                    brandID: created.id,
                    usage: "avatar"
                )
                uploadedAvatarURL = uploadedAvatar.url
            }

            var uploadedBackgroundURL: String?
            if let createFestivalBackgroundData {
                let uploadedBackground = try await wikiRepository.uploadWikiBrandImage(
                    imageData: jpegDataForFestivalImport(from: createFestivalBackgroundData),
                    fileName: "wiki-brand-background-\(UUID().uuidString).jpg",
                    mimeType: "image/jpeg",
                    brandID: created.id,
                    usage: "background"
                )
                uploadedBackgroundURL = uploadedBackground.url
            }

            if uploadedAvatarURL != nil || uploadedBackgroundURL != nil {
                created = try await wikiRepository.updateLearnFestival(
                    id: created.id,
                    input: UpdateLearnFestivalInput(
                        name: nil,
                        aliases: nil,
                        country: nil,
                        city: nil,
                        foundedYear: nil,
                        frequency: nil,
                        tagline: nil,
                        introduction: nil,
                        avatarUrl: uploadedAvatarURL,
                        backgroundUrl: uploadedBackgroundURL,
                        links: nil
                    )
                )
            }

            let hydrated = LearnFestival(web: created)
            updateFestival(hydrated)
            showFestivalCreateSheet = false
            errorMessage = L("电音节品牌已创建", "Festival brand created.")
        } catch {
            errorMessage = L("创建失败：\(error.userFacingMessage ?? "")", "Creation failed: \(error.userFacingMessage ?? "")")
        }
    }

    private func parseFestivalAliasTokens(_ raw: String) -> [String] {
        raw
            .split(whereSeparator: { $0 == "," || $0 == "，" || $0 == "/" || $0 == "、" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func jpegDataForFestivalImport(from data: Data) -> Data {
        guard let image = UIImage(data: data),
              let jpeg = image.jpegData(compressionQuality: 0.9) else {
            return data
        }
        return jpeg
    }

    private func normalizeFestivalURL(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let lower = trimmed.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
            return trimmed
        }
        return "https://\(trimmed)"
    }
}

private struct GenreNodeView: View {
    let node: LearnGenreNode

    var body: some View {
        DisclosureGroup {
            if let children = node.children, !children.isEmpty {
                ForEach(children) { child in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(child.name)
                            .font(.subheadline.weight(.medium))
                        Text(child.description)
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                    .padding(.vertical, 2)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(node.name)
                    .foregroundStyle(RaverTheme.primaryText)
                Text(node.description)
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
            }
        }
    }
}

enum LearnModuleSection: String, CaseIterable, Identifiable, Hashable {
    case rankings
    case festivals
    case labels
    case genres

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rankings: return L("DJ 榜单", "DJ Rankings")
        case .festivals: return L("电音节", "Festivals")
        case .labels: return L("厂牌", "Labels")
        case .genres: return L("流派树", "Genre Tree")
        }
    }
}

private enum LearnLabelFilterPanelType {
    case genres
    case nations
}

private struct LearnLabelMultiSelectPanel: View {
    let title: String
    let options: [String]
    let selectedValues: Set<String>
    let emptyText: String
    let onToggle: (String) -> Void
    let onClear: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(RaverTheme.primaryText)
                Spacer(minLength: 0)
                if !selectedValues.isEmpty {
                    Button(L("清空", "Clear")) {
                        onClear()
                    }
                    .buttonStyle(.plain)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.accent)
                }
                Button(LL("完成")) {
                    onClose()
                }
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .foregroundStyle(RaverTheme.secondaryText)
            }

            if options.isEmpty {
                Text(emptyText)
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(options, id: \.self) { item in
                            Button {
                                onToggle(item)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: selectedValues.contains(item) ? "checkmark.square.fill" : "square")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(selectedValues.contains(item) ? RaverTheme.accent : RaverTheme.secondaryText)
                                    Text(item)
                                        .font(.subheadline)
                                        .foregroundStyle(RaverTheme.primaryText)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(RaverTheme.background.opacity(0.45))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 220)
            }
        }
        .padding(12)
        .frame(width: 300, alignment: .leading)
        .background(RaverTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(RaverTheme.cardBorder, lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

enum LearnLabelSortOrder: String {
    case asc
    case desc
}

enum LearnLabelSortOption: String, CaseIterable, Identifiable {
    case soundcloudFollowers
    case likes
    case name
    case nation
    case latestRelease
    case createdAt

    var id: String { rawValue }

    var title: String {
        switch self {
        case .soundcloudFollowers: return L("热度", "Popularity")
        case .likes: return "Likes"
        case .name: return L("名称", "Name")
        case .nation: return L("国家", "Country")
        case .latestRelease: return L("发布时间文本", "Release Time Text")
        case .createdAt: return L("入库时间", "Created At")
        }
    }

    var defaultOrder: LearnLabelSortOrder {
        switch self {
        case .name, .nation, .latestRelease:
            return .asc
        case .soundcloudFollowers, .likes, .createdAt:
            return .desc
        }
    }

    var apiValue: String {
        rawValue
    }
}

struct LearnLabelCard: View {
    let label: LearnLabel
    @State private var avatarLuminance: CGFloat?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .overlay {
                    bannerView
                        .allowsHitTesting(false)
                }
                .clipped()

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                        .frame(width: 66)
                        .overlay {
                            avatarView
                                .allowsHitTesting(false)
                        }
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(LearnLabelAvatarStyling.borderColor(for: avatarLuminance), lineWidth: 1)
                        )
                        .offset(y: -22)
                        .padding(.bottom, -22)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(label.name)
                            .font(.headline.weight(.black))
                            .foregroundStyle(RaverTheme.primaryText)
                            .lineLimit(2)

                        Text(metaLine)
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)
                }

                if !displayGenres.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(displayGenres, id: \.self) { genre in
                                Text(genre)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(RaverTheme.secondaryText)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(RaverTheme.background)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                if let intro = introLine {
                    Text(intro)
                        .font(.subheadline)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .lineLimit(3)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
        .background(RaverTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(RaverTheme.cardBorder, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .task(id: label.avatarUrl ?? "") {
            await resolveAvatarLuminance()
        }
    }

    @ViewBuilder
    private var bannerView: some View {
        if let url = destinationURL(label.backgroundUrl) {
            fallbackBanner
                .overlay {
                    ImageLoaderView(urlString: url.absoluteString)
                        .background(Color.clear)
                }
        } else {
            fallbackBanner
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        if let url = destinationURL(label.avatarUrl) {
            fallbackAvatar
                .overlay {
                    ImageLoaderView(urlString: url.absoluteString)
                        .background(Color.clear)
                }
        } else {
            fallbackAvatar
        }
    }

    private var fallbackBanner: some View {
        LinearGradient(
            colors: [Color(red: 0.17, green: 0.20, blue: 0.28), Color(red: 0.08, green: 0.09, blue: 0.14)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var fallbackAvatar: some View {
        ZStack {
            fallbackBanner
            Text(String(label.name.prefix(2)).uppercased())
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.85))
        }
    }

    private var displayGenres: [String] {
        if !label.genres.isEmpty {
            return Array(label.genres.prefix(5))
        }
        let raw = label.genresPreview?.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } ?? []
        return Array(raw.filter { !$0.isEmpty }.prefix(5))
    }

    private var introLine: String? {
        let trimmed = label.introduction?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private var metaLine: String {
        let nation = label.nation?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return nation.isEmpty ? L("厂牌信息", "Label info") : nation
    }

    private func destinationURL(_ raw: String?) -> URL? {
        guard let resolved = AppConfig.resolvedURLString(raw) else { return nil }
        return URL(string: resolved)
    }

    private func resolveAvatarLuminance() async {
        guard let avatarURL = destinationURL(label.avatarUrl) else {
            await MainActor.run {
                avatarLuminance = nil
            }
            return
        }
        let luminance = await LearnLabelAvatarStyling.luminance(for: avatarURL)
        await MainActor.run {
            avatarLuminance = luminance
        }
    }
}

struct LearnLabelDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.discoverPush) private var discoverPush
    @Environment(\.appPush) private var appPush

    let label: LearnLabel

    @State private var previewImage: LearnLabelPreviewImage?
    @State private var avatarLuminance: CGFloat?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Color.clear
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .overlay {
                        Button {
                            openPreview(urlString: label.backgroundUrl, title: L("\(label.name) 背景图", "\(label.name) banner"))
                        } label: {
                            headerBanner
                        }
                        .buttonStyle(.plain)
                    }
                    .clipped()

                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 14) {
                        Button {
                            openPreview(urlString: label.avatarUrl, title: L("\(label.name) 头像", "\(label.name) avatar"))
                        } label: {
                            Color.clear
                                .aspectRatio(1, contentMode: .fit)
                                .frame(width: 98)
                                .overlay {
                                    headerAvatar
                                }
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(LearnLabelAvatarStyling.borderColor(for: avatarLuminance), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .offset(y: -50)
                        .padding(.bottom, -50)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(label.name)
                                .font(.title3.weight(.black))
                                .foregroundStyle(RaverTheme.primaryText)
                            if let intro = label.introduction?.trimmingCharacters(in: .whitespacesAndNewlines), !intro.isEmpty {
                                LearnLabelExpandableText(text: intro, collapsedLineLimit: 4)
                            }
                        }
                    }

                    if !displayGenres.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L("Genres", "Genres"))
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(RaverTheme.secondaryText)
                            WrapFlowLayout(items: displayGenres) { genre in
                                Text(genre)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(RaverTheme.secondaryText)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 6)
                                    .background(RaverTheme.background)
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        if hasFounderDisplay {
                            founderSection
                        }
                        LearnLabelInfoRow(title: L("国家", "Country"), value: label.nation)
                        LearnLabelInfoRow(title: L("地区/时期", "Region / Era"), value: label.locationPeriod)
                        LearnLabelInfoRow(title: L("联系邮箱", "Contact Email"), value: label.generalContactEmail)
                        LearnLabelInfoRow(title: L("Demo 提交", "Demo Submission"), value: label.demoSubmissionDisplay ?? label.demoSubmissionUrl)
                        if hasFoundedAtDisplay {
                            LearnLabelInfoRow(title: L("创始时间", "Founded At"), value: foundedAtDisplay)
                        }
                    }

                    linksSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(RaverTheme.background)
        .raverSystemNavigation(title: LL("厂牌详情"))
        .navigationDestination(item: $previewImage) { item in
            LearnLabelImagePreviewView(item: item)
        }
        .task(id: label.avatarUrl ?? "") {
            await resolveAvatarLuminance()
        }
    }

    @ViewBuilder
    private var headerBanner: some View {
        if let url = destinationURL(label.backgroundUrl) {
            fallbackBanner
                .overlay {
                    ImageLoaderView(urlString: url.absoluteString)
                        .background(Color.clear)
                }
                .overlay {
                    bannerEdgeGradient
                }
        } else {
            fallbackBanner
                .overlay {
                    bannerEdgeGradient
                }
        }
    }

    @ViewBuilder
    private var headerAvatar: some View {
        if let url = destinationURL(label.avatarUrl) {
            fallbackAvatar
                .overlay {
                    ImageLoaderView(urlString: url.absoluteString)
                        .background(Color.clear)
                }
        } else {
            fallbackAvatar
        }
    }

    private var fallbackBanner: some View {
        LinearGradient(
            colors: [Color(red: 0.17, green: 0.20, blue: 0.28), Color(red: 0.08, green: 0.09, blue: 0.14)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var fallbackAvatar: some View {
        ZStack {
            fallbackBanner
            Text(String(label.name.prefix(2)).uppercased())
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.85))
        }
    }

    private var displayGenres: [String] {
        if !label.genres.isEmpty {
            return label.genres
        }
        return label.genresPreview?
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []
    }

    private func destinationURL(_ raw: String?) -> URL? {
        guard let resolved = AppConfig.resolvedURLString(raw) else { return nil }
        return URL(string: resolved)
    }

    @ViewBuilder
    private var founderSection: some View {
        HStack(alignment: .center, spacing: 10) {
            if let founderDj = label.founderDj {
                Button {
                    appPush(.djDetail(djID: founderDj.id))
                } label: {
                    HStack(spacing: 10) {
                        LearnLabelFounderAvatar(urlString: founderDj.avatarUrl)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(LL("创始人"))
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                            Text(founderDisplayName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(RaverTheme.primaryText)
                                .lineLimit(1)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 10) {
                    LearnLabelFounderAvatar(urlString: nil)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(LL("创始人"))
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                        Text(founderDisplayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(RaverTheme.primaryText)
                            .lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var founderDisplayName: String {
        if let founderDj = label.founderDj {
            return founderDj.name
        }
        return (label.founderName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
    }

    private var foundedAtDisplay: String {
        label.foundedAt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var hasFounderDisplay: Bool {
        if label.founderDj != nil { return true }
        return !founderDisplayName.isEmpty
    }

    private var hasFoundedAtDisplay: Bool {
        !foundedAtDisplay.isEmpty
    }

    @ViewBuilder
    private var linksSection: some View {
        let hasLinks = destinationURL(label.facebookUrl) != nil
            || destinationURL(label.soundcloudUrl) != nil
            || destinationURL(label.musicPurchaseUrl) != nil
            || destinationURL(label.officialWebsiteUrl) != nil
            || destinationURL(label.demoSubmissionUrl) != nil
        if hasLinks {
            VStack(alignment: .leading, spacing: 10) {
                Text(L("Links", "Links"))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
                if let url = destinationURL(label.facebookUrl) {
                    LearnLabelExternalLinkRow(icon: "person.2.fill", title: "Facebook", url: url)
                }
                if let url = destinationURL(label.soundcloudUrl) {
                    LearnLabelExternalLinkRow(icon: "waveform", title: "SoundCloud", url: url)
                }
                if let url = destinationURL(label.musicPurchaseUrl) {
                    LearnLabelExternalLinkRow(icon: "cart.fill", title: L("音乐资产购买", "Music Asset Purchase"), url: url)
                }
                if let url = destinationURL(label.officialWebsiteUrl) {
                    LearnLabelExternalLinkRow(icon: "globe", title: L("官网", "Official"), url: url)
                }
                if let url = destinationURL(label.demoSubmissionUrl) {
                    LearnLabelExternalLinkRow(icon: "paperplane.fill", title: L("Demo 提交", "Demo Submission"), url: url)
                }
            }
        }
    }

    private var bannerEdgeGradient: some View {
        LinearGradient(
            stops: [
                .init(color: Color.black.opacity(0.76), location: 0),
                .init(color: Color.clear, location: 0.28),
                .init(color: Color.clear, location: 0.66),
                .init(color: Color.black.opacity(0.82), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func resolveAvatarLuminance() async {
        guard let avatarURL = destinationURL(label.avatarUrl) else {
            await MainActor.run {
                avatarLuminance = nil
            }
            return
        }
        let luminance = await LearnLabelAvatarStyling.luminance(for: avatarURL)
        await MainActor.run {
            avatarLuminance = luminance
        }
    }

    private func openPreview(urlString: String?, title: String) {
        guard let url = destinationURL(urlString) else { return }
        previewImage = LearnLabelPreviewImage(title: title, url: url)
    }
}

struct LearnFestival: Identifiable, Hashable {
    var id: String
    var name: String
    var aliases: [String]
    var country: String
    var city: String
    var foundedYear: String
    var frequency: String
    var tagline: String
    var introduction: String
    var genres: [String]
    var avatarUrl: String?
    var backgroundUrl: String?
    var links: [LearnFestivalLink]
    var contributors: [WebUserLite] = defaultContributors
    var canEdit: Bool? = nil

    static let defaultContributors: [WebUserLite] = [
        WebUserLite(
            id: "uploadtester",
            username: "uploadtester",
            displayName: "Upload Tester",
            avatarUrl: "https://api.dicebear.com/9.x/adventurer-neutral/png?seed=uploadtester&backgroundType=gradientLinear"
        )
    ]

    static let seedData: [LearnFestival] = [
        LearnFestival(
            id: "tomorrowland",
            name: "Tomorrowland",
            aliases: ["明日世界", "TL"],
            country: "比利时",
            city: "Boom",
            foundedYear: "2005",
            frequency: "每年 7 月",
            tagline: "全球最具辨识度的沉浸式 EDM 电音节之一。",
            introduction: "Tomorrowland 以大型主舞台叙事、超高制作和多舞台联动著称，覆盖 Mainstage、Techno、House、Trance 等多类电子音乐。",
            genres: ["EDM", "Progressive House", "Techno", "Trance"],
            avatarUrl: "https://logo.clearbit.com/tomorrowland.com",
            backgroundUrl: "https://images.unsplash.com/photo-1459749411175-04bf5292ceea?auto=format&fit=crop&w=1800&q=80",
            links: [
                LearnFestivalLink(title: "官网", icon: "globe", url: "https://www.tomorrowland.com"),
                LearnFestivalLink(title: "Instagram", icon: "camera", url: "https://www.instagram.com/tomorrowland/"),
                LearnFestivalLink(title: "Wikipedia", icon: "book", url: "https://en.wikipedia.org/wiki/Tomorrowland_(festival)")
            ]
        ),
        LearnFestival(
            id: "edc",
            name: "Electric Daisy Carnival",
            aliases: ["EDC", "EDC Las Vegas"],
            country: "美国",
            city: "Las Vegas",
            foundedYear: "1997",
            frequency: "每年 5 月（拉斯维加斯站）",
            tagline: "Insomniac 旗下头部 IP，视觉与舞美强调霓虹和嘉年华体验。",
            introduction: "EDC 在北美和全球拥有多站点，核心站点为 EDC Las Vegas，包含大量舞台和夜间演出，强调社区文化与沉浸体验。",
            genres: ["EDM", "Bass", "House", "Hardstyle"],
            avatarUrl: "https://logo.clearbit.com/electricdaisycarnival.com",
            backgroundUrl: "https://images.unsplash.com/photo-1470229722913-7c0e2dbbafd3?auto=format&fit=crop&w=1800&q=80",
            links: [
                LearnFestivalLink(title: "官网", icon: "globe", url: "https://lasvegas.electricdaisycarnival.com/"),
                LearnFestivalLink(title: "Instagram", icon: "camera", url: "https://www.instagram.com/edc_lasvegas/"),
                LearnFestivalLink(title: "Wikipedia", icon: "book", url: "https://en.wikipedia.org/wiki/Electric_Daisy_Carnival")
            ]
        ),
        LearnFestival(
            id: "ultra",
            name: "Ultra Music Festival",
            aliases: ["Ultra", "UMF"],
            country: "美国",
            city: "Miami",
            foundedYear: "1999",
            frequency: "每年 3 月",
            tagline: "Miami 春季大秀，Mainstage 与 Resistance 双核心舞台体系。",
            introduction: "Ultra Music Festival 是全球电子音乐节标杆之一，Ultra Worldwide 在多个国家巡回举办，Miami 主站影响力最大。",
            genres: ["EDM", "House", "Techno", "Trance"],
            avatarUrl: "https://logo.clearbit.com/ultramusicfestival.com",
            backgroundUrl: "https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&w=1800&q=80",
            links: [
                LearnFestivalLink(title: "官网", icon: "globe", url: "https://ultramusicfestival.com"),
                LearnFestivalLink(title: "Instagram", icon: "camera", url: "https://www.instagram.com/ultra/"),
                LearnFestivalLink(title: "Wikipedia", icon: "book", url: "https://en.wikipedia.org/wiki/Ultra_Music_Festival")
            ]
        ),
        LearnFestival(
            id: "soundstorm",
            name: "MDLBEAST Soundstorm",
            aliases: ["Soundstorm", "利雅得 Soundstorm"],
            country: "沙特阿拉伯",
            city: "Riyadh",
            foundedYear: "2019",
            frequency: "每年冬季",
            tagline: "中东地区高规格大型电子音乐节 IP。",
            introduction: "Soundstorm 由 MDLBEAST 打造，舞台规模和阵容体量增长迅速，已成为中东地区讨论度极高的电子音乐节。",
            genres: ["EDM", "House", "Techno", "Hip-Hop Crossover"],
            avatarUrl: "https://logo.clearbit.com/mdlbeast.com",
            backgroundUrl: "https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&w=1800&q=80",
            links: [
                LearnFestivalLink(title: "官网", icon: "globe", url: "https://mdlbeast.com"),
                LearnFestivalLink(title: "Instagram", icon: "camera", url: "https://www.instagram.com/soundstorm/"),
                LearnFestivalLink(title: "Wikipedia", icon: "book", url: "https://en.wikipedia.org/wiki/MDLBEAST")
            ]
        ),
        LearnFestival(
            id: "creamfields",
            name: "Creamfields",
            aliases: ["奶油田"],
            country: "英国",
            city: "Daresbury（主站）",
            foundedYear: "1998",
            frequency: "每年夏季",
            tagline: "英国历史悠久的大型电子音乐节品牌。",
            introduction: "Creamfields 以 UK 大型户外电子音乐节体验著称，除英国主站外也发展出国际系列站点。",
            genres: ["EDM", "Tech House", "Techno", "Drum & Bass"],
            avatarUrl: "https://logo.clearbit.com/creamfields.com",
            backgroundUrl: "https://images.unsplash.com/photo-1571266028243-d220c9c3b5f2?auto=format&fit=crop&w=1800&q=80",
            links: [
                LearnFestivalLink(title: "官网", icon: "globe", url: "https://www.creamfields.com"),
                LearnFestivalLink(title: "Instagram", icon: "camera", url: "https://www.instagram.com/creamfieldsofficial/"),
                LearnFestivalLink(title: "Wikipedia", icon: "book", url: "https://en.wikipedia.org/wiki/Creamfields")
            ]
        ),
        LearnFestival(
            id: "vac-music-festival",
            name: "VAC Music Festival",
            aliases: ["VAC", "VAC 电音节"],
            country: "中国",
            city: "多城市巡回",
            foundedYear: "近年兴起",
            frequency: "年度 / 季度站点",
            tagline: "中国本土电子音乐节 IP，强调国际阵容与本土场景融合。",
            introduction: "VAC Music Festival 聚焦国际电子音乐艺人与本土社群联动，通常包含多舞台与 Day 分场配置。",
            genres: ["EDM", "Bass", "Techno", "Future Rave"],
            avatarUrl: "https://logo.clearbit.com/vacmusicfestival.com",
            backgroundUrl: "https://images.unsplash.com/photo-1506157786151-b8491531f063?auto=format&fit=crop&w=1800&q=80",
            links: [
                LearnFestivalLink(title: "官网", icon: "globe", url: "https://www.vacmusicfestival.com")
            ]
        ),
        LearnFestival(
            id: "storm-festival",
            name: "STORM Festival",
            aliases: ["Storm 风暴电音节", "风暴电音节"],
            country: "中国",
            city: "上海 / 多城市",
            foundedYear: "2010 年代",
            frequency: "年度站点",
            tagline: "中国大型电子音乐节品牌之一，覆盖多风格舞台。",
            introduction: "STORM Festival 在国内电子音乐场景中有较高认知度，阵容涵盖主流 EDM 与细分舞曲风格。",
            genres: ["EDM", "House", "Bass", "Trance"],
            avatarUrl: "https://logo.clearbit.com/stormfestival.cn",
            backgroundUrl: "https://images.unsplash.com/photo-1487180144351-b8472da7d491?auto=format&fit=crop&w=1800&q=80",
            links: [
                LearnFestivalLink(title: "官网", icon: "globe", url: "https://stormfestival.cn")
            ]
        ),
        LearnFestival(
            id: "tmc-festival",
            name: "TMC Festival",
            aliases: ["TMC 电音节"],
            country: "中国",
            city: "多城市",
            foundedYear: "近年兴起",
            frequency: "年度站点",
            tagline: "面向年轻受众的本土电音节 IP。",
            introduction: "TMC Festival 以流行电子乐与现场体验为核心，常见多日程排布与跨风格艺人阵容。",
            genres: ["EDM", "Future Bass", "House"],
            avatarUrl: "https://logo.clearbit.com/tmcfestival.com",
            backgroundUrl: "https://images.unsplash.com/photo-1429962714451-bb934ecdc4ec?auto=format&fit=crop&w=1800&q=80",
            links: [
                LearnFestivalLink(title: "官网", icon: "globe", url: "https://tmcfestival.com")
            ]
        )
    ]
}

struct LearnFestivalLink: Hashable {
    let title: String
    let icon: String
    let url: String
}

extension LearnFestival {
    init(web: WebLearnFestival) {
        self.id = web.id
        self.name = web.name
        self.aliases = web.aliases
        self.country = web.country
        self.city = web.city
        self.foundedYear = web.foundedYear
        self.frequency = web.frequency
        self.tagline = web.tagline
        self.introduction = web.introduction
        self.genres = []
        self.avatarUrl = web.avatarUrl
        self.backgroundUrl = web.backgroundUrl
        self.links = web.links.map { LearnFestivalLink(title: $0.title, icon: $0.icon, url: $0.url) }
        self.contributors = web.contributors.isEmpty ? LearnFestival.defaultContributors : web.contributors
        self.canEdit = web.canEdit
    }
}

private struct LearnFestivalRankingBoard: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let year: Int
    let rankedFestivalIDs: [String]

    static let djMagTop100Festival2025 = LearnFestivalRankingBoard(
        id: "djmag-top100-festival-2025",
        title: "DJ MAG TOP 100 Festival 2025",
        subtitle: L("全球电子音乐节年度热度榜", "Global annual popularity ranking of electronic music festivals"),
        year: 2025,
        rankedFestivalIDs: [
            "tomorrowland",
            "edc",
            "ultra",
            "creamfields",
            "soundstorm",
            "vac-music-festival",
            "storm-festival",
            "tmc-festival"
        ]
    )
}

private struct LearnFestivalRankedFestival: Identifiable, Hashable {
    var id: String { "\(rank)-\(festival.id)" }
    let rank: Int
    var festival: LearnFestival
}

private struct LearnFestivalRankingBoardCard: View {
    let board: LearnFestivalRankingBoard
    let rankedCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(LL("榜单"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.84))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.16), in: Capsule())
                Spacer(minLength: 0)
                Text(verbatim: String(board.year))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.86))
            }

            Text(board.title)
                .font(.subheadline.weight(.black))
                .foregroundStyle(Color.white)
                .lineLimit(2)

            Text(board.subtitle)
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.84))
                .lineLimit(2)

            Spacer(minLength: 0)

            Text(L("已收录 \(rankedCount) 个电音节", "\(rankedCount) festivals included"))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.82))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(width: 236, height: 144, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.15, green: 0.18, blue: 0.27),
                    Color(red: 0.09, green: 0.11, blue: 0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}

private struct LearnFestivalRankingDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.discoverPush) private var discoverPush
    @Environment(\.appPush) private var appPush

    let board: LearnFestivalRankingBoard
    let onFestivalUpdated: (LearnFestival) -> Void

    @State private var displayedRankedFestivals: [LearnFestivalRankedFestival]
    @State private var selectedFestivalForDetail: LearnFestival?

    init(
        board: LearnFestivalRankingBoard,
        rankedFestivals: [LearnFestivalRankedFestival],
        onFestivalUpdated: @escaping (LearnFestival) -> Void
    ) {
        self.board = board
        self.onFestivalUpdated = onFestivalUpdated
        _displayedRankedFestivals = State(initialValue: rankedFestivals)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(displayedRankedFestivals) { item in
                    Button {
                        selectedFestivalForDetail = item.festival
                    } label: {
                        LearnFestivalCard(festival: item.festival)
                            .overlay(alignment: .topTrailing) {
                                Text("\(item.rank)")
                                    .font(.system(size: 22, weight: .black, design: .rounded))
                                    .foregroundStyle(Color.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                                    .frame(width: 46, height: 46)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(Color(red: 0.16, green: 0.16, blue: 0.18).opacity(0.72))
                                    )
                                    .padding(.top, 8)
                                    .padding(.trailing, 8)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 14)
        }
        .background(RaverTheme.background)
        .raverGradientNavigationChrome(title: board.title) {
            dismiss()
        }
        .navigationDestination(item: $selectedFestivalForDetail) { festival in
            DiscoverCoordinatorView(push: discoverPush) {
                LearnFestivalDetailView(festival: festival) { updated in
                    onFestivalUpdated(updated)
                    if let index = displayedRankedFestivals.firstIndex(where: { $0.festival.id == updated.id }) {
                        displayedRankedFestivals[index].festival = updated
                    }
                }
            }
        }
    }

}

struct LearnFestivalCard: View {
    let festival: LearnFestival
    @State private var avatarLuminance: CGFloat?

    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
            Color.clear
                .frame(height: 132)
        }
        .frame(maxWidth: .infinity)
        .overlay {
            bannerView
                .overlay {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0.00),
                                    .init(color: Color.black.opacity(0.45), location: 0.22),
                                    .init(color: Color.black.opacity(0.65), location: 0.62),
                                    .init(color: Color.black.opacity(0.82), location: 1.00)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 118, alignment: .bottom)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .allowsHitTesting(false)
                }
                .overlay(alignment: .bottomLeading) {
                    HStack(alignment: .center, spacing: 12) {
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                            .frame(width: 62)
                            .overlay {
                                avatarView
                                    .allowsHitTesting(false)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(LearnLabelAvatarStyling.borderColor(for: avatarLuminance), lineWidth: 1)
                            )

                        VStack(alignment: .leading, spacing: 6) {
                            Text(festival.name)
                                .font(.headline.weight(.black))
                                .foregroundStyle(Color.white)
                                .lineLimit(2)

                            Text(infoLine)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.white.opacity(0.86))
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 20)
                }
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(RaverTheme.cardBorder, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .task(id: festival.avatarUrl ?? "") {
            await resolveAvatarLuminance()
        }
    }

    @ViewBuilder
    private var bannerView: some View {
        if let url = destinationURL(festival.backgroundUrl) {
            fallbackBanner
                .overlay {
                    ImageLoaderView(urlString: url.absoluteString)
                        .background(Color.clear)
                }
        } else {
            fallbackBanner
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        if let url = destinationURL(festival.avatarUrl) {
            fallbackAvatar
                .overlay {
                    ImageLoaderView(urlString: url.absoluteString)
                        .background(Color.clear)
                }
        } else {
            fallbackAvatar
        }
    }

    private var fallbackBanner: some View {
        LinearGradient(
            colors: [Color(red: 0.17, green: 0.20, blue: 0.28), Color(red: 0.08, green: 0.09, blue: 0.14)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var fallbackAvatar: some View {
        ZStack {
            fallbackBanner
            Text(String(festival.name.prefix(2)).uppercased())
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.85))
        }
    }

    private var infoLine: String {
        let country = festival.country.trimmingCharacters(in: .whitespacesAndNewlines)
        let city = festival.city.trimmingCharacters(in: .whitespacesAndNewlines)
        let founded = festival.foundedYear.trimmingCharacters(in: .whitespacesAndNewlines)
        let freq = festival.frequency.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = [country, city, founded, freq].filter { !$0.isEmpty }
        return parts.isEmpty ? L("电子音乐节品牌", "Festival Brand") : parts.joined(separator: " · ")
    }

    private func destinationURL(_ raw: String?) -> URL? {
        guard let resolved = AppConfig.resolvedURLString(raw) else { return nil }
        return URL(string: resolved)
    }

    private func resolveAvatarLuminance() async {
        guard let avatarURL = destinationURL(festival.avatarUrl) else {
            await MainActor.run {
                avatarLuminance = nil
            }
            return
        }
        let luminance = await LearnLabelAvatarStyling.luminance(for: avatarURL)
        await MainActor.run {
            avatarLuminance = luminance
        }
    }
}

struct LearnFestivalDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.discoverPush) private var discoverPush
    @Environment(\.appPush) private var appPush
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var appContainer: AppContainer
    let onFestivalUpdated: ((LearnFestival) -> Void)?

    private var wikiRepository: DiscoverWikiRepository {
        appContainer.discoverWikiRepository
    }

    private var eventsRepository: DiscoverEventsRepository {
        appContainer.discoverEventsRepository
    }

    private var newsRepository: DiscoverNewsRepository {
        appContainer.discoverNewsRepository
    }

    @State private var currentFestival: LearnFestival

    @State private var previewImage: LearnLabelPreviewImage?
    @State private var avatarLuminance: CGFloat?
    @State private var selectedTab: LearnFestivalDetailTab = .basic
    @State private var pageProgress: CGFloat = 0
    @State private var isTabSwitchingByTap = false
    @State private var tabSwitchUnlockWorkItem: DispatchWorkItem?
    @State private var relatedEvents: [WebEvent] = []
    @State private var relatedArticles: [DiscoverNewsArticle] = []
    @State private var isLoadingRelatedContent = false
    @State private var errorMessage: String?
    @State private var showCreateEventSheet = false
    @State private var showFestivalEditSheet = false
    @State private var isSavingFestival = false
    @State private var editName = ""
    @State private var editAliases = ""
    @State private var editCountry = ""
    @State private var editCity = ""
    @State private var editFoundedYear = ""
    @State private var editFrequency = ""
    @State private var editTagline = ""
    @State private var editIntroduction = ""
    @State private var editWebsite = ""
    @State private var editAvatarItem: PhotosPickerItem?
    @State private var editBackgroundItem: PhotosPickerItem?
    @State private var editAvatarData: Data?
    @State private var editBackgroundData: Data?

    init(festival: LearnFestival, onFestivalUpdated: ((LearnFestival) -> Void)? = nil) {
        self.onFestivalUpdated = onFestivalUpdated
        _currentFestival = State(initialValue: festival)
    }

    fileprivate enum LearnFestivalDetailTab: String, CaseIterable, Identifiable {
        case basic
        case events
        case posts

        var id: String { rawValue }

        var title: String {
            switch self {
            case .basic: return L("信息", "Info")
            case .events: return L("活动", "Events")
            case .posts: return L("动态", "Posts")
            }
        }

        var themeColor: Color {
            switch self {
            case .basic: return Color(red: 0.27, green: 0.85, blue: 0.82)
            case .events: return Color(red: 0.98, green: 0.71, blue: 0.22)
            case .posts: return Color(red: 0.95, green: 0.30, blue: 0.38)
            }
        }
    }

    var body: some View {
        RaverImmersiveDetailPagerChrome(
            title: currentFestival.name,
            tabs: LearnFestivalDetailTab.allCases,
            selectedTab: selectedTab,
            pageProgress: $pageProgress,
            namespace: "festival-detail",
            configuration: detailChromeConfiguration
        ) {
            heroSection
        } tabBar: {
            tabBar
        } content: { chrome in
            tabPager(chrome: chrome)
        }
        .raverImmersiveFloatingNavigationChrome(
            trailing: immersiveTrailingAction
        ) {
            dismiss()
        }
        .navigationDestination(item: $previewImage) { item in
            LearnLabelImagePreviewView(item: item)
        }
        .task(id: currentFestival.id) {
            prepareFestivalEditDraft()
            await loadRelatedContent()
            await hydrateFestivalContributorsIfNeeded()
        }
        .task(id: currentFestival.avatarUrl ?? "") {
            await resolveAvatarLuminance()
        }
        .onReceive(NotificationCenter.default.publisher(for: .discoverEventDidSave)) { _ in
            Task { await loadRelatedContent() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .discoverFestivalDidSave)) { notification in
            let savedFestivalID = notification.object as? String
            guard savedFestivalID == nil || savedFestivalID == currentFestival.id else { return }
            Task { await refreshCurrentFestivalAfterSave() }
        }
        .onChange(of: editAvatarItem) { _, item in
            Task { await loadFestivalEditPhoto(item, target: .avatar) }
        }
        .onChange(of: editBackgroundItem) { _, item in
            Task { await loadFestivalEditPhoto(item, target: .background) }
        }
        .alert(L("提示", "Notice"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(L("确定", "OK"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var immersiveTrailingAction: AnyView? {
        return AnyView(
            Menu {
                if canEditFestival {
                    Button {
                        prepareFestivalEditDraft()
                        discoverPush(.learnFestivalEdit(festivalID: currentFestival.id))
                    } label: {
                        Label(L("编辑", "Edit"), systemImage: "square.and.pencil")
                    }
                }

                Button {
                    openFestivalCacheEntry()
                } label: {
                    Label(L("缓存", "Cache"), systemImage: "arrow.down.circle")
                }

                Button {
                    openFestivalFeedbackEntry()
                } label: {
                    Label(L("贡献信息", "Incorrect Info"), systemImage: "info.circle")
                }

                Button {
                    openFestivalReportEntry()
                } label: {
                    Label(L("举报", "Report"), systemImage: "flag")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .menuStyle(.automatic)
        )
    }

    private func openFestivalCacheEntry() {
        // TODO: Add festival-level cache workflow if needed.
        errorMessage = L("该页面缓存能力正在建设中。", "Caching for this page is under construction.")
    }

    private func openFestivalFeedbackEntry() {
        // TODO: Wire to dedicated feedback route/page when available.
        errorMessage = L("贡献信息入口即将开放，当前已记录该需求。", "Incorrect info entry is coming soon. We have recorded this request.")
    }

    private func openFestivalReportEntry() {
        // TODO: Wire to dedicated report route/page when available.
        errorMessage = L("举报入口即将开放，当前已记录该需求。", "Report entry is coming soon. We have recorded this request.")
    }

    @ViewBuilder
    private var tabBar: some View {
        RaverScrollableTabBar(
            items: festivalDetailTabItems,
            selection: $selectedTab,
            progress: pageProgress,
            onSelect: { tab in
                withAnimation(.snappy(duration: 0.28, extraBounce: 0.06)) {
                    selectedTab = tab
                }
            },
            tabSpacing: 24,
            tabHorizontalPadding: 16,
            dividerColor: .gray.opacity(0.26),
            indicatorColorProvider: { $0.themeColor },
            activeTextColor: RaverTheme.primaryText,
            inactiveTextColor: RaverTheme.secondaryText,
            showsDivider: false,
            indicatorHeight: 2.6,
            tabFont: .system(size: 17, weight: .regular)
        )
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(RaverTheme.background)
    }

    private var festivalDetailTabItems: [RaverScrollableTabItem<LearnFestivalDetailTab>] {
        LearnFestivalDetailTab.allCases.map { tab in
            RaverScrollableTabItem(id: tab, title: tab.title)
        }
    }

    @ViewBuilder
    private func tabPager(
        chrome: RaverImmersiveDetailPagerContext<LearnFestivalDetailTab>
    ) -> some View {
        RaverScrollableTabPager(
            items: festivalDetailTabItems,
            selection: $selectedTab,
            tabSpacing: 24,
            tabHorizontalPadding: 16,
            dividerColor: .gray.opacity(0.26),
            indicatorColorProvider: { $0.themeColor },
            showsTabBar: false,
            showsDivider: false,
            indicatorHeight: 2.6,
            tabFont: .system(size: 17, weight: .regular),
            progress: $pageProgress
        ) { tab in
            ScrollView {
                VStack(spacing: 0) {
                    RaverImmersiveDetailOffsetMarker(
                        tabID: tab,
                        coordinateSpaceName: chrome.coordinateSpaceName(tab)
                    )
                    Color.clear
                        .frame(height: chrome.detailTopInset)

                    VStack(alignment: .leading, spacing: 14) {
                        tabContent(tab)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                }
            }
            .coordinateSpace(name: chrome.coordinateSpaceName(tab))
            .scrollBounceBehavior(.always)
            .contentShape(Rectangle())
            .background(RaverTheme.background)
        }
    }

    private var detailChromeConfiguration: RaverImmersiveDetailPagerConfiguration {
        RaverImmersiveDetailPagerConfiguration(
            heroHeight: 360,
            tabBarOverlayHeight: 52,
            pinnedTopBarHeight: 44,
            titleRevealLead: 8,
            titleRevealDistance: 20,
            backgroundColor: RaverTheme.background
        )
    }

    @ViewBuilder
    private var heroSection: some View {
        ZStack(alignment: .top) {
            GeometryReader { geo in
                if let url = destinationURL(currentFestival.backgroundUrl) {
                    ImageLoaderView(urlString: url.absoluteString)
                        .background(fallbackBanner)
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                    .clipped()
                } else {
                    fallbackBanner
                        .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                }
            }

            LinearGradient(
                colors: [
                    Color.black.opacity(0.12),
                    Color.black.opacity(0.26),
                    RaverTheme.background.opacity(0.84),
                    RaverTheme.background
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack {
                Spacer(minLength: 0)
                HStack(alignment: .center, spacing: 12) {
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                        .frame(width: 88)
                        .overlay { headerAvatar }
                        .clipped()
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(LearnLabelAvatarStyling.borderColor(for: avatarLuminance), lineWidth: 1)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(currentFestival.name)
                            .font(.headline.weight(.black))
                            .foregroundStyle(Color.black.opacity(0.88))
                            .lineLimit(2)

                        if !currentFestival.aliases.isEmpty {
                            Text(currentFestival.aliases.joined(separator: " / "))
                                .font(.caption)
                                .foregroundStyle(Color.black.opacity(0.78))
                                .lineLimit(2)
                        }

                    Text(L("\(currentFestival.country) \(currentFestival.city) · Since \(currentFestival.foundedYear)", "\(currentFestival.country) \(currentFestival.city) · Since \(currentFestival.foundedYear)"))
                            .font(.caption)
                            .foregroundStyle(Color.black.opacity(0.76))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
        }
        .frame(height: 360)
        .clipped()
        .zIndex(1)
    }

    @ViewBuilder
    private func tabContent(_ tab: LearnFestivalDetailTab) -> some View {
        switch tab {
        case .basic:
            basicInfoTabContent
        case .events:
            eventsTabContent
        case .posts:
            postsTabContent
        }
    }

    @ViewBuilder
    private var basicInfoTabContent: some View {
        LearnLabelExpandableText(text: currentFestival.introduction, collapsedLineLimit: 6)

        VStack(alignment: .leading, spacing: 10) {
            LearnLabelInfoRow(title: L("国家", "Country"), value: currentFestival.country)
            LearnLabelInfoRow(title: L("城市", "City"), value: currentFestival.city)
            LearnLabelInfoRow(title: L("首办时间", "Founded Year"), value: currentFestival.foundedYear)
            LearnLabelInfoRow(title: L("举办频次", "Frequency"), value: currentFestival.frequency)
            LearnLabelInfoRow(title: L("定位", "Tagline"), value: currentFestival.tagline)
        }

        linksSection
        contributorSection
    }

    @ViewBuilder
    private var eventsTabContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                discoverPush(.eventCreate)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text(LL("发布新活动"))
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(RaverTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)

            if isLoadingRelatedContent && relatedEvents.isEmpty {
                ProgressView(LL("正在加载关联活动..."))
                    .padding(.vertical, 8)
            } else if upcomingRelatedEvents.isEmpty && endedRelatedEvents.isEmpty {
                Text(LL("暂无关联活动"))
                    .foregroundStyle(RaverTheme.secondaryText)
                    .padding(.vertical, 8)
            } else {
                if !upcomingRelatedEvents.isEmpty {
                    festivalEventsSectionHeader(L("即将开始", "Upcoming"))
                    ForEach(upcomingRelatedEvents) { event in
                        Button {
                            appPush(.eventDetail(eventID: event.id))
                        } label: {
                            festivalEventRow(event)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !endedRelatedEvents.isEmpty {
                    festivalEventsSectionHeader(L("已结束活动", "Ended"))
                    ForEach(endedRelatedEvents) { event in
                        Button {
                            appPush(.eventDetail(eventID: event.id))
                        } label: {
                            festivalEventRow(event)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var upcomingRelatedEvents: [WebEvent] {
        relatedEvents
            .filter {
                let status = EventVisualStatus.resolve(event: $0)
                return status != .ended && status != .cancelled
            }
            .sorted(by: { $0.startDate < $1.startDate })
    }

    private var endedRelatedEvents: [WebEvent] {
        relatedEvents
            .filter {
                let status = EventVisualStatus.resolve(event: $0)
                return status == .ended || status == .cancelled
            }
            .sorted(by: { $0.startDate > $1.startDate })
    }

    private func festivalEventsSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(RaverTheme.primaryText)
            .padding(.top, 6)
            .padding(.bottom, 2)
    }

    @ViewBuilder
    private var postsTabContent: some View {
        if isLoadingRelatedContent && relatedArticles.isEmpty {
            ProgressView(LL("正在加载品牌动态..."))
                .padding(.vertical, 8)
        } else if relatedArticles.isEmpty {
            Text(LL("暂无相关动态"))
                .foregroundStyle(RaverTheme.secondaryText)
                .padding(.vertical, 8)
        } else {
            ForEach(Array(relatedArticles.enumerated()), id: \.element.id) { index, article in
                Button {
                    discoverPush(.newsDetail(articleID: article.id))
                } label: {
                    DiscoverNewsRow(article: article, showsSummary: false)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())

                if index < relatedArticles.count - 1 {
                    Divider()
                        .padding(.leading, 16)
                }
            }
        }
    }

    private func festivalEventRow(_ event: WebEvent) -> some View {
        let locationText = event.unifiedAddress.trimmingCharacters(in: .whitespacesAndNewlines)

        return HStack(alignment: .top, spacing: 10) {
            festivalEventCoverImage(event)
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(event.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(2)

                Text(festivalEventDateText(event))
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .lineLimit(1)

                Text(locationText.isEmpty ? L("地点待补充", "Location pending") : locationText)
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.45)
        }
    }

    @ViewBuilder
    private func festivalEventCoverImage(_ event: WebEvent) -> some View {
        if let cover = AppConfig.resolvedURLString(event.cardImageURL) {
            ImageLoaderView(urlString: cover)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(RaverTheme.card)
                )
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [RaverTheme.accent.opacity(0.35), RaverTheme.card],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Image(systemName: "ticket.fill")
                        .font(.title3)
                        .foregroundStyle(RaverTheme.secondaryText)
                )
        }
    }

    private func festivalEventDateText(_ event: WebEvent) -> String {
        if AppLanguagePreference.current.effectiveLanguage == .zh {
            return event.startDate.appLocalizedDateRangeText(to: event.endDate)
        }
        let range = DateInterval(start: event.startDate, end: event.endDate)
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: range) ?? event.startDate.appLocalizedYMDText()
    }

    @ViewBuilder
    private var headerAvatar: some View {
        if let url = destinationURL(currentFestival.avatarUrl) {
            fallbackAvatar
                .overlay {
                    ImageLoaderView(urlString: url.absoluteString)
                        .background(Color.clear)
                }
        } else {
            fallbackAvatar
        }
    }

    @ViewBuilder
    private var linksSection: some View {
        let validLinks = currentFestival.links.compactMap { link -> (String, String, URL)? in
            guard let url = destinationURL(link.url) else { return nil }
            return (link.icon, link.title, url)
        }
        if !validLinks.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(L("Links", "Links"))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
                ForEach(validLinks, id: \.2.absoluteString) { item in
                    LearnLabelExternalLinkRow(icon: item.0, title: item.1, url: item.2)
                }
            }
        }
    }

    @ViewBuilder
    private var contributorSection: some View {
        let users = currentFestival.contributors.filter { !$0.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if !users.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(LL("贡献者"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(users) { user in
                        Button {
                            Task { await openContributorProfile(user) }
                        } label: {
                            HStack(spacing: 10) {
                                contributorUserAvatar(user, size: 30)
                                Text(contributorDisplayName(user))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(RaverTheme.primaryText)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func contributorUserAvatar(_ user: WebUserLite, size: CGFloat) -> some View {
        if let avatar = AppConfig.resolvedURLString(user.avatarUrl) {
            ImageLoaderView(urlString: avatar)
                .background(Circle().fill(RaverTheme.card))
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            Circle()
                .fill(RaverTheme.card)
                .frame(width: size, height: size)
                .overlay(
                    Text(initials(of: contributorDisplayName(user)))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(RaverTheme.secondaryText)
                )
        }
    }

    private func contributorDisplayName(_ user: WebUserLite) -> String {
        let trimmed = user.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? L("未设置昵称", "No nickname set") : trimmed
    }

    @MainActor
    private func openContributorProfile(_ contributor: WebUserLite) async {
        if let resolved = await resolveFestivalContributorUser(contributor) {
            if let index = currentFestival.contributors.firstIndex(where: {
                $0.id == contributor.id && $0.username.caseInsensitiveCompare(contributor.username) == .orderedSame
            }) {
                currentFestival.contributors[index] = resolved
                onFestivalUpdated?(currentFestival)
            }
            appPush(.userProfile(userID: resolved.id))
            return
        }
        errorMessage = L("未找到对应用户主页", "Matched user profile not found.")
    }

    @MainActor
    private func hydrateFestivalContributorsIfNeeded() async {
        guard !currentFestival.contributors.isEmpty else { return }

        var updated = currentFestival
        var didChange = false

        for index in updated.contributors.indices {
            let contributor = updated.contributors[index]
            guard shouldResolveFestivalContributor(contributor) else { continue }
            guard let resolved = await resolveFestivalContributorUser(contributor) else { continue }
            if resolved != contributor {
                updated.contributors[index] = resolved
                didChange = true
            }
        }

        guard didChange else { return }
        currentFestival = updated
        onFestivalUpdated?(updated)
    }

    private func shouldResolveFestivalContributor(_ contributor: WebUserLite) -> Bool {
        let trimmedID = contributor.id.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDisplayName = contributor.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmedDisplayName.isEmpty {
            return true
        }
        if trimmedID.isEmpty {
            return true
        }
        if trimmedID.caseInsensitiveCompare(contributor.username) == .orderedSame {
            return true
        }
        return !looksLikeUUID(trimmedID)
    }

    private func looksLikeUUID(_ value: String) -> Bool {
        UUID(uuidString: value) != nil
    }

    private func resolveFestivalContributorUser(_ contributor: WebUserLite) async -> WebUserLite? {
        let contributorID = contributor.id.trimmingCharacters(in: .whitespacesAndNewlines)
        if !contributorID.isEmpty, let profile = try? await newsRepository.fetchUserProfile(userID: contributorID) {
            return WebUserLite(
                id: profile.id,
                username: profile.username,
                displayName: profile.displayName,
                avatarUrl: profile.avatarURL ?? contributor.avatarUrl
            )
        }

        let queryCandidates = [
            contributor.username.trimmingCharacters(in: .whitespacesAndNewlines),
            contributor.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        ]
            .filter { !$0.isEmpty }

        for query in queryCandidates {
            guard let matched = await searchFestivalContributorMatch(
                query: query,
                expectedUsername: contributor.username,
                expectedDisplayName: contributor.displayName
            ) else { continue }
            return WebUserLite(
                id: matched.id,
                username: matched.username,
                displayName: matched.displayName,
                avatarUrl: matched.avatarURL ?? contributor.avatarUrl
            )
        }
        return nil
    }

    private func searchFestivalContributorMatch(
        query: String,
        expectedUsername: String,
        expectedDisplayName: String?
    ) async -> UserSummary? {
        guard let users = try? await newsRepository.searchUsers(query: query), !users.isEmpty else {
            return nil
        }

        let normalizedUsername = expectedUsername.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !normalizedUsername.isEmpty,
           let exactUsername = users.first(where: { $0.username.lowercased() == normalizedUsername }) {
            return exactUsername
        }

        let normalizedDisplayName = expectedDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        if !normalizedDisplayName.isEmpty,
           let exactDisplayName = users.first(where: { $0.displayName.lowercased() == normalizedDisplayName }) {
            return exactDisplayName
        }

        if users.count == 1 {
            return users[0]
        }
        return nil
    }

    private var canEditFestival: Bool {
        if let canEdit = currentFestival.canEdit {
            return canEdit
        }
        guard let currentUser = currentSessionContributor else { return false }
        return currentFestival.contributors.contains { contributor in
            contributor.id == currentUser.id
                || contributor.username.caseInsensitiveCompare(currentUser.username) == .orderedSame
        }
    }

    private var currentSessionContributor: WebUserLite? {
        guard let user = appState.session?.user else { return nil }
        return WebUserLite(
            id: user.id,
            username: user.username,
            displayName: user.displayName,
            avatarUrl: user.avatarURL
        )
    }

    private var festivalEditSheet: some View {
        NavigationStack {
            Form {
                Section(LL("基础信息")) {
                    TextField(LL("电音节名称"), text: $editName)
                    TextField(LL("别名（英文逗号分隔）"), text: $editAliases)
                    TextField(LL("国家"), text: $editCountry)
                    TextField(LL("城市"), text: $editCity)
                    TextField(LL("首办时间"), text: $editFoundedYear)
                    TextField(LL("举办频次"), text: $editFrequency)
                    TextField(LL("定位"), text: $editTagline)
                    TextField(LL("简介"), text: $editIntroduction, axis: .vertical)
                    TextField(LL("官网链接"), text: $editWebsite)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                }

                Section(LL("媒体")) {
                    HStack(spacing: 12) {
                        PhotosPicker(selection: $editAvatarItem, matching: .images) {
                            Label(LL("更换头像"), systemImage: "person.crop.square")
                        }
                        .buttonStyle(.bordered)

                        if let editAvatarData, let image = UIImage(data: editAvatarData) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        } else if let current = currentFestival.avatarUrl,
                                  let resolved = AppConfig.resolvedURLString(current) {
                            ImageLoaderView(urlString: resolved)
                                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(RaverTheme.card))
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }

                    HStack(spacing: 12) {
                        PhotosPicker(selection: $editBackgroundItem, matching: .images) {
                            Label(LL("更换背景"), systemImage: "photo.rectangle")
                        }
                        .buttonStyle(.bordered)

                        if let editBackgroundData, let image = UIImage(data: editBackgroundData) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 88, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        } else if let current = currentFestival.backgroundUrl,
                                  let resolved = AppConfig.resolvedURLString(current) {
                            ImageLoaderView(urlString: resolved)
                                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(RaverTheme.card))
                            .frame(width: 88, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                }

                Section {
                    Button(isSavingFestival ? L("保存中...", "Saving...") : "保存电音节信息") {
                        Task { await saveFestivalEdits() }
                    }
                    .disabled(isSavingFestival || editName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .raverSystemNavigation(title: LL("编辑电音节"))
            .scrollDismissesKeyboard(.interactively)
        }
        .raverEnableCustomSwipeBack(edgeRatio: 0.2)
    }

    private enum FestivalEditPhotoTarget {
        case avatar
        case background
    }

    private func prepareFestivalEditDraft() {
        editName = currentFestival.name
        editAliases = currentFestival.aliases.joined(separator: ", ")
        editCountry = currentFestival.country
        editCity = currentFestival.city
        editFoundedYear = currentFestival.foundedYear
        editFrequency = currentFestival.frequency
        editTagline = currentFestival.tagline
        editIntroduction = currentFestival.introduction
        editWebsite = currentFestival.links.first(where: { $0.icon == "globe" })?.url ?? currentFestival.links.first?.url ?? ""
        editAvatarItem = nil
        editBackgroundItem = nil
        editAvatarData = nil
        editBackgroundData = nil
    }

    @MainActor
    private func loadFestivalEditPhoto(_ item: PhotosPickerItem?, target: FestivalEditPhotoTarget) async {
        guard let item else {
            switch target {
            case .avatar:
                editAvatarData = nil
            case .background:
                editBackgroundData = nil
            }
            return
        }

        do {
            let loaded = try await item.loadTransferable(type: Data.self)
            switch target {
            case .avatar:
                editAvatarData = loaded
            case .background:
                editBackgroundData = loaded
            }
        } catch {
            errorMessage = L("读取图片失败，请重试", "Failed to read image. Please try again.")
        }
    }

    @MainActor
    private func saveFestivalEdits() async {
        guard canEditFestival else {
            errorMessage = L("仅贡献者可编辑电音节信息", "Only contributors can edit festival info.")
            return
        }

        let finalName = editName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalName.isEmpty else {
            errorMessage = L("电音节名称不能为空", "Festival name cannot be empty.")
            return
        }

        isSavingFestival = true
        defer { isSavingFestival = false }

        do {
            var updated = currentFestival
            updated.name = finalName
            updated.aliases = parseAliasTokens(editAliases)
            updated.country = editCountry.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.city = editCity.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.foundedYear = editFoundedYear.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.frequency = editFrequency.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.tagline = editTagline.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.introduction = editIntroduction.trimmingCharacters(in: .whitespacesAndNewlines)

            if let editAvatarData {
                let uploadedAvatar = try await wikiRepository.uploadWikiBrandImage(
                    imageData: jpegDataForFestivalImport(from: editAvatarData),
                    fileName: "wiki-brand-avatar-\(UUID().uuidString).jpg",
                    mimeType: "image/jpeg",
                    brandID: updated.id,
                    usage: "avatar"
                )
                updated.avatarUrl = uploadedAvatar.url
            }

            if let editBackgroundData {
                let uploadedBackground = try await wikiRepository.uploadWikiBrandImage(
                    imageData: jpegDataForFestivalImport(from: editBackgroundData),
                    fileName: "wiki-brand-background-\(UUID().uuidString).jpg",
                    mimeType: "image/jpeg",
                    brandID: updated.id,
                    usage: "background"
                )
                updated.backgroundUrl = uploadedBackground.url
            }

            let website = normalizeURL(editWebsite)
            var preservedLinks = updated.links.filter { link in
                !(link.icon == "globe" && (link.title == L("官网", "Official") || link.title == "Official"))
            }
            if let website {
                preservedLinks.insert(
                    LearnFestivalLink(title: L("官网", "Official"), icon: "globe", url: website),
                    at: 0
                )
            }
            updated.links = preservedLinks

            let payload = UpdateLearnFestivalInput(
                name: updated.name,
                aliases: updated.aliases,
                country: updated.country,
                city: updated.city,
                foundedYear: updated.foundedYear,
                frequency: updated.frequency,
                tagline: updated.tagline,
                introduction: updated.introduction,
                avatarUrl: updated.avatarUrl,
                backgroundUrl: updated.backgroundUrl,
                links: updated.links.map { link in
                    LearnFestivalLinkPayload(title: link.title, icon: link.icon, url: link.url)
                }
            )

            let persisted = try await wikiRepository.updateLearnFestival(id: updated.id, input: payload)
            let hydrated = LearnFestival(web: persisted)
            currentFestival = hydrated
            onFestivalUpdated?(hydrated)
            showFestivalEditSheet = false
            await loadRelatedContent()
            errorMessage = L("电音节信息已更新", "Festival info updated.")
        } catch {
            errorMessage = L("保存失败：\(error.userFacingMessage ?? "")", "Save failed: \(error.userFacingMessage ?? "")")
        }
    }

    private func parseAliasTokens(_ raw: String) -> [String] {
        raw
            .split(whereSeparator: { $0 == "," || $0 == "，" || $0 == "/" || $0 == "、" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func jpegDataForFestivalImport(from data: Data) -> Data {
        guard let image = UIImage(data: data),
              let jpeg = image.jpegData(compressionQuality: 0.9) else {
            return data
        }
        return jpeg
    }

    private func normalizeURL(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let lower = trimmed.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
            return trimmed
        }
        return "https://\(trimmed)"
    }

    private var fallbackBanner: some View {
        LinearGradient(
            colors: [Color(red: 0.17, green: 0.20, blue: 0.28), Color(red: 0.08, green: 0.09, blue: 0.14)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var fallbackAvatar: some View {
        ZStack {
            fallbackBanner
            Text(String(currentFestival.name.prefix(2)).uppercased())
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.85))
        }
    }

    private func selectFestivalDetailTab(_ tab: LearnFestivalDetailTab) {
        let targetProgress = CGFloat(selectedIndex(for: tab))
        if selectedTab == tab, abs(pageProgress - targetProgress) < 0.001 {
            return
        }

        isTabSwitchingByTap = true
        tabSwitchUnlockWorkItem?.cancel()

        withAnimation(.interactiveSpring(response: 0.26, dampingFraction: 0.84)) {
            selectedTab = tab
            pageProgress = targetProgress
        }

        let unlockWorkItem = DispatchWorkItem {
            isTabSwitchingByTap = false
            tabSwitchUnlockWorkItem = nil
        }
        tabSwitchUnlockWorkItem = unlockWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: unlockWorkItem)
    }

    private func selectedIndex(for tab: LearnFestivalDetailTab) -> Int {
        LearnFestivalDetailTab.allCases.firstIndex(of: tab) ?? 0
    }

    private func destinationURL(_ raw: String?) -> URL? {
        guard let resolved = AppConfig.resolvedURLString(raw) else { return nil }
        return URL(string: resolved)
    }

    private func resolveAvatarLuminance() async {
        guard let avatarURL = destinationURL(currentFestival.avatarUrl) else {
            await MainActor.run {
                avatarLuminance = nil
            }
            return
        }
        let luminance = await LearnLabelAvatarStyling.luminance(for: avatarURL)
        await MainActor.run {
            avatarLuminance = luminance
        }
    }

    private func openPreview(urlString: String?, title: String) {
        guard let url = destinationURL(urlString) else { return }
        previewImage = LearnLabelPreviewImage(title: title, url: url)
    }

    @MainActor
    private func loadRelatedContent() async {
        isLoadingRelatedContent = true
        defer { isLoadingRelatedContent = false }

        do {
            async let eventsTask = fetchRelatedEvents()
            async let postsTask = fetchRelatedPosts()
            relatedEvents = try await eventsTask
            relatedArticles = try await postsTask
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    private func fetchRelatedEvents() async throws -> [WebEvent] {
        let brandID = currentFestival.id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !brandID.isEmpty else { return [] }
        let queries = [brandID]
        var merged: [WebEvent] = []
        var seen = Set<String>()

        for query in queries {
            let page = try await eventsRepository.fetchEvents(
                request: DiscoverEventsPageRequest(
                    page: 1,
                    limit: 120,
                    search: query,
                    eventType: nil,
                    status: "all"
                )
            )
            for item in page.items where eventMatchesFestival(item) {
                if seen.insert(item.id).inserted {
                    merged.append(item)
                }
            }
        }

        return merged.sorted { $0.startDate > $1.startDate }
    }

    private func fetchRelatedPosts() async throws -> [DiscoverNewsArticle] {
        let brandID = currentFestival.id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !brandID.isEmpty else { return [] }
        return try await newsRepository.fetchArticlesBoundToFestival(festivalID: brandID, maxPages: 8)
    }

    private func eventMatchesFestival(_ event: WebEvent) -> Bool {
        let targetBrandID = currentFestival.id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !targetBrandID.isEmpty else { return false }

        if let boundBrandID = event.wikiFestivalId?.trimmingCharacters(in: .whitespacesAndNewlines),
           !boundBrandID.isEmpty,
           boundBrandID == targetBrandID {
            return true
        }
        if let boundBrandID = event.wikiFestival?.id.trimmingCharacters(in: .whitespacesAndNewlines),
           !boundBrandID.isEmpty,
           boundBrandID == targetBrandID {
            return true
        }
        return false
    }

    @MainActor
    private func refreshCurrentFestivalAfterSave() async {
        do {
            let festivals = try await wikiRepository.fetchLearnFestivals(search: nil)
            if let latest = festivals.first(where: { $0.id == currentFestival.id }) {
                let hydrated = LearnFestival(web: latest)
                currentFestival = hydrated
                onFestivalUpdated?(hydrated)
            }
            await loadRelatedContent()
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

}

struct LearnFestivalEditorView: View {
    enum Mode {
        case create
        case edit(LearnFestival)

        var title: String {
            switch self {
            case .create:
                return LL("新增电音节")
            case .edit:
                return LL("编辑电音节")
            }
        }

        var commitTitle: String {
            switch self {
            case .create:
                return L("创建电音节", "Create Festival")
            case .edit:
                return L("保存电音节信息", "Save Festival")
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var appState: AppState

    let mode: Mode
    let onSaved: (LearnFestival) -> Void

    @State private var didPrepareDraft = false
    @State private var isSaving = false
    @State private var name = ""
    @State private var aliases = ""
    @State private var country = ""
    @State private var city = ""
    @State private var foundedYear = ""
    @State private var frequency = ""
    @State private var tagline = ""
    @State private var introduction = ""
    @State private var website = ""
    @State private var avatarItem: PhotosPickerItem?
    @State private var backgroundItem: PhotosPickerItem?
    @State private var avatarData: Data?
    @State private var backgroundData: Data?
    @State private var errorMessage: String?

    private var wikiRepository: DiscoverWikiRepository {
        appContainer.discoverWikiRepository
    }

    private var editingFestival: LearnFestival? {
        if case .edit(let festival) = mode {
            return festival
        }
        return nil
    }

    private var canEditFestival: Bool {
        guard let festival = editingFestival else { return true }
        if let canEdit = festival.canEdit {
            return canEdit
        }
        guard let currentUser = currentSessionContributor else { return false }
        return festival.contributors.contains { contributor in
            contributor.id == currentUser.id
                || contributor.username.caseInsensitiveCompare(currentUser.username) == .orderedSame
        }
    }

    private var currentSessionContributor: WebUserLite? {
        guard let user = appState.session?.user else { return nil }
        return WebUserLite(
            id: user.id,
            username: user.username,
            displayName: user.displayName,
            avatarUrl: user.avatarURL
        )
    }

    var body: some View {
        Form {
            Section(LL("基础信息")) {
                TextField(LL("电音节名称"), text: $name)
                TextField(LL("别名（英文逗号分隔）"), text: $aliases)
                TextField(LL("国家"), text: $country)
                TextField(LL("城市"), text: $city)
                TextField(LL("首办时间"), text: $foundedYear)
                TextField(LL("举办频次"), text: $frequency)
                TextField(LL("定位"), text: $tagline)
                TextField(LL("简介"), text: $introduction, axis: .vertical)
                TextField(LL("官网链接"), text: $website)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
            }

            Section(LL("媒体")) {
                HStack(spacing: 12) {
                    PhotosPicker(selection: $avatarItem, matching: .images) {
                        Label(editingFestival == nil ? LL("选择头像") : LL("更换头像"), systemImage: "person.crop.square")
                    }
                    .buttonStyle(.bordered)

                    avatarPreview
                }

                HStack(spacing: 12) {
                    PhotosPicker(selection: $backgroundItem, matching: .images) {
                        Label(editingFestival == nil ? LL("选择背景") : LL("更换背景"), systemImage: "photo.rectangle")
                    }
                    .buttonStyle(.bordered)

                    backgroundPreview
                }
            }

            Section {
                Button(isSaving ? L("保存中...", "Saving...") : mode.commitTitle) {
                    Task { await saveFestival() }
                }
                .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .raverSystemNavigation(title: mode.title)
        .scrollDismissesKeyboard(.interactively)
        .task {
            guard !didPrepareDraft else { return }
            didPrepareDraft = true
            prepareDraft()
        }
        .onChange(of: avatarItem) { _, item in
            Task { await loadPhoto(item, target: .avatar) }
        }
        .onChange(of: backgroundItem) { _, item in
            Task { await loadPhoto(item, target: .background) }
        }
        .alert(L("提示", "Notice"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(L("确定", "OK"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var avatarPreview: some View {
        if let avatarData, let image = UIImage(data: avatarData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else if let current = editingFestival?.avatarUrl,
                  let resolved = AppConfig.resolvedURLString(current) {
            ImageLoaderView(urlString: resolved)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(RaverTheme.card))
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    @ViewBuilder
    private var backgroundPreview: some View {
        if let backgroundData, let image = UIImage(data: backgroundData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 88, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else if let current = editingFestival?.backgroundUrl,
                  let resolved = AppConfig.resolvedURLString(current) {
            ImageLoaderView(urlString: resolved)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(RaverTheme.card))
            .frame(width: 88, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private enum PhotoTarget {
        case avatar
        case background
    }

    private func prepareDraft() {
        switch mode {
        case .create:
            name = ""
            aliases = ""
            country = ""
            city = ""
            foundedYear = ""
            frequency = ""
            tagline = ""
            introduction = ""
            website = ""
        case .edit(let festival):
            name = festival.name
            aliases = festival.aliases.joined(separator: ", ")
            country = festival.country
            city = festival.city
            foundedYear = festival.foundedYear
            frequency = festival.frequency
            tagline = festival.tagline
            introduction = festival.introduction
            website = festival.links.first(where: { $0.icon == "globe" })?.url ?? festival.links.first?.url ?? ""
        }

        avatarItem = nil
        backgroundItem = nil
        avatarData = nil
        backgroundData = nil
    }

    @MainActor
    private func loadPhoto(_ item: PhotosPickerItem?, target: PhotoTarget) async {
        guard let item else {
            switch target {
            case .avatar:
                avatarData = nil
            case .background:
                backgroundData = nil
            }
            return
        }

        do {
            let loaded = try await item.loadTransferable(type: Data.self)
            switch target {
            case .avatar:
                avatarData = loaded
            case .background:
                backgroundData = loaded
            }
        } catch {
            errorMessage = L("读取图片失败，请重试", "Failed to read image. Please try again.")
        }
    }

    @MainActor
    private func saveFestival() async {
        if editingFestival != nil, !canEditFestival {
            errorMessage = L("仅贡献者可编辑电音节信息", "Only contributors can edit festival info.")
            return
        }

        let finalName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalName.isEmpty else {
            errorMessage = L("电音节名称不能为空", "Festival name cannot be empty.")
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            if var editing = editingFestival {
                editing.name = finalName
                editing.aliases = parseAliasTokens(aliases)
                editing.country = country.trimmingCharacters(in: .whitespacesAndNewlines)
                editing.city = city.trimmingCharacters(in: .whitespacesAndNewlines)
                editing.foundedYear = foundedYear.trimmingCharacters(in: .whitespacesAndNewlines)
                editing.frequency = frequency.trimmingCharacters(in: .whitespacesAndNewlines)
                editing.tagline = tagline.trimmingCharacters(in: .whitespacesAndNewlines)
                editing.introduction = introduction.trimmingCharacters(in: .whitespacesAndNewlines)

                if let avatarData {
                    let uploadedAvatar = try await wikiRepository.uploadWikiBrandImage(
                        imageData: jpegDataForFestivalImport(from: avatarData),
                        fileName: "wiki-brand-avatar-\(UUID().uuidString).jpg",
                        mimeType: "image/jpeg",
                        brandID: editing.id,
                        usage: "avatar"
                    )
                    editing.avatarUrl = uploadedAvatar.url
                }

                if let backgroundData {
                    let uploadedBackground = try await wikiRepository.uploadWikiBrandImage(
                        imageData: jpegDataForFestivalImport(from: backgroundData),
                        fileName: "wiki-brand-background-\(UUID().uuidString).jpg",
                        mimeType: "image/jpeg",
                        brandID: editing.id,
                        usage: "background"
                    )
                    editing.backgroundUrl = uploadedBackground.url
                }

                let normalizedWebsite = normalizeURL(website)
                var preservedLinks = editing.links.filter { $0.icon != "globe" }
                if let normalizedWebsite {
                    preservedLinks.insert(
                        LearnFestivalLink(title: L("官网", "Official"), icon: "globe", url: normalizedWebsite),
                        at: 0
                    )
                }
                editing.links = preservedLinks

                let payload = UpdateLearnFestivalInput(
                    name: editing.name,
                    aliases: editing.aliases,
                    country: editing.country,
                    city: editing.city,
                    foundedYear: editing.foundedYear,
                    frequency: editing.frequency,
                    tagline: editing.tagline,
                    introduction: editing.introduction,
                    avatarUrl: editing.avatarUrl,
                    backgroundUrl: editing.backgroundUrl,
                    links: editing.links.map { link in
                        LearnFestivalLinkPayload(title: link.title, icon: link.icon, url: link.url)
                    }
                )

                let persisted = try await wikiRepository.updateLearnFestival(id: editing.id, input: payload)
                let hydrated = LearnFestival(web: persisted)
                onSaved(hydrated)
                dismiss()
            } else {
                let normalizedWebsite = normalizeURL(website)
                let links: [LearnFestivalLinkPayload] = {
                    guard let normalizedWebsite else { return [] }
                    return [LearnFestivalLinkPayload(title: L("官网", "Official"), icon: "globe", url: normalizedWebsite)]
                }()

                var created = try await wikiRepository.createLearnFestival(
                    input: CreateLearnFestivalInput(
                        name: finalName,
                        aliases: parseAliasTokens(aliases),
                        country: country.trimmingCharacters(in: .whitespacesAndNewlines),
                        city: city.trimmingCharacters(in: .whitespacesAndNewlines),
                        foundedYear: foundedYear.trimmingCharacters(in: .whitespacesAndNewlines),
                        frequency: frequency.trimmingCharacters(in: .whitespacesAndNewlines),
                        tagline: tagline.trimmingCharacters(in: .whitespacesAndNewlines),
                        introduction: introduction.trimmingCharacters(in: .whitespacesAndNewlines),
                        avatarUrl: nil,
                        backgroundUrl: nil,
                        links: links
                    )
                )

                var uploadedAvatarURL: String?
                if let avatarData {
                    let uploadedAvatar = try await wikiRepository.uploadWikiBrandImage(
                        imageData: jpegDataForFestivalImport(from: avatarData),
                        fileName: "wiki-brand-avatar-\(UUID().uuidString).jpg",
                        mimeType: "image/jpeg",
                        brandID: created.id,
                        usage: "avatar"
                    )
                    uploadedAvatarURL = uploadedAvatar.url
                }

                var uploadedBackgroundURL: String?
                if let backgroundData {
                    let uploadedBackground = try await wikiRepository.uploadWikiBrandImage(
                        imageData: jpegDataForFestivalImport(from: backgroundData),
                        fileName: "wiki-brand-background-\(UUID().uuidString).jpg",
                        mimeType: "image/jpeg",
                        brandID: created.id,
                        usage: "background"
                    )
                    uploadedBackgroundURL = uploadedBackground.url
                }

                if uploadedAvatarURL != nil || uploadedBackgroundURL != nil {
                    created = try await wikiRepository.updateLearnFestival(
                        id: created.id,
                        input: UpdateLearnFestivalInput(
                            name: nil,
                            aliases: nil,
                            country: nil,
                            city: nil,
                            foundedYear: nil,
                            frequency: nil,
                            tagline: nil,
                            introduction: nil,
                            avatarUrl: uploadedAvatarURL,
                            backgroundUrl: uploadedBackgroundURL,
                            links: nil
                        )
                    )
                }

                let hydrated = LearnFestival(web: created)
                onSaved(hydrated)
                dismiss()
            }
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    private func parseAliasTokens(_ raw: String) -> [String] {
        raw
            .split(whereSeparator: { $0 == "," || $0 == "，" || $0 == "/" || $0 == "、" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func jpegDataForFestivalImport(from data: Data) -> Data {
        guard let image = UIImage(data: data),
              let jpeg = image.jpegData(compressionQuality: 0.9) else {
            return data
        }
        return jpeg
    }

    private func normalizeURL(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let lower = trimmed.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
            return trimmed
        }
        return "https://\(trimmed)"
    }
}

private struct LearnLabelExpandableText: View {
    let text: String
    let collapsedLineLimit: Int

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(text)
                .font(.subheadline)
                .foregroundStyle(RaverTheme.secondaryText)
                .lineLimit(isExpanded ? nil : collapsedLineLimit)

            if shouldShowToggle {
                Button(isExpanded ? L("收起", "Collapse") : L("展开全文", "Expand")) {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isExpanded.toggle()
                    }
                }
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .foregroundStyle(RaverTheme.accent)
            }
        }
    }

    private var shouldShowToggle: Bool {
        text.count > 80 || text.contains("\n")
    }
}

private struct LearnLabelFounderAvatar: View {
    let urlString: String?

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .frame(width: 42)
            .overlay {
                if let url = destinationURL(urlString) {
                    ImageLoaderView(urlString: url.absoluteString)
                        .background(placeholder)
                } else {
                    placeholder
                }
            }
            .clipped()
            .clipShape(Circle())
    }

    private var placeholder: some View {
        ZStack {
            Color.white.opacity(0.1)
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 23, weight: .regular))
                .foregroundStyle(RaverTheme.secondaryText)
        }
    }

    private func destinationURL(_ raw: String?) -> URL? {
        guard let resolved = AppConfig.resolvedURLString(raw) else { return nil }
        return URL(string: resolved)
    }
}

private struct LearnLabelExternalLinkRow: View {
    let icon: String
    let title: String
    let url: URL

    var body: some View {
        Link(destination: url) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(RaverTheme.accent)
                    .frame(width: 16)

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)

                Spacer(minLength: 8)

                Text(url.host ?? url.absoluteString)
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .lineLimit(1)

                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 3)
        }
    }
}

private enum LearnLabelAvatarStyling {
    private static let ciContext = CIContext()
    private static let luminanceCache = NSCache<NSURL, NSNumber>()

    static func borderColor(for luminance: CGFloat?) -> Color {
        guard let luminance else {
            return Color.white.opacity(0.55)
        }
        if luminance >= 0.67 {
            return Color.black.opacity(0.78)
        }
        return Color.white.opacity(0.82)
    }

    static func luminance(for url: URL) async -> CGFloat? {
        if let cached = luminanceCache.object(forKey: url as NSURL) {
            return CGFloat(truncating: cached)
        }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
                return nil
            }
            guard let image = UIImage(data: data), let luminance = averageLuminance(for: image) else {
                return nil
            }
            luminanceCache.setObject(NSNumber(value: Double(luminance)), forKey: url as NSURL)
            return luminance
        } catch {
            return nil
        }
    }

    private static func averageLuminance(for image: UIImage) -> CGFloat? {
        guard let cgImage = image.cgImage else { return nil }
        let inputImage = CIImage(cgImage: cgImage)
        guard !inputImage.extent.isEmpty else { return nil }
        let filter = CIFilter.areaAverage()
        filter.inputImage = inputImage
        filter.extent = inputImage.extent
        guard let outputImage = filter.outputImage else { return nil }

        var rgba = [UInt8](repeating: 0, count: 4)
        ciContext.render(
            outputImage,
            toBitmap: &rgba,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        let red = CGFloat(rgba[0]) / 255.0
        let green = CGFloat(rgba[1]) / 255.0
        let blue = CGFloat(rgba[2]) / 255.0
        return (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
    }
}

private struct LearnLabelInfoRow: View {
    let title: String
    let value: String?

    var body: some View {
        if let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            HStack(alignment: .top, spacing: 10) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .frame(width: 78, alignment: .leading)
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(RaverTheme.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct LearnLabelPreviewImage: Identifiable, Hashable {
    let id = UUID().uuidString
    let title: String
    let url: URL
}

private struct LearnLabelImagePreviewView: View {
    @Environment(\.dismiss) private var dismiss

    let item: LearnLabelPreviewImage

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            ImageLoaderView(urlString: item.url.absoluteString, resizingMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    Text(LL("图片加载失败"))
                        .foregroundStyle(Color.white.opacity(0.85))
                )
            .padding(.horizontal, 12)
            .padding(.vertical, 44)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.92))
            }
            .padding(.top, 12)
            .padding(.trailing, 12)
        }
        .overlay(alignment: .topLeading) {
            Text(item.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.9))
                .padding(.top, 18)
                .padding(.leading, 16)
        }
    }
}

private struct WrapFlowLayout<Item: Hashable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content

    init(items: [Item], @ViewBuilder content: @escaping (Item) -> Content) {
        self.items = items
        self.content = content
    }

    var body: some View {
        let rows = buildRows()
        return VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 6) {
                    ForEach(row, id: \.self) { item in
                        content(item)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func buildRows() -> [[Item]] {
        // Keep a deterministic, lightweight wrap in the absence of runtime width measurement.
        // This is good enough for short tag strings and keeps implementation simple.
        var rows: [[Item]] = []
        var current: [Item] = []
        for (index, item) in items.enumerated() {
            current.append(item)
            if current.count == 4 || index == items.count - 1 {
                rows.append(current)
                current = []
            }
        }
        return rows
    }
}

struct RankingBoardDetailView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @Environment(\.appPush) private var appPush

    private var djsRepository: DiscoverDJsRepository {
        appContainer.discoverDJsRepository
    }

    let board: RankingBoard

    @State private var selectedYear: Int
    @State private var detail: RankingBoardDetail?
    @State private var isLoading = false
    @State private var errorMessage: String?

    init(board: RankingBoard) {
        self.board = board
        let latestYear = board.years.max() ?? 2025
        _selectedYear = State(initialValue: latestYear)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                contentBody
            }
        }
        .background(RaverTheme.background)
        .raverSystemNavigation(title: board.title)
        .task {
            await load()
        }
        .onChange(of: selectedYear) { _, _ in
            Task { await load() }
        }
        .alert(L("提示", "Notice"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(L("确定", "OK"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var contentBody: some View {
        if isLoading, detail == nil {
            ProgressView(L("加载榜单中...", "Loading rankings..."))
                .frame(maxWidth: .infinity, minHeight: 240)
        } else if let detail {
            rankingDetailContent(detail: detail)
        } else {
            ContentUnavailableView(LL("榜单为空"), systemImage: "list.number")
                .frame(maxWidth: .infinity, minHeight: 240)
        }
    }

    private func rankingDetailContent(detail: RankingBoardDetail) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            rankingHeader
            rankingGrid(entries: detail.entries)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var rankingHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(board.title)
                .font(.title.weight(.black))
                .foregroundStyle(RaverTheme.primaryText)
            Text(board.subtitle ?? board.defaultSubtitle)
                .font(.subheadline)
                .foregroundStyle(RaverTheme.secondaryText)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(sortedYears, id: \.self) { year in
                        Button {
                            selectedYear = year
                        } label: {
                            Text(verbatim: String(year))
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selectedYear == year ? RaverTheme.accent : RaverTheme.card)
                        .foregroundStyle(selectedYear == year ? Color.white : RaverTheme.primaryText)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
        .padding(16)
        .background(RaverTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var sortedYears: [Int] {
        Array(Set(board.years)).sorted(by: >)
    }

    private func rankingGrid(entries: [RankingEntry]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(entries) { entry in
                Button {
                    if let festival = entry.festival {
                        appPush(.discover(.festivalDetail(festivalID: festival.id)))
                    } else if let dj = entry.dj {
                        appPush(.djDetail(djID: dj.id))
                    }
                } label: {
                    RankingEntryCard(entry: entry)
                }
                .buttonStyle(.plain)
                .disabled(entry.festival?.id == nil && entry.dj?.id == nil)
            }
        }
    }

    private func mapFestivalLiteToLearnFestival(_ festival: RankingFestivalLite) -> LearnFestival {
        LearnFestival(
            id: festival.id,
            name: festival.name,
            aliases: [],
            country: festival.country ?? "",
            city: festival.city ?? "",
            foundedYear: "",
            frequency: "",
            tagline: festival.tagline ?? "",
            introduction: "",
            genres: [],
            avatarUrl: festival.avatarUrl,
            backgroundUrl: festival.backgroundUrl,
            links: []
        )
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            detail = try await djsRepository.fetchRankingBoardDetail(boardID: board.id, year: selectedYear)
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

}

private struct RankingEntryCard: View {
    let entry: RankingEntry

    var body: some View {
        ZStack {
            GeometryReader { geo in
                entryImage
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }

            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.22), Color.black.opacity(0.82)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack {
                HStack {
                    Spacer()
                    Text(deltaLabel)
                        .font(.caption.bold())
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(deltaColor.opacity(0.88))
                        .foregroundStyle(Color.white)
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)
                Spacer()
            }

            HStack {
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: 34, height: 34)
                        .overlay(
                            Text("\(entry.rank)")
                                .font(.system(size: 17, weight: .black, design: .rounded))
                                .foregroundStyle(Color.white)
                        )
                }
                .padding(.leading, 8)
                .padding(.bottom, 8)
                Spacer()
            }

            VStack {
                Spacer()
                HStack(alignment: .bottom, spacing: 10) {
                    Spacer(minLength: 46)

                    Text((entry.festival?.name ?? entry.name).uppercased())
                        .font(.headline.weight(.black))
                        .foregroundStyle(Color.white)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.trailing, 10)
                .padding(.bottom, 12)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .clipShape(Rectangle())
        .overlay(
            Rectangle()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var entryImage: some View {
        if let festivalBackground = AppConfig.resolvedURLString(entry.festival?.backgroundUrl),
           URL(string: festivalBackground) != nil {
            ImageLoaderView(urlString: festivalBackground)
                .background(fallbackImage)
        } else if let festivalAvatar = AppConfig.resolvedURLString(entry.festival?.avatarUrl),
                  URL(string: festivalAvatar) != nil {
            ImageLoaderView(urlString: festivalAvatar)
                .background(fallbackImage)
        } else if let avatar = AppConfig.resolvedDJAvatarURLString(entry.dj?.avatarMediumUrl ?? entry.dj?.avatarUrl, size: .medium),
           URL(string: highResAvatarURL(avatar)) != nil {
            ImageLoaderView(urlString: highResAvatarURL(avatar))
                .background(fallbackImage)
        } else {
            fallbackImage
        }
    }

    private var fallbackImage: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.17, green: 0.20, blue: 0.28), Color(red: 0.10, green: 0.12, blue: 0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Text(String((entry.festival?.name ?? entry.name).prefix(2)).uppercased())
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.85))
        }
    }

    private var deltaLabel: String {
        guard let delta = entry.delta else { return "—" }
        if delta > 0 { return "▲ \(delta)" }
        if delta < 0 { return "▼ \(abs(delta))" }
        return "• 0"
    }

    private var deltaColor: Color {
        guard let delta = entry.delta else { return Color.gray }
        if delta > 0 { return Color.green }
        if delta < 0 { return Color.red }
        return Color.gray
    }
}

struct DJSearchResultCard: View {
    let dj: WebDJ

    var body: some View {
        ZStack {
            GeometryReader { geo in
                djImage
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }

            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.22), Color.black.opacity(0.82)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack {
                Spacer()
                HStack(alignment: .bottom, spacing: 10) {
                    Spacer(minLength: 10)

                    Text(dj.name.uppercased())
                        .font(.headline.weight(.black))
                        .foregroundStyle(Color.white)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.trailing, 10)
                .padding(.bottom, 12)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .clipShape(Rectangle())
        .overlay(
            Rectangle()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var djImage: some View {
        if let avatar = AppConfig.resolvedDJAvatarURLString(dj.avatarOriginalUrl ?? dj.avatarUrl, size: .original),
           URL(string: highResAvatarURL(avatar)) != nil {
            ImageLoaderView(urlString: highResAvatarURL(avatar))
                .background(fallbackImage)
        } else {
            fallbackImage
        }
    }

    private var fallbackImage: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.17, green: 0.20, blue: 0.28), Color(red: 0.10, green: 0.12, blue: 0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Text(String(dj.name.prefix(2)).uppercased())
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.85))
        }
    }

    private func highResAvatarURL(_ url: String) -> String {
        url
            .replacingOccurrences(of: "ab6761610000f178", with: "ab6761610000e5eb")
            .replacingOccurrences(of: "ab67616100005174", with: "ab6761610000e5eb")
            .replacingOccurrences(of: "ab67616d00004851", with: "ab67616d0000b273")
            .replacingOccurrences(of: "ab67616d00001e02", with: "ab67616d0000b273")
    }
}

extension RankingBoard {
    var yearsText: String {
        guard let minYear = years.min(), let maxYear = years.max() else { return "—" }
        return minYear == maxYear ? "\(minYear)" : "\(minYear) - \(maxYear)"
    }

    var defaultSubtitle: String {
        switch id {
        case "djmag": return L("全球电子音乐最有影响力榜单之一", "One of the most influential global electronic music rankings")
        case "dongye": return L("中文圈 DJ 热度与影响力榜单", "Popularity and influence ranking for Chinese-speaking DJs")
        default: return L("各大榜单年度排名与升降变化", "Annual ranking movements across major charts")
        }
    }

    var shortMark: String {
        switch id {
        case "djmag": return "TOP"
        case "dongye": return "东野"
        default: return String(title.prefix(3)).uppercased()
        }
    }
}

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }
}

extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
