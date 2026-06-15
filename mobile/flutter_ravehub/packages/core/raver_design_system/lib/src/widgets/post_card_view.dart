import 'package:flutter/material.dart';

import '../theme/raver_theme.dart';
import '../theme/raver_typography.dart';
import 'remote_cover_image.dart';

/// Data contract for a post to be displayed in a [PostCardView].
///
/// This is a UI-level abstraction so the widget does not import
/// `raver_models` directly. Feature modules map their domain `Post` to this.
class PostCardData {
  const PostCardData({
    required this.id,
    required this.authorName,
    required this.content,
    required this.createdAt,
    this.authorAvatarUrl,
    this.images = const [],
    this.likeCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
    this.isLiked = false,
    this.squadName,
    this.eventName,
  });

  final String id;
  final String authorName;
  final String? authorAvatarUrl;
  final String content;
  final String createdAt;
  final List<String> images;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final bool isLiked;
  final String? squadName;
  final String? eventName;
}

/// A shared post card widget used across Feed, Profile, and Circle screens.
///
/// Displays the author header, text content, optional image grid, and an
/// action bar (like / comment / share).
class PostCardView extends StatelessWidget {
  /// Creates a [PostCardView].
  const PostCardView({
    required this.post,
    super.key,
    this.onTap,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onAuthorTap,
    this.onMoreTap,
  });

  /// The post data to display.
  final PostCardData post;

  /// Called when the card body is tapped.
  final VoidCallback? onTap;

  /// Called when the like button is tapped.
  final VoidCallback? onLike;

  /// Called when the comment button is tapped.
  final VoidCallback? onComment;

  /// Called when the share button is tapped.
  final VoidCallback? onShare;

  /// Called when the author avatar / name is tapped.
  final VoidCallback? onAuthorTap;

  /// Called when the more (ellipsis) button is tapped.
  final VoidCallback? onMoreTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author header
            _AuthorHeader(
              name: post.authorName,
              avatarUrl: post.authorAvatarUrl,
              timestamp: post.createdAt,
              squadName: post.squadName,
              eventName: post.eventName,
              theme: theme,
              onTap: onAuthorTap,
              onMoreTap: onMoreTap,
            ),
            const SizedBox(height: 12),

            // Content
            Text(
              post.content,
              style: RaverTypography.body(
                size: 15,
                color: theme.primaryText,
              ),
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),

            // Images
            if (post.images.isNotEmpty) ...[
              const SizedBox(height: 12),
              _ImageGrid(images: post.images),
            ],

            // Action bar
            const SizedBox(height: 12),
            _ActionBar(
              likeCount: post.likeCount,
              commentCount: post.commentCount,
              shareCount: post.shareCount,
              isLiked: post.isLiked,
              theme: theme,
              onLike: onLike,
              onComment: onComment,
              onShare: onShare,
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthorHeader extends StatelessWidget {
  const _AuthorHeader({
    required this.name,
    required this.timestamp,
    required this.theme,
    this.avatarUrl,
    this.squadName,
    this.eventName,
    this.onTap,
    this.onMoreTap,
  });

  final String name;
  final String? avatarUrl;
  final String timestamp;
  final String? squadName;
  final String? eventName;
  final RaverThemeData theme;
  final VoidCallback? onTap;
  final VoidCallback? onMoreTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onTap,
          child: CircleAvatar(
            radius: 20,
            backgroundColor: theme.cardBorder,
            backgroundImage:
                avatarUrl != null ? NetworkImage(avatarUrl!) : null,
            child: avatarUrl == null
                ? Icon(
                    Icons.person,
                    size: 20,
                    color: theme.secondaryText,
                  )
                : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: RaverTypography.label(
                          size: 14,
                          color: theme.primaryText,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (squadName != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          squadName!,
                          style: RaverTypography.caption(
                            size: 10,
                            color: theme.accent,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      timestamp,
                      style: RaverTypography.caption(
                        color: theme.secondaryText,
                      ),
                    ),
                    if (eventName != null) ...[
                      Text(
                        ' \u2022 ',
                        style: RaverTypography.caption(
                          color: theme.secondaryText,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          eventName!,
                          style: RaverTypography.caption(
                            color: theme.accent,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        if (onMoreTap != null)
          GestureDetector(
            onTap: onMoreTap,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.more_horiz,
                size: 20,
                color: theme.secondaryText,
              ),
            ),
          ),
      ],
    );
  }
}

class _ImageGrid extends StatelessWidget {
  const _ImageGrid({required this.images});

  final List<String> images;

  @override
  Widget build(BuildContext context) {
    if (images.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: RemoteCoverImage(
          url: images.first,
          width: double.infinity,
          height: 200,
          fit: BoxFit.cover,
        ),
      );
    }

    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) => RemoteCoverImage(
          url: images[index],
          width: 160,
          height: 160,
          fit: BoxFit.cover,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    required this.isLiked,
    required this.theme,
    this.onLike,
    this.onComment,
    this.onShare,
  });

  final int likeCount;
  final int commentCount;
  final int shareCount;
  final bool isLiked;
  final RaverThemeData theme;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ActionButton(
          icon: isLiked ? Icons.favorite : Icons.favorite_border,
          count: likeCount,
          color: isLiked ? Colors.red : theme.secondaryText,
          onTap: onLike,
        ),
        const SizedBox(width: 20),
        _ActionButton(
          icon: Icons.chat_bubble_outline,
          count: commentCount,
          color: theme.secondaryText,
          onTap: onComment,
        ),
        const SizedBox(width: 20),
        _ActionButton(
          icon: Icons.share_outlined,
          count: shareCount,
          color: theme.secondaryText,
          onTap: onShare,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.count,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final int count;
  final Color color;
  final VoidCallback? onTap;

  String _formatCount(int value) {
    if (value <= 0) return '';
    if (value >= 10000) return '${(value / 1000).toStringAsFixed(1)}k';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return '$value';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Text(
              _formatCount(count),
              style: RaverTypography.caption(
                size: 12,
                color: color,
                weight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
