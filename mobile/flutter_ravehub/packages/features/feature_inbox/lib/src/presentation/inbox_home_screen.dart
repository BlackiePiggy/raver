import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';

import '../data/inbox_service_locator.dart';
import 'view_models/inbox_view_model.dart';

/// Home screen for the Inbox tab.
///
/// Displays five notification sections as GlassCards, each showing a category
/// icon, name, unread badge, and the most recent notification preview.
class InboxHomeScreen extends StatefulWidget {
  const InboxHomeScreen({super.key});

  @override
  State<InboxHomeScreen> createState() => _InboxHomeScreenState();
}

class _InboxHomeScreenState extends State<InboxHomeScreen> {
  late final InboxViewModel _viewModel;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _viewModel = InboxViewModel(
      repository: InboxServiceLocator.notificationRepository,
    );
    _viewModel.addListener(_rebuild);
    _loadUnreadCounts();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<void> _loadUnreadCounts() async {
    await _viewModel.loadUnreadCounts();
    final counts = _viewModel.unreadCount;
    if (mounted && counts != null) {
      InboxServiceLocator.syncUnreadCounts(counts);
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_rebuild);
    _scrollController.dispose();
    _viewModel.dispose();
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
    final theme = context.raver;

    return RaverTabReselectionListener(
      tabIndex: 2,
      onReselected: _scrollToTop,
      child: Scaffold(
        backgroundColor: theme.background,
        appBar: AppBar(
          backgroundColor: theme.background,
          title: Text(
            lt('通知中心', 'Inbox', '通知センター'),
            style: RaverTypography.title(color: theme.primaryText),
          ),
        ),
        body: LoadPhaseBuilder<NotificationUnreadCount>(
          phase: _viewModel.unreadPhase,
          onLoading: () => const _InboxHomeSkeleton(),
          onFailure: (error) => ErrorStateView(
            title: lt('加载失败', 'Failed to Load', '読み込みに失敗しました'),
            error: error,
            onRetry: _loadUnreadCounts,
            retryLabel: lt('重试', 'Retry', '再試行'),
          ),
          onSuccess: (counts) => RefreshIndicator(
            color: theme.accent,
            onRefresh: _loadUnreadCounts,
            child: ListView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                _InboxCategoryCard(
                  icon: Icons.notifications_outlined,
                  title: lt('社区互动', 'Community', 'コミュニティ'),
                  subtitle: lt(
                    '关注/点赞/评论/小队邀请',
                    'Follows/Likes/Comments/Invites',
                    'フォロー/いいね/コメント/招待',
                  ),
                  unreadCount: counts.community,
                  color: const Color(0xFFF24D61),
                  onTap: () => context.push('/inbox/alerts/community'),
                ),
                const SizedBox(height: 12),
                _InboxCategoryCard(
                  icon: Icons.event,
                  title: lt('关注活动更新', 'Followed Events', 'フォローイベント'),
                  subtitle: lt(
                    '您关注的活动有变更',
                    'Updates from events you follow',
                    'フォロー中のイベントの更新',
                  ),
                  unreadCount: counts.followedEvents,
                  color: const Color(0xFFF88A35),
                  onTap: () => context.push('/inbox/followed-events'),
                ),
                const SizedBox(height: 12),
                _InboxCategoryCard(
                  icon: Icons.headset,
                  title: lt('关注 DJ 更新', 'Followed DJs', 'フォロー DJ'),
                  subtitle: lt(
                    '您关注的 DJ 有变更',
                    'Updates from DJs you follow',
                    'フォロー中の DJ の更新',
                  ),
                  unreadCount: counts.followedDJs,
                  color: const Color(0xFF70C754),
                  onTap: () => context.push('/inbox/followed-djs'),
                ),
                const SizedBox(height: 12),
                _InboxCategoryCard(
                  icon: Icons.storefront,
                  title: lt('关注厂牌更新', 'Followed Brands', 'フォローブランド'),
                  subtitle: lt(
                    '您关注的厂牌有变更',
                    'Updates from brands you follow',
                    'フォロー中のブランドの更新',
                  ),
                  unreadCount: counts.followedBrands,
                  color: const Color(0xFFC278F2),
                  onTap: () => context.push('/inbox/followed-brands'),
                ),
                const SizedBox(height: 12),
                _InboxCategoryCard(
                  icon: Icons.rate_review_outlined,
                  title: lt('内容审核状态', 'Content Reviews', 'コンテンツ審査'),
                  subtitle: lt(
                    '提交内容的审核进度',
                    'Review status of your submissions',
                    '投稿内容の審査状況',
                  ),
                  unreadCount: 0, // Content reviews don't have unread in model
                  color: const Color(0xFF4DABF7),
                  onTap: () => context.push('/inbox/content-reviews'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InboxCategoryCard extends StatelessWidget {
  const _InboxCategoryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.unreadCount,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int unreadCount;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: RaverTypography.label(
                      size: 15,
                      color: context.raver.primaryText,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: RaverTypography.caption(
                      color: context.raver.secondaryText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  style: RaverTypography.caption(
                    color: Colors.white,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: context.raver.secondaryText,
            ),
          ],
        ),
      ),
    );
  }
}

class _InboxHomeSkeleton extends StatelessWidget {
  const _InboxHomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => Container(
          height: 76,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: const [
              SkeletonBox(width: 44, height: 44, borderRadius: 12),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SkeletonLine(width: 120, height: 16),
                    SizedBox(height: 6),
                    SkeletonLine(width: 180, height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
