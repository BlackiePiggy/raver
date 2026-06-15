import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';

/// Detail screen for a virtual asset.
class VirtualAssetDetailScreen extends StatelessWidget {
  const VirtualAssetDetailScreen({
    super.key,
    required this.definition,
    required this.isOwned,
    required this.isEquipped,
    this.onToggleEquip,
  });

  final VirtualAssetDefinition definition;
  final bool isOwned;
  final bool isEquipped;
  final void Function(bool equip)? onToggleEquip;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return Scaffold(
      appBar: AppBar(
        title: Text(definition.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Large preview
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: definition.previewImageUrl.isNotEmpty
                  ? RemoteCoverImage(
                      url: definition.previewImageUrl,
                      width: double.infinity,
                      height: 280,
                      fit: BoxFit.contain,
                    )
                  : Container(
                      width: double.infinity,
                      height: 280,
                      color: theme.cardBorder,
                      child: Icon(
                        Icons.diamond_outlined,
                        size: 80,
                        color: theme.secondaryText,
                      ),
                    ),
            ),
            const SizedBox(height: 20),

            // Name
            Text(
              definition.name,
              style: RaverTypography.headline(
                color: theme.primaryText,
              ).copyWith(fontSize: 22),
            ),
            const SizedBox(height: 8),

            // Type badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                definition.type.name.toUpperCase(),
                style: RaverTypography.caption(
                  color: theme.accent,
                  weight: FontWeight.w600,
                ),
              ),
            ),

            // Equipped badge
            if (isEquipped) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  lt('已装备', 'Equipped', '装備中'),
                  style: RaverTypography.caption(
                    color: Colors.green,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Action button
            if (isOwned && onToggleEquip != null)
              PrimaryButton(
                label: isEquipped
                    ? lt('卸下', 'Unequip', '装備解除')
                    : lt('装备', 'Equip', '装備する'),
                onPressed: () => onToggleEquip!(!isEquipped),
                isExpanded: true,
              )
            else if (!isOwned)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: theme.cardBorder,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(
                  child: Text(
                    lt('未拥有', 'Not Owned', '未所有'),
                    style: RaverTypography.label(
                      size: 15,
                      color: theme.secondaryText,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
