import SwiftUI

struct LearnOrganizersRootView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @Environment(\.discoverPush) private var discoverPush

    @StateObject private var viewModel = LearnOrganizersRootViewModel()

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
                        InlineLoadingBadge(title: LT("正在更新主办方", "Updating organizers", "主催を更新中"))
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

            festivalsToolbar
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
        .onReceive(NotificationCenter.default.publisher(for: .discoverOrganizerDidSave)) { _ in
            Task { await viewModel.reload(repository: wikiRepository, force: true) }
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
                title: LT("主办方加载失败", "Organizers Failed to Load", "主催の読み込みに失敗しました"),
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
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if viewModel.festivals.isEmpty {
                        ContentUnavailableView(
                            LT("暂无匹配主办方", "No Matching Organizers", "一致する主催はありません"),
                            systemImage: "music.quarternote.3"
                        )
                        .frame(maxWidth: .infinity, minHeight: 220)
                    } else {
                        LazyVStack(spacing: 14) {
                            ForEach(viewModel.festivals) { festival in
                                LearnFestivalCard(festival: festival)
                                    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .onTapGesture {
                                        discoverPush(.festivalDetail(festivalID: festival.id, prefetchedFestival: festival))
                                    }
                                    .onAppear {
                                        guard festival.id == viewModel.festivals.last?.id else { return }
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
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .raverTabBarBottomPadding(12)
            }
            .refreshable {
                await viewModel.reload(repository: wikiRepository, force: true)
            }
        }
    }

    @ViewBuilder
    private var festivalsToolbar: some View {
        HStack(spacing: 10) {
            let totalFestivals = viewModel.pagination?.total ?? viewModel.festivals.count
            Text(
                LT(
                    "已加载 \(viewModel.festivals.count) / 共 \(totalFestivals) 个主办方",
                    "Loaded \(viewModel.festivals.count) / \(totalFestivals) organizers",
                    "\(viewModel.festivals.count) / \(totalFestivals) 件の主催を読み込み済み"
                )
            )
            .font(.caption)
            .foregroundStyle(RaverTheme.secondaryText)

            Spacer(minLength: 0)

            Button {
                discoverPush(.organizerCreate(initialName: nil))
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
