import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';
import 'package:raver_platform/raver_platform.dart';

import '../data/ranking_api.dart';
import 'ranking_view_model.dart';

class RankingBoardDetailScreen extends ConsumerWidget {
  const RankingBoardDetailScreen({super.key, required this.boardId, this.year});

  final String boardId;
  final int? year;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = RankingDetailRequest(boardId: boardId, year: year);
    final state = ref.watch(rankingDetailProvider(request));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          state.detail?.title ?? lt('排行榜', 'Rankings', 'ランキング'),
        ),
        actions: [
          IconButton(
            tooltip: lt('分享', 'Share', '共有'),
            icon: const Icon(Icons.share_outlined),
            onPressed: state.detail == null
                ? null
                : () => _shareRankingBoard(context, ref, state.detail!),
          ),
        ],
      ),
      body: _buildBody(context, ref, state, request),
    );
  }

  Future<void> _shareRankingBoard(
    BuildContext context,
    WidgetRef ref,
    RankingBoardDetail detail,
  ) async {
    final fallbackUrl =
        'https://ravehub.top/ranking-board/${detail.id}?year=${detail.year}';
    try {
      final payload = await ref
          .read(rankingApiProvider)
          .resolveShareLink(detail: detail, channel: 'system_share');
      final shareUrl = payload.shortUrl.isNotEmpty
          ? payload.shortUrl
          : (payload.url.isNotEmpty ? payload.url : fallbackUrl);
      await ShareService.shareUrl(shareUrl, subject: detail.title);
    } catch (e) {
      await ShareService.shareUrl(fallbackUrl, subject: detail.title);
      if (!context.mounted) return;
      ToastBanner.show(
        context,
        message: lt('已使用备用链接分享', 'Shared fallback link', '予備リンクを共有しました'),
        type: ToastType.info,
      );
    }
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    RankingDetailState state,
    RankingDetailRequest request,
  ) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (state.error != null) {
      return ErrorStateView(
        title: lt('加载失败', 'Failed to load', 'ロードに失敗しました'),
        description: state.error,
        onRetry: () =>
            ref.read(rankingDetailProvider(request).notifier).retry(),
      );
    }

    final detail = state.detail;
    if (detail == null) {
      return EmptyStateView(
        icon: Icons.leaderboard_outlined,
        title: lt('排行榜未找到', 'Ranking not found', 'ランキングが見つかりません'),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                '${detail.year}',
                style: RaverTypography.headline(),
              ),
              const Spacer(),
              Text(
                '${detail.entries.length} ${lt("位", "entries", "エントリー")}',
                style: RaverTypography.caption(),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: detail.entries.length,
            itemBuilder: (context, index) {
              final entry = detail.entries[index];
              return _RankingEntryTile(
                boardId: detail.id,
                year: detail.year,
                entry: entry,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RankingEntryTile extends StatelessWidget {
  const _RankingEntryTile({
    required this.boardId,
    required this.year,
    required this.entry,
  });

  final String boardId;
  final int year;
  final RankingEntry entry;

  @override
  Widget build(BuildContext context) {
    final isTopThree = entry.rank <= 3;

    final entryId = Uri.encodeComponent(entry.djId ?? '${entry.rank}');

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () =>
            context.push('/rankings/$boardId/entries/$entryId?year=$year'),
        borderRadius: BorderRadius.circular(14),
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          borderRadius: 14,
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: isTopThree
                    ? Icon(
                        Icons.emoji_events_rounded,
                        color: _medalColor(entry.rank),
                        size: 24,
                      )
                    : Text(
                        '#${entry.rank}',
                        style: RaverTypography.label(),
                        textAlign: TextAlign.center,
                      ),
              ),
              const SizedBox(width: 12),
              if (entry.djAvatarUrl != null)
                ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: entry.djAvatarUrl!,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const SkeletonShimmer(
                      child: SkeletonCircle(size: 40),
                    ),
                    errorWidget: (_, __, ___) => CircleAvatar(
                      radius: 20,
                      child: Text(
                        entry.name.isNotEmpty ? entry.name[0] : '?',
                      ),
                    ),
                  ),
                )
              else
                CircleAvatar(
                  radius: 20,
                  child: Text(entry.name.isNotEmpty ? entry.name[0] : '?'),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  entry.name,
                  style: RaverTypography.title(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (entry.delta != null) _DeltaBadge(delta: entry.delta!),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Color _medalColor(int rank) {
    return switch (rank) {
      1 => const Color(0xFFFFD700),
      2 => const Color(0xFFC0C0C0),
      3 => const Color(0xFFCD7F32),
      _ => Colors.grey,
    };
  }
}

class _DeltaBadge extends StatelessWidget {
  const _DeltaBadge({required this.delta});
  final int delta;

  @override
  Widget build(BuildContext context) {
    if (delta == 0) {
      return Text('—', style: RaverTypography.caption());
    }

    final isUp = delta > 0;
    final color = isUp ? Colors.green : Colors.red;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isUp ? Icons.arrow_drop_up : Icons.arrow_drop_down,
          color: color,
          size: 20,
        ),
        Text(
          '${delta.abs()}',
          style: RaverTypography.caption().copyWith(color: color),
        ),
      ],
    );
  }
}
