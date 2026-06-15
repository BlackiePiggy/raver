import 'package:flutter/material.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';

/// Displays the profile header: avatar, display name, EDMTI tag, and bio.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.profile,
    this.onAvatarTap,
  });

  final UserProfile profile;
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return Column(
      children: [
        // iOS: avatar 84pt, clipped to Circle, NO border stroke
        GestureDetector(
          onTap: onAvatarTap,
          child: ClipOval(
            child: profile.avatarUrl != null &&
                    profile.avatarUrl!.isNotEmpty
                ? RemoteCoverImage(
                    url: profile.avatarUrl!,
                    width: 84,
                    height: 84,
                  )
                : Container(
                    width: 84,
                    height: 84,
                    color: theme.cardBorder,
                    child: Icon(
                      Icons.person,
                      size: 42,
                      color: theme.secondaryText,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        // Display name
        Text(
          profile.displayName,
          style: RaverTypography.headline(
            color: theme.primaryText,
          ).copyWith(fontSize: 22),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        // Username
        Text(
          '@${profile.username}',
          style: RaverTypography.caption(color: theme.secondaryText),
        ),
        // Age band tag
        if (profile.ageBand.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: theme.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              profile.ageBand,
              style: RaverTypography.label(
                size: 12,
                color: theme.accent,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ],
        // Bio
        if (profile.bio != null && profile.bio!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              profile.bio!,
              style: RaverTypography.body(
                size: 14,
                color: theme.secondaryText,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}
