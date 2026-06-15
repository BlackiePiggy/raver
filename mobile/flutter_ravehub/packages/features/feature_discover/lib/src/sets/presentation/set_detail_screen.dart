import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

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
        () => ref.read(setDetailProvider(widget.setId).notifier).load());
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
            Text(lt('加载失败', 'Failed to load', '読み込みに失敗しました'),
                style: TextStyle(color: theme.primaryText)),
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

    if (djSet.videoUrl.isNotEmpty) {
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

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          djSet.thumbnailUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: djSet.thumbnailUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _videoFallback(theme),
                )
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
                child: const Icon(Icons.play_arrow,
                    size: 36, color: Colors.white),
              ),
            ),
        ],
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
                  _tracklistExpanded
                      ? Icons.expand_less
                      : Icons.expand_more,
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
      WebDJSet djSet, SetDetailState state, RaverThemeData theme) {
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
                        ? CachedNetworkImage(
                            imageUrl: djSet.djAvatarUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                _avatarFallback(theme),
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
                Icon(Icons.calendar_today,
                    size: 14, color: theme.secondaryText),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    djSet.eventName,
                    style: TextStyle(
                        fontSize: 13, color: theme.secondaryText),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                _formatDuration(djSet.duration),
                style:
                    TextStyle(fontSize: 12, color: theme.secondaryText),
              ),
              const SizedBox(width: 16),
              Icon(Icons.chat_bubble_outline,
                  size: 14, color: theme.secondaryText),
              const SizedBox(width: 4),
              Text(
                '${djSet.commentCount}',
                style:
                    TextStyle(fontSize: 12, color: theme.secondaryText),
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
              lt('还没有评论，来抢沙发吧。', 'No comments yet. Be the first!',
                  'コメントはまだありません。最初のコメントを書きましょう。'),
              style: TextStyle(
                  fontSize: 14, color: theme.secondaryText),
            )
          else
            ...state.comments.map((comment) => _CommentTile(comment: comment)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _commentInputBar(SetDetailState state, RaverThemeData theme) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 8, 16, 8 + MediaQuery.of(context).padding.bottom),
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
                    horizontal: 12, vertical: 10),
              ),
              maxLines: 1,
              style: TextStyle(fontSize: 14, color: theme.primaryText),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: state.isSendingComment ||
                    state.commentInput.trim().isEmpty
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
                    child:
                        CircularProgressIndicator(strokeWidth: 2),
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
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});

  final WebSetComment comment;

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
                  ? CachedNetworkImage(
                      imageUrl: comment.avatarUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        color: theme.cardBorder,
                        child: Icon(Icons.person,
                            size: 14, color: theme.secondaryText),
                      ),
                    )
                  : Container(
                      color: theme.cardBorder,
                      child: Icon(Icons.person,
                          size: 14, color: theme.secondaryText),
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
                  style:
                      TextStyle(fontSize: 11, color: theme.secondaryText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
