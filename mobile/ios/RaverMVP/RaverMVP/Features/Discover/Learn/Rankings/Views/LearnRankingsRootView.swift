import SwiftUI

struct LearnRankingsRootView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @Environment(\.appPush) private var appPush

    @StateObject private var viewModel = LearnRankingsRootViewModel()

    let isActive: Bool

    init(isActive: Bool = true) {
        self.isActive = isActive
    }

    private var djRankingRepository: DJRankingRepository {
        appContainer.djRankingRepository
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isRefreshing || viewModel.bannerMessage != nil {
                VStack(alignment: .leading, spacing: 10) {
                    if viewModel.isRefreshing {
                        InlineLoadingBadge(title: LT("正在更新榜单", "Updating rankings", "ランキングを更新中"))
                    }
                    if let bannerMessage = viewModel.bannerMessage {
                        ScreenStatusBanner(
                            message: bannerMessage,
                            style: .error,
                            actionTitle: LT("重试", "Retry", "再試行")
                        ) {
                            Task { await viewModel.reload(repository: djRankingRepository, force: true) }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(RaverTheme.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.triggerInitialLoadIfNeeded(isActive: isActive, repository: djRankingRepository)
        }
        .onChange(of: isActive) { _, nextValue in
            Task {
                await viewModel.triggerInitialLoadIfNeeded(isActive: nextValue, repository: djRankingRepository)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.phase == .idle || viewModel.phase == .initialLoading {
            DiscoverGridSkeletonView()
                .frame(maxWidth: .infinity, minHeight: 220)
        } else if case .failure(let message) = viewModel.phase {
            ScreenErrorCard(
                title: LT("榜单加载失败", "Rankings Failed to Load", "ランキングの読み込みに失敗しました"),
                message: message
            ) {
                Task { await viewModel.reload(repository: djRankingRepository, force: true) }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
        } else if case .offline(let message) = viewModel.phase {
            ScreenErrorCard(
                title: LT("网络不可用", "Network Unavailable", "ネットワークを利用できません"),
                message: message
            ) {
                Task { await viewModel.reload(repository: djRankingRepository, force: true) }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
        } else if viewModel.rankingBoards.isEmpty {
            ContentUnavailableView(LT("暂无榜单", "暂无榜单", "ランキングはまだありません"), systemImage: "list.number")
                .frame(maxWidth: .infinity, minHeight: 220)
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(viewModel.rankingBoards) { board in
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
                .raverTabBarBottomPadding(12)
            }
            .refreshable {
                await viewModel.reload(repository: djRankingRepository, force: true)
            }
        }
    }
}
