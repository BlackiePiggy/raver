import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';

import 'recommend_view_model.dart';
import '../../../src/_shared/discover_service_locator.dart';

class RecommendScreen extends StatefulWidget {
  const RecommendScreen({super.key});

  @override
  State<RecommendScreen> createState() => _RecommendScreenState();
}

class _RecommendScreenState extends State<RecommendScreen> {
  late final RecommendViewModel _viewModel;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _viewModel = RecommendViewModel(
      repository: DiscoverServiceLocator.eventsRepository,
    );
    _pageController = PageController(viewportFraction: 0.88);
    _viewModel.addListener(_rebuild);
    _viewModel.loadIfNeeded();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _viewModel.removeListener(_rebuild);
    _pageController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return Stack(
      children: [
        LoadPhaseBuilder<List<WebEvent>>(
          phase: _viewModel.phase,
          onLoading: () => _buildSkeleton(theme),
          onEmpty: () => EmptyStateView(
            icon: Icons.auto_awesome,
            title: lt('暂无推荐活动', 'No Recommendations', 'おすすめなし'),
            subtitle: lt(
              '稍后再来看看',
              'Check back later',
              'あとでまた確認してください',
            ),
          ),
          onFailure: (error) => ErrorStateView(
            title: lt(
              '推荐加载失败',
              'Recommendations Failed',
              'おすすめの読み込みに失敗しました',
            ),
            error: error,
            onRetry: _viewModel.reload,
            retryLabel: lt('重试', 'Retry', '再試行'),
          ),
          onSuccess: (events) => _buildPager(events, theme),
        ),
        if (_viewModel.isRefreshing)
          Positioned(
            top: 12,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: theme.card.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.cardBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: theme.accent,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    lt('更新推荐中', 'Updating', '更新中'),
                    style: RaverTypography.caption(color: theme.secondaryText),
                  ),
                ],
              ),
            ),
          ),
        if (_viewModel.bannerMessage != null)
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _viewModel.bannerMessage!,
                      style: RaverTypography.caption(color: Colors.orange),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _viewModel.reload,
                    child: Text(
                      lt('重试', 'Retry', '再試行'),
                      style: RaverTypography.caption(
                        color: Colors.orange,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPager(List<WebEvent> events, RaverThemeData theme) {
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: events.length,
            onPageChanged: _viewModel.setPageIndex,
            itemBuilder: (context, index) {
              return AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  double value = 1.0;
                  if (_pageController.position.haveDimensions) {
                    value = (_pageController.page ?? 0) - index;
                    value = (1 - value.abs() * 0.15).clamp(0.85, 1.0);
                  }
                  return Transform.scale(
                    scale: value,
                    child: _buildEventCard(events[index], theme),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        _buildPageIndicator(events.length, theme),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildEventCard(WebEvent event, RaverThemeData theme) {
    return GestureDetector(
      onTap: () => context.push('/events/${event.id}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            RemoteCoverImage(url: event.coverImageUrl, fit: BoxFit.cover),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.3, 0.7, 1.0],
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.3),
                    Colors.black.withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.accent.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _eventTypeLabel(event.eventType),
                  style: RaverTypography.caption(
                    color: Colors.white,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    event.name,
                    style: RaverTypography.title(
                      size: 18,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 12,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _formatDate(event.startDate),
                          style: RaverTypography.caption(
                            color: Colors.white70,
                          ),
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                  if (event.location != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            [
                              event.location!.city,
                              event.location!.country,
                            ].where((s) => s.isNotEmpty).join(', '),
                            style: RaverTypography.caption(
                              color: Colors.white70,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageIndicator(int count, RaverThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == _viewModel.currentPageIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive
                ? theme.accent
                : theme.secondaryText.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }

  Widget _buildSkeleton(RaverThemeData theme) {
    return SkeletonShimmer(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Expanded(
              child: SkeletonBox(
                width: double.infinity,
                height: double.infinity,
                borderRadius: 28,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                5,
                (i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: SkeletonBox(
                    width: i == 0 ? 20 : 6,
                    height: 6,
                    borderRadius: 3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _eventTypeLabel(String type) => switch (type) {
        'festival' => 'Festival',
        'bar_event' => 'Bar',
        'outdoor_event' => 'Outdoor',
        'club_party' => 'Club',
        'liveshow' => 'Live Show',
        'warehouse' => 'Warehouse',
        'cruise' => 'Cruise',
        _ => type,
      };

  static String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}
