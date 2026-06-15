import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';

import '../data/dj_providers.dart';

class DjDetailScreen extends ConsumerStatefulWidget {
  const DjDetailScreen({super.key, required this.djId});

  final String djId;

  @override
  ConsumerState<DjDetailScreen> createState() => _DjDetailScreenState();
}

class _DjDetailScreenState extends ConsumerState<DjDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(djDetailProvider(widget.djId).notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(djDetailProvider(widget.djId));
    final theme = context.raver;

    return Scaffold(
      backgroundColor: theme.background,
      body: _buildBody(state, theme),
    );
  }

  Widget _buildBody(DjDetailState state, RaverThemeData theme) {
    if (state.isLoading && state.dj == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.errorMessage != null && state.dj == null) {
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
                  ref.read(djDetailProvider(widget.djId).notifier).load(),
              child: Text(lt('重试', 'Retry', '再試行')),
            ),
          ],
        ),
      );
    }

    final dj = state.dj;
    if (dj == null) return const SizedBox.shrink();

    return CustomScrollView(
      slivers: [
        _HeroHeader(dj: dj, state: state, djId: widget.djId),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _TabSelector(
              selected: state.selectedTab,
              onSelected: (tab) => ref
                  .read(djDetailProvider(widget.djId).notifier)
                  .setTab(tab),
              theme: theme,
            ),
          ),
        ),
        if (state.selectedTab == DjDetailTab.intro)
          SliverToBoxAdapter(
            child: _IntroSection(dj: dj, theme: theme),
          ),
        if (state.selectedTab == DjDetailTab.sets)
          state.sets.isEmpty
              ? SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        lt('暂无 Sets', 'No sets yet', 'セットはまだありません'),
                        style: TextStyle(
                            color: theme.secondaryText, fontSize: 14),
                      ),
                    ),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final set = state.sets[index];
                      return _SetTile(djSet: set);
                    },
                    childCount: state.sets.length,
                  ),
                ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
      ],
    );
  }
}

class _HeroHeader extends ConsumerWidget {
  const _HeroHeader({
    required this.dj,
    required this.state,
    required this.djId,
  });

  final WebDJ dj;
  final DjDetailState state;
  final String djId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SliverAppBar(
      expandedHeight: 320,
      pinned: true,
      backgroundColor: Colors.black,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => context.pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            dj.avatarUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: dj.avatarUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _fallbackGradient(),
                  )
                : _fallbackGradient(),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.black.withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          dj.name,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (dj.aliases != null && dj.aliases!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            children: dj.aliases!.take(3).map((alias) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  alias,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.people,
                                size: 14, color: Colors.white70),
                            const SizedBox(width: 4),
                            Text(
                              '${dj.followerCount} ${lt("粉丝", "followers", "フォロワー")}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.white70),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _FollowButton(
                    isFollowing: dj.isFollowing ?? false,
                    isLoading: state.isFollowLoading,
                    onTap: () =>
                        ref.read(djDetailProvider(djId).notifier).toggleFollow(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackGradient() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}

class _FollowButton extends StatelessWidget {
  const _FollowButton({
    required this.isFollowing,
    required this.isLoading,
    required this.onTap,
  });

  final bool isFollowing;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isFollowing
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Text(
                isFollowing
                    ? lt('已关注', 'Following', 'フォロー中')
                    : lt('关注', 'Follow', 'フォロー'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isFollowing ? Colors.white : Colors.black,
                ),
              ),
      ),
    );
  }
}

class _TabSelector extends StatelessWidget {
  const _TabSelector({
    required this.selected,
    required this.onSelected,
    required this.theme,
  });

  final DjDetailTab selected;
  final ValueChanged<DjDetailTab> onSelected;
  final RaverThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: DjDetailTab.values.map((tab) {
          final isSelected = tab == selected;
          return GestureDetector(
            onTap: () => onSelected(tab),
            child: Padding(
              padding: const EdgeInsets.only(right: 24),
              child: Column(
                children: [
                  Text(
                    _tabTitle(tab),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color:
                          isSelected ? theme.primaryText : theme.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 3,
                    width: isSelected ? 24 : 0,
                    decoration: BoxDecoration(
                      color: theme.accent,
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _tabTitle(DjDetailTab tab) {
    switch (tab) {
      case DjDetailTab.intro:
        return lt('介绍', 'Intro', '紹介');
      case DjDetailTab.sets:
        return 'Sets';
    }
  }
}

class _IntroSection extends StatelessWidget {
  const _IntroSection({required this.dj, required this.theme});

  final WebDJ dj;
  final RaverThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (dj.country.isNotEmpty) ...[
            _InfoPill(
              icon: Icons.location_on,
              text: dj.country,
              theme: theme,
            ),
            const SizedBox(height: 8),
          ],
          if (dj.genres != null && dj.genres!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: dj.genres!.map((genre) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: theme.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    genre,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: theme.accent,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
          if (dj.bio.isNotEmpty) ...[
            Text(
              dj.bio,
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: theme.primaryText,
              ),
            ),
            const SizedBox(height: 16),
          ],
          _SocialLinks(dj: dj, theme: theme),
          if (dj.honors != null && dj.honors!.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              lt('荣誉', 'Honors', '受賞歴'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.primaryText,
              ),
            ),
            const SizedBox(height: 8),
            ...dj.honors!.map((honor) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(Icons.emoji_events,
                          size: 16, color: theme.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${honor.title} (${honor.year}) #${honor.rank}',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.primaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.text,
    required this.theme,
  });

  final IconData icon;
  final String text;
  final RaverThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.secondaryText),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 12, color: theme.primaryText),
          ),
        ],
      ),
    );
  }
}

class _SocialLinks extends StatelessWidget {
  const _SocialLinks({required this.dj, required this.theme});

  final WebDJ dj;
  final RaverThemeData theme;

  @override
  Widget build(BuildContext context) {
    final links = <MapEntry<IconData, String>>[];
    if (dj.instagramUrl.isNotEmpty) {
      links.add(MapEntry(Icons.camera_alt, 'Instagram'));
    }
    if (dj.soundcloudUrl.isNotEmpty) {
      links.add(MapEntry(Icons.headphones, 'SoundCloud'));
    }
    if (dj.spotifyUrl.isNotEmpty) {
      links.add(MapEntry(Icons.music_note, 'Spotify'));
    }
    if (links.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 12,
      children: links.map((entry) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(entry.key, size: 16, color: theme.accent),
            const SizedBox(width: 4),
            Text(
              entry.value,
              style: TextStyle(fontSize: 13, color: theme.accent),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _SetTile extends StatelessWidget {
  const _SetTile({required this.djSet});

  final WebDJSet djSet;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    return InkWell(
      onTap: () => context.push('/sets/${djSet.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 80,
                height: 45,
                child: djSet.thumbnailUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: djSet.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            _thumbnailFallback(theme),
                      )
                    : _thumbnailFallback(theme),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    djSet.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.primaryText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDuration(djSet.duration),
                    style: TextStyle(
                        fontSize: 11, color: theme.secondaryText),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbnailFallback(RaverThemeData theme) {
    return Container(
      color: theme.card,
      child: Icon(Icons.play_circle_outline,
          size: 24, color: theme.secondaryText),
    );
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m ${s}s';
  }
}
