import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';
import 'package:raver_platform/raver_platform.dart';

import '../view_models/event_detail_view_model.dart';
import '../../_shared/discover_service_locator.dart';
import '../widgets/event_schedule_section.dart';
import '../widgets/event_live_discussion_section.dart';
import '../widgets/event_checkin_section.dart';
import '../widgets/event_route_section.dart';
import '../widgets/event_map_section.dart';
import '../widgets/event_share_section.dart';

// iOS per-tab theme colours (MainTabView / EventDetailView)
const _kInfoColor       = Color(0xFF44D9D1);  // teal     (0.27, 0.85, 0.82)
const _kLineupColor     = Color(0xFF4DAAF8);  // blue     (0.30, 0.67, 0.97)
const _kTimetableColor  = Color(0xFF8FC74C);  // green    (0.56, 0.78, 0.30)
const _kNewsColor       = Color(0xFFF88C3F);  // orange   (0.97, 0.55, 0.25)
const _kPostsColor      = Color(0xFFF24D61);  // red      (0.95, 0.30, 0.38)
const _kRatingsColor    = Color(0xFFFAB538);  // gold     (0.98, 0.71, 0.22)
const _kSetsColor       = Color(0xFF946EF2);  // purple   (0.58, 0.43, 0.95)

// iOS hero height 360pt
const double _kHeroHeight = 360;

