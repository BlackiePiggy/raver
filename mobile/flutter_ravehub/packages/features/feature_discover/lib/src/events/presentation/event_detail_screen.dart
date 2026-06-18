import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';
import 'package:raver_platform/raver_platform.dart';

import 'view_models/event_detail_view_model.dart';
import '../../_shared/discover_service_locator.dart';
import 'widgets/event_schedule_section.dart';
import 'widgets/event_live_discussion_section.dart';
import 'widgets/event_lineup_section.dart';
import 'widgets/event_checkin_section.dart';
import 'widgets/event_route_section.dart';
import 'widgets/event_map_section.dart';
import 'widgets/event_share_section.dart';
import 'widgets/event_date_formatter.dart';

// iOS per-tab theme colours (MainTabView / EventDetailView)
const _kInfoColor = Color(0xFF44D9D1); // teal     (0.27, 0.85, 0.82)
const _kLineupColor = Color(0xFF4DAAF8); // blue     (0.30, 0.67, 0.97)
const _kTimetableColor = Color(0xFF8FC74C); // green    (0.56, 0.78, 0.30)
const _kNewsColor = Color(0xFFF88C3F); // orange   (0.97, 0.55, 0.25)
const _kPostsColor = Color(0xFFF24D61); // red      (0.95, 0.30, 0.38)
const _kRatingsColor = Color(0xFFFAB538); // gold     (0.98, 0.71, 0.22)
const _kSetsColor = Color(0xFF946EF2); // purple   (0.58, 0.43, 0.95)
const _kTabColors = [
  _kInfoColor,
  _kLineupColor,
  _kTimetableColor,
  _kNewsColor,
  _kPostsColor,
  _kRatingsColor,
  _kSetsColor,
];

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
        if (_viewModel.isShowingCachedEvent)
          SliverToBoxAdapter(child: _buildCachedSnapshotBanner(theme)),
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
          _buildLineupTab(),
          _buildTimetableTab(event, theme),
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
          tooltip: lt('更多', 'More', 'その他'),
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.more_horiz, color: Colors.white, size: 20),
          ),
          onPressed: () => _showMoreActions(event),
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
              icon: _viewModel.hasCheckedIn
                  ? Icons.check_circle
                  : Icons.where_to_vote_outlined,
              label: _viewModel.hasCheckedIn
                  ? lt('已签到', 'Checked In', 'チェックイン済み')
                  : lt('签到', 'Check In', 'チェックイン'),
              fillColor: _viewModel.hasCheckedIn
                  ? theme.accent.withValues(alpha: 0.72)
                  : theme.accent,
              isLoading: _viewModel.isCheckingIn,
              onTap: _viewModel.checkin,
            ),
          ),
          const SizedBox(width: 10),
          // Share button — iOS: ellipsis more button
          _CapsuleActionButton(
            icon: Icons.share_outlined,
            label: lt('分享', 'Share', 'シェア'),
            fillColor: Colors.white.withValues(alpha: 0.15),
            onTap: () => _shareEvent(event),
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
            EventDateFormatter.rangeFromStrings(event.startDate, event.endDate),
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
              EventDateFormatter.timezoneLabel(event.schedule),
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
                      style: RaverTypography.body(
                          size: 14, color: theme.primaryText),
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
              child: RemoteCoverImage(
                  url: event.lineupImageUrl, fit: BoxFit.fitWidth),
            ),
          ],
          const SizedBox(height: 24),
          EventCheckInSection(
            key: ValueKey(
              'checkins-${_viewModel.myCheckinAt}-${event.checkinCount}',
            ),
            eventId: widget.eventId,
            repository: DiscoverServiceLocator.eventsRepository,
          ),
          if (_viewModel.relatedCheckins.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildRelatedCheckinsSection(theme),
          ],
          const SizedBox(height: 24),
          EventRouteSection(event: event),
          const SizedBox(height: 24),
          EventMapSection(event: event),
          const SizedBox(height: 24),
          EventShareSection(
            eventId: widget.eventId,
            eventName: event.name,
            onShare: () => _shareEvent(event),
          ),
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

  Future<void> _shareEvent(WebEvent event) async {
    final fallbackUrl = 'https://ravehub.top/events/${event.id}';
    try {
      final payload = await DiscoverServiceLocator.eventsRepository
          .resolveShareLink(event: event, channel: 'system_share');
      final shareUrl = payload.shortUrl.isNotEmpty
          ? payload.shortUrl
          : (payload.url.isNotEmpty ? payload.url : fallbackUrl);
      await ShareService.shareUrl(shareUrl, subject: event.name);
    } catch (_) {
      await ShareService.shareUrl(fallbackUrl, subject: event.name);
    }
  }

  Future<void> _copyEventLink(WebEvent event) async {
    final fallbackUrl = 'https://ravehub.top/events/${event.id}';
    try {
      final payload = await DiscoverServiceLocator.eventsRepository
          .resolveShareLink(event: event, channel: 'copy_link');
      final link = payload.shortUrl.isNotEmpty
          ? payload.shortUrl
          : (payload.url.isNotEmpty ? payload.url : fallbackUrl);
      await ClipboardService.copyText(link);
      if (!mounted) return;
      ToastBanner.show(
        context,
        message: lt('已复制链接', 'Link copied', 'リンクをコピーしました'),
        type: ToastType.success,
      );
    } catch (_) {
      try {
        await ClipboardService.copyText(fallbackUrl);
        if (!mounted) return;
        ToastBanner.show(
          context,
          message: lt('已复制活动链接', 'Event link copied', 'イベントリンクをコピーしました'),
          type: ToastType.success,
        );
      } catch (_) {
        if (!mounted) return;
        ToastBanner.show(
          context,
          message: lt('复制链接失败', 'Failed to copy link', 'リンクをコピーできませんでした'),
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _reportEvent(WebEvent event) {
    return ReportSheet.show(
      context,
      contentType: lt('活动', 'Event', 'イベント'),
      onSubmit: (reason, details) async {
        await DiscoverServiceLocator.eventsRepository.reportEvent(
          eventId: event.id,
          reason: reason.value,
          detail: details,
        );
        if (!mounted) return;
        ToastBanner.show(
          context,
          message: lt('举报已提交', 'Report submitted', '報告を送信しました'),
          type: ToastType.success,
        );
      },
    );
  }

  Future<void> _cacheCurrentEvent() async {
    try {
      final cachedAt = await _viewModel.cacheCurrentEvent();
      if (!mounted) return;
      ToastBanner.show(
        context,
        message: cachedAt == null
            ? lt('暂无可缓存内容', 'Nothing to cache yet', 'キャッシュする内容がありません')
            : lt(
                '活动已缓存，弱网环境也可查看。',
                'Event cached for weak-network viewing.',
                '弱いネットワークでも確認できるよう保存しました。',
              ),
        type: cachedAt == null ? ToastType.info : ToastType.success,
      );
    } catch (_) {
      if (!mounted) return;
      ToastBanner.show(
        context,
        message: lt('缓存失败，请稍后重试。', 'Caching failed. Please try again.',
            'キャッシュに失敗しました。時間をおいて再試行してください。'),
        type: ToastType.error,
      );
    }
  }

  void _openRoutePlanner(WebEvent event) {
    final location = event.location;
    if (location == null) {
      ToastBanner.show(
        context,
        message: lt('暂无位置信息', 'No location info available', '位置情報がありません'),
        type: ToastType.info,
      );
      return;
    }
    final uri = Uri(
      path: '/events/${event.id}/route',
      queryParameters: {
        'venueName': location.name.isNotEmpty ? location.name : event.name,
        if (location.latitude != null) 'lat': '${location.latitude}',
        if (location.longitude != null) 'lng': '${location.longitude}',
      },
    );
    context.push(uri.toString());
  }

  Future<void> _saveEventToCountdownWidget(WebEvent event) async {
    try {
      await CountdownWidgetService.saveSelectedEvent(
        CountdownWidgetEvent(
          id: event.id,
          name: event.name,
          startDateIso: event.startDate,
          venueName: event.location?.name ?? '',
        ),
      );
      if (!mounted) return;
      ToastBanner.show(
        context,
        message: lt(
          '已设为倒计时小组件活动',
          'Countdown widget event updated',
          'カウントダウンウィジェットを更新しました',
        ),
        type: ToastType.success,
      );
    } catch (_) {
      if (!mounted) return;
      ToastBanner.show(
        context,
        message: lt(
          '小组件更新失败，请稍后重试',
          'Widget update failed. Please try again.',
          'ウィジェット更新に失敗しました。もう一度お試しください',
        ),
        type: ToastType.error,
      );
    }
  }

  void _showMoreActions(WebEvent event) {
    final theme = context.raver;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          decoration: BoxDecoration(
            color: theme.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.cardBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.secondaryText.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 10),
              _EventMoreActionTile(
                icon: Icons.ios_share,
                label: lt('分享', 'Share', 'シェア'),
                theme: theme,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _shareEvent(event);
                },
              ),
              _EventMoreActionTile(
                icon: Icons.link,
                label: lt('复制链接', 'Copy Link', 'リンクをコピー'),
                theme: theme,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _copyEventLink(event);
                },
              ),
              _EventMoreActionTile(
                icon: Icons.navigation_outlined,
                label: lt('路线规划', 'Route', 'ルート案内'),
                theme: theme,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _openRoutePlanner(event);
                },
              ),
              _EventMoreActionTile(
                icon: Icons.offline_pin_outlined,
                label: lt('缓存', 'Cache', 'キャッシュ'),
                theme: theme,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _cacheCurrentEvent();
                },
              ),
              _EventMoreActionTile(
                icon: Icons.widgets_outlined,
                label: lt('设为倒计时小组件', 'Set Countdown Widget', 'ウィジェットに設定'),
                theme: theme,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _saveEventToCountdownWidget(event);
                },
              ),
              _EventMoreActionTile(
                icon: Icons.edit_outlined,
                label: lt('贡献信息', 'Incorrect Info', '情報を修正'),
                theme: theme,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.push('/events/${event.id}/edit');
                },
              ),
              _EventMoreActionTile(
                icon: Icons.person_search_outlined,
                label: lt('导入阵容', 'Import Lineup', 'ラインナップを取込'),
                theme: theme,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.push('/events/${event.id}/lineup/import');
                },
              ),
              _EventMoreActionTile(
                icon: Icons.flag_outlined,
                label: lt('举报', 'Report', '報告'),
                theme: theme,
                isDestructive: true,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _reportEvent(event);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLineupTab() {
    return EventLineupSection(
      artists: _viewModel.lineup,
      onDjTap: (djId) => context.push('/djs/$djId'),
    );
  }

  Widget _buildTimetableTab(WebEvent event, RaverThemeData theme) {
    if (_viewModel.timetable.isEmpty) {
      return EmptyStateView(
        icon: Icons.schedule,
        title: lt('暂无时间表', 'No Timetable', 'タイムテーブルなし'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: EventScheduleSection(
        event: event,
        timetable: _viewModel.timetable,
      ),
    );
  }

  Widget _buildNewsTab(RaverThemeData theme) {
    final articles = _viewModel.relatedNews;
    if (articles.isNotEmpty) {
      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: articles.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _EventNewsTile(
          article: articles[index],
          theme: theme,
          onTap: () => context.push('/news/${articles[index].id}'),
        ),
      );
    }

    return EmptyStateView(
      icon: Icons.newspaper_outlined,
      title: lt('暂无新闻', 'No News', 'ニュースはありません'),
      subtitle: lt('关于本活动的新闻将显示在这里', 'Event news will appear here',
          'イベントのニュースがここに表示されます'),
    );
  }

  Widget _buildPostsTab(RaverThemeData theme) {
    final posts = _viewModel.relatedPosts;
    if (posts.isNotEmpty) {
      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: posts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _EventPostTile(
          post: posts[index],
          theme: theme,
          onTap: () => context.push('/circle/post/${posts[index].id}'),
        ),
      );
    }

    return EmptyStateView(
      icon: Icons.dynamic_feed_outlined,
      title: lt('暂无动态', 'No Posts', '投稿はありません'),
      subtitle: lt(
          '活动相关动态将显示在这里', 'Event posts will appear here', 'イベントの投稿がここに表示されます'),
    );
  }

  Widget _buildRatingsTab(RaverThemeData theme) {
    final ratings = _viewModel.relatedRatingEvents;
    if (ratings.isNotEmpty) {
      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: ratings.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _EventRatingTile(
          rating: ratings[index],
          theme: theme,
          onTap: () => context.push('/circle/ratings/${ratings[index].id}'),
        ),
      );
    }

    return EmptyStateView(
      icon: Icons.star_outline,
      title: lt('暂无评分', 'No Ratings', '評価はありません'),
      subtitle: lt('参与活动后为活动评分', 'Rate this event after attending',
          '参加後にこのイベントを評価してください'),
    );
  }

  Widget _buildSetsTab(RaverThemeData theme) {
    final sets = _viewModel.relatedSets;
    if (sets.isNotEmpty) {
      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: sets.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _EventSetTile(
          djSet: sets[index],
          theme: theme,
          onTap: () => context.push('/sets/${sets[index].id}'),
        ),
      );
    }

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

  Widget _buildCachedSnapshotBanner(RaverThemeData theme) {
    final cachedAt = _viewModel.manualCachedAt;
    final cachedAtText =
        cachedAt == null ? '' : _formatCacheTimestamp(cachedAt);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _kInfoColor.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kInfoColor.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, color: _kInfoColor, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                cachedAtText.isEmpty
                    ? lt(
                        '网络较弱，已展示活动缓存数据。',
                        'Network is weak. Showing cached event data.',
                        'ネットワークが弱いため、イベントのキャッシュデータを表示しています。',
                      )
                    : lt(
                        '网络较弱，已展示 $cachedAtText 的活动缓存。',
                        'Network is weak. Showing the event cache from $cachedAtText.',
                        'ネットワークが弱いため、$cachedAtText のイベントキャッシュを表示しています。',
                      ),
                style: RaverTypography.body(
                  size: 13,
                  color: theme.primaryText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCacheTimestamp(DateTime cachedAt) {
    final local = cachedAt.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  Widget _buildRelatedCheckinsSection(RaverThemeData theme) {
    final checkins = _viewModel.relatedCheckins.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lt('相关打卡', 'Related Check-ins', '関連チェックイン'),
          style: RaverTypography.title(size: 16, color: theme.primaryText),
        ),
        const SizedBox(height: 10),
        ...checkins.map(
          (checkin) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _EventCheckinTile(
              checkin: checkin,
              theme: theme,
              onTap: checkin.userId.isEmpty
                  ? null
                  : () => context.push('/users/${checkin.userId}'),
            ),
          ),
        ),
      ],
    );
  }

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
          Text(label,
              style: RaverTypography.caption(color: theme.secondaryText)),
        ],
      ),
    );
  }
}

