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
import Foundation

struct LearnModuleView: View {
    @Environment(\.discoverPush) private var discoverPush
    @Environment(\.appPush) private var appPush
    @Environment(\.raverTabBarReservedHeight) private var tabBarReservedHeight
    @EnvironmentObject private var appContainer: AppContainer

    private var wikiRepository: DiscoverWikiRepository {
        appContainer.discoverWikiRepository
    }

    private var djRankingRepository: DJRankingRepository {
        appContainer.djRankingRepository
    }

    @State private var genres: [LearnGenreNode] = []
    @State private var allLabels: [LearnLabel] = []
    @State private var labels: [LearnLabel] = []
    @State private var allFestivals: [LearnFestival] = []
    @State private var festivals: [LearnFestival] = []
    @State private var rankingBoards: [RankingBoard] = []
    @State private var labelsPagination: BFFPagination?
    private let initialSection: LearnModuleSection
    private let showsSectionTabs: Bool
    @State private var selectedSection: LearnModuleSection
    @State private var selectedSort: LearnLabelSortOption = .soundcloudFollowers
    @State private var sortOrder: LearnLabelSortOrder = .desc
    @State private var selectedGenreFilters: Set<String> = []
    @State private var selectedNationFilters: Set<String> = []
    @State private var activeFilterPanel: LearnLabelFilterPanelType?
    @State private var isLoadingRankings = false
    @State private var isLoadingGenres = false
    @State private var isLoadingLabels = false
    @State private var isLoadingFestivals = false
    @State private var rankingsPhase: LoadPhase = .idle
    @State private var genresPhase: LoadPhase = .idle
    @State private var labelsPhase: LoadPhase = .idle
    @State private var festivalsPhase: LoadPhase = .idle
    @State private var isRefreshingRankings = false
    @State private var isRefreshingGenres = false
    @State private var isRefreshingLabels = false
    @State private var isRefreshingFestivals = false
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
    @State private var bannerMessage: String?
    @State private var errorMessage: String?

