import 'package:flutter/material.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';

/// Displays the iOS-matching stats row:
/// Posts | Followers | Following | Friends (4 columns, HStack spacing 18).
class ProfileStatsRow extends StatelessWidget {
  const ProfileStatsRow({
    super.key,
    required this.postCount,
    required this.followingCount,
    required this.followerCount,
    required this.friendCount,
    this.onPostsTap,
    this.onFollowingTap,
    this.onFollowersTap,
    this.onFriendsTap,
  });

  final int postCount;
  final int followingCount;
  final int followerCount;
  final int friendCount;
  final VoidCallback? onPostsTap;
  final VoidCallback? onFollowingTap;
  final VoidCallback? onFollowersTap;
  final VoidCallback? onFriendsTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    // iOS: HStack(spacing: 18) with 4 stat columns
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _StatItem(
          count: postCount,
          label: lt('动态', 'Posts', '投稿'),
          onTap: onPostsTap,
          theme: theme,
        ),
        _divider(theme),
        _StatItem(
          count: followerCount,
          label: lt('粉丝', 'Followers', 'フォロワー'),
          onTap: onFollowersTap,
          theme: theme,
        ),
        _divider(theme),
        _StatItem(
          count: followingCount,
          label: lt('关注', 'Following', 'フォロー中'),
          onTap: onFollowingTap,
          theme: theme,
        ),
        _divider(theme),
        _StatItem(
          count: friendCount,
          label: lt('好友', 'Friends', 'フレンド'),
          onTap: onFriendsTap,
          theme: theme,
        ),
      ],
    );
  }

  Widget _divider(RaverThemeData theme) {
    return Container(width: 1, height: 28, color: theme.cardBorder);
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.count,
    required this.label,
    required this.theme,
    this.onTap,
  });

  final int count;
  final String label;
  final RaverThemeData theme;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        // iOS: VStack spacing 4, horizontal padding effectively ~16
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatCount(count),
              // iOS: .font(.headline)
              style: RaverTypography.title(size: 18, color: theme.primaryText),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: RaverTypography.caption(color: theme.secondaryText),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 10000) return '${(count / 10000).toStringAsFixed(1)}w';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }
}
