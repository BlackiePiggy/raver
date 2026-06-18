import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';

import 'ranking_view_model.dart';

class RankingsRootScreen extends ConsumerStatefulWidget {
  const RankingsRootScreen({super.key});

  @override
  ConsumerState<RankingsRootScreen> createState() => _RankingsRootScreenState();
}

class _RankingsRootScreenState extends ConsumerState<RankingsRootScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: RaverMotion.normal,
      curve: RaverMotion.curve,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rankingsProvider);

    if (state.isLoading && state.boards.isEmpty) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (state.error != null && state.boards.isEmpty) {
      return ErrorStateView(
        title: lt('加载失败', 'Failed to load', 'ロードに失敗しました'),
        description: state.error,
        onRetry: () => ref.read(rankingsProvider.notifier).loadRankings(),
      );
    }

    if (state.boards.isEmpty) {
      return EmptyStateView(
        icon: Icons.leaderboard_outlined,
        title: lt('暂无排行榜', 'No rankings yet', 'ランキングなし'),
      );
    }

    return RaverTabReselectionListener(
      tabIndex: 0,
      onReselected: _scrollToTop,
      child: RefreshIndicator(
        onRefresh: () => ref.read(rankingsProvider.notifier).loadRankings(),
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: state.boards.length,
          itemBuilder: (context, index) {
            final board = state.boards[index];
            return _RankingBoardTile(
              board: board,
              onTap: () => context.push('/rankings/${board.id}'),
            );
          },
        ),
      ),
    );
  }
}

class _RankingBoardTile extends StatelessWidget {
  const _RankingBoardTile({required this.board, required this.onTap});
  final RankingBoard board;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [
                    RaverColors.accent(Theme.of(context).brightness),
                    RaverColors.accent(Theme.of(context).brightness)
                        .withValues(alpha: 0.6),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    board.title,
                    style: RaverTypography.title(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${board.years.length} ${lt("届", "editions", "回")}  •  ${board.years.first}–${board.years.last}',
                    style: RaverTypography.caption(),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ),
    );
  }
}
