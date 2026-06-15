import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';

import 'organizer_view_model.dart';

class FestivalDetailScreen extends ConsumerWidget {
  const FestivalDetailScreen({super.key, required this.festivalId});

  final String festivalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(festivalDetailProvider(festivalId));

    return Scaffold(
      body: _buildBody(context, ref, state),
    );
  }

  Widget _buildBody(
      BuildContext context, WidgetRef ref, FestivalDetailState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (state.error != null) {
      return ErrorStateView(
        title: lt('加载失败', 'Failed to load', 'ロードに失敗しました'),
        description: state.error,
        onRetry: () =>
            ref.read(festivalDetailProvider(festivalId).notifier).retry(),
      );
    }

    final festival = state.festival;
    if (festival == null) {
      return EmptyStateView(
        icon: Icons.festival_outlined,
        title: lt('音乐节未找到', 'Festival not found', 'フェスが見つかりません'),
      );
    }

    final hasImages =
        festival.imageUrls != null && festival.imageUrls!.isNotEmpty;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: hasImages ? 260 : 0,
          pinned: true,
          flexibleSpace: hasImages
              ? FlexibleSpaceBar(
                  title: Text(
                    festival.name,
                    style: RaverTypography.title()
                        .copyWith(color: Colors.white),
                  ),
                  background: CachedNetworkImage(
                    imageUrl: festival.imageUrls!.first,
                    fit: BoxFit.cover,
                    color: Colors.black.withValues(alpha: 0.3),
                    colorBlendMode: BlendMode.darken,
                  ),
                )
              : null,
          title: hasImages ? null : Text(festival.name),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          '${festival.city}, ${festival.country}',
                          style: RaverTypography.body(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.people_outline, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          '${festival.followerCount} ${lt("关注者", "followers", "フォロワー")}',
                          style: RaverTypography.body(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                lt('简介', 'Introduction', '紹介'),
                style: RaverTypography.title(),
              ),
              const SizedBox(height: 8),
              Text(festival.introduction, style: RaverTypography.body()),
              if (festival.genres != null &&
                  festival.genres!.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  lt('流派', 'Genres', 'ジャンル'),
                  style: RaverTypography.title(),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: festival.genres!
                      .map((g) => Chip(label: Text(g)))
                      .toList(),
                ),
              ],
              if (festival.aliases != null &&
                  festival.aliases!.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  lt('别名', 'Also known as', '別名'),
                  style: RaverTypography.title(),
                ),
                const SizedBox(height: 8),
                Text(
                  festival.aliases!.join(', '),
                  style: RaverTypography.body(),
                ),
              ],
              if (festival.links != null &&
                  festival.links!.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  lt('链接', 'Links', 'リンク'),
                  style: RaverTypography.title(),
                ),
                const SizedBox(height: 8),
                ...festival.links!.map(
                  (link) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.link, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            link.label,
                            style: RaverTypography.label().copyWith(
                              color: RaverColors.accent(
                                  Theme.of(context).brightness),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ]),
          ),
        ),
      ],
    );
  }
}