class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen>
    with SingleTickerProviderStateMixin {
  late final EventDetailViewModel _viewModel;
  late final TabController _tabController;

  static const _tabColors = [
    _kInfoColor,
    _kLineupColor,
    _kTimetableColor,
    _kNewsColor,
    _kPostsColor,
    _kRatingsColor,
    _kSetsColor,
  ];

  @override
  void initState() {
    super.initState();
    _viewModel = EventDetailViewModel(
      eventId: widget.eventId,
      repository: DiscoverServiceLocator.eventsRepository,
    );
    // iOS has 7 tabs: Info / Lineup / Timetable / News / Posts / Ratings / Sets
    _tabController = TabController(length: 7, vsync: this);
    _viewModel.addListener(_rebuild);
    _viewModel.load();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _viewModel.removeListener(_rebuild);
    _tabController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LoadPhaseBuilder<WebEvent>(
        phase: _viewModel.phase,
        onLoading: () => const EventDetailSkeleton(),
        onFailure: (error) => ErrorStateView(
          title: lt('加载失败', 'Failed to Load', '読み込みに失敗しました'),
          error: error,
          onRetry: _viewModel.load,
          retryLabel: lt('重试', 'Retry', '再試行'),
        ),
        onSuccess: (event) => _buildDetail(context, event),
      ),
    );
  }

  Widget _buildDetail(BuildContext context, WebEvent event) {
    final theme = context.raver;

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        _buildHeroAppBar(context, event, theme),
        SliverToBoxAdapter(child: _buildActionBar(event, theme)),
        SliverPersistentHeader(
          pinned: true,
          delegate: _TabBarDelegate(
            tabController: _tabController,
            theme: theme,
          ),
        ),
      ],
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInfoTab(event, theme),
          _buildLineupTab(theme),
          _buildTimetableTab(theme),
          _buildNewsTab(theme),
          _buildPostsTab(theme),
          _buildRatingsTab(theme),
          _buildSetsTab(theme),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Hero
  // ---------------------------------------------------------------------------

  Widget _buildHeroAppBar(
    BuildContext context,
    WebEvent event,
    RaverThemeData theme,
  ) {
    return SliverAppBar(
      // iOS: heroHeight 360
      expandedHeight: _kHeroHeight,
      pinned: true,
      backgroundColor: theme.background,
      leading: IconButton(
        icon: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
        ),
        onPressed: () => context.pop(),
      ),
      actions: [
        IconButton(
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.more_horiz, color: Colors.white, size: 20),
          ),
          onPressed: () {},
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            RemoteCoverImage(url: event.coverImageUrl, fit: BoxFit.cover),
            // iOS: 4-stop gradient (clear, black@0.42, black@0.78, black@0.94)
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Color(0x6B000000), // black @ 0.42
                    Color(0xC7000000), // black @ 0.78
                    Color(0xF0000000), // black @ 0.94
                  ],
                  stops: [0.0, 0.4, 0.75, 1.0],
                ),
              ),
            ),
            // iOS: event name 28pt bold at bottom-left
            Positioned(
              left: 16,
              right: 72,
              bottom: 16,
              child: Text(
                event.name,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Action bar  (iOS: Follow capsule + Check-in capsule + Live Discussion)
  // ---------------------------------------------------------------------------

  Widget _buildActionBar(WebEvent event, RaverThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Follow button — iOS: blue (0.20, 0.56, 0.98) capsule + bell icon
          Expanded(
            child: _CapsuleActionButton(
              icon: _viewModel.isFavorited
                  ? Icons.notifications
                  : Icons.notifications_outlined,
              label: _viewModel.isFavorited
                  ? lt('已关注', 'Following', 'フォロー中')
                  : lt('关注', 'Follow', 'フォロー'),
              fillColor: const Color(0xFF339AFC), // blue (0.20, 0.56, 0.98)
              isLoading: _viewModel.isTogglingFavorite,
              onTap: _viewModel.toggleFavorite,
            ),
          ),
          const SizedBox(width: 10),
          // Check-in button — iOS: accent capsule
          Expanded(
            child: _CapsuleActionButton(
              icon: Icons.where_to_vote_outlined,
              label: lt('签到', 'Check In', 'チェックイン'),
              fillColor: theme.accent,
              onTap: () => _tabController.animateTo(0),
            ),
          ),
          const SizedBox(width: 10),
          // Share button — iOS: ellipsis more button
          _CapsuleActionButton(
            icon: Icons.share_outlined,
            label: lt('分享', 'Share', 'シェア'),
            fillColor: Colors.white.withValues(alpha: 0.15),
            onTap: () {
              final url = 'https://ravehub.top/events/${widget.eventId}';
              ShareService.shareUrl(url, subject: event.name);
            },
            compact: true,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab content
  // ---------------------------------------------------------------------------

  Widget _buildInfoTab(WebEvent event, RaverThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoChip(
            theme,
            Icons.calendar_today,
            _formatDateRange(event.startDate, event.endDate),
          ),
          if (event.location != null) ...[
            const SizedBox(height: 10),
            _buildInfoChip(
              theme,
              Icons.location_on_outlined,
              [
                event.location!.name,
                event.location!.city,
                event.location!.country,
              ].where((s) => s.isNotEmpty).join(', '),
            ),
          ],
          if (event.schedule != null) ...[
            const SizedBox(height: 10),
            _buildInfoChip(
              theme,
              Icons.access_time,
              '${event.schedule!.timezoneName} (${event.schedule!.timezoneId})',
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatBadge(
                theme,
                Icons.favorite,
                '${event.favoriteCount}',
                lt('收藏', 'Favorites', 'お気に入り'),
              ),
              const SizedBox(width: 16),
              _buildStatBadge(
                theme,
                Icons.check_circle,
                '${event.checkinCount}',
                lt('签到', 'Check-ins', 'チェックイン'),
              ),
            ],
          ),
          if (event.ticketTiers != null && event.ticketTiers!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              lt('票价', 'Tickets', 'チケット'),
              style: RaverTypography.title(size: 16, color: theme.primaryText),
            ),
            const SizedBox(height: 8),
            ...event.ticketTiers!.map(
              (tier) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      tier.name,
                      style: RaverTypography.body(size: 14, color: theme.primaryText),
                    ),
                    Text(
                      '${tier.currency} ${tier.price}',
                      style: RaverTypography.label(
                        size: 14,
                        color: theme.accent,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            lt('活动介绍', 'About', 'イベント紹介'),
            style: RaverTypography.title(size: 16, color: theme.primaryText),
          ),
          const SizedBox(height: 8),
          Text(
            event.description,
            style: RaverTypography.body(size: 14, color: theme.primaryText),
          ),
          if (event.lineupImageUrl.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              lt('阵容海报', 'Lineup Poster', 'ラインナップポスター'),
              style: RaverTypography.title(size: 16, color: theme.primaryText),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: RemoteCoverImage(url: event.lineupImageUrl, fit: BoxFit.fitWidth),
            ),
          ],
          const SizedBox(height: 24),
          EventCheckInSection(
            eventId: widget.eventId,
            repository: DiscoverServiceLocator.eventsRepository,
          ),
          const SizedBox(height: 24),
          EventRouteSection(event: event),
          const SizedBox(height: 24),
          EventMapSection(event: event),
          const SizedBox(height: 24),
          EventShareSection(eventId: widget.eventId, eventName: event.name),
          const SizedBox(height: 24),
          EventLiveDiscussionSection(
            eventId: widget.eventId,
            repository: DiscoverServiceLocator.eventsRepository,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildLineupTab(RaverThemeData theme) {
    if (_viewModel.lineup.isEmpty) {
      return EmptyStateView(
        icon: Icons.people_outline,
        title: lt('暂无阵容信息', 'No Lineup Info', 'ラインナップ情報なし'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _viewModel.lineup.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final artist = _viewModel.lineup[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.cardBorder),
          ),
          child: Row(
            children: [
              ClipOval(
                child: artist.avatarUrl.isNotEmpty
                    ? RemoteCoverImage(url: artist.avatarUrl, width: 44, height: 44)
                    : Container(
                        width: 44,
                        height: 44,
                        color: theme.cardBorder,
                        child: Icon(Icons.person, color: theme.secondaryText),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      artist.name,
                      style: RaverTypography.label(
                        size: 15,
                        color: theme.primaryText,
                        weight: FontWeight.w600,
                      ),
                    ),
                    if (artist.isB2B &&
                        artist.members != null &&
                        artist.members!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'B2B: ${artist.members!.map((m) => m.name).join(' & ')}',
                        style: RaverTypography.caption(color: theme.secondaryText),
                      ),
                    ],
                  ],
                ),
              ),
              if (artist.djId.isNotEmpty)
                IconButton(
                  icon: Icon(Icons.chevron_right, color: theme.secondaryText),
                  onPressed: () => context.push('/djs/${artist.djId}'),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimetableTab(RaverThemeData theme) {
    if (_viewModel.timetable.isEmpty) {
      return EmptyStateView(
        icon: Icons.schedule,
        title: lt('暂无时间表', 'No Timetable', 'タイムテーブルなし'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: EventScheduleSection(timetable: _viewModel.timetable),
    );
  }

  Widget _buildNewsTab(RaverThemeData theme) {
    return EmptyStateView(
      icon: Icons.newspaper_outlined,
      title: lt('暂无新闻', 'No News', 'ニュースはありません'),
      subtitle: lt('关于本活动的新闻将显示在这里', 'Event news will appear here',
          'イベントのニュースがここに表示されます'),
    );
  }

  Widget _buildPostsTab(RaverThemeData theme) {
    return EmptyStateView(
      icon: Icons.dynamic_feed_outlined,
      title: lt('暂无动态', 'No Posts', '投稿はありません'),
      subtitle: lt('活动相关动态将显示在这里', 'Event posts will appear here',
          'イベントの投稿がここに表示されます'),
    );
  }

  Widget _buildRatingsTab(RaverThemeData theme) {
    return EmptyStateView(
      icon: Icons.star_outline,
      title: lt('暂无评分', 'No Ratings', '評価はありません'),
      subtitle: lt('参与活动后为活动评分', 'Rate this event after attending',
          '参加後にこのイベントを評価してください'),
    );
  }

  Widget _buildSetsTab(RaverThemeData theme) {
    return EmptyStateView(
      icon: Icons.music_note_outlined,
      title: lt('暂无 Sets', 'No Sets', 'セットはありません'),
      subtitle: lt('演出结束后 Sets 将上传至此', 'Sets will be uploaded after the event',
          'イベント後にセットがアップロードされます'),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Widget _buildInfoChip(RaverThemeData theme, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.secondaryText),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: RaverTypography.body(size: 14, color: theme.primaryText),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStatBadge(
    RaverThemeData theme,
    IconData icon,
    String count,
    String label,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.accent),
          const SizedBox(width: 4),
          Text(
            count,
            style: RaverTypography.label(
              size: 14,
              color: theme.primaryText,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Text(label, style: RaverTypography.caption(color: theme.secondaryText)),
        ],
      ),
    );
  }

  static String _formatDateRange(String start, String end) {
    try {
      final s = DateTime.parse(start);
      final e = DateTime.parse(end);
      final sf =
          '${s.year}-${s.month.toString().padLeft(2, '0')}-${s.day.toString().padLeft(2, '0')}';
      if (s.year == e.year && s.month == e.month && s.day == e.day) return sf;
      final ef =
          '${e.year}-${e.month.toString().padLeft(2, '0')}-${e.day.toString().padLeft(2, '0')}';
      return '$sf ~ $ef';
    } catch (_) {
      return '$start ~ $end';
    }
  }
}

// ---------------------------------------------------------------------------
// iOS-style capsule action button
// ---------------------------------------------------------------------------

class _CapsuleActionButton extends StatelessWidget {
  const _CapsuleActionButton({
    required this.icon,
    required this.label,
    required this.fillColor,
    required this.onTap,
    this.isLoading = false,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final Color fillColor;
  final VoidCallback onTap;
  final bool isLoading;
  // When true, shows only icon (compact mode for share/more)
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        height: 44,
        padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 16),
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(22), // full capsule
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
          children: [
            if (isLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              Icon(icon, size: 18, color: Colors.white),
            if (!compact) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SliverPersistentHeader delegate for the 7-tab bar
// ---------------------------------------------------------------------------

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  const _TabBarDelegate({
    required this.tabController,
    required this.theme,
  });

  final TabController tabController;
  final RaverThemeData theme;

  static const _tabNames = [
    'Info', 'Lineup', 'Timetable', 'News', 'Posts', 'Ratings', 'Sets',
  ];

  // iOS: tabBarOverlayHeight 52, tab font system 17pt regular
  static const double _height = 52;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  bool shouldRebuild(_TabBarDelegate old) =>
      old.tabController != tabController || old.theme != theme;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      height: _height,
      color: theme.background,
      child: AnimatedBuilder(
        animation: tabController,
        builder: (context, _) {
          final selected = tabController.index;
          return TabBar(
            controller: tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            padding: EdgeInsets.zero,
            labelPadding: const EdgeInsets.symmetric(horizontal: 12),
            // iOS: indicator height 2.6, tab accent color changes per tab
            indicatorColor: EventDetailScreen._tabColors[selected],
            indicatorWeight: 2.6,
            indicatorSize: TabBarIndicatorSize.label,
            // iOS: system 17pt regular
            labelStyle: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w400,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w400,
            ),
            labelColor: EventDetailScreen._tabColors[selected],
            unselectedLabelColor: theme.secondaryText,
            splashFactory: NoSplash.splashFactory,
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            dividerColor: theme.cardBorder,
            tabs: _tabNames.map((name) => Tab(text: name)).toList(),
          );
        },
      ),
    );
  }
}
