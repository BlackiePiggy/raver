import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';
import 'package:raver_platform/raver_platform.dart';

import '../data/organizer_api.dart';
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

  Future<void> _shareFestival(
    BuildContext context,
    WidgetRef ref,
    LearnFestival festival,
  ) async {
    final fallbackUrl = 'https://ravehub.top/festivals/${festival.id}';
    try {
      final payload = await ref
          .read(organizerApiProvider)
          .resolveShareLink(festival: festival, channel: 'system_share');
      final shareUrl = payload.shortUrl.isNotEmpty
          ? payload.shortUrl
          : (payload.url.isNotEmpty ? payload.url : fallbackUrl);
      await ShareService.shareUrl(shareUrl, subject: festival.name);
    } catch (_) {
      await ShareService.shareUrl(fallbackUrl, subject: festival.name);
    }
  }

  Future<void> _openExternalUrl(BuildContext context, String url) async {
    try {
      await UrlLauncherService.openExternalUrl(url);
    } catch (e) {
      if (!context.mounted) return;
      ToastBanner.show(
        context,
        message: e.toString(),
        type: ToastType.error,
      );
    }
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
                    style:
                        RaverTypography.title().copyWith(color: Colors.white),
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
          actions: [
            IconButton(
              tooltip: lt('分享', 'Share', '共有'),
              icon: const Icon(Icons.share_outlined),
              onPressed: () => _shareFestival(context, ref, festival),
            ),
          ],
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
                        Expanded(
                          child: Text(
                            '${festival.followerCount} ${lt("关注者", "followers", "フォロワー")}',
                            style: RaverTypography.body(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _FestivalFollowButton(
                          isFollowing: festival.isFollowing ?? false,
                          isLoading: state.isFollowLoading,
                          onPressed: () => ref
                              .read(
                                festivalDetailProvider(festivalId).notifier,
                              )
                              .toggleFollow(),
                        ),
                      ],
                    ),
                    if (state.followError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        state.followError!,
                        style: RaverTypography.caption().copyWith(
                          color: Colors.red.shade300,
                        ),
                      ),
                    ],
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
              if (festival.genres != null && festival.genres!.isNotEmpty) ...[
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
              if (festival.aliases != null && festival.aliases!.isNotEmpty) ...[
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
              if (festival.links != null && festival.links!.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  lt('链接', 'Links', 'リンク'),
                  style: RaverTypography.title(),
                ),
                const SizedBox(height: 8),
                ...festival.links!.map(
                  (link) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: InkWell(
                      onTap: link.url.isEmpty
                          ? null
                          : () => _openExternalUrl(context, link.url),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.link, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                link.label.isEmpty ? link.url : link.label,
                                style: RaverTypography.label().copyWith(
                                  color: RaverColors.accent(
                                    Theme.of(context).brightness,
                                  ),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (link.url.isNotEmpty)
                              const Icon(Icons.open_in_new_rounded, size: 16),
                          ],
                        ),
                      ),
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

class _FestivalFollowButton extends StatelessWidget {
  const _FestivalFollowButton({
    required this.isFollowing,
    required this.isLoading,
    required this.onPressed,
  });

  final bool isFollowing;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final accent = RaverColors.accent(Theme.of(context).brightness);
    return TextButton(
      onPressed: isLoading ? null : onPressed,
      style: TextButton.styleFrom(
        backgroundColor: isFollowing ? accent.withValues(alpha: 0.45) : accent,
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(64, 34),
        shape: const StadiumBorder(),
      ),
      child: isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              isFollowing
                  ? lt('已关注', 'Following', 'フォロー中')
                  : lt('关注', 'Follow', 'フォロー'),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
    );
  }
}
