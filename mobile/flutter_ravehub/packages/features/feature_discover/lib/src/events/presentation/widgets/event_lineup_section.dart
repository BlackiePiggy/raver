import 'package:flutter/material.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';

enum _LineupSortMode { popularity, alphabetical }

class EventLineupSection extends StatefulWidget {
  const EventLineupSection({
    super.key,
    required this.artists,
    this.onDjTap,
  });

  final List<WebEventLineupArtist> artists;
  final ValueChanged<String>? onDjTap;

  @override
  State<EventLineupSection> createState() => _EventLineupSectionState();
}

class _EventLineupSectionState extends State<EventLineupSection> {
  _LineupSortMode _sortMode = _LineupSortMode.popularity;
  bool _isExpanded = false;

  List<_LineupEntry> get _entries {
    final entries = widget.artists
        .asMap()
        .entries
        .map((entry) => _LineupEntry.fromArtist(entry.value, entry.key))
        .where((entry) => entry.name.trim().isNotEmpty)
        .toList();

    return switch (_sortMode) {
      _LineupSortMode.popularity => entries
        ..sort((a, b) => a.originalIndex.compareTo(b.originalIndex)),
      _LineupSortMode.alphabetical => entries
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    final entries = _entries;

    if (entries.isEmpty) {
      return EmptyStateView(
        icon: Icons.people_outline,
        title: lt('暂无阵容信息', 'No Lineup Info', 'ラインナップ情報なし'),
      );
    }

    final visibleRows = _isExpanded ? entries : entries.take(8).toList();
    final canExpand = entries.length > visibleRows.length || _isExpanded;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Text(
              lt('参演 DJ', 'Lineup DJs', '出演DJ'),
              style: RaverTypography.title(size: 16, color: theme.primaryText),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: theme.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _sortMode == _LineupSortMode.alphabetical
                    ? 'A-Z'
                    : lt('热度', 'Hot', '人気'),
                style: RaverTypography.label(
                  size: 11,
                  color: theme.accent,
                  weight: FontWeight.w700,
                ),
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => setState(() {
                _sortMode = _sortMode == _LineupSortMode.alphabetical
                    ? _LineupSortMode.popularity
                    : _LineupSortMode.alphabetical;
              }),
              icon: Icon(
                _sortMode == _LineupSortMode.alphabetical
                    ? Icons.trending_up
                    : Icons.sort_by_alpha,
                size: 16,
              ),
              label: Text(
                _sortMode == _LineupSortMode.alphabetical
                    ? lt('按热度', 'By popularity', '人気順')
                    : 'A-Z',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: entries.take(24).length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return _LineupAvatarItem(
                entry: entry,
                theme: theme,
                onTap: entry.primaryDjId.isEmpty
                    ? null
                    : () => widget.onDjTap?.call(entry.primaryDjId),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        ...visibleRows.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _LineupRow(
              entry: entry,
              theme: theme,
              onDjTap: widget.onDjTap,
            ),
          ),
        ),
        if (canExpand)
          TextButton.icon(
            onPressed: () => setState(() => _isExpanded = !_isExpanded),
            icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
            label: Text(
              _isExpanded
                  ? lt('收起名单', 'Collapse lineup', 'ラインナップを閉じる')
                  : lt('展开完整名单', 'Expand full lineup', '全ラインナップを表示'),
            ),
          ),
      ],
    );
  }
}

class _LineupAvatarItem extends StatelessWidget {
  const _LineupAvatarItem({
    required this.entry,
    required this.theme,
    required this.onTap,
  });

  final _LineupEntry entry;
  final RaverThemeData theme;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            _LineupAvatar(
              imageUrl: entry.avatarUrl,
              fallbackIcon: entry.isB2B ? Icons.groups : Icons.person,
              size: 52,
              theme: theme,
            ),
            const SizedBox(height: 5),
            Text(
              entry.name,
              style: RaverTypography.caption(color: theme.primaryText),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _LineupRow extends StatelessWidget {
  const _LineupRow({
    required this.entry,
    required this.theme,
    required this.onDjTap,
  });

  final _LineupEntry entry;
  final RaverThemeData theme;
  final ValueChanged<String>? onDjTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.cardBorder),
      ),
      child: Row(
        children: [
          _LineupAvatar(
            imageUrl: entry.avatarUrl,
            fallbackIcon: entry.isB2B ? Icons.groups : Icons.person,
            size: 46,
            theme: theme,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.name,
                        style: RaverTypography.label(
                          size: 15,
                          color: theme.primaryText,
                          weight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (entry.isB2B) ...[
                      const SizedBox(width: 6),
                      _LineupBadge(theme: theme, label: 'B2B'),
                    ],
                  ],
                ),
                if (entry.members.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: entry.members
                        .map(
                          (member) => _LineupMemberChip(
                            member: member,
                            theme: theme,
                            onTap: member.djId.isEmpty
                                ? null
                                : () => onDjTap?.call(member.djId),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          if (entry.primaryDjId.isNotEmpty)
            IconButton(
              icon: Icon(Icons.chevron_right, color: theme.secondaryText),
              onPressed: () => onDjTap?.call(entry.primaryDjId),
            ),
        ],
      ),
    );
  }
}

class _LineupMemberChip extends StatelessWidget {
  const _LineupMemberChip({
    required this.member,
    required this.theme,
    required this.onTap,
  });

  final WebEventLineupArtistMember member;
  final RaverThemeData theme;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: theme.accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: theme.accent.withValues(alpha: 0.18)),
        ),
        child: Text(
          member.name,
          style: RaverTypography.caption(color: theme.accent),
        ),
      ),
    );
  }
}

class _LineupBadge extends StatelessWidget {
  const _LineupBadge({required this.theme, required this.label});

  final RaverThemeData theme;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: RaverTypography.label(
          size: 10,
          color: theme.accent,
          weight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _LineupAvatar extends StatelessWidget {
  const _LineupAvatar({
    required this.imageUrl,
    required this.fallbackIcon,
    required this.size,
    required this.theme,
  });

  final String imageUrl;
  final IconData fallbackIcon;
  final double size;
  final RaverThemeData theme;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: imageUrl.isNotEmpty
          ? RemoteCoverImage(url: imageUrl, width: size, height: size)
          : Container(
              width: size,
              height: size,
              color: theme.cardBorder,
              child: Icon(fallbackIcon, color: theme.secondaryText),
            ),
    );
  }
}

class _LineupEntry {
  const _LineupEntry({
    required this.name,
    required this.primaryDjId,
    required this.avatarUrl,
    required this.isB2B,
    required this.members,
    required this.originalIndex,
  });

  factory _LineupEntry.fromArtist(WebEventLineupArtist artist, int index) {
    final members = artist.members ?? const <WebEventLineupArtistMember>[];
    final memberNames = members
        .map((member) => member.name.trim())
        .where((name) => name.isNotEmpty)
        .join(' & ');
    final name =
        artist.name.trim().isNotEmpty ? artist.name.trim() : memberNames;
    final primaryDjId = artist.djId.trim().isNotEmpty
        ? artist.djId.trim()
        : members
            .map((member) => member.djId.trim())
            .firstWhere((id) => id.isNotEmpty, orElse: () => '');
    return _LineupEntry(
      name: name,
      primaryDjId: primaryDjId,
      avatarUrl: artist.avatarUrl,
      isB2B: artist.isB2B || members.length > 1,
      members: members,
      originalIndex: index,
    );
  }

  final String name;
  final String primaryDjId;
  final String avatarUrl;
  final bool isB2B;
  final List<WebEventLineupArtistMember> members;
  final int originalIndex;
}
