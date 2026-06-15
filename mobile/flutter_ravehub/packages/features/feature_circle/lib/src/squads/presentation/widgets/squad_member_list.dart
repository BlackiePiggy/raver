import 'package:flutter/material.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_models/raver_models.dart';

/// Displays a grid of squad member avatars with optional "view all" behaviour.
class SquadMemberList extends StatelessWidget {
  const SquadMemberList({
    super.key,
    required this.members,
    required this.theme,
    this.maxVisible = 8,
    this.onViewAll,
  });

  final List<SquadMemberProfile> members;
  final RaverThemeData theme;
  final int maxVisible;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final visible = members.take(maxVisible).toList();
    final hasMore = members.length > maxVisible;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...visible.map((m) => _MemberAvatar(member: m, theme: theme)),
        if (hasMore)
          GestureDetector(
            onTap: onViewAll,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: theme.card,
                shape: BoxShape.circle,
                border: Border.all(color: theme.cardBorder),
              ),
              child: Center(
                child: Text(
                  '+${members.length - maxVisible}',
                  style: RaverTypography.caption(
                    size: 12,
                    color: theme.secondaryText,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({
    required this.member,
    required this.theme,
  });

  final SquadMemberProfile member;
  final RaverThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: member.displayName,
      child: CircleAvatar(
        radius: 22,
        backgroundColor: theme.cardBorder,
        backgroundImage: member.avatarUrl.isNotEmpty
            ? NetworkImage(member.avatarUrl)
            : null,
        child: member.avatarUrl.isEmpty
            ? Icon(Icons.person, size: 20, color: theme.secondaryText)
            : null,
      ),
    );
  }
}
