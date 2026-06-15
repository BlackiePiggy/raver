import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';

import '../view_models/rating_view_model.dart';
import '../widgets/create_rating_event_sheet.dart';
import '../../_shared/circle_service_locator.dart';

/// Hub for viewing and submitting ratings for events and DJs.
class RatingHubScreen extends StatefulWidget {
  const RatingHubScreen({super.key});

  @override
  State<RatingHubScreen> createState() => _RatingHubScreenState();
}

class _RatingHubScreenState extends State<RatingHubScreen> {
  late final RatingViewModel _viewModel;
  final ScrollController _scrollController = ScrollController();
  int _segmentIndex = 0;

  @override
  void initState() {
    super.initState();
    _viewModel = RatingViewModel(
      repository: CircleServiceLocator.ratingRepository,
    );
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

  void _showCreateSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateRatingEventSheet(
        onSubmit: (name, description, eventId) async {
          try {
            await CircleServiceLocator.ratingRepository.createRatingEvent(
              name: name,
              description: description,
              eventId: eventId,
            );
            if (mounted) {
              Navigator.of(context).pop();
              _viewModel.refresh();
            }
          } catch (_) {}
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return Column(
      children: [
        // Segmented control + create button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: RaverSegmentedControl(
                  segments: [
                    lt('进行中', 'Ongoing', '進行中'),
                    lt('已结束', 'Ended', '終了'),
                  ],
                  selectedIndex: _segmentIndex,
                  onChanged: (index) {
                    setState(() => _segmentIndex = index);
                    _viewModel.setStatusFilter(
                      index == 0 ? 'ongoing' : 'ended',
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _showCreateSheet,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.accent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: LoadPhaseBuilder<List<WebRatingEvent>>(
            phase: _viewModel.phase,
            onLoading: () => const EventListSkeleton(),
            onEmpty: () => EmptyStateView(
              icon: Icons.star_border,
              title: lt('暂无评分活动', 'No Rating Events', '評価イベントなし'),
              subtitle: lt(
                '创建一个评分活动来开始',
                'Create a rating event to get started',
                '評価イベントを作成して始めましょう',
              ),
            ),
            onFailure: (error) => ErrorStateView(
              title: lt('加载失败', 'Failed to Load', '読み込みに失敗しました'),
              error: error,
              onRetry: _viewModel.load,
              retryLabel: lt('重试', 'Retry', '再試行'),
            ),
            onSuccess: (_) => _buildList(theme),
          ),
        ),
      ],
    );
  }

  Widget _buildList(RaverThemeData theme) {
    return RefreshIndicator(
      color: theme.accent,
      onRefresh: _viewModel.refresh,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount:
            _viewModel.events.length + (_viewModel.canLoadMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index >= _viewModel.events.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator.adaptive()),
            );
          }

          final event = _viewModel.events[index];
          return _RatingEventCard(
            event: event,
            theme: theme,
            isOngoing: _segmentIndex == 0,
            onTap: () =>
                context.push('/circle/ratings/${event.id}'),
          );
        },
      ),
    );
  }
}

class _RatingEventCard extends StatelessWidget {
  const _RatingEventCard({
    required this.event,
    required this.theme,
    required this.isOngoing,
    required this.onTap,
  });

  final WebRatingEvent event;
  final RaverThemeData theme;
  final bool isOngoing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.cardBorder),
        ),
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: event.imageUrl.isNotEmpty
                  ? RemoteCoverImage(
                      url: event.imageUrl,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 64,
                      height: 64,
                      color: theme.cardBorder,
                      child: Icon(
                        Icons.star,
                        color: theme.secondaryText,
                        size: 28,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.name,
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
                    event.description,
                    style: RaverTypography.caption(
                      color: theme.secondaryText,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (event.units != null)
                        Text(
                          '${event.units!.length} ${lt("评分单元", "units", "ユニット")}',
                          style: RaverTypography.caption(
                            size: 11,
                            color: theme.accent,
                          ),
                        ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isOngoing
                              ? Colors.green.withValues(alpha: 0.12)
                              : theme.cardBorder,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isOngoing
                              ? lt('进行中', 'Ongoing', '進行中')
                              : lt('已结束', 'Ended', '終了'),
                          style: RaverTypography.caption(
                            size: 10,
                            color:
                                isOngoing ? Colors.green : theme.secondaryText,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: theme.secondaryText,
            ),
          ],
        ),
      ),
    );
  }
}
