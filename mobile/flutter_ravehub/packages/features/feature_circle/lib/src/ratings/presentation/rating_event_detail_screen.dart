import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';

import '../view_models/rating_view_model.dart';
import '../widgets/create_rating_unit_sheet.dart';
import '../../_shared/circle_service_locator.dart';

/// Detail screen for a specific rating event, showing all rating units.
class RatingEventDetailScreen extends StatefulWidget {
  const RatingEventDetailScreen({super.key, required this.ratingId});

  final String ratingId;

  @override
  State<RatingEventDetailScreen> createState() =>
      _RatingEventDetailScreenState();
}

class _RatingEventDetailScreenState extends State<RatingEventDetailScreen> {
  late final RatingDetailViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = RatingDetailViewModel(
      ratingId: widget.ratingId,
      repository: CircleServiceLocator.ratingRepository,
    );
    _viewModel.addListener(_rebuild);
    _viewModel.load();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _viewModel.removeListener(_rebuild);
    _viewModel.dispose();
    super.dispose();
  }

  void _showCreateUnitSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateRatingUnitSheet(
        onSubmit: (name, djId) async {
          await _viewModel.createUnit(name: name, djId: djId);
          if (mounted) Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.background,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.primaryText),
          onPressed: () => context.pop(),
        ),
        title: Text(
          lt('评分详情', 'Rating Detail', '評価詳細'),
          style: RaverTypography.title(size: 17, color: theme.primaryText),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: theme.accent),
            onPressed: _showCreateUnitSheet,
          ),
        ],
        elevation: 0,
      ),
      body: LoadPhaseBuilder<WebRatingEvent>(
        phase: _viewModel.phase,
        onLoading: () =>
            const Center(child: CircularProgressIndicator.adaptive()),
        onFailure: (error) => ErrorStateView(
          title: lt('加载失败', 'Failed to Load', '読み込みに失敗しました'),
          error: error,
          onRetry: _viewModel.load,
          retryLabel: lt('重试', 'Retry', '再試行'),
        ),
        onSuccess: (event) => _buildContent(event, theme),
      ),
    );
  }

  Widget _buildContent(WebRatingEvent event, RaverThemeData theme) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(event, theme),

          const SizedBox(height: 20),

          // Ranking chart
          if (_viewModel.units.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                lt('排名', 'Rankings', 'ランキング'),
                style: RaverTypography.title(
                  size: 16,
                  color: theme.primaryText,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildRankingChart(theme),
            const SizedBox(height: 20),
          ],

          // Units list
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              lt('评分单元', 'Rating Units', '評価ユニット'),
              style: RaverTypography.title(
                size: 16,
                color: theme.primaryText,
              ),
            ),
          ),
          const SizedBox(height: 8),

          if (_viewModel.units.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: EmptyStateView(
                icon: Icons.format_list_numbered,
                title: lt('暂无评分单元', 'No units yet', 'ユニットなし'),
              ),
            )
          else
            ..._viewModel.units.asMap().entries.map(
                  (entry) => _UnitTile(
                    unit: entry.value,
                    rank: entry.key + 1,
                    theme: theme,
                    onTap: () => context.push(
                      '/circle/ratings/${widget.ratingId}/units/${entry.value.id}',
                    ),
                  ),
                ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHeader(WebRatingEvent event, RaverThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (event.imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: RemoteCoverImage(
                url: event.imageUrl,
                width: double.infinity,
                height: 180,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(height: 16),
          Text(
            event.name,
            style: RaverTypography.headline(color: theme.primaryText)
                .copyWith(fontSize: 22),
          ),
          const SizedBox(height: 6),
          Text(
            event.description,
            style: RaverTypography.body(
              size: 14,
              color: theme.secondaryText,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.event, size: 14, color: theme.accent),
              const SizedBox(width: 4),
              Text(
                event.eventName,
                style: RaverTypography.caption(
                  size: 12,
                  color: theme.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRankingChart(RaverThemeData theme) {
    final maxRating = _viewModel.units
        .map((u) => u.rating ?? 0)
        .reduce((a, b) => a > b ? a : b);
    if (maxRating == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: _viewModel.units.take(5).map((unit) {
          final ratio = (unit.rating ?? 0) / maxRating;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    unit.djName,
                    style: RaverTypography.caption(
                      size: 12,
                      color: theme.primaryText,
                      weight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 24,
                    decoration: BoxDecoration(
                      color: theme.card,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: ratio.clamp(0.05, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.accent.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  (unit.rating ?? 0).toStringAsFixed(1),
                  style: RaverTypography.label(
                    size: 13,
                    color: theme.primaryText,
                    weight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _UnitTile extends StatelessWidget {
  const _UnitTile({
    required this.unit,
    required this.rank,
    required this.theme,
    required this.onTap,
  });

  final WebRatingUnit unit;
  final int rank;
  final RaverThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.cardBorder),
        ),
        child: Row(
          children: [
            // Rank number
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: rank <= 3
                    ? theme.accent.withValues(alpha: 0.15)
                    : theme.cardBorder,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '$rank',
                  style: RaverTypography.label(
                    size: 13,
                    color: rank <= 3 ? theme.accent : theme.secondaryText,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Avatar
            CircleAvatar(
              radius: 18,
              backgroundColor: theme.cardBorder,
              backgroundImage: unit.djAvatarUrl.isNotEmpty
                  ? NetworkImage(unit.djAvatarUrl)
                  : null,
              child: unit.djAvatarUrl.isEmpty
                  ? Icon(Icons.person, size: 18, color: theme.secondaryText)
                  : null,
            ),
            const SizedBox(width: 10),

            // Name and score
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    unit.name,
                    style: RaverTypography.label(
                      size: 14,
                      color: theme.primaryText,
                      weight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    unit.djName,
                    style: RaverTypography.caption(
                      color: theme.secondaryText,
                    ),
                  ),
                ],
              ),
            ),

            // Rating
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, size: 16, color: Colors.amber),
                    const SizedBox(width: 2),
                    Text(
                      (unit.rating ?? 0).toStringAsFixed(1),
                      style: RaverTypography.label(
                        size: 15,
                        color: theme.primaryText,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${unit.ratingCount} ${lt("票", "votes", "票")}',
                  style: RaverTypography.caption(
                    size: 11,
                    color: theme.secondaryText,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
