import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';

import '../_shared/profile_service_locator.dart';
import 'view_models/checkin_view_model.dart';

/// Screen listing the current user's event check-ins.
class MyCheckinsScreen extends StatefulWidget {
  const MyCheckinsScreen({super.key});

  @override
  State<MyCheckinsScreen> createState() => _MyCheckinsScreenState();
}

class _MyCheckinsScreenState extends State<MyCheckinsScreen> {
  late final CheckinViewModel _viewModel;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _viewModel = CheckinViewModel(api: ProfileServiceLocator.checkinApi);
    _viewModel.addListener(_rebuild);
    _viewModel.load();
    _scrollController.addListener(_onScroll);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _viewModel.loadMore();
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_rebuild);
    _scrollController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return Scaffold(
      appBar: AppBar(
        title: Text(lt('我的签到', 'My Check-ins', 'マイチェックイン')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: LoadPhaseBuilder<MyCheckinsOverviewResponse>(
        phase: _viewModel.phase,
        onLoading: () => const Center(
          child: CircularProgressIndicator.adaptive(),
        ),
        onFailure: (error) => ErrorStateView(
          title: lt('加载失败', 'Failed to Load', '読み込みに失敗しました'),
          error: error,
          onRetry: _viewModel.load,
          retryLabel: lt('重试', 'Retry', '再試行'),
        ),
        onSuccess: (overview) => _buildContent(context, theme, overview),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    RaverThemeData theme,
    MyCheckinsOverviewResponse overview,
  ) {
    return RefreshIndicator(
      color: theme.accent,
      onRefresh: _viewModel.refresh,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Stats card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildStatsCard(theme, overview.stats),
            ),
          ),

          // View mode toggle
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: RaverSegmentedControl(
                segments: [
                  lt('时间线', 'Timeline', 'タイムライン'),
                  lt('画廊', 'Gallery', 'ギャラリー'),
                ],
                selectedIndex: _viewModel.viewMode,
                onChanged: _viewModel.setViewMode,
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // Content
          if (_viewModel.viewMode == 0)
            _buildTimelineView(theme, overview)
          else
            _buildGalleryView(theme),
        ],
      ),
    );
  }

  Widget _buildStatsCard(
      RaverThemeData theme, MyCheckinsOverviewStats stats) {
    return GlassCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatColumn(
            value: stats.totalCheckins.toString(),
            label: lt('总签到', 'Total', '合計'),
            theme: theme,
          ),
          _StatColumn(
            value: stats.uniqueEvents.toString(),
            label: lt('活动', 'Events', 'イベント'),
            theme: theme,
          ),
          _StatColumn(
            value: stats.uniqueDJs.toString(),
            label: lt('DJ', 'DJs', 'DJ'),
            theme: theme,
          ),
          _StatColumn(
            value: stats.totalDays.toString(),
            label: lt('天数', 'Days', '日数'),
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineView(
    RaverThemeData theme,
    MyCheckinsOverviewResponse overview,
  ) {
    if (overview.timeline.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: EmptyStateView(
            icon: Icons.timeline,
            title: lt('暂无签到记录', 'No Check-ins', 'チェックイン記録なし'),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, sectionIndex) {
          final section = overview.timeline[sectionIndex];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Year header
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${section.year}',
                    style: RaverTypography.label(
                      size: 14,
                      color: theme.accent,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Timeline items
                ...section.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildTimelineItem(theme, item),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
        childCount: overview.timeline.length,
      ),
    );
  }

  Widget _buildTimelineItem(
    RaverThemeData theme,
    MyCheckinsOverviewTimelineItem item,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.cardBorder),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: item.coverImageUrl.isNotEmpty
                ? RemoteCoverImage(
                    url: item.coverImageUrl,
                    width: 56,
                    height: 56,
                  )
                : Container(
                    width: 56,
                    height: 56,
                    color: theme.cardBorder,
                    child: Icon(Icons.event, color: theme.secondaryText),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.eventName,
                  style: RaverTypography.label(
                    size: 15,
                    color: theme.primaryText,
                    weight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  item.date,
                  style: RaverTypography.caption(color: theme.secondaryText),
                ),
                if (item.djCount > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${item.djCount} DJs',
                    style: RaverTypography.caption(color: theme.accent),
                  ),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: theme.secondaryText, size: 20),
        ],
      ),
    );
  }

  Widget _buildGalleryView(RaverThemeData theme) {
    if (_viewModel.checkins.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: EmptyStateView(
            icon: Icons.photo_library_outlined,
            title: lt('暂无签到照片', 'No Photos', 'チェックイン写真なし'),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.85,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final checkin = _viewModel.checkins[index];
            return _buildGalleryItem(theme, checkin);
          },
          childCount: _viewModel.checkins.length,
        ),
      ),
    );
  }

  Widget _buildGalleryItem(RaverThemeData theme, WebCheckin checkin) {
    return Container(
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12)),
              child: checkin.eventCoverUrl.isNotEmpty
                  ? RemoteCoverImage(
                      url: checkin.eventCoverUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    )
                  : Container(
                      color: theme.cardBorder,
                      child:
                          Icon(Icons.event, color: theme.secondaryText),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  checkin.eventName,
                  style: RaverTypography.label(
                    size: 13,
                    color: theme.primaryText,
                    weight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  checkin.attendedAt,
                  style: RaverTypography.caption(
                      color: theme.secondaryText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.value,
    required this.label,
    required this.theme,
  });

  final String value;
  final String label;
  final RaverThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: RaverTypography.title(
            size: 20,
            color: theme.accent,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: RaverTypography.caption(color: theme.secondaryText),
        ),
      ],
    );
  }
}
