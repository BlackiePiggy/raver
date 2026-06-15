import 'package:flutter/material.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';

/// A shareable personality result card.
class PersonalityShareCard extends StatelessWidget {
  const PersonalityShareCard({
    super.key,
    required this.typeCode,
    required this.description,
    required this.theme,
  });

  final String typeCode;
  final String description;
  final RaverThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.accent,
            HSLColor.fromColor(theme.accent)
                .withLightness(
                  (HSLColor.fromColor(theme.accent).lightness - 0.15)
                      .clamp(0.0, 1.0),
                )
                .toColor(),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.accent.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'EDMTI',
            style: RaverTypography.caption(
              color: Colors.white.withValues(alpha: 0.7),
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            typeCode,
            style: RaverTypography.headline(
              color: Colors.white,
            ).copyWith(
              fontSize: 42,
              letterSpacing: 6,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: RaverTypography.body(
              size: 13,
              color: Colors.white.withValues(alpha: 0.85),
            ),
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.music_note,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.7)),
              const SizedBox(width: 4),
              Text(
                'RaveHub',
                style: RaverTypography.caption(
                  color: Colors.white.withValues(alpha: 0.7),
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  lt('关闭', 'Close', '閉じる'),
                  style: RaverTypography.label(
                    size: 14,
                    color: Colors.white,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
