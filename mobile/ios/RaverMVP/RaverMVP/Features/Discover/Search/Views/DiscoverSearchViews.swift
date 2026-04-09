import SwiftUI

struct DiscoverFullScreenSearchInputView: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let placeholder: String
    let initialQuery: String
    let onSearch: (String) -> Void

    @State private var query: String
    @FocusState private var isInputFocused: Bool

    init(
        title: String,
        placeholder: String,
        initialQuery: String = "",
        onSearch: @escaping (String) -> Void
    ) {
        self.title = title
        self.placeholder = placeholder
        self.initialQuery = initialQuery
        self.onSearch = onSearch
        _query = State(initialValue: initialQuery)
    }

    var body: some View {
        VStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RaverTheme.accent)
                    Text(L("探索模式", "Explore Mode"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RaverTheme.secondaryText)
                }

                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Text(L("输入关键词开始搜索，结果会从右侧继续推进。", "Enter keywords and the results page will slide in from the right."))
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(RaverTheme.secondaryText)

                    TextField(placeholder, text: $query)
                        .font(.headline)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .focused($isInputFocused)
                        .onSubmit {
                            submit()
                        }
                }
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(RaverTheme.secondaryText.opacity(0.18), lineWidth: 1)
                )

                Button {
                    submit()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.right")
                            .font(.subheadline.weight(.bold))
                        Text(L("查看结果", "View Results"))
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        LinearGradient(
                            colors: [
                                RaverTheme.accent.opacity(trimmedQuery.isEmpty ? 0.42 : 1),
                                Color(red: 0.33, green: 0.22, blue: 0.88).opacity(trimmedQuery.isEmpty ? 0.35 : 0.92)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .disabled(trimmedQuery.isEmpty)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(RaverTheme.card.opacity(0.42))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(RaverTheme.secondaryText.opacity(0.12), lineWidth: 1)
            )

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .background(RaverTheme.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(L("取消", "Cancel")) {
                    dismiss()
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(L("收起", "Dismiss")) {
                    isInputFocused = false
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isInputFocused = true
            }
        }
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func submit() {
        let keyword = trimmedQuery
        guard !keyword.isEmpty else { return }
        isInputFocused = false
        onSearch(keyword)
    }
}

struct DiscoverSearchResultHeader: View {
    let title: String
    let query: String
    let resultCount: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(RaverTheme.primaryText)
            HStack(alignment: .center, spacing: 8) {
                Text("“\(query)”")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RaverTheme.accent)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if let resultCount {
                    Text("\(resultCount)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(RaverTheme.accent, in: Capsule())
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(RaverTheme.card.opacity(0.45))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(RaverTheme.secondaryText.opacity(0.12), lineWidth: 1)
        )
    }
}

struct EventsSearchResultsView: View {
    @Environment(\.discoverPush) private var discoverPush
    @StateObject private var viewModel: EventsSearchResultsViewModel

    init(viewModel: EventsSearchResultsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 10) {
            DiscoverSearchResultHeader(
                title: L("活动搜索结果", "Event Results"),
                query: viewModel.query,
                resultCount: viewModel.events.isEmpty ? nil : viewModel.events.count
            )

            Group {
                if viewModel.isLoading && viewModel.events.isEmpty {
                    ProgressView(L("搜索中...", "Searching..."))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.events.isEmpty {
                    ContentUnavailableView(
                        L("未找到活动", "No events found"),
                        systemImage: "magnifyingglass",
                        description: Text(L("关键词：\(viewModel.query)", "Keyword: \(viewModel.query)"))
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(viewModel.events) { event in
                                Button {
                                    discoverPush(.eventDetail(eventID: event.id))
                                } label: {
                                    EventRow(event: event)
                                }
                                .buttonStyle(.plain)
                            }

                            if viewModel.canLoadMore {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .padding(.vertical, 10)
                                    Spacer()
                                }
                                .onAppear {
                                    Task {
                                        await viewModel.loadMoreIfNeeded(currentEvent: viewModel.events.last)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 4)
                        .padding(.bottom, 18)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .background(RaverTheme.background)
        .navigationTitle(L("搜索", "Search"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task {
            await viewModel.loadIfNeeded()
        }
        .refreshable {
            await viewModel.refresh()
        }
        .alert(L("提示", "Notice"), isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button(L("确定", "OK"), role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

struct NewsSearchResultsView: View {
    @StateObject private var viewModel: NewsSearchResultsViewModel
    @State private var selectedArticleForDetail: DiscoverNewsArticle?

    init(viewModel: NewsSearchResultsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 10) {
            DiscoverSearchResultHeader(
                title: L("资讯搜索结果", "News Results"),
                query: viewModel.query,
                resultCount: viewModel.articles.isEmpty ? nil : viewModel.articles.count
            )

            Group {
                if viewModel.isLoading && viewModel.articles.isEmpty {
                    ProgressView(L("搜索中...", "Searching..."))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.articles.isEmpty {
                    ContentUnavailableView(
                        L("未找到资讯", "No news found"),
                        systemImage: "newspaper",
                        description: Text(L("关键词：\(viewModel.query)", "Keyword: \(viewModel.query)"))
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(viewModel.articles.enumerated()), id: \.element.id) { index, article in
                                Button {
                                    selectedArticleForDetail = article
                                } label: {
                                    DiscoverNewsRow(article: article)
                                }
                                .buttonStyle(.plain)
                                .contentShape(Rectangle())

                                if index < viewModel.articles.count - 1 {
                                    Divider()
                                        .padding(.leading, 16)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .background(RaverTheme.background)
        .navigationTitle(L("搜索", "Search"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task {
            await viewModel.loadIfNeeded()
        }
        .refreshable {
            await viewModel.refresh()
        }
        .fullScreenCover(item: $selectedArticleForDetail) { article in
            DiscoverCoordinatorView {
                DiscoverNewsDetailView(article: article)
            }
        }
        .alert(L("提示", "Notice"), isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button(L("确定", "OK"), role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

struct DJsSearchResultsView: View {
    @StateObject private var viewModel: DJsSearchResultsViewModel
    @State private var selectedDJForDetail: WebDJ?
    @State private var selectedBoardForDetail: RankingBoard?

    init(viewModel: DJsSearchResultsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 10) {
            DiscoverSearchResultHeader(
                title: L("DJ / 榜单结果", "DJ / Ranking Results"),
                query: viewModel.query,
                resultCount: {
                    let total = viewModel.djs.count + viewModel.rankingBoards.count
                    return total == 0 ? nil : total
                }()
            )

            Group {
                if viewModel.isLoading && viewModel.djs.isEmpty && viewModel.rankingBoards.isEmpty {
                    ProgressView(L("搜索中...", "Searching..."))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.djs.isEmpty && viewModel.rankingBoards.isEmpty {
                    ContentUnavailableView(
                        L("未找到 DJ 或榜单", "No DJs or rankings found"),
                        systemImage: "music.mic",
                        description: Text(L("关键词：\(viewModel.query)", "Keyword: \(viewModel.query)"))
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if !viewModel.djs.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(L("DJ", "DJ"))
                                        .font(.headline.weight(.bold))
                                        .foregroundStyle(RaverTheme.primaryText)

                                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                        ForEach(viewModel.djs) { dj in
                                            Button {
                                                selectedDJForDetail = dj
                                            } label: {
                                                DJSearchResultCard(dj: dj)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }

                            if !viewModel.rankingBoards.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(L("榜单", "Rankings"))
                                        .font(.headline.weight(.bold))
                                        .foregroundStyle(RaverTheme.primaryText)

                                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                        ForEach(viewModel.rankingBoards) { board in
                                            Button {
                                                selectedBoardForDetail = board
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
                                }
                            }
                        }
                        .padding(.horizontal, 2)
                        .padding(.top, 4)
                        .padding(.bottom, 16)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .background(RaverTheme.background)
        .navigationTitle(L("搜索", "Search"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task {
            await viewModel.loadIfNeeded()
        }
        .refreshable {
            await viewModel.refresh()
        }
        .fullScreenCover(item: $selectedDJForDetail) { dj in
            DiscoverCoordinatorView {
                DJDetailView(djID: dj.id)
            }
        }
        .navigationDestination(item: $selectedBoardForDetail) { board in
            RankingBoardDetailView(board: board)
        }
        .alert(L("提示", "Notice"), isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button(L("确定", "OK"), role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

struct SetsSearchResultsView: View {
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    @StateObject private var viewModel: SetsSearchResultsViewModel
    @State private var selectedSetForPlayback: WebDJSet?

    init(viewModel: SetsSearchResultsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 10) {
            DiscoverSearchResultHeader(
                title: L("Sets 搜索结果", "Sets Search Results"),
                query: viewModel.query,
                resultCount: viewModel.sets.isEmpty ? nil : viewModel.sets.count
            )

            Group {
                if viewModel.isLoading && viewModel.sets.isEmpty {
                    ProgressView(L("搜索中...", "Searching..."))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.sets.isEmpty {
                    ContentUnavailableView(
                        L("未找到 Sets", "No sets found"),
                        systemImage: "waveform.path.ecg",
                        description: Text(L("关键词：\(viewModel.query)", "Keyword: \(viewModel.query)"))
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(viewModel.sets) { set in
                                Button {
                                    selectedSetForPlayback = set
                                } label: {
                                    DJSetGridCard(set: set)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 2)
                        .padding(.top, 4)
                        .padding(.bottom, 16)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .background(RaverTheme.background)
        .navigationTitle(L("搜索", "Search"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task {
            await viewModel.loadIfNeeded()
        }
        .refreshable {
            await viewModel.refresh()
        }
        .fullScreenCover(item: $selectedSetForPlayback) { set in
            NavigationStack {
                DJSetDetailView(setID: set.id)
            }
            .toolbar(.hidden, for: .tabBar)
        }
        .alert(L("提示", "Notice"), isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button(L("确定", "OK"), role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

struct WikiSearchResultsView: View {
    let preferredSection: LearnModuleSection

    @StateObject private var viewModel: WikiSearchResultsViewModel
    @State private var selectedTab: Tab
    @State private var selectedLabelForDetail: LearnLabel?
    @State private var selectedFestivalForDetail: LearnFestival?

    private enum Tab: String, CaseIterable, Identifiable {
        case labels
        case festivals

        var id: String { rawValue }
        var title: String {
            switch self {
            case .labels: return L("厂牌", "Labels")
            case .festivals: return L("电音节", "Festivals")
            }
        }
    }

    init(viewModel: WikiSearchResultsViewModel, preferredSection: LearnModuleSection) {
        self.preferredSection = preferredSection
        _viewModel = StateObject(wrappedValue: viewModel)
        _selectedTab = State(initialValue: preferredSection == .festivals ? .festivals : .labels)
    }

    var body: some View {
        VStack(spacing: 10) {
            DiscoverSearchResultHeader(
                title: L("Wiki 搜索结果", "Wiki Search Results"),
                query: viewModel.query,
                resultCount: {
                    let total = selectedTab == .labels ? viewModel.labels.count : viewModel.festivals.count
                    return total == 0 ? nil : total
                }()
            )

            Picker("", selection: $selectedTab) {
                ForEach(Tab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 2)

            Group {
                if viewModel.isLoading && viewModel.labels.isEmpty && viewModel.festivals.isEmpty {
                    ProgressView(L("搜索中...", "Searching..."))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if selectedTab == .labels {
                    labelsSection
                } else {
                    festivalsSection
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .background(RaverTheme.background)
        .navigationTitle(L("搜索", "Search"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task {
            await viewModel.loadIfNeeded()
        }
        .refreshable {
            await viewModel.refresh()
        }
        .fullScreenCover(item: $selectedLabelForDetail) { label in
            NavigationStack {
                LearnLabelDetailView(label: label)
            }
        }
        .fullScreenCover(item: $selectedFestivalForDetail) { festival in
            DiscoverCoordinatorView {
                LearnFestivalDetailView(festival: festival)
            }
        }
        .alert(L("提示", "Notice"), isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button(L("确定", "OK"), role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var labelsSection: some View {
        if viewModel.labels.isEmpty {
            ContentUnavailableView(
                L("未找到厂牌", "No labels found"),
                systemImage: "building.2",
                description: Text(L("关键词：\(viewModel.query)", "Keyword: \(viewModel.query)"))
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(viewModel.labels) { label in
                        LearnLabelCard(label: label)
                            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .onTapGesture {
                                selectedLabelForDetail = label
                            }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }

    @ViewBuilder
    private var festivalsSection: some View {
        if viewModel.festivals.isEmpty {
            ContentUnavailableView(
                L("未找到电音节", "No festivals found"),
                systemImage: "music.quarternote.3",
                description: Text(L("关键词：\(viewModel.query)", "Keyword: \(viewModel.query)"))
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(viewModel.festivals) { festival in
                        LearnFestivalCard(festival: festival)
                            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .onTapGesture {
                                selectedFestivalForDetail = festival
                            }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }
}
