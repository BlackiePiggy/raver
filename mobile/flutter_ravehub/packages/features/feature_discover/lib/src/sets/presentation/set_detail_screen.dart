import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';
import 'package:raver_platform/raver_platform.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

import '../../_shared/discover_service_locator.dart';
import '../data/set_providers.dart';

class SetDetailScreen extends ConsumerStatefulWidget {
  const SetDetailScreen({super.key, required this.setId});

  final String setId;

  @override
  ConsumerState<SetDetailScreen> createState() => _SetDetailScreenState();
}

class _SetDetailScreenState extends ConsumerState<SetDetailScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _tracklistExpanded = false;
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(setDetailProvider(widget.setId).notifier).load(),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  void _initVideoPlayer(String videoUrl) {
    if (_videoController != null) return;
    if (videoUrl.isEmpty) return;

    final uri = Uri.tryParse(videoUrl);
    if (uri == null) return;

    _videoController = VideoPlayerController.networkUrl(uri)
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _chewieController = ChewieController(
              videoPlayerController: _videoController!,
              autoPlay: false,
              looping: false,
              aspectRatio: 16 / 9,
              showControlsOnInitialize: false,
            );
          });
        }
      });
  }

  Future<void> _openExternalVideo(WebDJSet djSet) async {
    final videoUrl = djSet.videoUrl.trim();
    if (videoUrl.isEmpty) return;

    try {
      await UrlLauncherService.openExternalUrl(videoUrl);
    } catch (_) {
      if (!mounted) return;
      ToastBanner.show(
        context,
        message: lt('无法打开视频链接', 'Unable to open video link', '動画リンクを開けません'),
        type: ToastType.error,
      );
    }
  }

  Future<void> _shareSet(WebDJSet djSet) async {
    final fallbackUrl = 'https://ravehub.top/set/${djSet.id}';
    try {
      final payload = await ref
          .read(setApiProvider)
          .resolveShareLink(djSet: djSet, channel: 'system_share');
      final shareUrl = payload.shortUrl.isNotEmpty
          ? payload.shortUrl
          : (payload.url.isNotEmpty ? payload.url : fallbackUrl);
      await ShareService.shareUrl(shareUrl, subject: djSet.title);
    } catch (_) {
      await ShareService.shareUrl(fallbackUrl, subject: djSet.title);
    }
  }

  Future<void> _openTrackLink(String url) async {
    try {
      await UrlLauncherService.openExternalUrl(url);
    } catch (_) {
      if (!mounted) return;
      ToastBanner.show(
        context,
        message: lt('无法打开链接', 'Unable to open link', 'リンクを開けません'),
        type: ToastType.error,
      );
    }
  }

  Future<void> _editComment(WebSetComment comment) async {
    final controller = TextEditingController(text: comment.content);
    final updatedContent = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(lt('编辑评论', 'Edit Comment', 'コメントを編集')),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 4,
            minLines: 1,
            decoration: InputDecoration(
              hintText: lt('说点什么...', 'Say something...', '何か書いてください...'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(lt('取消', 'Cancel', 'キャンセル')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: Text(lt('保存', 'Save', '保存')),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (!mounted || updatedContent == null) return;
    await ref
        .read(setDetailProvider(widget.setId).notifier)
        .updateComment(comment.id, updatedContent);
  }

  Future<void> _deleteComment(WebSetComment comment) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text(lt('删除评论', 'Delete Comment', 'コメントを削除')),
              content: Text(
                lt(
                  '确定要删除这条评论吗？',
                  'Delete this comment?',
                  'このコメントを削除しますか？',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(lt('取消', 'Cancel', 'キャンセル')),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(lt('删除', 'Delete', '削除')),
                ),
              ],
            );
          },
        ) ??
        false;
    if (!mounted || !confirmed) return;
    await ref
        .read(setDetailProvider(widget.setId).notifier)
        .deleteComment(comment.id);
  }

  Future<void> _deleteSet() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text(lt('删除 Set', 'Delete Set', 'Setを削除')),
              content: Text(
                lt(
                  '确定要删除这个 Set 吗？此操作无法撤销。',
                  'Delete this set? This cannot be undone.',
                  'このSetを削除しますか？この操作は元に戻せません。',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(lt('取消', 'Cancel', 'キャンセル')),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(lt('删除', 'Delete', '削除')),
                ),
              ],
            );
          },
        ) ??
        false;
    if (!mounted || !confirmed) return;

    final success =
        await ref.read(setDetailProvider(widget.setId).notifier).deleteSet();
    if (!mounted) return;
    if (success) {
      ToastBanner.show(
        context,
        message: lt('Set 已删除', 'Set deleted', 'Setを削除しました'),
      );
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/discover');
      }
    } else {
      ToastBanner.show(
        context,
        message: ref.read(setDetailProvider(widget.setId)).errorMessage ??
            lt('删除失败', 'Delete failed', '削除に失敗しました'),
        type: ToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(setDetailProvider(widget.setId));
    final theme = context.raver;

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.background,
        title: Text(lt('Set 详情', 'Set Detail', 'セット詳細')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _buildBody(state, theme),
    );
  }

  Widget _buildBody(SetDetailState state, RaverThemeData theme) {
    if (state.isLoading && state.djSet == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.errorMessage != null && state.djSet == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.secondaryText),
            const SizedBox(height: 12),
            Text(
              lt('加载失败', 'Failed to load', '読み込みに失敗しました'),
              style: TextStyle(color: theme.primaryText),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () =>
                  ref.read(setDetailProvider(widget.setId).notifier).load(),
              child: Text(lt('重试', 'Retry', '再試行')),
            ),
          ],
        ),
      );
    }

    final djSet = state.djSet;
    if (djSet == null) return const SizedBox.shrink();

    if (_canInlinePlay(djSet)) {
      _initVideoPlayer(djSet.videoUrl);
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _videoSection(djSet, theme),
                if (djSet.tracks != null && djSet.tracks!.isNotEmpty)
                  _tracklistSection(djSet, theme),
                _detailBody(djSet, state, theme),
              ],
            ),
          ),
        ),
        _commentInputBar(state, theme),
      ],
    );
  }

  Widget _videoSection(WebDJSet djSet, RaverThemeData theme) {
    if (_chewieController != null) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Chewie(controller: _chewieController!),
      );
    }

    return GestureDetector(
      onTap: djSet.videoUrl.isNotEmpty ? () => _openExternalVideo(djSet) : null,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            djSet.thumbnailUrl.isNotEmpty
                ? RemoteCoverImage(url: djSet.thumbnailUrl, fit: BoxFit.cover)
                : _videoFallback(theme),
            if (djSet.videoUrl.isNotEmpty)
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _videoFallback(RaverThemeData theme) {
    return Container(
      color: theme.card,
      child: Center(
        child: Icon(Icons.videocam_off, size: 48, color: theme.secondaryText),
      ),
    );
  }

  bool _canInlinePlay(WebDJSet djSet) {
    final url = djSet.videoUrl.toLowerCase();
    if (url.isEmpty) return false;
    return url.endsWith('.mp4') ||
        url.endsWith('.m3u8') ||
        url.endsWith('.mov');
  }

  Widget _tracklistSection(WebDJSet djSet, RaverThemeData theme) {
    final tracks = djSet.tracks ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _tracklistExpanded = !_tracklistExpanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Icon(Icons.queue_music, size: 18, color: theme.primaryText),
                const SizedBox(width: 8),
                Text(
                  '${lt("曲目列表", "Tracklist", "トラックリスト")} (${tracks.length})',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.primaryText,
                  ),
                ),
                const Spacer(),
                Icon(
                  _tracklistExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: theme.secondaryText,
                ),
              ],
            ),
          ),
        ),
        if (_tracklistExpanded)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 230),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: tracks.length,
              itemBuilder: (context, index) {
                final track = tracks[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 50,
                        child: Text(
                          track.startTime.isNotEmpty
                              ? track.startTime
                              : '${track.position}',
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: theme.secondaryText,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.title,
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.primaryText,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (track.artist.isNotEmpty)
                              Text(
                                track.artist,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.secondaryText,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      if (track.spotifyUrl.isNotEmpty)
                        IconButton(
                          tooltip: 'Spotify',
                          icon: Icon(
                            Icons.music_note,
                            size: 18,
                            color: theme.accent,
                          ),
                          onPressed: () => _openTrackLink(track.spotifyUrl),
                        ),
                      if (track.neteaseUrl.isNotEmpty)
                        IconButton(
                          tooltip: lt('网易云', 'NetEase', 'NetEase'),
                          icon: Icon(
                            Icons.library_music,
                            size: 18,
                            color: theme.accent,
                          ),
                          onPressed: () => _openTrackLink(track.neteaseUrl),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        Divider(color: theme.cardBorder),
      ],
    );
  }

  Widget _detailBody(
    WebDJSet djSet,
    SetDetailState state,
    RaverThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            djSet.title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.primaryText,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () {
              if (djSet.djId.isNotEmpty) {
                context.push('/djs/${djSet.djId}');
              }
            },
            child: Row(
              children: [
                ClipOval(
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: djSet.djAvatarUrl.isNotEmpty
                        ? RemoteCoverImage(
                            url: djSet.djAvatarUrl,
                            fit: BoxFit.cover,
                          )
                        : _avatarFallback(theme),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  djSet.djName.isNotEmpty
                      ? djSet.djName
                      : lt('未关联 DJ', 'No DJ Linked', 'DJ未リンク'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: theme.primaryText,
                  ),
                ),
              ],
            ),
          ),
          if (djSet.eventName.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: theme.secondaryText,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    djSet.eventName,
                    style: TextStyle(fontSize: 13, color: theme.secondaryText),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              _SetMetaPill(
                icon: Icons.schedule,
                label: _formatDuration(djSet.duration),
              ),
              _SetMetaPill(
                icon: Icons.queue_music,
                label: '${_resolvedTrackCount(djSet)}',
              ),
              _SetMetaPill(
                icon: Icons.visibility_outlined,
                label: _formatCount(djSet.viewCount),
              ),
              _SetMetaPill(
                icon: Icons.favorite_border,
                label: _formatCount(djSet.likeCount),
              ),
              _SetMetaPill(
                icon: Icons.chat_bubble_outline,
                label: _formatCount(djSet.commentCount),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (_canManageSet(djSet))
                _SetActionChip(
                  icon: Icons.edit_outlined,
                  label: lt('编辑 Set', 'Edit Set', 'Setを編集'),
                  onTap: () => context.push('/sets/${djSet.id}/edit'),
                ),
              if (_canManageSet(djSet))
                _SetActionChip(
                  icon: Icons.text_snippet_outlined,
                  label: lt('编辑曲目', 'Edit Tracklist', '曲目編集'),
                  onTap: () => context.push('/sets/${djSet.id}/tracklist/edit'),
                ),
              if (djSet.videoUrl.isNotEmpty)
                _SetActionChip(
                  icon: Icons.open_in_new,
                  label: lt('打开视频', 'Open Video', '動画を開く'),
                  onTap: () => _openExternalVideo(djSet),
                ),
              _SetActionChip(
                icon: Icons.share_outlined,
                label: lt('分享', 'Share', 'シェア'),
                onTap: () => _shareSet(djSet),
              ),
              if (_canManageSet(djSet))
                _SetActionChip(
                  icon: Icons.delete_outline,
                  label: state.isDeletingSet
                      ? lt('删除中', 'Deleting', '削除中')
                      : lt('删除 Set', 'Delete Set', 'Setを削除'),
                  onTap: state.isDeletingSet ? null : _deleteSet,
                  isDestructive: true,
                ),
            ],
          ),
          const SizedBox(height: 24),
          Divider(color: theme.cardBorder),
          const SizedBox(height: 12),
          Text(
            lt('评论', 'Comments', 'コメント'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.primaryText,
            ),
          ),
          const SizedBox(height: 12),
          if (state.comments.isEmpty)
            Text(
              lt(
                '还没有评论，来抢沙发吧。',
                'No comments yet. Be the first!',
                'コメントはまだありません。最初のコメントを書きましょう。',
              ),
              style: TextStyle(fontSize: 14, color: theme.secondaryText),
            )
          else
            ...state.comments.map((comment) {
              final currentUserId = DiscoverServiceLocator.currentUserId;
              final canManage = currentUserId != null &&
                  currentUserId.isNotEmpty &&
                  comment.userId == currentUserId;
              return _CommentTile(
                comment: comment,
                canManage: canManage,
                onEdit: () => _editComment(comment),
                onDelete: () => _deleteComment(comment),
              );
            }),
          if (state.canLoadMoreComments || state.isLoadingMoreComments) ...[
            const SizedBox(height: 4),
            Center(
              child: TextButton.icon(
                onPressed: state.isLoadingMoreComments
                    ? null
                    : () => ref
                        .read(setDetailProvider(widget.setId).notifier)
                        .loadMoreComments(),
                icon: state.isLoadingMoreComments
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more),
                label: Text(
                  state.isLoadingMoreComments
                      ? lt('加载中', 'Loading', '読み込み中')
                      : lt('加载更多评论', 'Load more comments', 'コメントをもっと読む'),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _commentInputBar(SetDetailState state, RaverThemeData theme) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        8 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: theme.background,
        border: Border(top: BorderSide(color: theme.cardBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              onChanged: (text) => ref
                  .read(setDetailProvider(widget.setId).notifier)
                  .setCommentInput(text),
              decoration: InputDecoration(
                hintText: lt('说点什么...', 'Say something...', '何か書いてください...'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.card,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              maxLines: 1,
              style: TextStyle(fontSize: 14, color: theme.primaryText),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed:
                state.isSendingComment || state.commentInput.trim().isEmpty
                    ? null
                    : () {
                        ref
                            .read(setDetailProvider(widget.setId).notifier)
                            .submitComment();
                        _commentController.clear();
                      },
            child: state.isSendingComment
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(lt('发送', 'Send', '送信')),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback(RaverThemeData theme) {
    return Container(
      color: theme.cardBorder,
      child: Icon(Icons.person, size: 18, color: theme.secondaryText),
    );
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  int _resolvedTrackCount(WebDJSet djSet) {
    if (djSet.trackCount > 0) return djSet.trackCount;
    return djSet.tracks?.length ?? 0;
  }

  bool _canManageSet(WebDJSet djSet) {
    final currentUserId = DiscoverServiceLocator.currentUserId;
    return currentUserId != null &&
        currentUserId.isNotEmpty &&
        djSet.uploadedById == currentUserId;
  }

  String _formatCount(int value) {
    if (value >= 1000000) {
      final compact =
          (value / 1000000).toStringAsFixed(value >= 10000000 ? 0 : 1);
      return '${compact}m';
    }
    if (value >= 1000) {
      final compact = (value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1);
      return '${compact}k';
    }
    return '$value';
  }
}

class _SetMetaPill extends StatelessWidget {
  const _SetMetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.secondaryText),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: theme.secondaryText),
        ),
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
  });

  final WebSetComment comment;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipOval(
            child: SizedBox(
              width: 28,
              height: 28,
              child: comment.avatarUrl.isNotEmpty
                  ? RemoteCoverImage(url: comment.avatarUrl, fit: BoxFit.cover)
                  : Container(
                      color: theme.cardBorder,
                      child: Icon(
                        Icons.person,
                        size: 14,
                        color: theme.secondaryText,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment.displayName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.primaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  comment.content,
                  style: TextStyle(fontSize: 14, color: theme.primaryText),
                ),
                const SizedBox(height: 2),
                Text(
                  comment.createdAt.length > 10
                      ? comment.createdAt.substring(0, 10)
                      : comment.createdAt,
                  style: TextStyle(fontSize: 11, color: theme.secondaryText),
                ),
              ],
            ),
          ),
          if (canManage)
            PopupMenuButton<_CommentAction>(
              icon: Icon(Icons.more_horiz, color: theme.secondaryText),
              tooltip: lt('更多', 'More', 'その他'),
              onSelected: (action) {
                switch (action) {
                  case _CommentAction.edit:
                    onEdit();
                  case _CommentAction.delete:
                    onDelete();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _CommentAction.edit,
                  child: Text(lt('编辑', 'Edit', '編集')),
                ),
                PopupMenuItem(
                  value: _CommentAction.delete,
                  child: Text(lt('删除', 'Delete', '削除')),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

enum _CommentAction { edit, delete }

class _SetActionChip extends StatelessWidget {
  const _SetActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    final color = isDestructive ? Colors.redAccent : theme.accent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.card,
          border: Border.all(color: theme.cardBorder),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: onTap == null ? theme.secondaryText : color,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: RaverTypography.label(
                size: 13,
                color: isDestructive && onTap != null
                    ? Colors.redAccent
                    : theme.primaryText,
                weight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