    init(initialSection: LearnModuleSection = .rankings, showsSectionTabs: Bool = true) {
        self.initialSection = initialSection
        self.showsSectionTabs = showsSectionTabs
        _selectedSection = State(initialValue: initialSection)
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsSectionTabs {
                headerTabs
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
            }

                if selectedSection == .labels {
                    labelsToolbar
                        .padding(.horizontal, 16)
                        .padding(.top, showsSectionTabs ? 0 : 12)
                        .padding(.bottom, 6)
                } else if selectedSection == .festivals {
                    festivalsToolbar
                        .padding(.horizontal, 16)
                        .padding(.top, showsSectionTabs ? 0 : 12)
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

                if selectedSectionIsRefreshing || bannerMessage != nil {
                    VStack(alignment: .leading, spacing: 10) {
                        if selectedSectionIsRefreshing {
                            InlineLoadingBadge(title: LT("正在更新内容", "Updating content", "コンテンツを更新中"))
                        }
                        if let bannerMessage {
                            ScreenStatusBanner(
                                message: bannerMessage,
                                style: .error,
                                actionTitle: LT("重试", "Retry", "再試行")
                            ) {
                                Task { await refreshSelectedSection() }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }
            .background(RaverTheme.background)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                if showsSectionTabs {
                    await loadInitial()
                } else {
                    await refreshSelectedSection()
                }
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
                guard selectedSection == .festivals else { return }
                Task { await loadFestivals() }
            }
            .alert(LT("提示", "Notice", "お知らせ"), isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button(LT("确定", "OK", "OK"), role: .cancel) {}
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
        }
    }

    @ViewBuilder
    private var labelsToolbar: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
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
                        .frame(height: 32)
                        .background(RaverTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    Button {
                        sortOrder = sortOrder == .desc ? .asc : .desc
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: sortOrder == .desc ? "arrow.down" : "arrow.up")
                            Text(sortOrder == .desc ? LT("降序", "Desc", "降順") : LT("升序", "Asc", "昇順"))
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                        .padding(.horizontal, 10)
                        .frame(height: 32)
                        .background(RaverTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            activeFilterPanel = activeFilterPanel == .genres ? nil : .genres
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: activeFilterPanel == .genres ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            Text(selectedGenreFilters.isEmpty ? LT("风格", "Genres", "ジャンル") : LT("风格 \(selectedGenreFilters.count)", "Genres \(selectedGenreFilters.count)", "ジャンル \(selectedGenreFilters.count)"))
                                .lineLimit(1)
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                        .padding(.horizontal, 10)
                        .frame(height: 32)
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
                            Text(selectedNationFilters.isEmpty ? LT("国家", "Countries", "国") : LT("国家 \(selectedNationFilters.count)", "Countries \(selectedNationFilters.count)", "国 \(selectedNationFilters.count)"))
                                .lineLimit(1)
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                        .padding(.horizontal, 10)
                        .frame(height: 32)
                        .background(RaverTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    if !selectedGenreFilters.isEmpty || !selectedNationFilters.isEmpty {
                        Button(LT("清空全部", "清空全部", "すべてクリア")) {
                            selectedGenreFilters.removeAll()
                            selectedNationFilters.removeAll()
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RaverTheme.secondaryText)
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
            }

            if activeFilterPanel == .genres {
                LearnLabelMultiSelectPanel(
                    title: LT("筛选风格", "Filter Genres", "ジャンルで絞り込み"),
                    options: availableGenreFilters,
                    selectedValues: selectedGenreFilters,
                    emptyText: LT("暂无可筛选风格", "No genres available for filtering", "絞り込めるジャンルはありません"),
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
                    title: LT("筛选国家", "Filter Countries", "国で絞り込み"),
                    options: availableNationFilters,
                    selectedValues: selectedNationFilters,
                    emptyText: LT("暂无可筛选国家", "No countries available for filtering", "絞り込める国はありません"),
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
                Text(LT("筛选后 \(labels.count) / 共 \(total) 个厂牌", "Filtered \(labels.count) / Total \(total) labels", "絞り込み後 \(labels.count) / 全 \(total) 件のレーベル"))
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var festivalsToolbar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Text(LT("筛选后 \(festivals.count) / 共 \(allFestivals.count) 个主办方", "Filtered \(festivals.count) / Total \(allFestivals.count) organizers", "絞り込み後 \(festivals.count) / 全 \(allFestivals.count) 件の主催"))
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
                        Text(LT("新增主办方", "Add Organizer", "主催を追加"))
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
        if rankingsPhase == .idle || rankingsPhase == .initialLoading {
            DiscoverGridSkeletonView()
                .frame(maxWidth: .infinity, minHeight: 220)
        } else if case .failure(let message) = rankingsPhase {
            ScreenErrorCard(
                title: LT("榜单加载失败", "Rankings Failed to Load", "ランキングの読み込みに失敗しました"),
                message: message
            ) {
                Task { await loadRankingBoards() }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
        } else if case .offline(let message) = rankingsPhase {
            ScreenErrorCard(
                title: LT("网络不可用", "Network Unavailable", "ネットワークを利用できません"),
                message: message
            ) {
                Task { await loadRankingBoards() }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
        } else if rankingBoards.isEmpty {
            ContentUnavailableView(LT("暂无榜单", "暂无榜单", "ランキングはまだありません"), systemImage: "list.number")
                .frame(maxWidth: .infinity, minHeight: 220)
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(rankingBoards) { board in
                        Button {
                            appPush(.rankingBoardDetail(board: board, year: nil))
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
                if showsSectionTabs {
                    await refreshAll()
                } else {
                    await loadRankingBoards()
                }
            }
        }
    }

    @ViewBuilder
    private var genresContent: some View {
        if genresPhase == .idle || genresPhase == .initialLoading {
            FeedSkeletonView(count: 4)
                .padding(.horizontal, 16)
                .padding(.top, 12)
        } else if case .failure(let message) = genresPhase {
            ScreenErrorCard(
                title: LT("学习内容加载失败", "Learn Content Failed to Load", "学習コンテンツの読み込みに失敗しました"),
                message: message
            ) {
                Task { await loadGenres() }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
        } else if case .offline(let message) = genresPhase {
            ScreenErrorCard(
                title: LT("网络不可用", "Network Unavailable", "ネットワークを利用できません"),
                message: message
            ) {
                Task { await loadGenres() }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
        } else if genres.isEmpty {
            ContentUnavailableView(LT("暂无学习内容", "暂无学习内容", "学習コンテンツはまだありません"), systemImage: "book")
        } else {
            LearnGenreSunburstSection(
                genres: genres,
                bottomInset: max(0, tabBarReservedHeight) + 14
            )
            .refreshable {
                if showsSectionTabs {
                    await refreshAll()
                } else {
                    await loadGenres()
                }
            }
        }
    }

    @ViewBuilder
    private var labelsContent: some View {
        if labelsPhase == .idle || labelsPhase == .initialLoading {
            FeedSkeletonView(count: 4)
                .padding(.horizontal, 16)
                .padding(.top, 12)
        } else if case .failure(let message) = labelsPhase {
            ScreenErrorCard(
                title: LT("厂牌加载失败", "Labels Failed to Load", "レーベルの読み込みに失敗しました"),
                message: message
            ) {
                Task { await loadLabels() }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
        } else if case .offline(let message) = labelsPhase {
            ScreenErrorCard(
                title: LT("网络不可用", "Network Unavailable", "ネットワークを利用できません"),
                message: message
            ) {
                Task { await loadLabels() }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
        } else if labels.isEmpty {
            ContentUnavailableView(LT("暂无厂牌", "暂无厂牌", "レーベルはまだありません"), systemImage: "building.2")
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
                if showsSectionTabs {
                    await refreshAll()
                } else {
                    await loadLabels()
                }
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
        if festivalsPhase == .idle || festivalsPhase == .initialLoading {
            FeedSkeletonView(count: 4)
                .padding(.horizontal, 16)
                .padding(.top, 12)
        } else if case .failure(let message) = festivalsPhase {
            ScreenErrorCard(
                title: LT("主办方加载失败", "Organizers Failed to Load", "主催の読み込みに失敗しました"),
                message: message
            ) {
                Task { await loadFestivals() }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
        } else if case .offline(let message) = festivalsPhase {
            ScreenErrorCard(
                title: LT("网络不可用", "Network Unavailable", "ネットワークを利用できません"),
                message: message
            ) {
                Task { await loadFestivals() }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if festivals.isEmpty {
                        ContentUnavailableView(LT("暂无匹配主办方", "No Matching Organizers", "一致する主催はありません"), systemImage: "music.quarternote.3")
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
                if showsSectionTabs {
                    await refreshAll()
                } else {
                    await loadFestivals()
                }
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

    private func refreshSelectedSection() async {
        switch selectedSection {
        case .rankings:
            await loadRankingBoards()
        case .genres:
            await loadGenres()
        case .labels:
            await loadLabels()
        case .festivals:
            await loadFestivals()
        }
    }

    private func loadRankingBoards() async {
        let hadContent = !rankingBoards.isEmpty
        isLoadingRankings = true
        if hadContent {
            isRefreshingRankings = true
        } else {
            rankingsPhase = .initialLoading
        }
        defer { isLoadingRankings = false }
        defer { isRefreshingRankings = false }

        do {
            rankingBoards = try await djRankingRepository.fetchRankingBoards()
            rankingsPhase = rankingBoards.isEmpty ? .empty : .success
            bannerMessage = nil
        } catch {
            let message = error.userFacingMessage ?? LT("榜单加载失败，请稍后重试", "Failed to load rankings. Please try again later.", "ランキングを読み込めませんでした。時間をおいて再試行してください。")
            if hadContent {
                bannerMessage = message
                rankingsPhase = .success
            } else {
                rankingsPhase = .failure(message: message)
            }
        }
    }

    private func loadGenres() async {
        let hadContent = !genres.isEmpty
        isLoadingGenres = true
        if hadContent {
            isRefreshingGenres = true
        } else {
            genresPhase = .initialLoading
        }
        defer { isLoadingGenres = false }
        defer { isRefreshingGenres = false }
        do {
            genres = try await wikiRepository.fetchLearnGenres()
            genresPhase = genres.isEmpty ? .empty : .success
            bannerMessage = nil
        } catch {
            let message = error.userFacingMessage ?? LT("学习内容加载失败，请稍后重试", "Failed to load learn content. Please try again later.", "学習コンテンツを読み込めませんでした。時間をおいて再試行してください。")
            if hadContent {
                bannerMessage = message
                genresPhase = .success
            } else {
                genresPhase = .failure(message: message)
            }
        }
    }

    private func loadLabels() async {
        let hadContent = !labels.isEmpty
        isLoadingLabels = true
        if hadContent {
            isRefreshingLabels = true
        } else {
            labelsPhase = .initialLoading
        }
        defer { isLoadingLabels = false }
        defer { isRefreshingLabels = false }

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
            labelsPhase = labels.isEmpty ? .empty : .success
            bannerMessage = nil
        } catch {
            let message = error.userFacingMessage ?? LT("厂牌加载失败，请稍后重试", "Failed to load labels. Please try again later.", "レーベルを読み込めませんでした。時間をおいて再試行してください。")
            if hadContent {
                bannerMessage = message
                labelsPhase = .success
            } else {
                labelsPhase = .failure(message: message)
            }
        }
    }

    private func loadFestivals() async {
        let hadContent = !allFestivals.isEmpty
        isLoadingFestivals = true
        if hadContent {
            isRefreshingFestivals = true
        } else {
            festivalsPhase = .initialLoading
        }
        defer { isLoadingFestivals = false }
        defer { isRefreshingFestivals = false }

        do {
            let fetched = try await wikiRepository.fetchLearnFestivals(search: nil)
            allFestivals = fetched.map { LearnFestival(web: $0) }
            applyFestivalFilters()
            festivalsPhase = festivals.isEmpty ? .empty : .success
            bannerMessage = nil
        } catch {
            let message = error.userFacingMessage ?? LT("主办方加载失败，请稍后重试", "Failed to load organizers. Please try again later.", "主催を読み込めませんでした。時間をおいて再試行してください。")
            if hadContent {
                bannerMessage = message
                festivalsPhase = .success
            } else {
                festivalsPhase = .failure(message: message)
            }
        }
    }

    private var selectedSectionIsRefreshing: Bool {
        switch selectedSection {
        case .rankings:
            return isRefreshingRankings
        case .genres:
            return isRefreshingGenres
        case .labels:
            return isRefreshingLabels
        case .festivals:
            return isRefreshingFestivals
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
            Text(LT("榜单分区", "榜单分区", "ランキング区分"))
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
                Section(LT("基础信息", "基础信息", "基本情報")) {
                    TextField(LT("电音节名称", "电音节名称", "フェス名"), text: $createFestivalName)
                    TextField(LT("别名（英文逗号分隔）", "别名（英文逗号分隔）", "別名（半角カンマ区切り）"), text: $createFestivalAliases)
                    TextField(LT("国家", "国家", "国"), text: $createFestivalCountry)
                    TextField(LT("城市", "城市", "都市"), text: $createFestivalCity)
                    TextField(LT("首办时间", "首办时间", "初開催年"), text: $createFestivalFoundedYear)
                    TextField(LT("举办频次", "举办频次", "開催頻度"), text: $createFestivalFrequency)
                    TextField(LT("定位", "定位", "タグライン"), text: $createFestivalTagline)
                    TextField(LT("简介", "简介", "概要"), text: $createFestivalIntroduction, axis: .vertical)
                    TextField(LT("官网链接", "官网链接", "公式サイトリンク"), text: $createFestivalWebsite)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                }

                Section(LT("媒体", "媒体", "メディア")) {
                    HStack(spacing: 12) {
                        PhotosPicker(selection: $createFestivalAvatarItem, matching: .images) {
                            Label(LT("选择头像", "选择头像", "アバターを選択"), systemImage: "person.crop.square")
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
                            Label(LT("选择背景", "选择背景", "背景を選択"), systemImage: "photo.rectangle")
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
                    Button(isCreatingFestival ? LT("创建中...", "Creating...", "作成中...") : "创建电音节") {
                        Task { await createFestival() }
                    }
                    .disabled(isCreatingFestival || createFestivalName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .raverSystemNavigation(title: LT("新增电音节", "新增电音节", "フェスを追加"))
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
            errorMessage = LT("读取图片失败，请重试", "Failed to read image. Please try again.", "画像を読み込めませんでした。もう一度お試しください。")
        }
    }

    @MainActor
    private func createFestival() async {
        let finalName = createFestivalName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalName.isEmpty else {
            errorMessage = LT("电音节名称不能为空", "Festival name cannot be empty.", "フェス名を入力してください。")
            return
        }

        isCreatingFestival = true
        defer { isCreatingFestival = false }

        do {
            let website = normalizeFestivalURL(createFestivalWebsite)
            let links: [LearnFestivalLinkPayload] = {
                guard let website else { return [] }
                return [LearnFestivalLinkPayload(title: LT("官网", "Official", "公式サイト"), icon: "globe", url: website)]
            }()

            let createResult = try await wikiRepository.createLearnFestival(
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
            guard case .created(var created) = createResult else {
                showFestivalCreateSheet = false
                errorMessage = LT("品牌信息已提交审核", "Brand submitted for review.", "ブランド情報を審査に送信しました。")
                return
            }

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
            errorMessage = LT("电音节品牌已创建", "Festival brand created.", "フェスブランドを作成しました。")
        } catch {
            errorMessage = LT("创建失败：\(error.userFacingMessage ?? "")", "Creation failed: \(error.userFacingMessage ?? "")", "作成に失敗しました: \(error.userFacingMessage ?? "")")
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

private struct LearnGenreSunburstSection: View {
    let genres: [LearnGenreNode]
    let bottomInset: CGFloat

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appPush) private var appPush
    @State private var focusedId: String?
    @State private var selectedNode: GenreSunburstNode?
    @State private var rootNode: GenreSunburstNode
    @State private var searchIndex: [GenreSunburstSearchItem]

    init(genres: [LearnGenreNode], bottomInset: CGFloat) {
        self.genres = genres
        self.bottomInset = bottomInset

        let root = Self.makeRootNode(from: genres)
        _rootNode = State(initialValue: root)
        _searchIndex = State(initialValue: Self.makeSearchIndex(root: root))
    }

    private static func makeRootNode(from genres: [LearnGenreNode]) -> GenreSunburstNode {
        GenreSunburstNode(
            id: "learn-genres-root",
            name: LT("流派树", "Genre Tree", "ジャンルツリー"),
            path: "learn-genres-root",
            description: LT("点击外圈进入分支，点击中心返回上一级。", "Tap outer rings to dive in, tap the center to go back.", "外周リングで深掘りし、中央タップで戻ります。"),
            example: "",
            spotifyTrackURL: "",
            wikipediaURL: "",
            keyArtists: [],
            keyArtistBindings: [],
            children: genres.map { GenreSunburstNode(learnNode: $0, parentPath: "learn-genres-root") }
        )
    }

    private static func makeSearchIndex(root: GenreSunburstNode) -> [GenreSunburstSearchItem] {
        root.allDescendants()
            .filter { $0.id != root.id }
            .map { node in
                GenreSunburstSearchItem(
                    node: node,
                    parentId: node.parentNode(root: root)?.id,
                    pathText: node.pathDisplayText(root: root)
                )
            }
    }

    var body: some View {
        GeometryReader { geometry in
            let horizontalPadding = geometry.size.width >= 768 ? CGFloat(18) : CGFloat(10)
            let chartWidth = max(260, geometry.size.width - horizontalPadding * 2)
            let maxChartHeight = max(320, geometry.size.height - bottomInset - 112)
            let chartSize = min(chartWidth, maxChartHeight, geometry.size.width >= 768 ? 680 : 520)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    GenreSunburstSearchPanel(
                        items: searchIndex
                    ) { item in
                        focusedId = item.id
                        selectedNode = item.node
                    }

                    GenreSunburstCanvasContainer(
                        rootNode: rootNode,
                        focusedId: $focusedId,
                        selectedNode: $selectedNode
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: chartSize)

                    GenreSunburstSelectionCard(
                        node: selectedNode ?? rootNode.firstNode(withId: focusedId ?? "") ?? rootNode,
                        pathText: pathText(for: selectedNode ?? rootNode.firstNode(withId: focusedId ?? "") ?? rootNode),
                        onArtistTap: openArtistDetail
                    )
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 10)
                .padding(.bottom, bottomInset)
            }
            .background(
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        hideKeyboard()
                    }
            )
            .scrollDismissesKeyboard(.interactively)
        }
        .onChange(of: genres) { _, newGenres in
            let updatedRoot = Self.makeRootNode(from: newGenres)
            rootNode = updatedRoot
            searchIndex = Self.makeSearchIndex(root: updatedRoot)
            focusedId = nil
            selectedNode = nil
        }
    }

    private func pathText(for node: GenreSunburstNode) -> String {
        node.pathDisplayText(root: rootNode)
    }

    private func openArtistDetail(_ artist: LearnGenreKeyArtistBinding) {
        guard let djID = (artist.dj?.id.nilIfBlank ?? artist.djId?.nilIfBlank) else { return }
        appPush(.djDetail(djID: djID))
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

private struct GenreSunburstCanvasContainer: View {
    @Environment(\.colorScheme) private var colorScheme
    let rootNode: GenreSunburstNode
    @Binding var focusedId: String?
    @Binding var selectedNode: GenreSunburstNode?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            GenreSunburstCanvasView(
                root: rootNode,
                focusedId: $focusedId,
                selectedNode: $selectedNode
            )

            Button {
                focusedId = nil
                selectedNode = nil
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(resetForeground)
                    .frame(width: 52, height: 52)
                    .background(resetBackground, in: Circle())
                    .overlay(
                        Circle()
                            .stroke(resetStroke, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
            .padding(.trailing, 6)
            .opacity((focusedId == nil && selectedNode == nil) ? 0.65 : 1)
        }
    }

    private var resetForeground: Color {
        colorScheme == .dark ? .white.opacity(0.92) : Color.black.opacity(0.78)
    }

    private var resetBackground: Color {
        colorScheme == .dark ? .black.opacity(0.34) : .white.opacity(0.78)
    }

    private var resetStroke: Color {
        colorScheme == .dark ? .white.opacity(0.12) : .black.opacity(0.08)
    }
}

private struct GenreSunburstSelectionCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let node: GenreSunburstNode
    let pathText: String
    let onArtistTap: (LearnGenreKeyArtistBinding) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(node.name)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.86)

            if !pathText.isEmpty {
                Text(pathText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accentText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            if !node.description.isEmpty {
                Text(node.description)
                    .font(.system(size: 14.5, weight: .regular))
                    .foregroundStyle(secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }

            if !infoItems.isEmpty {
                VStack(spacing: 10) {
                    ForEach(infoItems) { item in
                        GenreSunburstInfoTile(item: item, onArtistTap: onArtistTap)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: cardGradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: cardStrokeColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(
            color: colorScheme == .dark ? .clear : Color.black.opacity(0.10),
            radius: colorScheme == .dark ? 0 : 18,
            x: 0,
            y: colorScheme == .dark ? 0 : 10
        )
    }

    private var primaryText: Color {
        colorScheme == .dark ? .white : Color.black.opacity(0.86)
    }

    private var secondaryText: Color {
        colorScheme == .dark ? .white.opacity(0.76) : Color.black.opacity(0.68)
    }

    private var accentText: Color {
        colorScheme == .dark
            ? Color(red: 0.46, green: 0.88, blue: 1.0).opacity(0.92)
            : Color.black.opacity(0.82)
    }

    private var cardGradientColors: [Color] {
        colorScheme == .dark
            ? [
                Color(red: 0.08, green: 0.10, blue: 0.16).opacity(0.94),
                Color(red: 0.04, green: 0.05, blue: 0.09).opacity(0.98)
            ]
            : [
                Color.white.opacity(0.96),
                Color(red: 0.92, green: 0.96, blue: 1.0).opacity(0.92)
            ]
    }

    private var cardStrokeColors: [Color] {
        colorScheme == .dark
            ? [
                Color(red: 0.42, green: 0.84, blue: 1.0).opacity(0.34),
                Color(red: 1.0, green: 0.26, blue: 0.67).opacity(0.16)
            ]
            : [
                Color(red: 0.10, green: 0.48, blue: 0.78).opacity(0.18),
                Color(red: 0.86, green: 0.20, blue: 0.52).opacity(0.10)
            ]
    }

    private var infoItems: [GenreSunburstInfoItem] {
        var items: [GenreSunburstInfoItem] = []

        let artistBindings = normalizedArtistBindings()
        if !artistBindings.isEmpty {
            items.append(GenreSunburstInfoItem(
                id: "artists",
                icon: "person.2.fill",
                title: LT("代表艺人", "Key artists", "代表アーティスト"),
                value: "",
                artists: artistBindings
            ))
        }

        if !node.example.isEmpty {
            items.append(GenreSunburstInfoItem(
                id: "example",
                icon: "music.note",
                title: LT("声音线索", "Sound cue", "サウンド"),
                value: node.example,
                artists: []
            ))
        }

        return items
    }

    private func normalizedArtistBindings() -> [LearnGenreKeyArtistBinding] {
        if !node.keyArtistBindings.isEmpty {
            return node.keyArtistBindings
        }

        return node.keyArtists.map { LearnGenreKeyArtistBinding(name: $0, djId: nil, dj: nil) }
    }
}

private struct GenreSunburstInfoItem: Identifiable {
    let id: String
    let icon: String
    let title: String
    let value: String
    let artists: [LearnGenreKeyArtistBinding]
}

private struct GenreSunburstInfoTile: View {
    @Environment(\.colorScheme) private var colorScheme
    let item: GenreSunburstInfoItem
    let onArtistTap: (LearnGenreKeyArtistBinding) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: item.icon)
                    .font(.system(size: 11, weight: .bold))
                Text(item.title)
                    .font(.system(size: 11, weight: .bold))
                    .lineLimit(1)
            }
            .foregroundStyle(labelText)

            if !item.artists.isEmpty {
                GenreSunburstArtistCapsuleCloud(artists: item.artists, onArtistTap: onArtistTap)
            } else {
                Text(item.value)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(valueText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 74, alignment: .topLeading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.055) : Color.black.opacity(0.04))
        )
    }

    private var labelText: Color {
        colorScheme == .dark
            ? Color(red: 0.62, green: 0.90, blue: 1.0).opacity(0.95)
            : Color.black.opacity(0.74)
    }

    private var valueText: Color {
        colorScheme == .dark ? .white.opacity(0.78) : Color.black.opacity(0.86)
    }
}

private struct GenreSunburstArtistCapsuleCloud: View {
    let artists: [LearnGenreKeyArtistBinding]
    let onArtistTap: (LearnGenreKeyArtistBinding) -> Void

    var body: some View {
        GenreSunburstFlowLayout(spacing: 8, lineSpacing: 8) {
            ForEach(artists) { artist in
                GenreSunburstArtistCapsule(artist: artist, onTap: onArtistTap)
            }
        }
    }
}

private struct GenreSunburstFlowLayout: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 0
        guard maxWidth > 0 else {
            let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
            return CGSize(
                width: sizes.map(\.width).max() ?? 0,
                height: sizes.reduce(CGFloat(0)) { $0 + $1.height } + lineSpacing * CGFloat(max(0, sizes.count - 1))
            )
        }

        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += rowHeight + lineSpacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + lineSpacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

private struct GenreSunburstArtistCapsule: View {
    @Environment(\.colorScheme) private var colorScheme
    let artist: LearnGenreKeyArtistBinding
    let onTap: (LearnGenreKeyArtistBinding) -> Void

    var body: some View {
        Group {
            if canOpenDetail {
                Button {
                    onTap(artist)
                } label: {
                    capsuleContent
                }
                .buttonStyle(.plain)
                .accessibilityHint(LT("打开 DJ 详情", "Open DJ detail", "DJ詳細を開く"))
            } else {
                capsuleContent
            }
        }
    }

    private var capsuleContent: some View {
        HStack(spacing: 7) {
            AsyncImage(url: avatarURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    ZStack {
                        Circle().fill(avatarFallbackBackground)
                        Text(String(displayName.prefix(1)).uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(avatarFallbackText)
                    }
                }
            }
            .frame(width: 22, height: 22)
            .clipShape(Circle())

            Text(displayName)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(textColor)
                .lineLimit(1)
        }
        .padding(.leading, 5)
        .padding(.trailing, 10)
        .frame(height: 32)
        .background(capsuleBackground, in: Capsule())
        .overlay(Capsule().stroke(capsuleStroke, lineWidth: 1))
    }

    private var canOpenDetail: Bool {
        (artist.dj?.id.nilIfBlank ?? artist.djId?.nilIfBlank) != nil
    }

    private var displayName: String {
        artist.dj?.name.nilIfBlank ?? artist.name
    }

    private var avatarURL: URL? {
        let resolved = AppConfig.resolvedDJAvatarURLString(
            artist.dj?.avatarMediumUrl ?? artist.dj?.avatarUrl,
            size: .medium
        )
        guard let resolved else { return nil }
        return URL(string: resolved)
    }

    private var textColor: Color {
        colorScheme == .dark ? .white.opacity(0.88) : Color.black.opacity(0.84)
    }

    private var capsuleBackground: Color {
        colorScheme == .dark ? .white.opacity(0.075) : .white.opacity(0.92)
    }

    private var capsuleStroke: Color {
        colorScheme == .dark ? .white.opacity(0.10) : .black.opacity(0.08)
    }

    private var avatarFallbackBackground: Color {
        colorScheme == .dark ? .white.opacity(0.16) : .black.opacity(0.08)
    }

    private var avatarFallbackText: Color {
        colorScheme == .dark ? .white.opacity(0.82) : .black.opacity(0.62)
    }
}

private struct GenreSunburstSearchItem: Identifiable, Sendable {
    let id: String
    let node: GenreSunburstNode
    let parentId: String?
    let pathText: String
    let nameLower: String
    let pathLower: String
    let descriptionLower: String
    let exampleLower: String
    let artistLower: String

    init(node: GenreSunburstNode, parentId: String?, pathText: String) {
        self.id = node.id
        self.node = node
        self.parentId = parentId
        self.pathText = pathText
        self.nameLower = node.name.lowercased()
        self.pathLower = node.path.lowercased()
        self.descriptionLower = node.description.lowercased()
        self.exampleLower = node.example.lowercased()
        self.artistLower = node.keyArtists.joined(separator: " ").lowercased()
    }

    func score(for query: String) -> Int {
        var score = 0
        if nameLower == query { score += 1200 }
        if pathLower == query { score += 900 }
        if nameLower.hasPrefix(query) { score += 700 }
        if pathLower.hasPrefix(query) { score += 450 }
        if nameLower.contains(query) { score += 300 }
        if pathLower.contains(query) { score += 220 }
        if descriptionLower.contains(query) { score += 120 }
        if exampleLower.contains(query) { score += 100 }
        if artistLower.contains(query) { score += 100 }
        return score
    }
}

private struct GenreSunburstSearchPanel: View {
    @Environment(\.colorScheme) private var colorScheme
    let items: [GenreSunburstSearchItem]
    let onSelect: (GenreSunburstSearchItem) -> Void

    @State private var text = ""
    @State private var candidates: [GenreSunburstSearchItem] = []
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var searchFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(secondaryText)

                TextField(LT("搜索风格", "Search genres", "ジャンルを検索"), text: $text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(primaryText)
                    .submitLabel(.done)
                    .focused($searchFieldFocused)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button(LT("收起", "Done", "閉じる")) {
                                searchFieldFocused = false
                            }
                        }
                    }

                if !text.isEmpty {
                    Button {
                        text = ""
                        searchFieldFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(secondaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: 560)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(searchFieldBackground)
            )
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(colorScheme == .dark ? 0.32 : 0.58)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(searchStroke, lineWidth: 1)
            )
            .shadow(
                color: colorScheme == .dark ? .clear : Color.black.opacity(0.07),
                radius: colorScheme == .dark ? 0 : 12,
                x: 0,
                y: colorScheme == .dark ? 0 : 6
            )
            .frame(maxWidth: .infinity, alignment: .center)

            if !candidates.isEmpty {
                VStack(spacing: 8) {
                    ForEach(candidates) { item in
                        Button {
                            onSelect(item)
                            text = ""
                            candidates = []
                            searchFieldFocused = false
                        } label: {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.node.name)
                                        .font(.system(size: 14.5, weight: .semibold))
                                        .foregroundStyle(primaryText)
                                        .lineLimit(1)

                                    Text(item.pathText)
                                        .font(.system(size: 11.5, weight: .medium))
                                        .foregroundStyle(secondaryText)
                                        .lineLimit(1)
                                }

                                Spacer(minLength: 8)

                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(accentText)
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 46)
                            .frame(maxWidth: 560)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(candidateBackground)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 6)
        .onChange(of: text) { _, value in
            scheduleSearch(for: value)
        }
        .onDisappear {
            searchTask?.cancel()
        }
    }

    private var primaryText: Color {
        colorScheme == .dark ? .white : Color.black.opacity(0.86)
    }

    private var secondaryText: Color {
        colorScheme == .dark ? .white.opacity(0.58) : Color.black.opacity(0.50)
    }

    private var accentText: Color {
        colorScheme == .dark
            ? Color(red: 0.48, green: 0.88, blue: 1.0)
            : Color(red: 0.10, green: 0.48, blue: 0.78)
    }

    private var searchFieldBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.035) : Color.white.opacity(0.28)
    }

    private var searchStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.54)
    }

    private var candidateBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white.opacity(0.78)
    }

    private func scheduleSearch(for value: String) {
        searchTask?.cancel()
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            candidates = []
            return
        }

        let items = items
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled else { return }

            let query = trimmed.lowercased()
            let result = await Task.detached(priority: .userInitiated) {
                GenreSunburstSearchPanel.search(items: items, query: query)
            }.value

            guard !Task.isCancelled else { return }
            candidates = result
        }
    }

    nonisolated private static func search(items: [GenreSunburstSearchItem], query: String) -> [GenreSunburstSearchItem] {
        items
            .map { item in (item, item.score(for: query)) }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                return lhs.0.node.leafCount > rhs.0.node.leafCount
            }
            .prefix(8)
            .map(\.0)
    }
}

private extension GenreSunburstNode {
    func allDescendants(includeSelf: Bool = true) -> [GenreSunburstNode] {
        var output: [GenreSunburstNode] = []
        if includeSelf { output.append(self) }
        for child in children {
            output.append(contentsOf: child.allDescendants(includeSelf: true))
        }
        return output
    }

    func parentNode(root: GenreSunburstNode) -> GenreSunburstNode? {
        guard let path = root.pathToNode(withId: id), path.count > 1 else { return nil }
        return path[path.count - 2]
    }

    func pathDisplayText(root: GenreSunburstNode) -> String {
        guard let path = root.pathToNode(withId: id) else { return "" }
        let names = path.dropFirst().map(\.name)
        return names.joined(separator: " / ")
    }

    var searchIndex: String {
        [
            name,
            description,
            example,
            wikipediaURL,
            keyArtists.joined(separator: " "),
            path
        ]
        .joined(separator: " ")
        .lowercased()
    }

    func searchScore(for query: String) -> Int {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedQuery.isEmpty else { return 0 }

        let nameLower = name.lowercased()
        let pathLower = path.lowercased()
        let descriptionLower = description.lowercased()
        let exampleLower = example.lowercased()
        let artistLower = keyArtists.joined(separator: " ").lowercased()

        var score = 0
        if nameLower == normalizedQuery { score += 1200 }
        if pathLower == normalizedQuery { score += 900 }
        if nameLower.hasPrefix(normalizedQuery) { score += 700 }
        if pathLower.hasPrefix(normalizedQuery) { score += 450 }
        if nameLower.contains(normalizedQuery) { score += 300 }
        if pathLower.contains(normalizedQuery) { score += 220 }
        if descriptionLower.contains(normalizedQuery) { score += 120 }
        if exampleLower.contains(normalizedQuery) { score += 100 }
        if artistLower.contains(normalizedQuery) { score += 100 }
        return score
    }
}

private struct GenreSunburstNode: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let path: String
    let description: String
    let example: String
    let spotifyTrackURL: String
    let wikipediaURL: String
    let keyArtists: [String]
    let keyArtistBindings: [LearnGenreKeyArtistBinding]
    let children: [GenreSunburstNode]

    init(
        id: String,
        name: String,
        path: String,
        description: String,
        example: String,
        spotifyTrackURL: String,
        wikipediaURL: String,
        keyArtists: [String],
        keyArtistBindings: [LearnGenreKeyArtistBinding] = [],
        children: [GenreSunburstNode]
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.description = description
        self.example = example
        self.spotifyTrackURL = spotifyTrackURL
        self.wikipediaURL = wikipediaURL
        self.keyArtists = keyArtists
        self.keyArtistBindings = keyArtistBindings
        self.children = children
    }

    init(learnNode: LearnGenreNode, parentPath: String) {
        self.id = learnNode.id
        self.name = learnNode.name
        self.path = learnNode.path ?? "\(parentPath)/\(learnNode.id)"
        self.description = learnNode.description
        self.example = learnNode.example ?? ""
        self.spotifyTrackURL = learnNode.spotifyTrackURL ?? ""
        self.wikipediaURL = learnNode.wikipediaURL ?? ""
        self.keyArtists = learnNode.keyArtists ?? []
        self.keyArtistBindings = learnNode.keyArtistBindings ?? []
        self.children = (learnNode.children ?? []).map { GenreSunburstNode(learnNode: $0, parentPath: "\(parentPath)/\(learnNode.id)") }
    }

    var isLeaf: Bool {
        children.isEmpty
    }

    var leafCount: Int {
        if children.isEmpty { return 1 }
        return children.reduce(0) { $0 + $1.leafCount }
    }

    func firstNode(withId targetId: String) -> GenreSunburstNode? {
        if id == targetId { return self }

        for child in children {
            if let match = child.firstNode(withId: targetId) {
                return match
            }
        }

        return nil
    }

    func pathToNode(withId targetId: String) -> [GenreSunburstNode]? {
        if id == targetId { return [self] }

        for child in children {
            if let childPath = child.pathToNode(withId: targetId) {
                return [self] + childPath
            }
        }

        return nil
    }
}

private struct GenreSunburstSegment: Identifiable, Hashable {
    let id: String
    let node: GenreSunburstNode
    let parentId: String?
    let depth: Int
    let x0: Double
    let x1: Double
    let y0: Double
    let y1: Double
    let startAngle: Double
    let endAngle: Double
    let innerRadius: CGFloat
    let outerRadius: CGFloat
    let color: Color

    var midAngle: Double {
        (startAngle + endAngle) / 2
    }

    var angleSpan: Double {
        endAngle - startAngle
    }
}

private struct GenreSunburstFocus: Equatable, Sendable {
    let angleStart: Double
    let angleEnd: Double
    let depthStart: Double
    let depthEnd: Double

    static let root = GenreSunburstFocus(
        angleStart: 0,
        angleEnd: 1,
        depthStart: 0,
        depthEnd: 1
    )
}

private enum GenreSunburstLayout {
    static func partitionSegments(
        root: GenreSunburstNode,
        canvasSize: CGSize,
        focus: GenreSunburstFocus
    ) -> [GenreSunburstSegment] {
        let maxDepth = max(1, maxDepth(from: root))
        let chartRadius = max(10, min(canvasSize.width, canvasSize.height) * 0.485)
        let topLevelPalette = paletteMap(root: root)
        let baseSegments = partition(root: root, maxDepth: maxDepth, topLevelPalette: topLevelPalette)

        return baseSegments.compactMap { segment in
            project(segment, radius: chartRadius, focus: focus)
        }
    }

    static func focus(for nodeId: String?, root: GenreSunburstNode) -> GenreSunburstFocus {
        guard
            let nodeId,
            let segment = partition(
                root: root,
                maxDepth: max(1, maxDepth(from: root)),
                topLevelPalette: paletteMap(root: root)
            ).first(where: { $0.id == nodeId })
        else {
            return .root
        }

        return GenreSunburstFocus(
            angleStart: segment.x0,
            angleEnd: segment.x1,
            depthStart: segment.y0,
            depthEnd: 1
        )
    }

    private static func partition(
        root: GenreSunburstNode,
        maxDepth: Int,
        topLevelPalette: [String: Color]
    ) -> [GenreSunburstSegment] {
        var output: [GenreSunburstSegment] = []
        let totalWeight = Double(root.children.reduce(0) { $0 + $1.leafCount })
        var cursor = 0.0

        for child in root.children {
            let span = totalWeight == 0 ? 0 : Double(child.leafCount) / totalWeight
            appendPartition(
                node: child,
                parentId: root.id,
                root: root,
                depth: 1,
                maxDepth: maxDepth,
                x0: cursor,
                x1: cursor + span,
                topLevelPalette: topLevelPalette,
                output: &output
            )
            cursor += span
        }

        return output
    }

    private static func appendPartition(
        node: GenreSunburstNode,
        parentId: String?,
        root: GenreSunburstNode,
        depth: Int,
        maxDepth: Int,
        x0: Double,
        x1: Double,
        topLevelPalette: [String: Color],
        output: inout [GenreSunburstSegment]
    ) {
        let y0 = Double(depth - 1) / Double(maxDepth)
        let y1 = Double(depth) / Double(maxDepth)
        let topLevelId = root.pathToNode(withId: node.id)?.dropFirst().first?.id ?? node.id

        output.append(
            GenreSunburstSegment(
                id: node.id,
                node: node,
                parentId: parentId,
                depth: depth,
                x0: x0,
                x1: x1,
                y0: y0,
                y1: y1,
                startAngle: 0,
                endAngle: 0,
                innerRadius: 0,
                outerRadius: 0,
                color: topLevelPalette[topLevelId] ?? .gray
            )
        )

        guard !node.children.isEmpty else { return }

        let totalWeight = Double(node.children.reduce(0) { $0 + $1.leafCount })
        var cursor = x0

        for child in node.children {
            let span = totalWeight == 0 ? 0 : (Double(child.leafCount) / totalWeight) * (x1 - x0)
            appendPartition(
                node: child,
                parentId: node.id,
                root: root,
                depth: depth + 1,
                maxDepth: maxDepth,
                x0: cursor,
                x1: cursor + span,
                topLevelPalette: topLevelPalette,
                output: &output
            )
            cursor += span
        }
    }

    private static func project(
        _ segment: GenreSunburstSegment,
        radius: CGFloat,
        focus: GenreSunburstFocus
    ) -> GenreSunburstSegment? {
        let angleSpan = focus.angleEnd - focus.angleStart
        let depthSpan = focus.depthEnd - focus.depthStart
        guard angleSpan > 0, depthSpan > 0 else { return nil }

        let x0 = (segment.x0 - focus.angleStart) / angleSpan
        let x1 = (segment.x1 - focus.angleStart) / angleSpan
        let y0 = (segment.y0 - focus.depthStart) / depthSpan
        let y1 = (segment.y1 - focus.depthStart) / depthSpan

        if x1 <= 0 || x0 >= 1 || y1 <= 0 || y0 >= 1 {
            return nil
        }

        let clampedX0 = max(0, min(1, x0))
        let clampedX1 = max(0, min(1, x1))
        let clampedY0 = max(0, min(1, y0))
        let clampedY1 = max(0, min(1, y1))

        guard clampedX1 > clampedX0, clampedY1 > clampedY0 else { return nil }

        let startAngle = clampedX0 * Double.pi * 2 - Double.pi / 2
        let endAngle = clampedX1 * Double.pi * 2 - Double.pi / 2
        let centerRadius = radius * 0.16
        let drawableRadius = radius - centerRadius
        let innerRadius = centerRadius + CGFloat(sqrt(clampedY0)) * drawableRadius
        let outerRadius = centerRadius + CGFloat(sqrt(clampedY1)) * drawableRadius

        return GenreSunburstSegment(
            id: segment.id,
            node: segment.node,
            parentId: segment.parentId,
            depth: segment.depth,
            x0: segment.x0,
            x1: segment.x1,
            y0: segment.y0,
            y1: segment.y1,
            startAngle: startAngle,
            endAngle: endAngle,
            innerRadius: innerRadius,
            outerRadius: outerRadius,
            color: segment.color
        )
    }

    private static func maxDepth(from node: GenreSunburstNode) -> Int {
        if node.children.isEmpty { return 0 }
        return 1 + (node.children.map(maxDepth).max() ?? 0)
    }

    private static func paletteMap(root: GenreSunburstNode) -> [String: Color] {
        let colors: [Color] = [
            Color(red: 0.18, green: 0.72, blue: 0.96),
            Color(red: 0.94, green: 0.30, blue: 0.74),
            Color(red: 0.46, green: 0.86, blue: 0.40),
            Color(red: 0.96, green: 0.54, blue: 0.18),
            Color(red: 0.48, green: 0.42, blue: 0.92),
            Color(red: 0.08, green: 0.82, blue: 0.70),
            Color(red: 0.90, green: 0.25, blue: 0.35),
            Color(red: 0.72, green: 0.62, blue: 0.96),
            Color(red: 0.86, green: 0.78, blue: 0.28),
            Color(red: 0.30, green: 0.48, blue: 0.92)
        ]

        return Dictionary(uniqueKeysWithValues: root.children.enumerated().map { index, node in
            (node.id, colors[index % colors.count])
        })
    }
}

private enum GenreSunburstHitTesting {
    static func hitSegment(
        at point: CGPoint,
        in size: CGSize,
        segments: [GenreSunburstSegment]
    ) -> GenreSunburstSegment? {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = point.x - center.x
        let dy = point.y - center.y
        let radius = sqrt(dx * dx + dy * dy)
        let angle = projectedAngle(atan2(dy, dx))

        return segments
            .sorted { $0.depth > $1.depth }
            .first { segment in
                radius >= segment.innerRadius &&
                radius <= segment.outerRadius &&
                angle >= segment.startAngle &&
                angle <= segment.endAngle
            }
    }

    static func isCenterTap(
        at point: CGPoint,
        in size: CGSize,
        segments: [GenreSunburstSegment]
    ) -> Bool {
        guard let innerRadius = segments.map(\.innerRadius).min() else { return false }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = point.x - center.x
        let dy = point.y - center.y
        return sqrt(dx * dx + dy * dy) < innerRadius
    }

    private static func projectedAngle(_ angle: Double) -> Double {
        var value = angle
        while value < -Double.pi / 2 { value += Double.pi * 2 }
        while value > Double.pi * 1.5 { value -= Double.pi * 2 }
        return value
    }
}

private struct GenreSunburstStaticRecordBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outerRadius = max(10, min(size.width, size.height) * 0.485)
            let centerRadius = outerRadius * 0.16
            let discRect = CGRect(
                x: center.x - outerRadius,
                y: center.y - outerRadius,
                width: outerRadius * 2,
                height: outerRadius * 2
            )
            let disc = Path(ellipseIn: discRect)

            context.fill(disc, with: .color(discFill))
            context.stroke(disc, with: .color(discStroke), lineWidth: 1)

            var radius = centerRadius + 7
            while radius < outerRadius - 4 {
                let rect = CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                let groove = Path(ellipseIn: rect)
                let alternatingOpacity = Int(radius / 8).isMultiple(of: 2) ? 0.11 : 0.055
                context.stroke(
                    groove,
                    with: .color(grooveColor.opacity(alternatingOpacity)),
                    lineWidth: 0.4
                )
                radius += 8
            }
        }
    }

    private var discFill: Color {
        colorScheme == .dark
            ? Color(red: 0.018, green: 0.02, blue: 0.03)
            : Color(red: 0.77, green: 0.79, blue: 0.82)
    }

    private var discStroke: Color {
        colorScheme == .dark ? .white.opacity(0.16) : Color(red: 0.24, green: 0.26, blue: 0.30).opacity(0.22)
    }

    private var grooveColor: Color {
        colorScheme == .dark
            ? Color(red: 0.88, green: 0.96, blue: 1.0)
            : Color(red: 0.16, green: 0.18, blue: 0.22)
    }
}

private struct GenreSunburstCanvasView: View {
    @Environment(\.colorScheme) private var colorScheme
    let root: GenreSunburstNode
    @Binding var focusedId: String?
    @Binding var selectedNode: GenreSunburstNode?

    @State private var currentFocus: GenreSunburstFocus = .root
    @State private var fromFocus: GenreSunburstFocus = .root
    @State private var toFocus: GenreSunburstFocus = .root
    @State private var animationStart: Date?
    @State private var lastCanvasSize: CGSize = .zero

    private let animationDuration: TimeInterval = 0.4
    private let labelStrokeWidth: CGFloat = 5

    private struct LabelPlacement {
        let segment: GenreSunburstSegment
        let lines: [String]
        let point: CGPoint
        let fontSize: CGFloat
        let rotation: Double
        let calloutStart: CGPoint?
        let calloutBend: CGPoint?
        let calloutEnd: CGPoint?
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                GenreSunburstStaticRecordBackground()

                if animationStart != nil {
                    TimelineView(.animation) { timeline in
                        Canvas { context, size in
                            let focus = focusForFrame(at: timeline.date)
                            renderSunburst(in: size, focus: focus, context: &context)
                        }
                    }
                } else {
                    Canvas { context, size in
                        renderSunburst(in: size, focus: currentFocus, context: &context)
                    }
                }
            }
            .contentShape(Rectangle())
            .onAppear {
                lastCanvasSize = geometry.size
                currentFocus = GenreSunburstLayout.focus(for: focusedId, root: root)
                fromFocus = currentFocus
                toFocus = currentFocus
            }
            .onChange(of: geometry.size) { _, newSize in
                lastCanvasSize = newSize
            }
            .onChange(of: focusedId) { _, newFocusId in
                guard GenreSunburstLayout.focus(for: newFocusId, root: root) != toFocus else { return }
                let selected = newFocusId.flatMap { root.firstNode(withId: $0) }
                transition(to: newFocusId, selected: selected, updateBinding: false)
            }
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { value in
                        handleTap(value.location, size: geometry.size)
                    }
            )
        }
    }

    private func renderSunburst(
        in size: CGSize,
        focus: GenreSunburstFocus,
        context: inout GraphicsContext
    ) {
        let segments = GenreSunburstLayout.partitionSegments(
            root: root,
            canvasSize: size,
            focus: focus
        )
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        for segment in segments {
            drawSegment(segment, center: center, context: &context)
        }

        drawCenterLabel(context: &context, center: center, size: size, segments: segments)
        if animationStart == nil {
            drawLabels(context: &context, center: center, size: size, segments: segments)
        }
    }

    private func handleTap(_ point: CGPoint, size: CGSize) {
        let focus = animationStart == nil ? currentFocus : interpolatedFocus(now: Date())
        let segments = GenreSunburstLayout.partitionSegments(root: root, canvasSize: size, focus: focus)

        if GenreSunburstHitTesting.isCenterTap(at: point, in: size, segments: segments) {
            goToParent()
            return
        }

        guard let segment = GenreSunburstHitTesting.hitSegment(at: point, in: size, segments: segments) else {
            return
        }

        let targetId = nextFocusId(forTapped: segment.node.id)
        let targetNode = targetId.flatMap { root.firstNode(withId: $0) }
        transition(to: targetId, selected: targetNode)
    }

    private func goToParent() {
        guard let currentFocusId = focusedId else {
            selectedNode = nil
            return
        }

        let path = root.pathToNode(withId: currentFocusId) ?? []
        if path.count > 2 {
            transition(to: path[path.count - 2].id, selected: path[path.count - 2])
        } else {
            transition(to: nil, selected: nil)
        }
    }

    private func transition(
        to newFocusId: String?,
        selected newSelectedNode: GenreSunburstNode?,
        updateBinding: Bool = true
    ) {
        fromFocus = animationStart == nil ? currentFocus : interpolatedFocus(now: Date())
        toFocus = GenreSunburstLayout.focus(for: newFocusId, root: root)
        if updateBinding {
            focusedId = newFocusId
        }
        selectedNode = newSelectedNode
        animationStart = Date()
    }

    private func focusForFrame(at date: Date) -> GenreSunburstFocus {
        guard let animationStart else {
            return currentFocus
        }

        let elapsed = date.timeIntervalSince(animationStart)
        let rawProgress = min(1, elapsed / animationDuration)
        let eased = easeInOutCubic(CGFloat(rawProgress))
        let focus = interpolate(from: fromFocus, to: toFocus, progress: eased)

        if rawProgress >= 1 {
            DispatchQueue.main.async {
                currentFocus = toFocus
                self.animationStart = nil
            }
        }

        return focus
    }

    private func interpolatedFocus(now: Date) -> GenreSunburstFocus {
        guard let animationStart else { return currentFocus }
        let elapsed = now.timeIntervalSince(animationStart)
        let rawProgress = min(1, elapsed / animationDuration)
        let eased = easeInOutCubic(CGFloat(rawProgress))
        return interpolate(from: fromFocus, to: toFocus, progress: eased)
    }

    private func interpolate(from: GenreSunburstFocus, to: GenreSunburstFocus, progress: CGFloat) -> GenreSunburstFocus {
        GenreSunburstFocus(
            angleStart: lerp(from.angleStart, to.angleStart, progress),
            angleEnd: lerp(from.angleEnd, to.angleEnd, progress),
            depthStart: lerp(from.depthStart, to.depthStart, progress),
            depthEnd: lerp(from.depthEnd, to.depthEnd, progress)
        )
    }

    private func lerp(_ from: Double, _ to: Double, _ progress: CGFloat) -> Double {
        from + (to - from) * Double(progress)
    }

    private func easeInOutCubic(_ value: CGFloat) -> CGFloat {
        value < 0.5
            ? 4 * value * value * value
            : 1 - pow(-2 * value + 2, 3) / 2
    }

    private func labelFontSize(for size: CGSize) -> CGFloat {
        min(13, max(9.5, min(size.width, size.height) * 0.024))
    }

    private func calloutFontSize(for size: CGSize) -> CGFloat {
        min(11.5, max(9, min(size.width, size.height) * 0.0205))
    }

    private func opacity(for segment: GenreSunburstSegment) -> Double {
        guard let selectedNode else { return 0.82 }
        return segment.node.id == selectedNode.id ? 0.96 : 0.66
    }

    private func strokeColor(for segment: GenreSunburstSegment) -> Color {
        if segment.node.id == selectedNode?.id {
            return colorScheme == .dark
                ? Color(red: 0.84, green: 0.98, blue: 1.0).opacity(0.88)
                : Color.black.opacity(0.46)
        }

        return colorScheme == .dark
            ? Color(red: 0.82, green: 0.95, blue: 1.0).opacity(0.18)
            : Color.black.opacity(0.16)
    }

    private func strokeWidth(for segment: GenreSunburstSegment) -> CGFloat {
        segment.node.id == selectedNode?.id ? 1.4 : 0.65
    }

    private func drawSegment(_ segment: GenreSunburstSegment, center: CGPoint, context: inout GraphicsContext) {
        let path = segmentPath(segment, center: center)
        let selected = segment.node.id == selectedNode?.id

        context.fill(path, with: .color(segment.color.opacity(selected ? 0.92 : opacity(for: segment))))
        context.stroke(
            path,
            with: .color(strokeColor(for: segment)),
            lineWidth: strokeWidth(for: segment)
        )
    }

    private func maxSegmentOuterRadius(in segments: [GenreSunburstSegment], fallbackSize size: CGSize) -> CGFloat {
        segments.map(\.outerRadius).max() ?? min(size.width, size.height) * 0.44
    }

    private func segmentPath(_ segment: GenreSunburstSegment, center: CGPoint) -> Path {
        var path = Path()
        path.addArc(
            center: center,
            radius: segment.outerRadius,
            startAngle: .radians(segment.startAngle),
            endAngle: .radians(segment.endAngle),
            clockwise: false
        )
        path.addArc(
            center: center,
            radius: segment.innerRadius,
            startAngle: .radians(segment.endAngle),
            endAngle: .radians(segment.startAngle),
            clockwise: true
        )
        path.closeSubpath()
        return path
    }

    private func drawLabels(
        context: inout GraphicsContext,
        center: CGPoint,
        size: CGSize,
        segments: [GenreSunburstSegment]
    ) {
        for placement in labelPlacements(center: center, size: size, segments: segments) {
            if let start = placement.calloutStart, let bend = placement.calloutBend, let end = placement.calloutEnd {
                var line = Path()
                line.move(to: start)
                line.addLine(to: bend)
                line.addLine(to: end)
                context.stroke(line, with: .color(labelGuideColor), lineWidth: 0.8)
            }

            let lineHeight = placement.fontSize * 1.08
            let startY = -lineHeight * CGFloat(placement.lines.count - 1) / 2
            context.drawLayer { layer in
                layer.translateBy(x: placement.point.x, y: placement.point.y)
                layer.rotate(by: .radians(placement.rotation))
                for (index, line) in placement.lines.enumerated() {
                    let calloutOffset = placement.calloutEnd == nil ? CGFloat(0) : -placement.fontSize * 0.58
                    let y = startY + CGFloat(index) * lineHeight + calloutOffset
                    let shadowText = labelText(line, size: placement.fontSize, isShadow: true)
                    let text = labelText(line, size: placement.fontSize, isShadow: false)
                    layer.draw(shadowText, at: CGPoint(x: 0, y: y + 1), anchor: .center)
                    layer.draw(text, at: CGPoint(x: 0, y: y), anchor: .center)
                }
            }
        }
    }

    private func drawCenterLabel(
        context: inout GraphicsContext,
        center: CGPoint,
        size: CGSize,
        segments: [GenreSunburstSegment]
    ) {
        let lines = centerLabelLines()
        let fontSize = centerLabelFontSize(for: size, lineCount: lines.count)
        let lineHeight = fontSize * 1.12
        let startY = center.y - lineHeight * CGFloat(lines.count - 1) / 2
        let centerRadius = centerLabelRadius(for: size, segments: segments)
        let labelRect = CGRect(
            x: center.x - centerRadius,
            y: center.y - centerRadius,
            width: centerRadius * 2,
            height: centerRadius * 2
        )
        let labelDisc = Path(ellipseIn: labelRect)
        let spindleRadius = max(6, centerRadius * 0.18)
        let spindleRect = CGRect(
            x: center.x - spindleRadius,
            y: center.y - spindleRadius,
            width: spindleRadius * 2,
            height: spindleRadius * 2
        )

        context.fill(labelDisc, with: .color(Color(red: 0.08, green: 0.11, blue: 0.18).opacity(0.96)))

        context.stroke(labelDisc, with: .color(.white.opacity(0.34)), lineWidth: 0.85)
        context.stroke(
            Path(ellipseIn: labelRect.insetBy(dx: centerRadius * 0.18, dy: centerRadius * 0.18)),
            with: .color(.white.opacity(0.18)),
            lineWidth: 0.65
        )
        context.fill(Path(ellipseIn: spindleRect), with: .color(Color(red: 0.018, green: 0.02, blue: 0.028)))
        context.stroke(Path(ellipseIn: spindleRect), with: .color(.white.opacity(0.24)), lineWidth: 0.55)

        for (index, line) in lines.enumerated() {
            let y = startY + CGFloat(index) * lineHeight
            let title = Text(line)
                .font(.system(size: fontSize, weight: .bold))
                .foregroundStyle(Color(red: 0.92, green: 0.98, blue: 1.0))
            context.draw(title, at: CGPoint(x: center.x, y: y), anchor: .center)
        }
    }

    private func centerLabelRadius(for size: CGSize, segments: [GenreSunburstSegment]) -> CGFloat {
        let projectedInnerRadius = segments.map(\.innerRadius).min()
        let fallback = min(size.width, size.height) * 0.075
        return max(34, (projectedInnerRadius ?? fallback) * 0.86)
    }

    private func labelPlacements(
        center: CGPoint,
        size: CGSize,
        segments: [GenreSunburstSegment]
    ) -> [LabelPlacement] {
        let inlineLabelFontSize = labelFontSize(for: size)
        let calloutLabelFontSize = calloutFontSize(for: size)
        var calloutPlacements: [LabelPlacement] = []
        let inlinePlacements = segments.compactMap { segment -> LabelPlacement? in
            guard labeledRelativeDepth(for: segment.node.id) != nil else { return nil }

            let lines = [segment.node.name]
            let radius = inlineLabelRadius(for: segment)
            let inlinePoint = CGPoint(
                x: center.x + cos(segment.midAngle) * radius,
                y: center.y + sin(segment.midAngle) * radius
            )

            if angularLabelFitsInside(segment, fontSize: inlineLabelFontSize) {
                return LabelPlacement(
                    segment: segment,
                    lines: lines,
                    point: inlinePoint,
                    fontSize: inlineLabelFontSize,
                    rotation: angularLabelRotation(for: segment),
                    calloutStart: nil,
                    calloutBend: nil,
                    calloutEnd: nil
                )
            }

            if radialLabelFitsInside(segment, fontSize: inlineLabelFontSize) {
                return LabelPlacement(
                    segment: segment,
                    lines: lines,
                    point: inlinePoint,
                    fontSize: inlineLabelFontSize,
                    rotation: radialLabelRotation(for: segment),
                    calloutStart: nil,
                    calloutBend: nil,
                    calloutEnd: nil
                )
            }

            let side: CGFloat = cos(segment.midAngle) >= 0 ? 1 : -1
            let radialMid = (segment.innerRadius + segment.outerRadius) / 2
            let start = CGPoint(
                x: center.x + cos(segment.midAngle) * radialMid,
                y: center.y + sin(segment.midAngle) * radialMid
            )
            let bendRadius = min(max(size.width, size.height) * 0.48, segment.outerRadius + 20)
            let bend = CGPoint(
                x: center.x + cos(segment.midAngle) * bendRadius,
                y: center.y + sin(segment.midAngle) * bendRadius
            )
            let lineLength = max(44, min(96, size.width * 0.08))
            let endX = min(max(bend.x + side * lineLength, 48), size.width - 48)
            let lineY = min(max(bend.y, 24), size.height - 24)
            let end = CGPoint(x: endX, y: lineY)

            calloutPlacements.append(LabelPlacement(
                segment: segment,
                lines: labelLines(for: segment.node.name),
                point: CGPoint(x: (bend.x + endX) / 2, y: lineY),
                fontSize: calloutLabelFontSize,
                rotation: 0,
                calloutStart: start,
                calloutBend: CGPoint(x: bend.x, y: lineY),
                calloutEnd: end
            ))
            return nil
        }

        return inlinePlacements + resolvedCalloutCollisions(calloutPlacements, canvasHeight: size.height)
    }

    private func angularLabelFitsInside(_ segment: GenreSunburstSegment, fontSize: CGFloat) -> Bool {
        let midRadius = (segment.innerRadius + segment.outerRadius) / 2
        let availableAngularSpace = CGFloat(segment.angleSpan) * midRadius
        let textWidth = estimatedLabelWidth(segment.node.name, fontSize: fontSize) + labelStrokeWidth
        return textWidth < availableAngularSpace
    }

    private func radialLabelFitsInside(_ segment: GenreSunburstSegment, fontSize: CGFloat) -> Bool {
        let midRadius = inlineLabelRadius(for: segment)
        let availableAngularHeight = CGFloat(segment.angleSpan) * midRadius
        guard availableAngularHeight >= fontSize + labelStrokeWidth + 4 else { return false }

        let availableRadialSpace = segment.outerRadius - segment.innerRadius
        let textWidth = estimatedLabelWidth(segment.node.name, fontSize: fontSize) + labelStrokeWidth
        return textWidth + 8 < availableRadialSpace
    }

    private func inlineLabelRadius(for segment: GenreSunburstSegment) -> CGFloat {
        (segment.innerRadius + segment.outerRadius) / 2
    }

    private func labelLines(for name: String) -> [String] {
        let words = name.split(separator: " ").map(String.init)
        guard words.count > 2 else { return [name] }

        let totalCharacters = words.reduce(0) { $0 + $1.count }
        var firstLine: [String] = []
        var secondLine = words
        var firstCount = 0

        while secondLine.count > 1 && firstCount < totalCharacters / 2 {
            let word = secondLine.removeFirst()
            firstLine.append(word)
            firstCount += word.count
        }

        return [firstLine.joined(separator: " "), secondLine.joined(separator: " ")]
    }

    private func estimatedLabelWidth(_ text: String, fontSize: CGFloat) -> CGFloat {
        CGFloat(text.count) * fontSize * 0.56
    }

    private func resolvedCalloutCollisions(
        _ placements: [LabelPlacement],
        canvasHeight: CGFloat
    ) -> [LabelPlacement] {
        let left = resolveCalloutSide(
            placements.filter { $0.point.x < lastCanvasSize.width / 2 },
            canvasHeight: canvasHeight
        )
        let right = resolveCalloutSide(
            placements.filter { $0.point.x >= lastCanvasSize.width / 2 },
            canvasHeight: canvasHeight
        )
        return left + right
    }

    private func resolveCalloutSide(_ placements: [LabelPlacement], canvasHeight: CGFloat) -> [LabelPlacement] {
        var nextY: CGFloat = 22
        return placements
            .sorted { $0.point.y < $1.point.y }
            .map { placement in
                let minGap = placement.fontSize * CGFloat(placement.lines.count) * 1.12 + 6
                let y = min(max(placement.point.y, nextY), canvasHeight - 22)
                nextY = y + minGap
                return LabelPlacement(
                    segment: placement.segment,
                    lines: placement.lines,
                    point: CGPoint(x: placement.point.x, y: y),
                    fontSize: placement.fontSize,
                    rotation: placement.rotation,
                    calloutStart: placement.calloutStart,
                    calloutBend: placement.calloutBend.map { CGPoint(x: $0.x, y: y) },
                    calloutEnd: placement.calloutEnd.map { CGPoint(x: $0.x, y: y) }
                )
            }
    }

    private func centerLabelFontSize(for size: CGSize, lineCount: Int) -> CGFloat {
        let baseSize = min(18, max(12, min(size.width, size.height) * 0.026))
        return lineCount > 1 ? baseSize * 0.92 : baseSize
    }

    private func centerLabelLines() -> [String] {
        guard let focusedId, let node = root.firstNode(withId: focusedId) else {
            return ["EDM"]
        }

        let name = node.name
        let words = name.split(separator: " ").map(String.init)
        guard words.count == 2 else { return [name] }
        return words
    }

    private func labelText(_ value: String, size: CGFloat, isShadow: Bool) -> Text {
        Text(value)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(labelForeground(isShadow: isShadow))
    }

    private var labelGuideColor: Color {
        colorScheme == .dark ? .white.opacity(0.52) : .black.opacity(0.42)
    }

    private func labelForeground(isShadow: Bool) -> Color {
        if colorScheme == .dark {
            return isShadow ? .black.opacity(0.72) : Color(red: 0.95, green: 0.98, blue: 1.0)
        }

        return isShadow ? .white.opacity(0.35) : .black.opacity(0.82)
    }

    private func angularLabelRotation(for segment: GenreSunburstSegment) -> Double {
        let middleAngle = segment.midAngle
        let invertDirection = middleAngle > 0 && middleAngle < Double.pi
        let tangentAngle = invertDirection ? middleAngle - Double.pi / 2 : middleAngle + Double.pi / 2
        return normalizedReadableAngle(tangentAngle)
    }

    private func radialLabelRotation(for segment: GenreSunburstSegment) -> Double {
        normalizedReadableAngle(segment.midAngle)
    }

    private func normalizedReadableAngle(_ angle: Double) -> Double {
        var value = angle.truncatingRemainder(dividingBy: Double.pi * 2)
        if value > Double.pi { value -= Double.pi * 2 }
        if value < -Double.pi { value += Double.pi * 2 }
        if value > Double.pi / 2 { value -= Double.pi }
        if value < -Double.pi / 2 { value += Double.pi }
        return value
    }

    private func labeledRelativeDepth(for nodeId: String) -> Int? {
        let focusPath = focusPath()
        guard let nodePath = root.pathToNode(withId: nodeId), nodePath.count > focusPath.count else {
            return nil
        }

        for index in focusPath.indices where focusPath[index].id != nodePath[index].id {
            return nil
        }

        let relativeDepth = nodePath.count - focusPath.count
        return relativeDepth == 1 ? relativeDepth : nil
    }

    private func focusPath() -> [GenreSunburstNode] {
        guard let focusedId, let path = root.pathToNode(withId: focusedId) else {
            return [root]
        }

        return path
    }

    private func nextFocusId(forTapped nodeId: String) -> String? {
        let focusPath = focusPath()
        guard let nodePath = root.pathToNode(withId: nodeId), nodePath.count > focusPath.count else {
            return focusedId
        }

        for index in focusPath.indices where focusPath[index].id != nodePath[index].id {
            return focusedId
        }

        return nodePath[focusPath.count].id
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
        case .rankings: return LT("DJ 榜单", "DJ Rankings", "DJランキング")
        case .festivals: return LT("主办方", "Organizers", "主催")
        case .labels: return LT("厂牌", "Labels", "レーベル")
        case .genres: return LT("流派树", "Genre Tree", "ジャンルツリー")
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
                    Button(LT("清空", "Clear", "クリア")) {
                        onClear()
                    }
                    .buttonStyle(.plain)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.accent)
                }
                Button(LT("完成", "完成", "完了")) {
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
        case .soundcloudFollowers: return LT("热度", "Popularity", "人気")
        case .likes: return "Likes"
        case .name: return LT("名称", "Name", "名称")
        case .nation: return LT("国家", "Country", "国")
        case .latestRelease: return LT("发布时间文本", "Release Time Text", "公開日時テキスト")
        case .createdAt: return LT("入库时间", "Created At", "登録日時")
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
        return nation.isEmpty ? LT("厂牌信息", "Label info", "レーベル情報") : nation
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
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var appContainer: AppContainer

    let label: LearnLabel

    @State private var previewImage: LearnLabelPreviewImage?
    @State private var avatarLuminance: CGFloat?
    @State private var shareMorePresentation: LabelCardSharePresentation?
    @State private var isShareMorePanelVisible = false
    @State private var fullChatSharePresentation: LabelCardSharePresentation?
    @State private var reportTarget: ReportSheetTarget?
    @State private var errorMessage: String?

    private var shareLinkCoordinator: ShareLinkCoordinator {
        ShareLinkCoordinator(repository: AppEnvironment.makeShareLinkRepository())
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Color.clear
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .overlay {
                        Button {
                            openPreview(urlString: label.backgroundUrl, title: LT("\(label.name) 背景图", "\(label.name) banner", "\(label.name) の背景画像"))
                        } label: {
                            headerBanner
                        }
                        .buttonStyle(.plain)
                    }
                    .clipped()

                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 14) {
                        Button {
                            openPreview(urlString: label.avatarUrl, title: LT("\(label.name) 头像", "\(label.name) avatar", "\(label.name) のアバター"))
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
                            Text(LT("Genres", "Genres", "ジャンル"))
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
                        LearnLabelInfoRow(title: LT("国家", "Country", "国"), value: label.nation)
                        LearnLabelInfoRow(title: LT("地区/时期", "Region / Era", "地域 / 時期"), value: label.locationPeriod)
                        LearnLabelInfoRow(title: LT("联系邮箱", "Contact Email", "連絡先メール"), value: label.generalContactEmail)
                        LearnLabelInfoRow(title: LT("Demo 提交", "Demo Submission", "Demo提出"), value: label.demoSubmissionDisplay ?? label.demoSubmissionUrl)
                        if hasFoundedAtDisplay {
                            LearnLabelInfoRow(title: LT("创始时间", "Founded At", "創設日時"), value: foundedAtDisplay)
                        }
                    }

                    linksSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(RaverTheme.background)
        .raverSystemNavigation(title: LT("厂牌详情", "厂牌详情", "レーベル詳細"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    shareMorePresentation = LabelCardSharePresentation(
                        payload: makeLabelShareCardPayload()
                    )
                    isShareMorePanelVisible = false
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                        .frame(width: 36, height: 36)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .navigationDestination(item: $previewImage) { item in
            LearnLabelImagePreviewView(item: item)
        }
        .sheet(item: $fullChatSharePresentation) { presentation in
            ChatShareSheet(
                loadConversations: {
                    try await loadSharePanelConversations()
                },
                onShareToConversation: { conversation in
                    try await sendSharePayload(
                        presentation.payload,
                        to: conversation,
                        note: nil
                    )
                }
            ) { conversation in
                showWidgetStatusBanner(
                    message: LT("已分享到 \(conversation.title)", "Shared to \(conversation.title)", "\(conversation.title) に共有しました"),
                    conversation: conversation
                )
            } preview: {
                LabelSharePreviewCard(payload: presentation.payload)
            }
            .presentationDetents([.fraction(0.76), .large])
        }
        .sheet(item: $reportTarget) { target in
            ReportSheet(target: target) { _, _ in
                showWidgetStatusBanner(message: LT("举报已提交", "Report submitted", "報告を送信しました"))
            }
            .environmentObject(appState)
            .presentationDetents([.large])
        }
        .task(id: label.avatarUrl ?? "") {
            await resolveAvatarLuminance()
        }
        .alert(LT("提示", "Notice", "お知らせ"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(LT("确定", "OK", "OK"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .overlay {
            if let presentation = shareMorePresentation {
                SharePanelOverlay(
                    isVisible: isShareMorePanelVisible,
                    onBackdropTap: { dismissShareMorePanel() }
                ) {
                    ShareActionPanel(
                        primaryActions: sharePrimaryActions(),
                        quickActions: shareMoreQuickActions(),
                        loadConversations: {
                            try await loadSharePanelConversations()
                        },
                        onSendToConversation: { conversation, note in
                            try await sendSharePayload(
                                presentation.payload,
                                to: conversation,
                                note: note
                            )
                        },
                        onDismiss: {
                            dismissShareMorePanel()
                        }
                    ) { conversation in
                        showWidgetStatusBanner(
                            message: LT("已分享到 \(conversation.title)", "Shared to \(conversation.title)", "\(conversation.title) に共有しました"),
                            conversation: conversation
                        )
                    } onMoreChats: {
                        dismissShareMorePanel {
                            fullChatSharePresentation = presentation
                        }
                    }
                }
                .onAppear {
                    withAnimation(.sharePanelPresentSpring) {
                        isShareMorePanelVisible = true
                    }
                }
            }
        }
        .operationBannerHost()
        .animation(.sharePanelPresentSpring, value: isShareMorePanelVisible)
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
                            Text(LT("创始人", "创始人", "創設者"))
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
                        Text(LT("创始人", "创始人", "創設者"))
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
                Text(LT("Links", "Links", "リンク"))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
                if let url = destinationURL(label.facebookUrl) {
                    LearnLabelExternalLinkRow(icon: "person.2.fill", title: "Facebook", url: url)
                }
                if let url = destinationURL(label.soundcloudUrl) {
                    LearnLabelExternalLinkRow(icon: "waveform", title: "SoundCloud", url: url)
                }
                if let url = destinationURL(label.musicPurchaseUrl) {
                    LearnLabelExternalLinkRow(icon: "cart.fill", title: LT("音乐资产购买", "Music Asset Purchase", "音楽アセット購入"), url: url)
                }
                if let url = destinationURL(label.officialWebsiteUrl) {
                    LearnLabelExternalLinkRow(icon: "globe", title: LT("官网", "Official", "公式サイト"), url: url)
                }
                if let url = destinationURL(label.demoSubmissionUrl) {
                    LearnLabelExternalLinkRow(icon: "paperplane.fill", title: LT("Demo 提交", "Demo Submission", "Demo提出"), url: url)
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

    private func dismissShareMorePanel(after: (() -> Void)? = nil) {
        withAnimation(.sharePanelDismissSpring) {
            isShareMorePanelVisible = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            guard !isShareMorePanelVisible else { return }
            shareMorePresentation = nil
            after?()
        }
    }

    private func showWidgetStatusBanner(message: String, conversation: Conversation? = nil) {
        OperationBannerCenter.shared.success(
            message,
            action: conversation.map { .appRoute(.conversation(target: .fromConversation($0))) } ?? .none
        )
    }

    private func makeLabelShareCardPayload() -> LabelShareCardPayload {
        let coverImageURL = AppConfig.resolvedURLString(label.backgroundUrl)
            ?? AppConfig.resolvedURLString(label.avatarUrl)
        let genreText = displayGenres.prefix(3).joined(separator: " / ").nilIfBlank
        return LabelShareCardPayload(
            labelID: label.id,
            labelName: label.name,
            country: label.nation?.nilIfBlank,
            genreText: genreText,
            coverImageURL: coverImageURL,
            badgeText: LT("厂牌", "Label", "レーベル")
        )
    }

    private func shareTarget() -> ShareTarget {
        let canonicalURL = "https://ravehub.top/label/\(label.id)"
        let coverImageURL = AppConfig.resolvedURLString(label.backgroundUrl)
            ?? AppConfig.resolvedURLString(label.avatarUrl)
        let subtitle = [
            label.nation?.nilIfBlank,
            displayGenres.prefix(3).isEmpty ? nil : displayGenres.prefix(3).joined(separator: " / ").nilIfBlank
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: " · ")
        return ShareTarget(
            type: .label,
            id: label.id,
            title: label.name,
            subtitle: subtitle.isEmpty ? nil : subtitle,
            imageURL: coverImageURL,
            canonicalURL: canonicalURL,
            deepLink: "raver://label/\(label.id)",
            fallbackURL: canonicalURL,
            previewType: "content_card",
            visibility: "public"
        )
    }

    private func loadSharePanelConversations() async throws -> [Conversation] {
        async let directs = appContainer.shareMessageRepository.fetchConversations(type: .direct)
        async let groups = appContainer.shareMessageRepository.fetchConversations(type: .group)
        let merged = try await directs + groups
        let deduped = merged.reduce(into: [String: Conversation]()) { partialResult, conversation in
            partialResult[conversation.id] = conversation
        }
        return deduped.values.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned && !$1.isPinned }
            return $0.updatedAt > $1.updatedAt
        }
    }

    private func sendSharePayload(
        _ payload: LabelShareCardPayload,
        to conversation: Conversation,
        note: String?
    ) async throws {
        _ = try await appContainer.shareMessageRepository.sendLabelCardMessage(
            conversationID: conversation.id,
            payload: payload
        )

        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedNote.isEmpty {
            _ = try await appContainer.shareMessageRepository.sendMessage(
                conversationID: conversation.id,
                content: trimmedNote
            )
        }
    }

    private func sharePrimaryActions() -> [SharePanelPrimaryAction] {
        [
            SharePanelPrimaryAction(
                title: "微信",
                systemImage: "message.circle.fill",
                accentColor: Color(red: 0.18, green: 0.76, blue: 0.35)
            ) {
                errorMessage = LT("微信分享接口待接入。", "WeChat share hook is not connected yet.", "WeChat共有連携は未接続です。")
            },
            SharePanelPrimaryAction(
                title: "Instagram",
                systemImage: "camera.circle.fill",
                accentColor: Color(red: 0.91, green: 0.30, blue: 0.48)
            ) {
                errorMessage = LT("Instagram 分享接口待接入。", "Instagram share hook is not connected yet.", "Instagram共有連携は未接続です。")
            },
            SharePanelPrimaryAction(
                title: "复制链接",
                systemImage: "link.circle.fill",
                accentColor: Color(red: 0.30, green: 0.67, blue: 0.97)
            ) {
                Task { await copyLabelShareLink() }
            }
        ]
    }

    private func shareMoreQuickActions() -> [SharePanelQuickAction] {
        var actions: [SharePanelQuickAction] = []

        actions.append(
            SharePanelQuickAction(
                title: LT("查看二维码", "View QR", "QRを見る"),
                systemImage: "qrcode",
                accentColor: Color(red: 0.46, green: 0.35, blue: 0.96)
            ) {
                Task { await openLabelQRCode() }
            }
        )
        actions.append(
            SharePanelQuickAction(
                title: LT("查看海报", "View Poster", "海報を見る"),
                systemImage: "photo.on.rectangle",
                accentColor: Color(red: 0.98, green: 0.71, blue: 0.22)
            ) {
                Task { await openLabelPoster() }
            }
        )
        actions.append(
            SharePanelQuickAction(
                title: LT("保存海报", "Save Poster", "海報を保存"),
                systemImage: "photo.badge.arrow.down",
                accentColor: Color(red: 0.21, green: 0.58, blue: 0.98)
            ) {
                Task { await saveLabelPoster() }
            }
        )

        actions.append(
            SharePanelQuickAction(
                title: LT("缓存", "Cache", "キャッシュ"),
                systemImage: "arrow.down.circle",
                accentColor: Color(red: 0.38, green: 0.73, blue: 0.98)
            ) {
                errorMessage = LT("该页面缓存能力正在建设中。", "Caching for this page is under construction.", "このページのキャッシュ機能は現在構築中です。")
            }
        )

        actions.append(
            SharePanelQuickAction(
                title: LT("贡献信息", "Incorrect Info", "情報を修正"),
                systemImage: "info.circle",
                accentColor: Color(red: 0.96, green: 0.69, blue: 0.25)
            ) {
                errorMessage = LT("贡献信息入口即将开放，当前已记录该需求。", "Incorrect info entry is coming soon. We have recorded this request.", "情報修正の入口は近日公開予定です。この要望は記録しました。")
            }
        )

        actions.append(
            SharePanelQuickAction(
                title: LT("举报", "Report", "報告"),
                systemImage: "flag",
                accentColor: Color(red: 0.93, green: 0.32, blue: 0.36)
            ) {
                reportTarget = ReportSheetTarget(
                    id: label.id,
                    type: .label,
                    title: label.name,
                    preview: label.introduction?.nilIfBlank ?? label.genresPreview?.nilIfBlank,
                    targetUserID: nil,
                    targetUserDisplayName: nil
                )
            }
        )

        if let url = destinationURL(label.officialWebsiteUrl) {
            actions.append(
                SharePanelQuickAction(
                    title: LT("官网", "Official", "公式サイト"),
                    systemImage: "globe",
                    accentColor: Color(red: 0.53, green: 0.45, blue: 0.96)
                ) {
                    UIApplication.shared.open(url)
                }
            )
        }

        return actions
    }

    @MainActor
    private func copyLabelShareLink() async {
        do {
            let result = try await shareLinkCoordinator.copyLink(target: shareTarget())
            showWidgetStatusBanner(
                message: result.usedDeepLinkFallback
                    ? LT("已复制 App 内链接", "Copied app-only link.", "アプリ内リンクをコピーしました")
                    : LT("已复制链接", "Link copied", "リンクをコピーしました")
            )
        } catch {
            errorMessage = error.userFacingMessage ?? LT("复制链接失败，请稍后重试。", "Failed to copy link. Please try again.", "リンクをコピーできませんでした。もう一度お試しください。")
        }
    }

    @MainActor
    private func openLabelQRCode() async {
        do {
            let resolved = try await shareLinkCoordinator.resolveLink(target: shareTarget(), channel: "view_qr")
            appPush(
                .profile(
                    .shareQRCode(
                        title: resolved.payload.title,
                        subtitle: resolved.payload.subtitle,
                        imageURL: resolved.payload.imageURL,
                        shortURL: resolved.payload.shortURL,
                        qrCodeURL: resolved.payload.qrCodeURL
                    )
                )
            )
        } catch {
            errorMessage = error.userFacingMessage ?? LT("打开二维码失败，请稍后重试。", "Failed to open QR code. Please try again later.", "QRコードを開けませんでした。時間をおいて再試行してください。")
        }
    }

    @MainActor
    private func openLabelPoster() async {
        do {
            let resolved = try await shareLinkCoordinator.resolveLink(target: shareTarget(), channel: "view_poster")
            appPush(
                .profile(
                    .shareAsset(
                        navigationTitle: LT("分享海报", "Share Poster", "海報を共有"),
                        title: resolved.payload.title,
                        subtitle: resolved.payload.subtitle,
                        imageURL: resolved.payload.imageURL,
                        assetURL: resolved.payload.posterURL,
                        emptyTitle: LT("海报暂未生成", "Poster Unavailable", "海報はまだ生成されていません"),
                        emptyMessage: LT("当前分享海报还没有准备好，请稍后再试。", "The share poster is not ready yet. Please try again later.", "共有海報はまだ準備できていません。時間をおいて再試行してください。"),
                        hintText: LT("Label 海报由分享系统统一生成，名称、摘要和二维码都会跟随短链保持一致。", "Label posters are generated by the share system, so the title, summary, and QR code stay aligned with the short link.", "Label海報は共有システムで生成され、名称、概要、QRコードは短縮リンクと同期されます。"),
                        saveButtonTitle: LT("保存海报", "Save Poster", "海報を保存")
                    )
                )
            )
        } catch {
            errorMessage = error.userFacingMessage ?? LT("打开分享海报失败，请稍后重试。", "Failed to open share poster. Please try again later.", "共有海報を開けませんでした。時間をおいて再試行してください。")
        }
    }

    @MainActor
    private func saveLabelPoster() async {
        do {
            let resolved = try await shareLinkCoordinator.resolveLink(target: shareTarget(), channel: "poster_save")
            try await ShareAssetPhotoSaver.saveRemoteImage(from: resolved.payload.posterURL)
            showWidgetStatusBanner(message: LT("海报已保存到相册", "Poster saved to Photos", "海報を写真に保存しました"))
        } catch {
            errorMessage = error.userFacingMessage ?? LT("保存海报失败，请稍后重试。", "Failed to save poster. Please try again later.", "海報を保存できませんでした。時間をおいて再試行してください。")
        }
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
        subtitle: LT("全球电子音乐节年度热度榜", "Global annual popularity ranking of electronic music festivals", "世界の電子音楽フェス年間人気ランキング"),
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
                Text(LT("榜单", "榜单", "ランキング"))
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

            Text(LT("已收录 \(rankedCount) 个电音节", "\(rankedCount) festivals included", "\(rankedCount)件のフェスを収録"))
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
        return parts.isEmpty ? LT("电子音乐节品牌", "Festival Brand", "電子音楽フェスブランド") : parts.joined(separator: " · ")
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

private struct LabelCardSharePresentation: Identifiable {
    let id = UUID()
    let payload: LabelShareCardPayload
}

private struct LabelSharePreviewCard: View {
    let payload: LabelShareCardPayload

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            previewImage
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                if let badge = payload.badgeText?.nilIfBlank {
                    Text(badge)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(RaverTheme.accent)
                }

                Text(payload.labelName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(2)

                if let metadataText {
                    Text(metadataText)
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RaverTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var previewImage: some View {
        if let raw = payload.coverImageURL,
           let url = URL(string: raw),
           !raw.isEmpty {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    fallbackImage
                }
            }
        } else {
            fallbackImage
        }
    }

    private var fallbackImage: some View {
        LinearGradient(
            colors: [RaverTheme.accent.opacity(0.95), Color(red: 0.19, green: 0.18, blue: 0.26)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "opticaldiscdrive.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.92))
        )
    }

    private var metadataText: String? {
        let parts = [payload.country?.nilIfBlank, payload.genreText?.nilIfBlank].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

private struct BrandCardSharePresentation: Identifiable {
    let id = UUID()
    let payload: BrandShareCardPayload
}

private struct BrandSharePreviewCard: View {
    let payload: BrandShareCardPayload

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            previewImage
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                if let badge = payload.badgeText?.nilIfBlank {
                    Text(badge)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(RaverTheme.accent)
                }

                Text(payload.brandName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(2)

                Text([payload.country, payload.city].compactMap { $0?.nilIfBlank }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RaverTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var previewImage: some View {
        if let raw = payload.coverImageURL,
           let url = URL(string: raw),
           !raw.isEmpty {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    fallbackImage
                }
            }
        } else {
            fallbackImage
        }
    }

    private var fallbackImage: some View {
        LinearGradient(
            colors: [RaverTheme.accent.opacity(0.95), Color(red: 0.19, green: 0.18, blue: 0.26)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "sparkles.tv")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.92))
        )
    }
}

struct LearnFestivalDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.discoverPush) private var discoverPush
    @Environment(\.appPush) private var appPush
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var appContainer: AppContainer
    let onFestivalUpdated: ((LearnFestival) -> Void)?

    private var wikiRepository: DiscoverWikiRepository {
        appContainer.discoverWikiRepository
    }

    private var eventListRepository: EventListRepository {
        appContainer.eventListRepository
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
    @State private var followedBrandUpdatePreference = FollowedBrandUpdatePreference.empty
    @State private var isLoadingFollowedBrandPreference = false
    @State private var isTogglingBrandFollow = false
    @State private var shareMorePresentation: BrandCardSharePresentation?
    @State private var isShareMorePanelVisible = false
    @State private var fullChatSharePresentation: BrandCardSharePresentation?
    @State private var reportTarget: ReportSheetTarget?

    private var shareLinkCoordinator: ShareLinkCoordinator {
        ShareLinkCoordinator(repository: AppEnvironment.makeShareLinkRepository())
    }

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
            case .basic: return LT("信息", "Info", "情報")
            case .events: return LT("活动", "Events", "イベント")
            case .posts: return LT("动态", "Posts", "投稿")
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
        .sheet(item: $fullChatSharePresentation) { presentation in
            ChatShareSheet(
                loadConversations: {
                    try await loadSharePanelConversations()
                },
                onShareToConversation: { conversation in
                    try await sendSharePayload(
                        presentation.payload,
                        to: conversation,
                        note: nil
                    )
                }
            ) { conversation in
                showWidgetStatusBanner(
                    message: LT("已分享到 \(conversation.title)", "Shared to \(conversation.title)", "\(conversation.title) に共有しました"),
                    conversation: conversation
                )
            } preview: {
                BrandSharePreviewCard(payload: presentation.payload)
            }
            .presentationDetents([.fraction(0.76), .large])
        }
        .sheet(item: $reportTarget) { target in
            ReportSheet(target: target) { _, _ in
                showWidgetStatusBanner(message: LT("举报已提交", "Report submitted", "報告を送信しました"))
            }
            .environmentObject(appState)
            .presentationDetents([.large])
        }
        .task(id: currentFestival.id) {
            prepareFestivalEditDraft()
            await loadRelatedContent()
            await hydrateFestivalContributorsIfNeeded()
            await refreshFollowedBrandUpdatePreference()
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
        .alert(LT("提示", "Notice", "お知らせ"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(LT("确定", "OK", "OK"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .overlay {
            if let presentation = shareMorePresentation {
                SharePanelOverlay(
                    isVisible: isShareMorePanelVisible,
                    onBackdropTap: { dismissShareMorePanel() }
                ) {
                    ShareActionPanel(
                        primaryActions: sharePrimaryActions(),
                        quickActions: shareMoreQuickActions(for: currentFestival),
                        loadConversations: {
                            try await loadSharePanelConversations()
                        },
                        onSendToConversation: { conversation, note in
                            try await sendSharePayload(
                                presentation.payload,
                                to: conversation,
                                note: note
                            )
                        },
                        onDismiss: {
                            dismissShareMorePanel()
                        }
                    ) { conversation in
                        showWidgetStatusBanner(
                            message: LT("已分享到 \(conversation.title)", "Shared to \(conversation.title)", "\(conversation.title) に共有しました"),
                            conversation: conversation
                        )
                    } onMoreChats: {
                        dismissShareMorePanel {
                            fullChatSharePresentation = presentation
                        }
                    }
                }
                .onAppear {
                    withAnimation(.sharePanelPresentSpring) {
                        isShareMorePanelVisible = true
                    }
                }
            }
        }
        .operationBannerHost()
        .animation(.sharePanelPresentSpring, value: isShareMorePanelVisible)
    }

    private var immersiveTrailingAction: AnyView? {
        return AnyView(
            Button {
                shareMorePresentation = BrandCardSharePresentation(
                    payload: makeBrandShareCardPayload(from: currentFestival)
                )
                isShareMorePanelVisible = false
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
        )
    }

    private var festivalHeaderPrimaryTextColor: Color {
        colorScheme == .dark ? Color.white : Color.black.opacity(0.88)
    }

    private var festivalHeaderSecondaryTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.82) : Color.black.opacity(0.78)
    }

    private var festivalHeaderTertiaryTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.78) : Color.black.opacity(0.76)
    }

    private func openFestivalCacheEntry() {
        // TODO: Add festival-level cache workflow if needed.
        errorMessage = LT("该页面缓存能力正在建设中。", "Caching for this page is under construction.", "このページのキャッシュ機能は現在構築中です。")
    }

    private func openFestivalFeedbackEntry() {
        // TODO: Wire to dedicated feedback route/page when available.
        errorMessage = LT("贡献信息入口即将开放，当前已记录该需求。", "Incorrect info entry is coming soon. We have recorded this request.", "情報修正の入口は近日公開予定です。この要望は記録しました。")
    }

    private func openFestivalReportEntry() {
        reportTarget = ReportSheetTarget(
            id: currentFestival.id,
            type: .festival,
            title: currentFestival.name,
            preview: currentFestival.introduction.nilIfBlank ?? currentFestival.tagline.nilIfBlank,
            targetUserID: nil,
            targetUserDisplayName: nil
        )
    }

    private var isFollowingCurrentFestivalBrand: Bool {
        followedBrandUpdatePreference.watchedBrandIds.contains(currentFestival.id)
    }

    @MainActor
    private func refreshFollowedBrandUpdatePreference() async {
        guard appState.session != nil else {
            followedBrandUpdatePreference = .empty
            isLoadingFollowedBrandPreference = false
            return
        }

        isLoadingFollowedBrandPreference = true
        defer { isLoadingFollowedBrandPreference = false }

        do {
            followedBrandUpdatePreference = try await wikiRepository.fetchFollowedBrandUpdatePreference()
        } catch {
            followedBrandUpdatePreference = .empty
        }
    }

    @MainActor
    private func toggleFestivalBrandFollow() async {
        guard appState.session != nil else {
            errorMessage = LT("请先登录后再关注电音节。", "Please log in before following this festival.", "フェスをフォローするにはログインしてください。")
            return
        }
        guard !isTogglingBrandFollow else { return }

        isTogglingBrandFollow = true
        defer { isTogglingBrandFollow = false }

        do {
            let currentPreference: FollowedBrandUpdatePreference
            if isLoadingFollowedBrandPreference {
                currentPreference = followedBrandUpdatePreference
            } else if followedBrandUpdatePreference == .empty {
                currentPreference = try await wikiRepository.fetchFollowedBrandUpdatePreference()
            } else {
                currentPreference = followedBrandUpdatePreference
            }

            var watchedBrandIDs = currentPreference.watchedBrandIds
            if let index = watchedBrandIDs.firstIndex(of: currentFestival.id) {
                watchedBrandIDs.remove(at: index)
            } else {
                watchedBrandIDs.append(currentFestival.id)
            }

            let normalizedBrandIDs = Array(
                NSOrderedSet(array: watchedBrandIDs.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
            ) as? [String] ?? watchedBrandIDs

            let shouldEnable = normalizedBrandIDs.contains(currentFestival.id) ? true : currentPreference.enabled
            followedBrandUpdatePreference = try await wikiRepository.updateFollowedBrandUpdatePreference(
                FollowedBrandUpdatePreferenceInput(
                    enabled: shouldEnable,
                    reminderHours: nil,
                    timezone: nil,
                    channels: nil,
                    watchedBrandIds: normalizedBrandIDs,
                    includeInfos: nil,
                    includeEvents: nil
                )
            )
        } catch {
            errorMessage = error.userFacingMessage ?? LT("关注状态更新失败，请稍后重试。", "Failed to update follow status. Please try again later.", "フォロー状態を更新できませんでした。時間をおいて再試行してください。")
        }
    }

    private func dismissShareMorePanel(after: (() -> Void)? = nil) {
        withAnimation(.sharePanelDismissSpring) {
            isShareMorePanelVisible = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            guard !isShareMorePanelVisible else { return }
            shareMorePresentation = nil
            after?()
        }
    }

    private func showWidgetStatusBanner(message: String, conversation: Conversation? = nil) {
        OperationBannerCenter.shared.success(
            message,
            action: conversation.map { .appRoute(.conversation(target: .fromConversation($0))) } ?? .none
        )
    }

    private func makeBrandShareCardPayload(from festival: LearnFestival) -> BrandShareCardPayload {
        let coverImageURL = AppConfig.resolvedURLString(festival.backgroundUrl)
            ?? AppConfig.resolvedURLString(festival.avatarUrl)
        return BrandShareCardPayload(
            brandID: festival.id,
            brandName: festival.name,
            country: festival.country.nilIfBlank,
            city: festival.city.nilIfBlank,
            tagline: festival.tagline.nilIfBlank,
            coverImageURL: coverImageURL,
            badgeText: LT("品牌", "Brand", "ブランド")
        )
    }

    private func shareTarget(for festival: LearnFestival) -> ShareTarget {
        let canonicalURL = "https://ravehub.top/festival/\(festival.id)"
        let imageURL = AppConfig.resolvedURLString(festival.backgroundUrl)
            ?? AppConfig.resolvedURLString(festival.avatarUrl)
        let subtitle = [
            festival.country.nilIfBlank,
            festival.city.nilIfBlank,
            festival.tagline.nilIfBlank
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: " · ")
        return ShareTarget(
            type: .festival,
            id: festival.id,
            title: festival.name,
            subtitle: subtitle.isEmpty ? nil : subtitle,
            imageURL: imageURL,
            canonicalURL: canonicalURL,
            deepLink: "raver://festival/\(festival.id)",
            fallbackURL: canonicalURL,
            previewType: "content_card",
            visibility: "public"
        )
    }

    private func loadSharePanelConversations() async throws -> [Conversation] {
        async let directs = appContainer.shareMessageRepository.fetchConversations(type: .direct)
        async let groups = appContainer.shareMessageRepository.fetchConversations(type: .group)
        let merged = try await directs + groups
        let deduped = merged.reduce(into: [String: Conversation]()) { partialResult, conversation in
            partialResult[conversation.id] = conversation
        }
        return deduped.values.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned && !$1.isPinned }
            return $0.updatedAt > $1.updatedAt
        }
    }

    private func sendSharePayload(
        _ payload: BrandShareCardPayload,
        to conversation: Conversation,
        note: String?
    ) async throws {
        _ = try await appContainer.shareMessageRepository.sendBrandCardMessage(
            conversationID: conversation.id,
            payload: payload
        )

        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedNote.isEmpty {
            _ = try await appContainer.shareMessageRepository.sendMessage(
                conversationID: conversation.id,
                content: trimmedNote
            )
        }
    }

    private func sharePrimaryActions() -> [SharePanelPrimaryAction] {
        [
            SharePanelPrimaryAction(
                title: "微信",
                systemImage: "message.circle.fill",
                accentColor: Color(red: 0.18, green: 0.76, blue: 0.35)
            ) {
                errorMessage = LT("微信分享接口待接入。", "WeChat share hook is not connected yet.", "WeChat共有連携は未接続です。")
            },
            SharePanelPrimaryAction(
                title: "Instagram",
                systemImage: "camera.circle.fill",
                accentColor: Color(red: 0.91, green: 0.30, blue: 0.48)
            ) {
                errorMessage = LT("Instagram 分享接口待接入。", "Instagram share hook is not connected yet.", "Instagram共有連携は未接続です。")
            },
            SharePanelPrimaryAction(
                title: "复制链接",
                systemImage: "link.circle.fill",
                accentColor: Color(red: 0.30, green: 0.67, blue: 0.97)
            ) {
                Task { await copyFestivalShareLink(currentFestival) }
            }
        ]
    }

    private func shareMoreQuickActions(for festival: LearnFestival?) -> [SharePanelQuickAction] {
        var actions: [SharePanelQuickAction] = []

        if let festival {
            actions.append(
                SharePanelQuickAction(
                    title: LT("查看二维码", "View QR", "QRを見る"),
                    systemImage: "qrcode",
                    accentColor: Color(red: 0.46, green: 0.35, blue: 0.96)
                ) {
                    Task { await openFestivalQRCode(festival) }
                }
            )
            actions.append(
                SharePanelQuickAction(
                    title: LT("查看海报", "View Poster", "海報を見る"),
                    systemImage: "photo.on.rectangle",
                    accentColor: Color(red: 0.98, green: 0.71, blue: 0.22)
                ) {
                    Task { await openFestivalPoster(festival) }
                }
            )
            actions.append(
                SharePanelQuickAction(
                    title: LT("保存海报", "Save Poster", "海報を保存"),
                    systemImage: "photo.badge.arrow.down",
                    accentColor: Color(red: 0.21, green: 0.58, blue: 0.98)
                ) {
                    Task { await saveFestivalPoster(festival) }
                }
            )
        }

        if canEditFestival {
            actions.append(
                SharePanelQuickAction(
                    title: LT("编辑", "Edit", "編集"),
                    systemImage: "square.and.pencil",
                    accentColor: RaverTheme.accent
                ) {
                    prepareFestivalEditDraft()
                    discoverPush(.learnFestivalEdit(festivalID: currentFestival.id))
                }
            )
        }

        actions.append(
            SharePanelQuickAction(
                title: LT("缓存", "Cache", "キャッシュ"),
                systemImage: "arrow.down.circle",
                accentColor: Color(red: 0.38, green: 0.73, blue: 0.98)
            ) {
                openFestivalCacheEntry()
            }
        )

        actions.append(
            SharePanelQuickAction(
                title: LT("贡献信息", "Incorrect Info", "情報を修正"),
                systemImage: "info.circle",
                accentColor: Color(red: 0.96, green: 0.69, blue: 0.25)
            ) {
                openFestivalFeedbackEntry()
            }
        )

        actions.append(
            SharePanelQuickAction(
                title: LT("举报", "Report", "報告"),
                systemImage: "flag",
                accentColor: Color(red: 0.93, green: 0.32, blue: 0.36)
            ) {
                openFestivalReportEntry()
            }
        )

        if festival?.links.first?.url != nil {
            actions.append(
                SharePanelQuickAction(
                    title: LT("官网", "Official", "公式サイト"),
                    systemImage: "globe",
                    accentColor: Color(red: 0.53, green: 0.45, blue: 0.96)
                ) {
                    if let url = destinationURL(festival?.links.first?.url) {
                        UIApplication.shared.open(url)
                    }
                }
            )
        }

        return actions
    }

    @MainActor
    private func copyFestivalShareLink(_ festival: LearnFestival) async {
        do {
            let result = try await shareLinkCoordinator.copyLink(target: shareTarget(for: festival))
            showWidgetStatusBanner(
                message: result.usedDeepLinkFallback
                    ? LT("已复制 App 内链接", "Copied app-only link.", "アプリ内リンクをコピーしました")
                    : LT("已复制链接", "Link copied", "リンクをコピーしました")
            )
        } catch {
            errorMessage = error.userFacingMessage ?? LT("复制链接失败，请稍后重试。", "Failed to copy link. Please try again.", "リンクをコピーできませんでした。もう一度お試しください。")
        }
    }

    @MainActor
    private func openFestivalQRCode(_ festival: LearnFestival) async {
        do {
            let resolved = try await shareLinkCoordinator.resolveLink(target: shareTarget(for: festival), channel: "view_qr")
            appPush(
                .profile(
                    .shareQRCode(
                        title: resolved.payload.title,
                        subtitle: resolved.payload.subtitle,
                        imageURL: resolved.payload.imageURL,
                        shortURL: resolved.payload.shortURL,
                        qrCodeURL: resolved.payload.qrCodeURL
                    )
                )
            )
        } catch {
            errorMessage = error.userFacingMessage ?? LT("打开二维码失败，请稍后重试。", "Failed to open QR code. Please try again later.", "QRコードを開けませんでした。時間をおいて再試行してください。")
        }
    }

    @MainActor
    private func openFestivalPoster(_ festival: LearnFestival) async {
        do {
            let resolved = try await shareLinkCoordinator.resolveLink(target: shareTarget(for: festival), channel: "view_poster")
            appPush(
                .profile(
                    .shareAsset(
                        navigationTitle: LT("分享海报", "Share Poster", "海報を共有"),
                        title: resolved.payload.title,
                        subtitle: resolved.payload.subtitle,
                        imageURL: resolved.payload.imageURL,
                        assetURL: resolved.payload.posterURL,
                        emptyTitle: LT("海报暂未生成", "Poster Unavailable", "海報はまだ生成されていません"),
                        emptyMessage: LT("当前分享海报还没有准备好，请稍后再试。", "The share poster is not ready yet. Please try again later.", "共有海報はまだ準備できていません。時間をおいて再試行してください。"),
                        hintText: LT("Festival 海报由分享系统统一生成，名称、摘要和二维码都会跟随短链保持一致。", "Festival posters are generated by the share system, so the title, summary, and QR code stay aligned with the short link.", "Festival海報は共有システムで生成され、名称、概要、QRコードは短縮リンクと同期されます。"),
                        saveButtonTitle: LT("保存海报", "Save Poster", "海報を保存")
                    )
                )
            )
        } catch {
            errorMessage = error.userFacingMessage ?? LT("打开分享海报失败，请稍后重试。", "Failed to open share poster. Please try again later.", "共有海報を開けませんでした。時間をおいて再試行してください。")
        }
    }

    @MainActor
    private func saveFestivalPoster(_ festival: LearnFestival) async {
        do {
            let resolved = try await shareLinkCoordinator.resolveLink(target: shareTarget(for: festival), channel: "poster_save")
            try await ShareAssetPhotoSaver.saveRemoteImage(from: resolved.payload.posterURL)
            showWidgetStatusBanner(message: LT("海报已保存到相册", "Poster saved to Photos", "海報を写真に保存しました"))
        } catch {
            errorMessage = error.userFacingMessage ?? LT("保存海报失败，请稍后重试。", "Failed to save poster. Please try again later.", "海報を保存できませんでした。時間をおいて再試行してください。")
        }
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
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(currentFestival.name)
                                    .font(.headline.weight(.black))
                                    .foregroundStyle(festivalHeaderPrimaryTextColor)
                                    .lineLimit(2)

                                if !currentFestival.aliases.isEmpty {
                                    Text(currentFestival.aliases.joined(separator: " / "))
                                        .font(.caption)
                                        .foregroundStyle(festivalHeaderSecondaryTextColor)
                                        .lineLimit(2)
                                }

                                Text(LT("\(currentFestival.country) \(currentFestival.city) · Since \(currentFestival.foundedYear)", "\(currentFestival.country) \(currentFestival.city) · Since \(currentFestival.foundedYear)", "\(currentFestival.country) \(currentFestival.city) · \(currentFestival.foundedYear)年開始"))
                                    .font(.caption)
                                    .foregroundStyle(festivalHeaderTertiaryTextColor)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Button {
                                Task { await toggleFestivalBrandFollow() }
                            } label: {
                                Group {
                                    if isLoadingFollowedBrandPreference || isTogglingBrandFollow {
                                        ProgressView()
                                            .controlSize(.small)
                                            .tint(.white)
                                            .frame(minWidth: 48)
                                    } else {
                                        Text(isFollowingCurrentFestivalBrand ? LT("已关注", "Following", "フォロー中") : LT("关注", "Follow", "フォロー"))
                                            .lineLimit(1)
                                    }
                                }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule()
                                        .fill(
                                            isFollowingCurrentFestivalBrand
                                            ? Color(red: 0.2, green: 0.56, blue: 0.98).opacity(0.45)
                                            : Color(red: 0.2, green: 0.56, blue: 0.98)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(isLoadingFollowedBrandPreference || isTogglingBrandFollow)
                        }
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
            LearnLabelInfoRow(title: LT("国家", "Country", "国"), value: currentFestival.country)
            LearnLabelInfoRow(title: LT("城市", "City", "都市"), value: currentFestival.city)
            LearnLabelInfoRow(title: LT("首办时间", "Founded Year", "初開催年"), value: currentFestival.foundedYear)
            LearnLabelInfoRow(title: LT("举办频次", "Frequency", "開催頻度"), value: currentFestival.frequency)
            LearnLabelInfoRow(title: LT("定位", "Tagline", "タグライン"), value: currentFestival.tagline)
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
                    Text(LT("发布新活动", "发布新活动", "新しいイベントを公開"))
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
                ProgressView(LT("正在加载关联活动...", "正在加载关联活动...", "関連イベントを読み込み中..."))
                    .padding(.vertical, 8)
            } else if upcomingRelatedEvents.isEmpty && endedRelatedEvents.isEmpty {
                Text(LT("暂无关联活动", "暂无关联活动", "関連イベントはまだありません"))
                    .foregroundStyle(RaverTheme.secondaryText)
                    .padding(.vertical, 8)
            } else {
                if !upcomingRelatedEvents.isEmpty {
                    festivalEventsSectionHeader(LT("即将开始", "Upcoming", "近日開催"))
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
                    festivalEventsSectionHeader(LT("已结束活动", "Ended", "終了済み"))
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
            ProgressView(LT("正在加载品牌动态...", "正在加载品牌动态...", "ブランド投稿を読み込み中..."))
                .padding(.vertical, 8)
        } else if relatedArticles.isEmpty {
            Text(LT("暂无相关动态", "暂无相关动态", "関連投稿はまだありません"))
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

                Text(locationText.isEmpty ? LT("地点待补充", "Location pending", "場所は未設定") : locationText)
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
        if AppLanguagePreference.current.effectiveLanguage != .en {
            return event.startDate.appLocalizedDateRangeText(to: event.endDate)
        }
        return event.startDate.appLocalizedDateRangeText(to: event.endDate)
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
                Text(LT("Links", "Links", "リンク"))
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
                Text(LT("贡献者", "贡献者", "コントリビューター"))
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
        return trimmed.isEmpty ? LT("未设置昵称", "No nickname set", "ニックネーム未設定") : trimmed
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
        errorMessage = LT("未找到对应用户主页", "Matched user profile not found.", "対応するユーザープロフィールが見つかりません。")
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
                Section(LT("基础信息", "基础信息", "基本情報")) {
                    TextField(LT("电音节名称", "电音节名称", "フェス名"), text: $editName)
                    TextField(LT("别名（英文逗号分隔）", "别名（英文逗号分隔）", "別名（半角カンマ区切り）"), text: $editAliases)
                    TextField(LT("国家", "国家", "国"), text: $editCountry)
                    TextField(LT("城市", "城市", "都市"), text: $editCity)
                    TextField(LT("首办时间", "首办时间", "初開催年"), text: $editFoundedYear)
                    TextField(LT("举办频次", "举办频次", "開催頻度"), text: $editFrequency)
                    TextField(LT("定位", "定位", "タグライン"), text: $editTagline)
                    TextField(LT("简介", "简介", "概要"), text: $editIntroduction, axis: .vertical)
                    TextField(LT("官网链接", "官网链接", "公式サイトリンク"), text: $editWebsite)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                }

                Section(LT("媒体", "媒体", "メディア")) {
                    HStack(spacing: 12) {
                        PhotosPicker(selection: $editAvatarItem, matching: .images) {
                            Label(LT("更换头像", "更换头像", "アバターを変更"), systemImage: "person.crop.square")
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
                            Label(LT("更换背景", "更换背景", "背景を変更"), systemImage: "photo.rectangle")
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
                    Button(isSavingFestival ? LT("保存中...", "Saving...", "保存中...") : "保存电音节信息") {
                        Task { await saveFestivalEdits() }
                    }
                    .disabled(isSavingFestival || editName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .raverSystemNavigation(title: LT("编辑电音节", "编辑电音节", "フェスを編集"))
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
            errorMessage = LT("读取图片失败，请重试", "Failed to read image. Please try again.", "画像を読み込めませんでした。もう一度お試しください。")
        }
    }

    @MainActor
    private func saveFestivalEdits() async {
        guard canEditFestival else {
            errorMessage = LT("仅贡献者可编辑电音节信息", "Only contributors can edit festival info.", "コントリビューターのみフェス情報を編集できます。")
            return
        }

        let finalName = editName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalName.isEmpty else {
            errorMessage = LT("电音节名称不能为空", "Festival name cannot be empty.", "フェス名を入力してください。")
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
                !(link.icon == "globe" && (link.title == LT("官网", "Official", "公式サイト") || link.title == "Official"))
            }
            if let website {
                preservedLinks.insert(
                    LearnFestivalLink(title: LT("官网", "Official", "公式サイト"), icon: "globe", url: website),
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
            errorMessage = LT("电音节信息已更新", "Festival info updated.", "フェス情報を更新しました。")
        } catch {
            errorMessage = LT("保存失败：\(error.userFacingMessage ?? "")", "Save failed: \(error.userFacingMessage ?? "")", "保存に失敗しました: \(error.userFacingMessage ?? "")")
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
            let page = try await eventListRepository.fetchEvents(
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
                return LT("新增电音节", "新增电音节", "フェスを追加")
            case .edit:
                return LT("编辑电音节", "编辑电音节", "フェスを編集")
            }
        }

        var commitTitle: String {
            switch self {
            case .create:
                return LT("创建电音节", "Create Festival", "フェスを作成")
            case .edit:
                return LT("保存电音节信息", "Save Festival", "フェス情報を保存")
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
            Section(LT("基础信息", "基础信息", "基本情報")) {
                TextField(LT("电音节名称", "电音节名称", "フェス名"), text: $name)
                TextField(LT("别名（英文逗号分隔）", "别名（英文逗号分隔）", "別名（半角カンマ区切り）"), text: $aliases)
                TextField(LT("国家", "国家", "国"), text: $country)
                TextField(LT("城市", "城市", "都市"), text: $city)
                TextField(LT("首办时间", "首办时间", "初開催年"), text: $foundedYear)
                TextField(LT("举办频次", "举办频次", "開催頻度"), text: $frequency)
                TextField(LT("定位", "定位", "タグライン"), text: $tagline)
                TextField(LT("简介", "简介", "概要"), text: $introduction, axis: .vertical)
                TextField(LT("官网链接", "官网链接", "公式サイトリンク"), text: $website)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
            }

            Section(LT("媒体", "媒体", "メディア")) {
                HStack(spacing: 12) {
                    PhotosPicker(selection: $avatarItem, matching: .images) {
                        Label(editingFestival == nil ? LT("选择头像", "选择头像", "アバターを選択") : LT("更换头像", "更换头像", "アバターを変更"), systemImage: "person.crop.square")
                    }
                    .buttonStyle(.bordered)

                    avatarPreview
                }

                HStack(spacing: 12) {
                    PhotosPicker(selection: $backgroundItem, matching: .images) {
                        Label(editingFestival == nil ? LT("选择背景", "选择背景", "背景を選択") : LT("更换背景", "更换背景", "背景を変更"), systemImage: "photo.rectangle")
                    }
                    .buttonStyle(.bordered)

                    backgroundPreview
                }
            }

            Section {
                Button(isSaving ? LT("保存中...", "Saving...", "保存中...") : mode.commitTitle) {
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
        .alert(LT("提示", "Notice", "お知らせ"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(LT("确定", "OK", "OK"), role: .cancel) {}
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
            errorMessage = LT("读取图片失败，请重试", "Failed to read image. Please try again.", "画像を読み込めませんでした。もう一度お試しください。")
        }
    }

    @MainActor
    private func saveFestival() async {
        if editingFestival != nil, !canEditFestival {
            errorMessage = LT("仅贡献者可编辑电音节信息", "Only contributors can edit festival info.", "コントリビューターのみフェス情報を編集できます。")
            return
        }

        let finalName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalName.isEmpty else {
            errorMessage = LT("电音节名称不能为空", "Festival name cannot be empty.", "フェス名を入力してください。")
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
                        LearnFestivalLink(title: LT("官网", "Official", "公式サイト"), icon: "globe", url: normalizedWebsite),
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
                    return [LearnFestivalLinkPayload(title: LT("官网", "Official", "公式サイト"), icon: "globe", url: normalizedWebsite)]
                }()

                let createResult = try await wikiRepository.createLearnFestival(
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
                guard case .created(var created) = createResult else {
                    OperationBannerCenter.shared.success(LT("品牌信息已提交审核", "Brand submitted for review", "ブランド情報を審査に送信しました"))
                    dismiss()
                    return
                }

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
                Button(isExpanded ? LT("收起", "Collapse", "閉じる") : LT("展开全文", "Expand", "全文を表示")) {
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
                    Text(LT("图片加载失败", "图片加载失败", "画像の読み込みに失敗しました"))
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

private struct RankingBoardCardSharePresentation: Identifiable {
    let id = UUID()
    let payload: RankingBoardShareCardPayload
}

private struct RankingBoardSharePreviewCard: View {
    let payload: RankingBoardShareCardPayload

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            previewImage
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                if let badge = payload.badgeText?.nilIfBlank {
                    Text(badge)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(RaverTheme.accent)
                }

                Text(payload.boardName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(2)

                Text(rankingMetadataText)
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RaverTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var previewImage: some View {
        if let raw = payload.coverImageURL,
           let url = URL(string: raw),
           !raw.isEmpty {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    fallbackImage
                }
            }
        } else {
            fallbackImage
        }
    }

    private var fallbackImage: some View {
        LinearGradient(
            colors: [RaverTheme.accent.opacity(0.95), Color(red: 0.19, green: 0.18, blue: 0.26)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.92))
        )
    }

    private var rankingMetadataText: String {
        if let subtitle = payload.boardSubtitle?.nilIfBlank {
            return "\(payload.year) · \(subtitle)"
        }
        return String(payload.year)
    }
}

struct RankingBoardDetailView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @Environment(\.appPush) private var appPush

    private var djRankingRepository: DJRankingRepository {
        appContainer.djRankingRepository
    }

    let board: RankingBoard

    @State private var selectedYear: Int
    @State private var detail: RankingBoardDetail?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var fullChatSharePresentation: RankingBoardCardSharePresentation?
    @State private var shareMorePresentation: RankingBoardCardSharePresentation?
    @State private var isShareMorePanelVisible = false

    private var shareLinkCoordinator: ShareLinkCoordinator {
        ShareLinkCoordinator(repository: AppEnvironment.makeShareLinkRepository())
    }

    init(board: RankingBoard, initialYear: Int? = nil) {
        self.board = board
        let latestYear = board.years.max() ?? 2025
        let seededYear = initialYear.flatMap { board.years.contains($0) || board.years.isEmpty ? $0 : nil } ?? latestYear
        _selectedYear = State(initialValue: seededYear)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                contentBody
            }
        }
        .background(RaverTheme.background)
        .raverSystemNavigation(title: board.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    shareMorePresentation = RankingBoardCardSharePresentation(
                        payload: makeRankingBoardShareCardPayload()
                    )
                    isShareMorePanelVisible = false
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                        .frame(width: 36, height: 36)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(item: $fullChatSharePresentation) { presentation in
            ChatShareSheet(
                loadConversations: {
                    try await loadSharePanelConversations()
                },
                onShareToConversation: { conversation in
                    try await sendSharePayload(
                        presentation.payload,
                        to: conversation,
                        note: nil
                    )
                }
            ) { conversation in
                showWidgetStatusBanner(
                    message: LT("已分享到 \(conversation.title)", "Shared to \(conversation.title)", "\(conversation.title) に共有しました"),
                    conversation: conversation
                )
            } preview: {
                RankingBoardSharePreviewCard(payload: presentation.payload)
            }
            .presentationDetents([.fraction(0.76), .large])
        }
        .overlay {
            if let presentation = shareMorePresentation {
                SharePanelOverlay(
                    isVisible: isShareMorePanelVisible,
                    onBackdropTap: { dismissShareMorePanel() }
                ) {
                    ShareActionPanel(
                        primaryActions: sharePrimaryActions(),
                        quickActions: shareMoreQuickActions(),
                        loadConversations: {
                            try await loadSharePanelConversations()
                        },
                        onSendToConversation: { conversation, note in
                            try await sendSharePayload(
                                presentation.payload,
                                to: conversation,
                                note: note
                            )
                        },
                        onDismiss: {
                            dismissShareMorePanel()
                        }
                    ) { conversation in
                        showWidgetStatusBanner(
                            message: LT("已分享到 \(conversation.title)", "Shared to \(conversation.title)", "\(conversation.title) に共有しました"),
                            conversation: conversation
                        )
                    } onMoreChats: {
                        dismissShareMorePanel {
                            fullChatSharePresentation = presentation
                        }
                    }
                }
                .onAppear {
                    withAnimation(.sharePanelPresentSpring) {
                        isShareMorePanelVisible = true
                    }
                }
            }
        }
        .operationBannerHost()
        .animation(.sharePanelPresentSpring, value: isShareMorePanelVisible)
        .task {
            await load()
        }
        .onChange(of: selectedYear) { _, _ in
            Task { await load() }
        }
        .alert(LT("提示", "Notice", "お知らせ"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(LT("确定", "OK", "OK"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var contentBody: some View {
        if isLoading, detail == nil {
            ProgressView(LT("加载榜单中...", "Loading rankings...", "ランキングを読み込み中..."))
                .frame(maxWidth: .infinity, minHeight: 240)
        } else if let detail {
            rankingDetailContent(detail: detail)
        } else {
            ContentUnavailableView(LT("榜单为空", "榜单为空", "ランキングは空です"), systemImage: "list.number")
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
            ScrollViewReader { proxy in
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
                            .id(year)
                        }
                    }
                }
                .onAppear {
                    scrollYearSelector(to: selectedYear, proxy: proxy, animated: false)
                }
                .onChange(of: selectedYear) { _, year in
                    scrollYearSelector(to: year, proxy: proxy, animated: true)
                }
                .onChange(of: sortedYears) { _, _ in
                    scrollYearSelector(to: selectedYear, proxy: proxy, animated: false)
                }
            }
        }
        .padding(16)
        .background(RaverTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var sortedYears: [Int] {
        let candidateYears = detail?.years ?? board.years
        return Array(Set(candidateYears)).sorted(by: >)
    }

    private func scrollYearSelector(
        to year: Int,
        proxy: ScrollViewProxy,
        animated: Bool
    ) {
        guard sortedYears.contains(year) else { return }
        DispatchQueue.main.async {
            if animated {
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(year, anchor: .leading)
                }
            } else {
                proxy.scrollTo(year, anchor: .leading)
            }
        }
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

    private func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            detail = try await djRankingRepository.fetchRankingBoardDetail(boardID: board.id, year: selectedYear)
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    private func makeRankingBoardShareCardPayload() -> RankingBoardShareCardPayload {
        RankingBoardShareCardPayload(
            boardID: board.id,
            boardName: board.title,
            boardSubtitle: detail?.title.nilIfBlank ?? board.subtitle?.nilIfBlank ?? board.defaultSubtitle,
            year: selectedYear,
            coverImageURL: board.coverImageUrl,
            badgeText: LT("榜单", "Ranking", "ランキング")
        )
    }

    private func rankingBoardDeeplink(for payload: RankingBoardShareCardPayload) -> String {
        var components = URLComponents()
        components.scheme = "raver"
        components.host = "ranking-board"
        components.path = "/\(payload.boardID)"
        components.queryItems = [
            URLQueryItem(name: "year", value: String(payload.year)),
            URLQueryItem(name: "title", value: payload.boardName),
            URLQueryItem(name: "subtitle", value: payload.boardSubtitle),
            URLQueryItem(name: "coverImageURL", value: payload.coverImageURL)
        ]
        return components.string ?? "raver://ranking-board/\(payload.boardID)?year=\(payload.year)"
    }

    private func shareTarget() -> ShareTarget {
        let payload = makeRankingBoardShareCardPayload()
        let canonicalURL = "https://ravehub.top/ranking-board/\(payload.boardID)?year=\(payload.year)"
        return ShareTarget(
            type: .rankingBoard,
            id: payload.boardID,
            title: payload.boardName,
            subtitle: payload.boardSubtitle,
            imageURL: payload.coverImageURL,
            canonicalURL: canonicalURL,
            deepLink: rankingBoardDeeplink(for: payload),
            fallbackURL: canonicalURL,
            previewType: "content_card",
            visibility: "public"
        )
    }

    private func loadSharePanelConversations() async throws -> [Conversation] {
        async let directs = appContainer.shareMessageRepository.fetchConversations(type: .direct)
        async let groups = appContainer.shareMessageRepository.fetchConversations(type: .group)
        let merged = try await directs + groups
        let deduped = merged.reduce(into: [String: Conversation]()) { partialResult, conversation in
            partialResult[conversation.id] = conversation
        }
        return deduped.values.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned && !$1.isPinned }
            return $0.updatedAt > $1.updatedAt
        }
    }

    private func sendSharePayload(
        _ payload: RankingBoardShareCardPayload,
        to conversation: Conversation,
        note: String?
    ) async throws {
        _ = try await appContainer.shareMessageRepository.sendRankingBoardCardMessage(
            conversationID: conversation.id,
            payload: payload
        )

        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedNote.isEmpty {
            _ = try await appContainer.shareMessageRepository.sendMessage(
                conversationID: conversation.id,
                content: trimmedNote
            )
        }
    }

    private func sharePrimaryActions() -> [SharePanelPrimaryAction] {
        [
            SharePanelPrimaryAction(
                title: "微信",
                systemImage: "message.circle.fill",
                accentColor: Color(red: 0.18, green: 0.76, blue: 0.35)
            ) {
                errorMessage = LT("微信分享接口待接入。", "WeChat share hook is not connected yet.", "WeChat共有連携は未接続です。")
            },
            SharePanelPrimaryAction(
                title: "QQ",
                systemImage: "paperplane.circle.fill",
                accentColor: Color(red: 0.21, green: 0.58, blue: 0.98)
            ) {
                errorMessage = LT("QQ 分享接口待接入。", "QQ share hook is not connected yet.", "QQ共有連携は未接続です。")
            }
        ]
    }

    private func shareMoreQuickActions() -> [SharePanelQuickAction] {
        [
            SharePanelQuickAction(
                title: LT("复制链接", "Copy Link", "リンクをコピー"),
                systemImage: "link",
                accentColor: Color(red: 0.33, green: 0.73, blue: 0.95)
            ) {
                Task { await copyRankingBoardShareLink() }
            },
            SharePanelQuickAction(
                title: LT("查看二维码", "View QR", "QRを見る"),
                systemImage: "qrcode",
                accentColor: Color(red: 0.46, green: 0.35, blue: 0.96)
            ) {
                Task { await openRankingBoardQRCode() }
            },
            SharePanelQuickAction(
                title: LT("查看海报", "View Poster", "海報を見る"),
                systemImage: "photo.on.rectangle",
                accentColor: Color(red: 0.98, green: 0.71, blue: 0.22)
            ) {
                Task { await openRankingBoardPoster() }
            },
            SharePanelQuickAction(
                title: LT("保存海报", "Save Poster", "海報を保存"),
                systemImage: "photo.badge.arrow.down",
                accentColor: Color(red: 0.21, green: 0.58, blue: 0.98)
            ) {
                Task { await saveRankingBoardPoster() }
            }
        ]
    }

    @MainActor
    private func copyRankingBoardShareLink() async {
        do {
            let result = try await shareLinkCoordinator.copyLink(target: shareTarget())
            showWidgetStatusBanner(
                message: result.usedDeepLinkFallback
                    ? LT("已复制 App 内链接", "Copied app-only link.", "アプリ内リンクをコピーしました")
                    : LT("链接已复制", "Link copied", "リンクをコピーしました")
            )
        } catch {
            errorMessage = error.userFacingMessage ?? LT("复制链接失败，请稍后重试。", "Failed to copy link. Please try again.", "リンクをコピーできませんでした。もう一度お試しください。")
        }
    }

    @MainActor
    private func openRankingBoardQRCode() async {
        do {
            let resolved = try await shareLinkCoordinator.resolveLink(target: shareTarget(), channel: "view_qr")
            appPush(
                .profile(
                    .shareQRCode(
                        title: resolved.payload.title,
                        subtitle: resolved.payload.subtitle,
                        imageURL: resolved.payload.imageURL,
                        shortURL: resolved.payload.shortURL,
                        qrCodeURL: resolved.payload.qrCodeURL
                    )
                )
            )
        } catch {
            errorMessage = error.userFacingMessage ?? LT("打开二维码失败，请稍后重试。", "Failed to open QR code. Please try again later.", "QRコードを開けませんでした。時間をおいて再試行してください。")
        }
    }

    @MainActor
    private func openRankingBoardPoster() async {
        do {
            let resolved = try await shareLinkCoordinator.resolveLink(target: shareTarget(), channel: "view_poster")
            appPush(
                .profile(
                    .shareAsset(
                        navigationTitle: LT("分享海报", "Share Poster", "海報を共有"),
                        title: resolved.payload.title,
                        subtitle: resolved.payload.subtitle,
                        imageURL: resolved.payload.imageURL,
                        assetURL: resolved.payload.posterURL,
                        emptyTitle: LT("海报暂未生成", "Poster Unavailable", "海報はまだ生成されていません"),
                        emptyMessage: LT("当前分享海报还没有准备好，请稍后再试。", "The share poster is not ready yet. Please try again later.", "共有海報はまだ準備できていません。時間をおいて再試行してください。"),
                        hintText: LT("榜单海报由分享系统统一生成，标题、摘要和二维码都会跟随短链保持一致。", "Ranking posters are generated by the share system, so the title, summary, and QR code stay aligned with the short link.", "ランキング海報は共有システムで生成され、タイトル、概要、QRコードは短縮リンクと同期されます。"),
                        saveButtonTitle: LT("保存海报", "Save Poster", "海報を保存")
                    )
                )
            )
        } catch {
            errorMessage = error.userFacingMessage ?? LT("打开分享海报失败，请稍后重试。", "Failed to open share poster. Please try again later.", "共有海報を開けませんでした。時間をおいて再試行してください。")
        }
    }

    @MainActor
    private func saveRankingBoardPoster() async {
        do {
            let resolved = try await shareLinkCoordinator.resolveLink(target: shareTarget(), channel: "poster_save")
            try await ShareAssetPhotoSaver.saveRemoteImage(from: resolved.payload.posterURL)
            showWidgetStatusBanner(message: LT("海报已保存到相册", "Poster saved to Photos", "海報を写真に保存しました"))
        } catch {
            errorMessage = error.userFacingMessage ?? LT("保存海报失败，请稍后重试。", "Failed to save poster. Please try again later.", "海報を保存できませんでした。時間をおいて再試行してください。")
        }
    }

    private func dismissShareMorePanel(after: (() -> Void)? = nil) {
        withAnimation(.sharePanelDismissSpring) {
            isShareMorePanelVisible = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            guard !isShareMorePanelVisible else { return }
            shareMorePresentation = nil
            after?()
        }
    }

    private func showWidgetStatusBanner(message: String, conversation: Conversation? = nil) {
        OperationBannerCenter.shared.success(
            message,
            action: conversation.map { .appRoute(.conversation(target: .fromConversation($0))) } ?? .none
        )
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

private struct FestivalDetailMoreActionPanel: View {
    let canEditFestival: Bool
    let onEdit: () -> Void
    let onCache: () -> Void
    let onIncorrectInfo: () -> Void
    let onReport: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LT("更多操作", "More actions", "その他の操作"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(RaverTheme.primaryText)

            VStack(spacing: 6) {
                if canEditFestival {
                    actionRow(
                        title: LT("编辑", "Edit", "編集"),
                        systemImage: "square.and.pencil",
                        accentColor: RaverTheme.accent,
                        action: onEdit
                    )
                }

                actionRow(
                    title: LT("缓存", "Cache", "キャッシュ"),
                    systemImage: "arrow.down.circle",
                    accentColor: Color(red: 0.38, green: 0.73, blue: 0.98),
                    action: onCache
                )

                actionRow(
                    title: LT("贡献信息", "Incorrect Info", "情報を修正"),
                    systemImage: "info.circle",
                    accentColor: Color(red: 0.96, green: 0.69, blue: 0.25),
                    action: onIncorrectInfo
                )

                actionRow(
                    title: LT("举报", "Report", "報告"),
                    systemImage: "flag",
                    accentColor: Color(red: 0.93, green: 0.32, blue: 0.36),
                    action: onReport
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(RaverTheme.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
        )
    }

    private func actionRow(
        title: String,
        systemImage: String,
        accentColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            onDismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                action()
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(accentColor.opacity(0.16))
                        .frame(width: 36, height: 36)
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(accentColor)
                }

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(RaverTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

extension RankingBoard {
    var yearsText: String {
        guard let minYear = years.min(), let maxYear = years.max() else { return "—" }
        return minYear == maxYear ? "\(minYear)" : "\(minYear) - \(maxYear)"
    }

    var defaultSubtitle: String {
        switch id {
        case "djmag": return LT("全球电子音乐最有影响力榜单之一", "One of the most influential global electronic music rankings", "世界で最も影響力のある電子音楽ランキングの一つ")
        case "dongye": return LT("中文圈 DJ 热度与影响力榜单", "Popularity and influence ranking for Chinese-speaking DJs", "中国語圏DJの人気と影響力ランキング")
        default: return LT("各大榜单年度排名与升降变化", "Annual ranking movements across major charts", "主要ランキングの年間順位と変動")
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
