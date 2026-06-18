import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';

import 'view_models/rating_view_model.dart';
import 'widgets/create_rating_event_sheet.dart';
import '../../_shared/circle_service_locator.dart';

const double iosRatingHubImageSize = 72;

@visibleForTesting
double ratingEventAverageScore(WebRatingEvent event) {
  final ratedUnits = (event.units ?? const <WebRatingUnit>[]).where((unit) {
    return unit.ratingCount > 0 && (unit.rating ?? 0) > 0;
  }).toList(growable: false);
  if (ratedUnits.isEmpty) return 0;
  return ratedUnits
          .map((unit) => unit.rating ?? 0)
          .reduce((value, element) => value + element) /
      ratedUnits.length;
}

@visibleForTesting
IconData ratingStarIconForIndex({
  required double score,
  required int starIndex,
}) {
  final clamped = score < 0
      ? 0.0
      : score > 10
          ? 10.0
          : score;
  final normalized = clamped / 2;
  if (normalized >= starIndex) return Icons.star;
  if (normalized >= starIndex - 0.5) return Icons.star_half;
  return Icons.star_border;
}

/// Hub for viewing and submitting ratings for events and DJs.
class RatingHubScreen extends StatefulWidget {
  const RatingHubScreen({super.key});

  @override
  State<RatingHubScreen> createState() => _RatingHubScreenState();
}

class _RatingHubScreenState extends State<RatingHubScreen> {
  late final RatingViewModel _viewModel;
  final ScrollController _scrollController = ScrollController();

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

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: RaverMotion.normal,
      curve: RaverMotion.curve,
    );
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
        onUploadImage: (localPath) =>
            CircleServiceLocator.ratingRepository.uploadRatingImage(
          localPath: localPath,
          usage: 'rating_event_cover',
        ),
        onSubmit: (name, description, eventId, imageUrl) async {
          try {
            await CircleServiceLocator.ratingRepository.createRatingEvent(
              name: name,
              description: description,
              eventId: eventId,
              imageUrl: imageUrl.isEmpty ? null : imageUrl,
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

    return RaverTabReselectionListener(
      tabIndex: 1,
      onReselected: _scrollToTop,
      child: Column(
        children: [
          _buildHeader(theme),
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
      ),
    );
  }

  Widget _buildHeader(RaverThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              lt('事件驱动打分', 'Event-driven ratings', 'イベント連動評価'),
              style: RaverTypography.title(
                size: 17,
                color: theme.primaryText,
              ),
            ),
          ),
          _HeaderCapsuleButton(
            label: lt('发布事件', 'Publish Event', 'イベントを公開'),
            icon: Icons.add,
            onTap: _showCreateSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildList(RaverThemeData theme) {
    return RefreshIndicator(
      color: theme.accent,
      onRefresh: _viewModel.refresh,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
        itemCount: _viewModel.events.length + (_viewModel.canLoadMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 10),
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
            onTap: () => context.push('/circle/ratings/${event.id}'),
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
    required this.onTap,
  });

  final WebRatingEvent event;
  final RaverThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final units = event.units ?? const <WebRatingUnit>[];
    final average = ratingEventAverageScore(event);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.card,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RatingSquareImage(
                  imageUrl: event.imageUrl,
                  theme: theme,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.name,
                        style: RaverTypography.label(
                          size: 15,
                          color: theme.primaryText,
                          weight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        event.description.isNotEmpty
                            ? event.description
                            : lt(
                                '暂无事件描述',
                                'No event description',
                                'イベント説明はまだありません',
                              ),
                        style:
                            RaverTypography.caption(color: theme.secondaryText),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _publisherLabel(event),
                        style: RaverTypography.caption(
                          size: 11,
                          color: theme.secondaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: theme.secondaryText, size: 18),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.grid_view_rounded,
                    size: 13, color: theme.secondaryText),
                const SizedBox(width: 4),
                Text(
                  lt(
                    '${units.length} 个单位',
                    '${units.length} units',
                    '${units.length} 件のユニット',
                  ),
                  style: RaverTypography.caption(
                    size: 11,
                    color: theme.secondaryText,
                    weight: FontWeight.w600,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '·',
                    style: RaverTypography.caption(
                      color: theme.secondaryText.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                Text(
                  '${lt("均分", "Average", "平均")} ${average.toStringAsFixed(1)}/10',
                  style: RaverTypography.caption(
                    size: 11,
                    color: theme.secondaryText,
                    weight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                _HalfStarRatingReadOnly(
                  score: average,
                  starSize: 12,
                  spacing: 2,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _publisherLabel(WebRatingEvent event) {
    final name = event.creatorId.trim().isEmpty
        ? lt('匿名用户', 'Anonymous', '匿名ユーザー')
        : event.creatorId;
    return lt('发布者：$name', 'Publisher: $name', '投稿者: $name');
  }
}

class _HeaderCapsuleButton extends StatelessWidget {
  const _HeaderCapsuleButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: ShapeDecoration(
          color: theme.card,
          shape: const StadiumBorder(),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: theme.primaryText, size: 14),
            const SizedBox(width: 5),
            Text(
              label,
              style: RaverTypography.caption(
                color: theme.primaryText,
                weight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingSquareImage extends StatelessWidget {
  const _RatingSquareImage({
    required this.imageUrl,
    required this.theme,
  });

  final String imageUrl;
  final RaverThemeData theme;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: iosRatingHubImageSize,
        height: iosRatingHubImageSize,
        child: imageUrl.isNotEmpty
            ? RemoteCoverImage(url: imageUrl, fit: BoxFit.cover)
            : DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF3D4261), Color(0xFF2B8CB8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(
                  Icons.auto_awesome_mosaic,
                  color: Colors.white.withValues(alpha: 0.92),
                  size: 24,
                ),
              ),
      ),
    );
  }
}

class _HalfStarRatingReadOnly extends StatelessWidget {
  const _HalfStarRatingReadOnly({
    required this.score,
    required this.starSize,
    required this.spacing,
  });

  final double score;
  final double starSize;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starIndex = index + 1;
        final icon = ratingStarIconForIndex(
          score: score,
          starIndex: starIndex,
        );
        final active = icon != Icons.star_border;
        return Padding(
          padding: EdgeInsets.only(left: index == 0 ? 0 : spacing),
          child: Icon(
            icon,
            size: starSize,
            color: active
                ? const Color(0xFFFFBA33)
                : Colors.grey.withValues(alpha: 0.45),
          ),
        );
      }),
    );
  }
}
