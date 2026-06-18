import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_models/raver_models.dart';

class OrganizerCard extends StatelessWidget {
  const OrganizerCard({
    super.key,
    required this.festival,
    required this.onTap,
  });

  final LearnFestival festival;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage =
        festival.imageUrls != null && festival.imageUrls!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasImage)
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                child: CachedNetworkImage(
                  imageUrl: festival.imageUrls!.first,
                  height: 160,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => const SkeletonShimmer(
                    child: SkeletonBox(height: 160, borderRadius: 0),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    height: 160,
                    color: RaverColors.card(Theme.of(context).brightness),
                    child: const Icon(Icons.festival, size: 48),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    festival.name,
                    style: RaverTypography.title(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: RaverColors.secondaryText(
                            Theme.of(context).brightness),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${festival.city}, ${festival.country}',
                        style: RaverTypography.caption(),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.people_outline,
                        size: 14,
                        color: RaverColors.secondaryText(
                            Theme.of(context).brightness),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatFollowers(festival.followerCount),
                        style: RaverTypography.caption(),
                      ),
                    ],
                  ),
                  if (festival.genres != null &&
                      festival.genres!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: festival.genres!
                          .take(3)
                          .map((g) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: RaverColors.accent(
                                          Theme.of(context).brightness)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  g,
                                  style: RaverTypography.caption().copyWith(
                                    color: RaverColors.accent(
                                        Theme.of(context).brightness),
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatFollowers(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}

class OrganizerListSkeleton extends StatelessWidget {
  const OrganizerListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(height: 160, borderRadius: 20),
              const SizedBox(height: 12),
              SkeletonLine(width: 200),
              const SizedBox(height: 8),
              SkeletonLine(width: 140),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
