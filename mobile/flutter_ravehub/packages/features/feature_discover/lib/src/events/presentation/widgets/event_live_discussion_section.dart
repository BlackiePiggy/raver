import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';

import '../../data/event_discussion_models.dart';
import '../../data/events_repository.dart';

/// Live discussion section with polling and comment posting.
class EventLiveDiscussionSection extends StatefulWidget {
  const EventLiveDiscussionSection({
    super.key,
    required this.eventId,
    required this.repository,
  });

  final String eventId;
  final EventsRepository repository;

  @override
  State<EventLiveDiscussionSection> createState() =>
      _EventLiveDiscussionSectionState();
}

class _EventLiveDiscussionSectionState
    extends State<EventLiveDiscussionSection> {
  final TextEditingController _inputController = TextEditingController();
  final List<EventDiscussionComment> _comments = [];
  bool _isLoading = true;
  bool _isSending = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadComments();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadComments(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final page = await widget.repository.fetchDiscussion(
        eventId: widget.eventId,
      );
      if (mounted) {
        setState(() {
          _comments
            ..clear()
            ..addAll(page.comments);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendComment() async {
    final content = _inputController.text.trim();
    if (content.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    try {
      final comment = await widget.repository.postComment(
        eventId: widget.eventId,
        content: content,
      );
      if (mounted) {
        setState(() {
          _comments.insert(0, comment);
          _inputController.clear();
          _isSending = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ToastBanner.show(
          context,
          message: lt('发送失败', 'Failed to send', '送信に失敗しました'),
          type: ToastType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            lt('实时讨论', 'Live Discussion', 'ライブディスカッション'),
            style: RaverTypography.title(size: 16, color: theme.primaryText),
          ),
        ),
        const SizedBox(height: 12),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator.adaptive()),
          )
        else if (_comments.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                lt('暂无评论，来发表第一条吧',
                    'No comments yet. Be the first!',
                    'まだコメントはありません。最初のコメントを投稿しましょう'),
                style: RaverTypography.body(
                  size: 14,
                  color: theme.secondaryText,
                ),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _comments.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) =>
                _buildCommentTile(_comments[index], theme),
          ),
        const SizedBox(height: 12),
        _buildInputBar(theme),
      ],
    );
  }

  Widget _buildCommentTile(EventDiscussionComment comment, RaverThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipOval(
            child: comment.avatarUrl.isNotEmpty
                ? RemoteCoverImage(
                    url: comment.avatarUrl,
                    width: 36,
                    height: 36,
                  )
                : Container(
                    width: 36,
                    height: 36,
                    color: theme.cardBorder,
                    child: Icon(Icons.person, color: theme.secondaryText, size: 20),
                  ),
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
                    Text(
                      _formatRelativeTime(comment.createdAt),
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

  Widget _buildInputBar(RaverThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.cardBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                style: RaverTypography.body(size: 14, color: theme.primaryText),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: lt('说点什么…', 'Say something…', '何か書いてみましょう…'),
                  hintStyle: RaverTypography.body(
                    size: 14,
                    color: theme.secondaryText,
                  ),
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendComment(),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _isSending ? null : _sendComment,
              child: _isSending
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.accent,
                      ),
                    )
                  : Icon(Icons.send, size: 20, color: theme.accent),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatRelativeTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return lt('刚刚', 'just now', 'たった今');
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      return '${diff.inDays}d';
    } catch (_) {
      return iso;
    }
  }
}
