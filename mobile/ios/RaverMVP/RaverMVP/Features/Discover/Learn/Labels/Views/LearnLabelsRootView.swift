import SwiftUI

struct LearnLabelsRootView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @Environment(\.discoverPush) private var discoverPush

    @StateObject private var viewModel = LearnLabelsRootViewModel()
    @State private var activeFilterPanel: LearnLabelsFilterPanelType?

    let isActive: Bool

    init(isActive: Bool = true) {
        self.isActive = isActive
    }

    private var wikiRepository: DiscoverWikiRepository {
        appContainer.discoverWikiRepository
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isRefreshing || viewModel.bannerMessage != nil {
                VStack(alignment: .leading, spacing: 10) {
                    if viewModel.isRefreshing {
                        InlineLoadingBadge(title: LT("正在更新厂牌", "Updating labels", "レーベルを更新中"))
                    }
                    if let bannerMessage = viewModel.bannerMessage {
                        ScreenStatusBanner(
                            message: bannerMessage,
                            style: .error,
                            actionTitle: LT("重试", "Retry", "再試行")
                        ) {
                            Task { await viewModel.reload(repository: wikiRepository, force: true) }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }

            labelsToolbar
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 6)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(RaverTheme.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.triggerInitialLoadIfNeeded(isActive: isActive, repository: wikiRepository)
        }
        .onChange(of: isActive) { _, nextValue in
            Task {
                await viewModel.triggerInitialLoadIfNeeded(isActive: nextValue, repository: wikiRepository)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.phase == .idle || viewModel.phase == .initialLoading {
            FeedSkeletonView(count: 4)
                .padding(.horizontal, 16)
                .padding(.top, 12)
        } else if case .failure(let message) = viewModel.phase {
            ScreenErrorCard(
                title: LT("厂牌加载失败", "Labels Failed to Load", "レーベルの読み込みに失敗しました"),
                message: message
            ) {
                Task { await viewModel.reload(repository: wikiRepository, force: true) }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
        } else if case .offline(let message) = viewModel.phase {
            ScreenErrorCard(
                title: LT("网络不可用", "Network Unavailable", "ネットワークを利用できません"),
                message: message
            ) {
                Task { await viewModel.reload(repository: wikiRepository, force: true) }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
        } else if viewModel.labels.isEmpty {
            ContentUnavailableView(LT("暂无厂牌", "暂无厂牌", "レーベルはまだありません"), systemImage: "building.2")
        } else {
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(viewModel.labels) { label in
                        LearnLabelCard(label: label)
                            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .onTapGesture {
                                discoverPush(.labelDetail(labelID: label.id, prefetchedLabel: label))
                            }
                            .onAppear {
                                guard label.id == viewModel.labels.last?.id else { return }
                                Task { await viewModel.loadMoreIfNeeded(repository: wikiRepository) }
                            }
                    }

                    if viewModel.isLoadingMore {
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding(.vertical, 8)
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .raverTabBarBottomPadding(12)
            }
            .refreshable {
                await viewModel.reload(repository: wikiRepository, force: true)
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
    private var labelsToolbar: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Menu {
                        ForEach(LearnLabelsSortOption.allCases) { option in
                            Button {
                                Task { await viewModel.updateSort(option, repository: wikiRepository) }
                            } label: {
                                if option == viewModel.selectedSort {
                                    Label(option.title, systemImage: "checkmark")
                                } else {
                                    Text(option.title)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(viewModel.selectedSort.title)
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
                        Task { await viewModel.toggleSortOrder(repository: wikiRepository) }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: viewModel.sortOrder == .desc ? "arrow.down" : "arrow.up")
                            Text(viewModel.sortOrder == .desc ? LT("降序", "Desc", "降順") : LT("升序", "Asc", "昇順"))
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
                            Text(viewModel.selectedGenreFilters.isEmpty ? LT("风格", "Genres", "ジャンル") : LT("风格 \(viewModel.selectedGenreFilters.count)", "Genres \(viewModel.selectedGenreFilters.count)", "ジャンル \(viewModel.selectedGenreFilters.count)"))
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
                            Text(viewModel.selectedNationFilters.isEmpty ? LT("国家", "Countries", "国") : LT("国家 \(viewModel.selectedNationFilters.count)", "Countries \(viewModel.selectedNationFilters.count)", "国 \(viewModel.selectedNationFilters.count)"))
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

                    if !viewModel.selectedGenreFilters.isEmpty || !viewModel.selectedNationFilters.isEmpty {
                        Button(LT("清空全部", "清空全部", "すべてクリア")) {
                            Task { await viewModel.clearAllFilters(repository: wikiRepository) }
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RaverTheme.secondaryText)
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
            }

            if activeFilterPanel == .genres {
                LearnLabelsMultiSelectPanel(
                    title: LT("筛选风格", "Filter Genres", "ジャンルで絞り込み"),
                    options: viewModel.availableGenreFilters,
                    selectedValues: viewModel.selectedGenreFilters,
                    emptyText: LT("暂无可筛选风格", "No genres available for filtering", "絞り込めるジャンルはありません"),
                    onToggle: { genre in
                        Task { await viewModel.toggleGenreFilter(genre, repository: wikiRepository) }
                    },
                    onClear: {
                        Task { await viewModel.clearGenreFilters(repository: wikiRepository) }
                    },
                    onClose: {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            activeFilterPanel = nil
                        }
                    }
                )
            } else if activeFilterPanel == .nations {
                LearnLabelsMultiSelectPanel(
                    title: LT("筛选国家", "Filter Countries", "国で絞り込み"),
                    options: viewModel.availableNationFilters,
                    selectedValues: viewModel.selectedNationFilters,
                    emptyText: LT("暂无可筛选国家", "No countries available for filtering", "絞り込める国はありません"),
                    onToggle: { nation in
                        Task { await viewModel.toggleNationFilter(nation, repository: wikiRepository) }
                    },
                    onClear: {
                        Task { await viewModel.clearNationFilters(repository: wikiRepository) }
                    },
                    onClose: {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            activeFilterPanel = nil
                        }
                    }
                )
            }

            if let total = viewModel.pagination?.total {
                Text(LT("筛选后 \(viewModel.labels.count) / 共 \(total) 个厂牌", "Filtered \(viewModel.labels.count) / Total \(total) labels", "絞り込み後 \(viewModel.labels.count) / 全 \(total) 件のレーベル"))
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private enum LearnLabelsFilterPanelType {
    case genres
    case nations
}

private struct LearnLabelsMultiSelectPanel: View {
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

enum LearnLabelsSortOrder: String {
    case asc
    case desc
}

enum LearnLabelsSortOption: String, CaseIterable, Identifiable {
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

    var defaultOrder: LearnLabelsSortOrder {
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
