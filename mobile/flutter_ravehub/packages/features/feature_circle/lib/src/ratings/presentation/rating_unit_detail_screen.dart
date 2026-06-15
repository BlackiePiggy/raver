import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';

import '../view_models/rating_view_model.dart';
import '../../_shared/circle_service_locator.dart';

/// Detail screen for a single rating unit with voting and comments.
class RatingUnitDetailScreen extends StatefulWidget {
  const RatingUnitDetailScreen({
    super.key,
    required this.ratingId,
    required this.unitId,
  });

  final String ratingId;
  final String unitId;

  @override
  State<RatingUnitDetailScreen> createState() =>
      _RatingUnitDetailScreenState();
}

class _RatingUnitDetailScreenState extends State<RatingUnitDetailScreen> {
  late final RatingUnitDetailViewModel _viewModel;
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _viewModel = RatingUnitDetailViewModel(
      ratingId: widget.ratingId,
      unitId: widget.unitId,
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
      _viewModel.loadMoreComments();
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_rebuild);
    _commentController.dispose();
    _scrollController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _submitVote() async {
    final success = await _viewModel.vote();
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lt('投票成功', 'Vote submitted', '投票しました')),
        ),
      );
    }
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    final success = await _viewModel.sendComment(text);
    if (success) {
      _commentController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    final unit = _viewModel.unit;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.background,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.primaryText),
          onPressed: () => context.pop(),
        ),
        title: Text(
          unit?.name ?? lt('评分单元', 'Rating Unit', '評価ユニット'),
          style: RaverTypography.title(size: 17, color: theme.primaryText),
        ),
        elevation: 0,
      ),
      body: unit == null
          ? const Center(child: CircularProgressIndicator.adaptive())
          : Column(
              children: [
                Expanded(
                  child: CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      SliverToBoxAdapter(
                        child: _buildUnitInfo(unit, theme),
                      ),
                      SliverToBoxAdapter(
                        child: _buildVotingSection(theme),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            lt('评论', 'Comments', 'コメント'),
                            style: RaverTypography.title(
                              size: 16,
                              color: theme.primaryText,
                            ),
                          ),
                        ),
                      ),
                      _buildCommentList(theme),
                    ],
                  ),
                ),
                _buildCommentInput(theme),
              ],
            ),
    );
  }

  Widget _buildUnitInfo(WebRatingUnit unit, RaverThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: theme.cardBorder,
            backgroundImage: unit.djAvatarUrl.isNotEmpty
                ? NetworkImage(unit.djAvatarUrl)
                : null,
            child: unit.djAvatarUrl.isEmpty
                ? Icon(Icons.person, size: 32, color: theme.secondaryText)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unit.name,
                  style: RaverTypography.headline(color: theme.primaryText)
                      .copyWith(fontSize: 20),
                ),
                Text(
                  unit.djName,
                  style: RaverTypography.body(
                    size: 14,
                    color: theme.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, size: 20, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(
                    (unit.rating ?? 0).toStringAsFixed(1),
                    style: RaverTypography.headline(color: theme.primaryText)
                        .copyWith(fontSize: 24),
                  ),
                ],
              ),
              Text(
                '${unit.ratingCount} ${lt("人评分", "votes", "人が評価")}',
                style: RaverTypography.caption(
                  size: 11,
                  color: theme.secondaryText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVotingSection(RaverThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.cardBorder),
      ),
      child: Column(
        children: [
          Text(
            lt('你的评分', 'Your Rating', 'あなたの評価'),
            style: RaverTypography.label(
              size: 14,
              color: theme.primaryText,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          // Star rating row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(10, (index) {
              final starValue = (index + 1).toDouble();
              final isFilled = starValue <= _viewModel.userScore;
              return GestureDetector(
                onTap: () => _viewModel.setUserScore(starValue),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(
                    isFilled ? Icons.star : Icons.star_border,
                    color: isFilled ? Colors.amber : theme.secondaryText,
                    size: 28,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),

          Text(
            '${_viewModel.userScore.toStringAsFixed(0)}/10',
            style: RaverTypography.label(
              size: 18,
              color: theme.primaryText,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),

          // Submit button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: _viewModel.isVoting ? null : _submitVote,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _viewModel.isVoting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      lt('提交评分', 'Submit Rating', '評価を送信'),
                      style: RaverTypography.label(
                        size: 15,
                        color: Colors.white,
                        weight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentList(RaverThemeData theme) {
    if (_viewModel.comments.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(
              lt('暂无评论', 'No comments yet', 'コメントはまだありません'),
              style: RaverTypography.body(
                size: 14,
                color: theme.secondaryText,
              ),
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index >= _viewModel.comments.length) {
            return _viewModel.canLoadMoreComments
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator.adaptive()),
                  )
                : const SizedBox.shrink();
          }

          final comment = _viewModel.comments[index];
          return _RatingCommentTile(comment: comment, theme: theme);
        },
        childCount: _viewModel.comments.length +
            (_viewModel.canLoadMoreComments ? 1 : 0),
      ),
    );
  }

  Widget _buildCommentInput(RaverThemeData theme) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: theme.background,
        border: Border(
          top: BorderSide(color: theme.cardBorder, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: theme.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.cardBorder),
              ),
              child: TextField(
                controller: _commentController,
                decoration: InputDecoration(
                  hintText: lt(
                    '写评论...',
                    'Write a comment...',
                    'コメントを書く...',
                  ),
                  hintStyle: RaverTypography.body(
                    size: 14,
                    color: theme.secondaryText,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                style: RaverTypography.body(
                  size: 14,
                  color: theme.primaryText,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _viewModel.isSendingComment ? null : _sendComment,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: theme.accent,
                shape: BoxShape.circle,
              ),
              child: _viewModel.isSendingComment
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingCommentTile extends StatelessWidget {
  const _RatingCommentTile({
    required this.comment,
    required this.theme,
  });

  final WebRatingComment comment;
  final RaverThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: theme.cardBorder,
            backgroundImage: comment.avatarUrl.isNotEmpty
                ? NetworkImage(comment.avatarUrl)
                : null,
            child: comment.avatarUrl.isEmpty
                ? Icon(Icons.person, size: 16, color: theme.secondaryText)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.displayName,
                      style: RaverTypography.label(
                        size: 13,
                        color: theme.primaryText,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, size: 12, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text(
                          comment.score.toStringAsFixed(0),
                          style: RaverTypography.caption(
                            size: 11,
                            color: theme.secondaryText,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      _formatRelative(comment.createdAt),
                      style: RaverTypography.caption(
                        color: theme.secondaryText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.content,
                  style: RaverTypography.body(
                    size: 14,
                    color: theme.primaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatRelative(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      if (diff.inDays < 7) return '${diff.inDays}d';
      return '${dt.month}/${dt.day}';
    } catch (_) {
      return iso;
    }
  }
}
