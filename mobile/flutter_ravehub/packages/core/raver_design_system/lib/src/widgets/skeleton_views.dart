import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/raver_theme.dart';

// =============================================================================
// Base skeleton primitives
// =============================================================================

/// A rectangular shimmer placeholder.
class SkeletonBox extends StatelessWidget {
  /// Creates a [SkeletonBox].
  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8,
  });

  final double? width;
  final double? height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: theme.cardBorder,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// A circular shimmer placeholder.
class SkeletonCircle extends StatelessWidget {
  /// Creates a [SkeletonCircle].
  const SkeletonCircle({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.cardBorder,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// A single-line text shimmer placeholder.
class SkeletonLine extends StatelessWidget {
  /// Creates a [SkeletonLine].
  const SkeletonLine({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius = 4,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: theme.cardBorder,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

// =============================================================================
// Shimmer wrapper
// =============================================================================

/// Wraps [child] in a Shimmer animation appropriate for the current theme.
class SkeletonShimmer extends StatelessWidget {
  /// Creates a [SkeletonShimmer].
  const SkeletonShimmer({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final baseColor = brightness == Brightness.light
        ? const Color(0xFFE0E0E0)
        : const Color(0xFF2A2A2A);
    final highlightColor = brightness == Brightness.light
        ? const Color(0xFFF5F5F5)
        : const Color(0xFF3A3A3A);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: child,
    );
  }
}

// =============================================================================
// Composed skeleton views
// =============================================================================

/// Skeleton for an event list screen.
class EventListSkeleton extends StatelessWidget {
  const EventListSkeleton({super.key, this.itemCount = 4});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (_, __) => _EventCardSkeleton(),
      ),
    );
  }
}

class _EventCardSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        SkeletonBox(width: double.infinity, height: 180, borderRadius: 16),
        SizedBox(height: 12),
        SkeletonLine(width: 200, height: 18),
        SizedBox(height: 8),
        SkeletonLine(width: 140, height: 14),
        SizedBox(height: 6),
        SkeletonLine(width: 100, height: 12),
      ],
    );
  }
}

/// Skeleton for an event detail screen.
class EventDetailSkeleton extends StatelessWidget {
  const EventDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            SkeletonBox(
              width: double.infinity,
              height: 240,
              borderRadius: 20,
            ),
            SizedBox(height: 20),
            SkeletonLine(width: 260, height: 24),
            SizedBox(height: 12),
            SkeletonLine(width: 180, height: 16),
            SizedBox(height: 8),
            SkeletonLine(width: 140, height: 14),
            SizedBox(height: 24),
            SkeletonLine(width: double.infinity, height: 14),
            SizedBox(height: 8),
            SkeletonLine(width: double.infinity, height: 14),
            SizedBox(height: 8),
            SkeletonLine(width: 200, height: 14),
            SizedBox(height: 24),
            Row(
              children: [
                SkeletonCircle(size: 44),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonLine(width: 120, height: 14),
                      SizedBox(height: 6),
                      SkeletonLine(width: 80, height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for a DJ list screen.
class DJListSkeleton extends StatelessWidget {
  const DJListSkeleton({super.key, this.itemCount = 6});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => Row(
          children: const [
            SkeletonCircle(size: 56),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLine(width: 140, height: 16),
                  SizedBox(height: 6),
                  SkeletonLine(width: 100, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for a feed / timeline screen.
class FeedSkeleton extends StatelessWidget {
  const FeedSkeleton({super.key, this.itemCount = 3});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(height: 20),
        itemBuilder: (_, __) => _PostCardSkeleton(),
      ),
    );
  }
}

class _PostCardSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            SkeletonCircle(size: 40),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLine(width: 120, height: 14),
                  SizedBox(height: 4),
                  SkeletonLine(width: 80, height: 12),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const SkeletonLine(width: double.infinity, height: 14),
        const SizedBox(height: 6),
        const SkeletonLine(width: 240, height: 14),
        const SizedBox(height: 12),
        const SkeletonBox(
          width: double.infinity,
          height: 200,
          borderRadius: 12,
        ),
        const SizedBox(height: 12),
        Row(
          children: const [
            SkeletonBox(width: 60, height: 24, borderRadius: 12),
            SizedBox(width: 16),
            SkeletonBox(width: 60, height: 24, borderRadius: 12),
            SizedBox(width: 16),
            SkeletonBox(width: 60, height: 24, borderRadius: 12),
          ],
        ),
      ],
    );
  }
}

/// Skeleton for a profile screen.
class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const SkeletonCircle(size: 80),
            const SizedBox(height: 16),
            const SkeletonLine(width: 140, height: 20),
            const SizedBox(height: 8),
            const SkeletonLine(width: 100, height: 14),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                _StatSkeleton(),
                SizedBox(width: 32),
                _StatSkeleton(),
                SizedBox(width: 32),
                _StatSkeleton(),
              ],
            ),
            const SizedBox(height: 24),
            const SkeletonBox(
              width: double.infinity,
              height: 44,
              borderRadius: 22,
            ),
            const SizedBox(height: 24),
            ...List.generate(
              3,
              (_) => const Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: _PostCardSkeleton(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatSkeleton extends StatelessWidget {
  const _StatSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SkeletonLine(width: 36, height: 18),
        SizedBox(height: 4),
        SkeletonLine(width: 50, height: 12),
      ],
    );
  }
}

/// Skeleton for a search results screen.
class SearchSkeleton extends StatelessWidget {
  const SearchSkeleton({super.key, this.itemCount = 8});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => Row(
          children: const [
            SkeletonBox(width: 60, height: 60, borderRadius: 12),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLine(width: 180, height: 16),
                  SizedBox(height: 6),
                  SkeletonLine(width: 120, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