class _EventMoreActionTile extends StatelessWidget {
  const _EventMoreActionTile({
    required this.icon,
    required this.label,
    required this.theme,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final RaverThemeData theme;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.redAccent : theme.primaryText;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 21, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: RaverTypography.body(
                    size: 15,
                    color: color,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: theme.secondaryText),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventNewsTile extends StatelessWidget {
  const _EventNewsTile({
    required this.article,
    required this.theme,
    required this.onTap,
  });

  final NewsArticle article;
  final RaverThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (article.summary.trim().isNotEmpty) article.summary.trim(),
      if (article.source.trim().isNotEmpty) article.source.trim(),
      if (article.createdAt.trim().isNotEmpty) article.createdAt.trim(),
    ].join(' · ');
    return _EventRelatedTileShell(
      onTap: onTap,
      theme: theme,
      leading: article.coverImageUrl?.isNotEmpty == true
          ? RemoteCoverImage(
              url: article.coverImageUrl!,
              width: 58,
              height: 58,
              fit: BoxFit.cover,
            )
          : Container(
              width: 58,
              height: 58,
              color: theme.cardBorder,
              child: Icon(Icons.newspaper_outlined, color: theme.secondaryText),
            ),
      title: article.title,
      subtitle: subtitle,
      trailing: '${article.replyCount}',
      trailingIcon: Icons.chat_bubble_outline,
    );
  }
}

class _EventRatingTile extends StatelessWidget {
  const _EventRatingTile({
    required this.rating,
    required this.theme,
    required this.onTap,
  });

