import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';
import 'package:raver_platform/raver_platform.dart';

import '../data/label_api.dart';
import 'label_view_model.dart';

class LabelDetailScreen extends ConsumerWidget {
  const LabelDetailScreen({super.key, required this.labelId});

  final String labelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(labelDetailProvider(labelId));

    return Scaffold(
      appBar: AppBar(
        title: Text(state.label?.name ?? lt('厂牌详情', 'Label Detail', 'レーベル詳細')),
        actions: [
          IconButton(
            tooltip: lt('分享', 'Share', '共有'),
            icon: const Icon(Icons.share_outlined),
            onPressed: state.label == null
                ? null
                : () => _shareLabel(context, ref, state.label!),
          ),
        ],
      ),
      body: _buildBody(context, ref, state),
    );
  }

  Future<void> _shareLabel(
    BuildContext context,
    WidgetRef ref,
    LearnLabel label,
  ) async {
    final fallbackUrl = 'https://ravehub.top/labels/${label.id}';
    try {
      final payload = await ref
          .read(labelApiProvider)
          .resolveShareLink(label: label, channel: 'system_share');
      final shareUrl = payload.shortUrl.isNotEmpty
          ? payload.shortUrl
          : (payload.url.isNotEmpty ? payload.url : fallbackUrl);
      await ShareService.shareUrl(shareUrl, subject: label.name);
    } catch (_) {
      await ShareService.shareUrl(fallbackUrl, subject: label.name);
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
      BuildContext context, WidgetRef ref, LabelDetailState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (state.error != null) {
      return ErrorStateView(
        title: lt('加载失败', 'Failed to load', 'ロードに失敗しました'),
        description: state.error,
        onRetry: () => ref.read(labelDetailProvider(labelId).notifier).retry(),
      );
    }

    final label = state.label;
    if (label == null) {
      return EmptyStateView(
        icon: Icons.album_outlined,
        title: lt('厂牌未找到', 'Label not found', 'レーベルが見つかりません'),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: CachedNetworkImage(
              imageUrl: label.imageUrl,
              width: 120,
              height: 120,
              fit: BoxFit.cover,
              placeholder: (_, __) => const SkeletonShimmer(
                child: SkeletonBox(width: 120, height: 120, borderRadius: 20),
              ),
              errorWidget: (_, __, ___) => Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: RaverColors.card(Theme.of(context).brightness),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.album, size: 56),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          label.name,
          style: RaverTypography.headline(),
          textAlign: TextAlign.center,
        ),
        if (label.slug.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            '@${label.slug}',
            style: RaverTypography.caption(),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 24),
        Text(
          lt('简介', 'About', '概要'),
          style: RaverTypography.title(),
        ),
        const SizedBox(height: 8),
        Text(label.introduction, style: RaverTypography.body()),
        if (label.genres != null && label.genres!.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            lt('流派', 'Genres', 'ジャンル'),
            style: RaverTypography.title(),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: label.genres!.map((g) => Chip(label: Text(g))).toList(),
          ),
        ],
        if (label.founders != null && label.founders!.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            lt('创始人', 'Founders', '創設者'),
            style: RaverTypography.title(),
          ),
          const SizedBox(height: 8),
          ...label.founders!.map(
            (founder) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: founder.djId.isEmpty
                    ? null
                    : () => context.push('/djs/${founder.djId}'),
                borderRadius: BorderRadius.circular(12),
                child: GlassCard(
                  padding: const EdgeInsets.all(12),
                  borderRadius: 12,
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child:
                            Text(founder.name, style: RaverTypography.label()),
                      ),
                      if (founder.djId.isNotEmpty)
                        const Icon(Icons.chevron_right_rounded, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
        if (label.websiteUrl.isNotEmpty) ...[
          const SizedBox(height: 24),
          InkWell(
            onTap: () => _openExternalUrl(context, label.websiteUrl),
            borderRadius: BorderRadius.circular(12),
            child: GlassCard(
              padding: const EdgeInsets.all(12),
              borderRadius: 12,
              child: Row(
                children: [
                  const Icon(Icons.language, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label.websiteUrl,
                      style: RaverTypography.label().copyWith(
                        color: RaverColors.accent(
                          Theme.of(context).brightness,
                        ),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.open_in_new_rounded, size: 18),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
