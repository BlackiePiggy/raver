import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';

import '../data/ranking_api.dart';
import 'ranking_view_model.dart';

/// Detail screen for a single ranking entry (a DJ or artist in the board).
///
/// Loads the parent board detail and finds the entry by index, since
/// the API does not expose a per-entry endpoint.
class RankingEntryDetailScreen extends ConsumerStatefulWidget {
  /// Creates a [RankingEntryDetailScreen].
  const RankingEntryDetailScreen({
    super.key,
    required this.boardId,
    required this.entryId,
  });

  /// The ranking board ID.
  final String boardId;

  /// The entry ID (used as an index or name key).
  final String entryId;

  @override
  ConsumerState<RankingEntryDetailScreen> createState() =>
      _RankingEntryDetailScreenState();
}

class _RankingEntryDetailScreenState
    extends ConsumerState<RankingEntryDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rankingDetailProvider(widget.boardId));
    final theme = context.raver;

    return Scaffold(
      appBar: RaverNavigationChrome(
        title: lt('排名详情', 'Ranking Entry', 'ランキング詳細'),
      ),
      body: _buildBody(context, state, theme),
    );
  }

  Widget _buildBody(
    BuildContext context,
    RankingDetailState state,
    RaverThemeData theme,
  ) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (state.error != null) {
      return ErrorStateView(
        title: lt('加载失败', 'Failed to load', 'ロードに失敗しました'),
        description: state.error,
        onRetry: () =>
            ref.read(rankingDetailProvider(widget.boardId).notifier).retry(),
      );
    }

    final detail = state.detail;
    if (detail == null) {
      return EmptyStateView(
        icon: Icons.leaderboard_outlined,
        title: lt('未找到', 'Not found', '見つかりません'),
      );
    }

    // Find the entry by matching entryId as rank index (1-based) or name.
    final entryIndex = int.tryParse(widget.entryId);
    RankingEntry? entry;
    if (entryIndex != null && entryIndex > 0 && entryIndex <= detail.entries.length) {
      entry = detail.entries[entryIndex - 1];
    } else {
      // Fall back to matching by name or djId.
      for (final e in detail.entries) {
        if (e.djId == widget.entryId || e.name == widget.entryId) {
          entry = e;
          break;
        }
      }
    }

    if (entry == null) {
      return EmptyStateView(
        icon: Icons.person_off_outlined,
        title: lt('条目未找到', 'Entry not found', 'エントリーが見つかりません'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar / hero image
          if (entry.djAvatarUrl != null)
            ClipOval(
              child: CachedNetworkImage(
                imageUrl: entry.djAvatarUrl!,
                width: 120,
                height: 120,
                fit: BoxFit.cover,
                placeholder: (_, __) => const SkeletonShimmer(
                  child: SkeletonCircle(size: 120),
                ),
                errorWidget: (_, __, ___) => CircleAvatar(
                  radius: 60,
                  child: Text(
                    entry!.name.isNotEmpty ? entry.name[0] : '?',
                    style: RaverTypography.headline(),
                  ),
                ),
              ),
            )
          else
            CircleAvatar(
              radius: 60,
              child: Text(
                entry.name.isNotEmpty ? entry.name[0] : '?',
                style: RaverTypography.headline(),
              ),
            ),
          const SizedBox(height: 16),

          // Name
          Text(
            entry.name,
            style: RaverTypography.headline(color: theme.primaryText),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Rank badge
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            borderRadius: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (entry.rank <= 3)
                  Icon(
                    Icons.emoji_events_rounded,
                    color: _medalColor(entry.rank),
                    size: 24,
                  )
                else
                  Text(
                    '#${entry.rank}',
                    style: RaverTypography.title(color: theme.primaryText),
                  ),
                const SizedBox(width: 8),
                Text(
                  '${lt("在", "in", "")} ${detail.title} ${detail.year}',
                  style: RaverTypography.body(color: theme.secondaryText),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Year-on-year delta
          if (entry.delta != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  lt('同比变化', 'Year-on-Year Change', '前年比'),
                  style: RaverTypography.label(color: theme.secondaryText),
                ),
                const SizedBox(width: 8),
                _buildDelta(entry.delta!),
              ],
            ),
            const SizedBox(height: 24),
          ],

          // DJ profile link
          if (entry.djId != null) ...[
            const Divider(),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => context.push('/djs/${entry!.djId}'),
              icon: const Icon(Icons.person_outline),
              label: Text(
                lt('查看DJ资料', 'View DJ Profile', 'DJプロフィールを見る'),
              ),
            ),
          ],

          // Festival link
          if (entry.festivalId != null) ...[
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: () =>
                  context.push('/festivals/${entry!.festivalId}'),
              icon: const Icon(Icons.festival_outlined),
              label: Text(
                lt('查看音乐节', 'View Festival', 'フェスティバルを見る'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDelta(int delta) {
    if (delta == 0) {
      return Text('--', style: RaverTypography.body());
    }
    final isUp = delta > 0;
    final color = isUp ? Colors.green : Colors.red;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isUp ? Icons.arrow_drop_up : Icons.arrow_drop_down,
          color: color,
          size: 28,
        ),
        Text(
          '${delta.abs()}',
          style: RaverTypography.title().copyWith(color: color),
        ),
      ],
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
