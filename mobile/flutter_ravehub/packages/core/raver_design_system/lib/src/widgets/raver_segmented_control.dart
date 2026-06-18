import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raver_platform/raver_platform.dart';

import '../theme/raver_motion.dart';
import '../theme/raver_theme.dart';
import '../theme/raver_typography.dart';

/// A pill-shaped segmented control.
///
/// Mirrors the iOS design with an animated capsule indicator that slides
/// behind the selected segment.
class RaverSegmentedControl extends StatelessWidget {
  /// Creates a [RaverSegmentedControl].
  const RaverSegmentedControl({
    required this.segments,
    required this.selectedIndex,
    required this.onChanged,
    super.key,
    this.height = 36,
    this.borderRadius = 18,
  });

  /// Labels for each segment.
  final List<String> segments;

  /// Currently selected segment index.
  final int selectedIndex;

  /// Called when the user taps a different segment.
  final ValueChanged<int> onChanged;

  /// Overall height.
  final double height;

  /// Corner radius of the outer capsule and indicator.
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    void handleSelection(int index) {
      if (index != selectedIndex) {
        unawaited(HapticService.selectionClick());
      }
      onChanged(index);
    }

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: theme.cardBorder,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth = constraints.maxWidth / segments.length;

          return Stack(
            children: [
              // Animated selection indicator
              AnimatedPositioned(
                duration: RaverMotion.normal,
                curve: RaverMotion.curve,
                left: selectedIndex * segmentWidth + 2,
                top: 2,
                bottom: 2,
                width: segmentWidth - 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.card,
                    borderRadius: BorderRadius.circular(borderRadius - 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
              // Segment labels
              Row(
                children: List.generate(segments.length, (index) {
                  final isSelected = index == selectedIndex;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => handleSelection(index),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: RaverMotion.fast,
                          style: RaverTypography.label(
                            size: 13,
                            color: isSelected
                                ? theme.primaryText
                                : theme.secondaryText,
                            weight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                          child: Text(segments[index]),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}
