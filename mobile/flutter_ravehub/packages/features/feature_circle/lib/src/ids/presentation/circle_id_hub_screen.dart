import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';

import '../../_shared/circle_service_locator.dart';
import '../data/circle_id_api.dart';
import 'view_models/circle_id_view_model.dart';
import 'widgets/circle_id_composer_sheet.dart';
import 'widgets/circle_id_share_sheet.dart';

class CircleIdHubScreen extends StatefulWidget {
  const CircleIdHubScreen({super.key});

  @override
  State<CircleIdHubScreen> createState() => _CircleIdHubScreenState();
}

class _CircleIdHubScreenState extends State<CircleIdHubScreen> {
  late final CircleIdViewModel _viewModel;
  final ScrollController _scrollController = ScrollController();
  final Set<String> _busyActions = {};

  @override
  void initState() {
    super.initState();
    _viewModel = CircleIdViewModel(
      repository: CircleServiceLocator.circleIdRepository,
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

  void _showCreateSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CircleIdComposerSheet(
        onSearchEvents: (search) => _viewModel.searchEvents(search: search),
        onSearchDjs: (search) => _viewModel.searchDjs(search: search),
        onSubmit: (draft) async {
          final card = await _viewModel.createCard(draft);
          if (!mounted) return;
          if (card == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  lt(
                    'ID 提交失败，请稍后重试',
                    'ID submission failed. Please try again.',
                    'IDの送信に失敗しました。もう一度お試しください。',
                  ),
                ),
              ),
            );
            return;
          }
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                lt('ID 已提交审核', 'ID submitted for review', 'IDを審査に送信しました'),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _toggleReaction(
    CircleIdCard card,
    _CircleIdReaction reaction,
  ) async {
    final key = '${card.id}:${reaction.name}';
    if (_busyActions.contains(key)) return;
    setState(() => _busyActions.add(key));
    try {
      final post = switch (reaction) {
        _CircleIdReaction.like =>
          await CircleServiceLocator.feedRepository.toggleLikePost(
            postId: card.id,
            currentlyLiked: card.isLiked,
          ),
        _CircleIdReaction.favorite =>
          await CircleServiceLocator.feedRepository.toggleFavoritePost(
            postId: card.id,
            currentlySaved: card.isFavorited,
          ),
        _CircleIdReaction.repost =>
          await CircleServiceLocator.feedRepository.toggleRepost(
            postId: card.id,
            currentlyReposted: card.isReposted,
          ),
      };
      _viewModel.replaceCard(card.withPostInteraction(post));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lt(
              '操作失败，请稍后重试',
              'Action failed. Please try again.',
              '操作に失敗しました。もう一度お試しください。',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busyActions.remove(key));
    }
  }

  Future<void> _showShareSheet(CircleIdCard card) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CircleIdShareSheet(
        card: card,
        onShared: (post) =>
            _viewModel.replaceCard(card.withPostInteraction(post)),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    lt('ID（未发行）', 'ID (Unreleased)', 'ID（未リリース）'),
                    style: RaverTypography.title(
                      size: 18,
                      color: theme.primaryText,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _showCreateSheet,
                  icon: Icon(Icons.add_circle, color: theme.accent, size: 19),
                  label: Text(
                    lt('发布 ID', 'Post ID', 'IDを投稿'),
                    style: RaverTypography.label(
                      color: theme.primaryText,
                      weight: FontWeight.w700,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: theme.card,
                    shape: const StadiumBorder(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: LoadPhaseBuilder<List<CircleIdCard>>(
              phase: _viewModel.phase,
              onLoading: () =>
                  const Center(child: CircularProgressIndicator.adaptive()),
              onEmpty: () => EmptyStateView(
                icon: Icons.music_note_outlined,
                title: lt(
                  '还没有 ID 讨论',
                  'No ID Discussion Yet',
                  'IDディスカッションはまだありません',
                ),
                subtitle: lt(
                  '点击“发布 ID”，记录一首未发行歌曲。',
                  'Tap “Post ID” to record an unreleased track.',
                  '「IDを投稿」をタップして未リリース曲を記録しましょう。',
                ),
                actionLabel: lt('发布 ID', 'Post ID', 'IDを投稿'),
                onAction: _showCreateSheet,
              ),
              onFailure: (error) => ErrorStateView(
                title: lt('加载失败', 'Failed to Load', '読み込みに失敗しました'),
                error: error,
                onRetry: _viewModel.load,
                retryLabel: lt('重试', 'Retry', '再試行'),
              ),
              onSuccess: (cards) => _buildList(cards, theme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<CircleIdCard> cards, RaverThemeData theme) {
    return RefreshIndicator(
      color: theme.accent,
      onRefresh: _viewModel.refresh,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final card = cards[index];
          return _CircleIdEntryCard(
            card: card,
            onTap: () =>
                context.push('/circle/ids/${Uri.encodeComponent(card.id)}'),
            onLike: () => _toggleReaction(card, _CircleIdReaction.like),
            onFavorite: () => _toggleReaction(card, _CircleIdReaction.favorite),
            onRepost: () => _toggleReaction(card, _CircleIdReaction.repost),
            onShare: () => _showShareSheet(card),
          );
        },
      ),
    );
  }
}

class _CircleIdEntryCard extends StatelessWidget {
  const _CircleIdEntryCard({
    required this.card,
    required this.onTap,
    required this.onLike,
    required this.onFavorite,
    required this.onRepost,
    required this.onShare,
  });

  final CircleIdCard card;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final VoidCallback onFavorite;
  final VoidCallback onRepost;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    card.songName,
                    style: RaverTypography.title(
                      size: 16,
                      color: theme.primaryText,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: theme.secondaryText),
              ],
            ),
            const SizedBox(height: 12),
            _CircleIdPlayerPreview(card: card),
            if (card.event != null) ...[
              const SizedBox(height: 10),
              _LinkedEventRow(event: card.event!),
            ],
            if (card.djs.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: card.djs.map(_LinkedDjChip.new).toList(),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                _ActionPill(
                  icon: card.isLiked ? Icons.favorite : Icons.favorite_border,
                  count: card.likeCount,
                  isActive: card.isLiked,
                  onTap: onLike,
                ),
                const SizedBox(width: 8),
                _ActionPill(
                  icon: card.isFavorited ? Icons.star : Icons.star_border,
                  count: card.favoriteCount,
                  isActive: card.isFavorited,
                  onTap: onFavorite,
                ),
                const SizedBox(width: 8),
                _ActionPill(
                  icon: Icons.repeat,
                  count: card.repostCount,
                  isActive: card.isReposted,
                  onTap: onRepost,
                ),
                const SizedBox(width: 8),
                _ActionPill(
                  icon: Icons.ios_share_outlined,
                  count: 0,
                  onTap: onShare,
                ),
                const SizedBox(width: 8),
                _ActionPill(
                  icon: Icons.chat_bubble_outline,
                  count: card.commentCount,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _Avatar(url: card.contributorAvatarUrl, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.contributorName.isEmpty
                            ? lt('贡献者', 'Contributor', '投稿者')
                            : card.contributorName,
                        style: RaverTypography.caption(
                          color: theme.primaryText,
                          weight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        lt('贡献者', 'Contributor', '投稿者'),
                        style: RaverTypography.caption(
                          size: 11,
                          color: theme.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _compactDate(card.createdAt),
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

class _CircleIdPlayerPreview extends StatelessWidget {
  const _CircleIdPlayerPreview({required this.card});

  final CircleIdCard card;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    final hasVideo = card.videoUrl.isNotEmpty;
    final hasAudio = card.audioUrl.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.cardBorder,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              hasVideo ? Icons.play_circle_fill : Icons.music_note,
              color: theme.accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.songName,
                  style: RaverTypography.label(
                    color: theme.primaryText,
                    weight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  hasVideo
                      ? lt('视频 ID', 'Video ID', '動画ID')
                      : hasAudio
                          ? lt('音频 ID', 'Audio ID', '音声ID')
                          : lt('ID 片段', 'ID Clip', 'IDクリップ'),
                  style: RaverTypography.caption(color: theme.secondaryText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkedEventRow extends StatelessWidget {
  const _LinkedEventRow({required this.event});

  final CircleIdLinkedEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.cardBorder),
      ),
      child: Row(
        children: [
          _Thumb(url: event.coverImageUrl, size: 44),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.name,
                  style: RaverTypography.caption(
                    color: theme.primaryText,
                    weight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _compactDate(event.startDate),
                  style: RaverTypography.caption(
                    size: 11,
                    color: theme.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 18, color: theme.secondaryText),
        ],
      ),
    );
  }
}

class _LinkedDjChip extends StatelessWidget {
  const _LinkedDjChip(this.dj);

  final CircleIdLinkedDj dj;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Avatar(url: dj.avatarUrl, size: 24),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              dj.name,
              style: RaverTypography.caption(
                color: theme.primaryText,
                weight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.count,
    this.isActive = false,
    this.onTap,
  });

  final IconData icon;
  final int count;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    final foreground = isActive ? theme.accent : theme.primaryText;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: (isActive ? theme.accent : theme.cardBorder).withValues(
            alpha: isActive ? 0.14 : 0.42,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            Icon(icon, size: 17, color: foreground),
            if (count > 0 || icon != Icons.ios_share_outlined) ...[
              const SizedBox(width: 5),
              Text(
                '$count',
                style: RaverTypography.caption(
                  color: foreground,
                  weight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _CircleIdReaction { like, favorite, repost }

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.size});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    if (url.isEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: theme.cardBorder,
        child: Icon(Icons.person, size: size * 0.5, color: theme.secondaryText),
      );
    }
    return ClipOval(
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => CircleAvatar(
          radius: size / 2,
          backgroundColor: theme.cardBorder,
          child: Icon(
            Icons.person,
            size: size * 0.5,
            color: theme.secondaryText,
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url, required this.size});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.cardBorder,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.event, color: theme.secondaryText, size: size * 0.45),
    );
    if (url.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}

String _compactDate(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
}