  final WebRatingEvent rating;
  final RaverThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _EventRelatedTileShell(
      onTap: onTap,
      theme: theme,
      leading: rating.imageUrl.isNotEmpty
          ? RemoteCoverImage(
              url: rating.imageUrl,
              width: 58,
              height: 58,
              fit: BoxFit.cover,
            )
          : Container(
              width: 58,
              height: 58,
              color: theme.cardBorder,
              child: Icon(Icons.star_outline, color: theme.secondaryText),
            ),
      title: rating.name,
      subtitle: rating.description.isNotEmpty
          ? rating.description
          : (rating.eventName.isNotEmpty ? rating.eventName : rating.eventId),
      trailing: rating.units == null ? null : '${rating.units!.length}',
      trailingIcon: Icons.fact_check_outlined,
    );
  }
}

class _EventSetTile extends StatelessWidget {
  const _EventSetTile({
    required this.djSet,
    required this.theme,
    required this.onTap,
  });

  final WebDJSet djSet;
  final RaverThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (djSet.djName.trim().isNotEmpty) djSet.djName.trim(),
      if (djSet.venue.trim().isNotEmpty) djSet.venue.trim(),
      if (djSet.recordedAt.trim().isNotEmpty) djSet.recordedAt.trim(),
    ].join(' · ');
    return _EventRelatedTileShell(
      onTap: onTap,
      theme: theme,
      leading: djSet.thumbnailUrl.isNotEmpty
          ? RemoteCoverImage(
              url: djSet.thumbnailUrl,
              width: 58,
              height: 58,
              fit: BoxFit.cover,
            )
          : Container(
              width: 58,
              height: 58,
              color: theme.cardBorder,
              child:
                  Icon(Icons.music_note_outlined, color: theme.secondaryText),
            ),
      title: djSet.title,
      subtitle: subtitle.isNotEmpty ? subtitle : djSet.eventName,
      trailing: '${djSet.likeCount}',
      trailingIcon: Icons.favorite_border,
    );
  }
}

