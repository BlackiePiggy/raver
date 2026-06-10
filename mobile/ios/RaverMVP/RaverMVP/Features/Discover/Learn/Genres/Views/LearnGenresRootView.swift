import SwiftUI

struct LearnGenresRootView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @Environment(\.raverTabBarReservedHeight) private var tabBarReservedHeight

    @StateObject private var viewModel = LearnGenresRootViewModel()

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
                        InlineLoadingBadge(title: LT("正在更新流派", "Updating genres", "ジャンルを更新中"))
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
                title: LT("学习内容加载失败", "Learn Content Failed to Load", "学習コンテンツの読み込みに失敗しました"),
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
        } else if viewModel.genreTree.isEmpty {
            ContentUnavailableView(
                LT("暂无学习内容", "暂无学习内容", "学習コンテンツはまだありません"),
                systemImage: "book"
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            LearnGenreSunburstSection(
                genres: viewModel.genreTree,
                wikiRepository: wikiRepository,
                bottomInset: max(0, tabBarReservedHeight) + 14
            )
            .refreshable {
                await viewModel.reload(repository: wikiRepository, force: true)
            }
        }
    }
}