class _EventCheckinTile extends StatelessWidget {
  const _EventCheckinTile({
    required this.checkin,
    required this.theme,
    required this.onTap,
  });

  final WebCheckin checkin;
  final RaverThemeData theme;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final title = checkin.note.trim().isNotEmpty
        ? checkin.note.trim()
        : lt('活动打卡', 'Event Check-in', 'イベントチェックイン');
    final subtitle = [
      if (checkin.attendedAt.trim().isNotEmpty) checkin.attendedAt.trim(),
      if (checkin.type.trim().isNotEmpty) checkin.type.trim(),
      if (checkin.userId.trim().isNotEmpty) checkin.userId.trim(),
    ].join(' · ');
    return _EventRelatedTileShell(
      onTap: onTap,
      theme: theme,
      leading: checkin.eventCoverUrl.isNotEmpty
          ? RemoteCoverImage(
              url: checkin.eventCoverUrl,
              width: 58,
              height: 58,
              fit: BoxFit.cover,
            )
          : Container(
              width: 58,
              height: 58,
              color: theme.cardBorder,
              child: Icon(Icons.where_to_vote_outlined,
                  color: theme.secondaryText),
            ),
      title: title,
      subtitle: subtitle,
      trailing: checkin.rating > 0 ? '${checkin.rating}' : null,
      trailingIcon: Icons.star_border,
    );
  }
}

class _EventRelatedTileShell extends StatelessWidget {
  const _EventRelatedTileShell({
    required this.onTap,
    required this.theme,
    required this.leading,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.trailingIcon,
  });

  final VoidCallback? onTap;
  final RaverThemeData theme;
  final Widget leading;
  final String title;
  final String subtitle;
  final String? trailing;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
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
                child: leading,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: RaverTypography.label(
                        size: 15,
                        color: theme.primaryText,
                        weight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle.trim(),
                        style:
                            RaverTypography.caption(color: theme.secondaryText),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null && trailingIcon != null) ...[
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(trailingIcon, size: 14, color: theme.secondaryText),
                    const SizedBox(width: 3),
                    Text(
                      trailing!,
                      style: RaverTypography.caption(
                        color: theme.secondaryText,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EventPostTile extends StatelessWidget {
  const _EventPostTile({
    required this.post,
    required this.theme,
    required this.onTap,
  });

  final Post post;
  final RaverThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final previewImage = post.images?.isNotEmpty == true
        ? post.images!.first
        : post.videos?.isNotEmpty == true
            ? post.videos!.first
            : null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.cardBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipOval(
                child: post.user.avatarUrl?.isNotEmpty == true
                    ? RemoteCoverImage(
                        url: post.user.avatarUrl!,
                        width: 38,
                        height: 38,
                      )
                    : Container(
                        width: 38,
                        height: 38,
                        color: theme.cardBorder,
                        child: Icon(
                          Icons.person,
                          color: theme.secondaryText,
                          size: 18,
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            post.user.displayName,
                            style: RaverTypography.label(
                              size: 14,
                              color: theme.primaryText,
                              weight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (post.createdAt.isNotEmpty)
                          Text(
                            post.createdAt,
                            style: RaverTypography.caption(
                              color: theme.secondaryText,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                    if (post.content.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        post.content.trim(),
                        style: RaverTypography.body(
                          size: 14,
                          color: theme.primaryText,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _EventPostMetric(
                          icon: Icons.favorite_border,
                          count: post.likeCount,
                          theme: theme,
                        ),
                        const SizedBox(width: 12),
                        _EventPostMetric(
                          icon: Icons.chat_bubble_outline,
                          count: post.commentCount,
                          theme: theme,
                        ),
                        const SizedBox(width: 12),
                        _EventPostMetric(
                          icon: Icons.bookmark_border,
                          count: post.saveCount,
                          theme: theme,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (previewImage != null && previewImage.isNotEmpty) ...[
                const SizedBox(width: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: RemoteCoverImage(
                    url: previewImage,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EventPostMetric extends StatelessWidget {
  const _EventPostMetric({
    required this.icon,
    required this.count,
    required this.theme,
  });

  final IconData icon;
  final int count;
  final RaverThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.secondaryText),
        const SizedBox(width: 3),
        Text(
          '$count',
          style: RaverTypography.caption(color: theme.secondaryText),
        ),
      ],
    );
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
    'Info',
    'Lineup',
    'Timetable',
    'News',
    'Posts',
    'Ratings',
    'Sets',
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
            indicatorColor: _kTabColors[selected],
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
            labelColor: _kTabColors[selected],
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
