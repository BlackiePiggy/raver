import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';

import '../_shared/profile_service_locator.dart';
import 'view_models/virtual_asset_view_model.dart';
import 'virtual_asset_detail_screen.dart';

/// Virtual assets screen with owned/shop tabs.
class VirtualAssetsScreen extends StatefulWidget {
  const VirtualAssetsScreen({super.key});

  @override
  State<VirtualAssetsScreen> createState() => _VirtualAssetsScreenState();
}

class _VirtualAssetsScreenState extends State<VirtualAssetsScreen> {
  late final VirtualAssetViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = VirtualAssetViewModel(
      api: ProfileServiceLocator.virtualAssetApi,
    );
    _viewModel.addListener(_rebuild);
    _viewModel.load();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _viewModel.removeListener(_rebuild);
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return Scaffold(
      appBar: AppBar(
        title: Text(lt('虚拟资产', 'Virtual Assets', '仮想アセット')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: RaverSegmentedControl(
              segments: [
                lt('已拥有', 'Owned', '所有'),
                lt('商店', 'Shop', 'ショップ'),
              ],
              selectedIndex: _viewModel.selectedTab,
              onChanged: _viewModel.setSelectedTab,
            ),
          ),
          Expanded(
            child: _viewModel.selectedTab == 0
                ? _buildOwnedGrid(theme)
                : _buildShopGrid(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnedGrid(RaverThemeData theme) {
    return LoadPhaseBuilder<List<UserVirtualAsset>>(
      phase: _viewModel.myPhase,
      onLoading: () =>
          const Center(child: CircularProgressIndicator.adaptive()),
      onEmpty: () => EmptyStateView(
        icon: Icons.diamond_outlined,
        title: lt('暂无资产', 'No Assets', 'アセットなし'),
        subtitle: lt('去商店获取资产吧', 'Get assets from the shop',
            'ショップでアセットを入手しましょう'),
      ),
      onFailure: (error) => ErrorStateView(
        title: lt('加载失败', 'Failed to Load', '読み込みに失敗しました'),
        error: error,
        onRetry: _viewModel.load,
        retryLabel: lt('重试', 'Retry', '再試行'),
      ),
      onSuccess: (_) => GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.85,
        ),
        itemCount: _viewModel.myAssets.length,
        itemBuilder: (context, index) {
          final asset = _viewModel.myAssets[index];
          // Find matching definition for preview
          final def = _viewModel.allAssets
              .where((d) => d.id == asset.definitionId)
              .firstOrNull;

          return _AssetGridItem(
            name: def?.name ?? asset.type.name,
            previewUrl: def?.previewImageUrl ?? '',
            isEquipped: asset.status == 'equipped',
            theme: theme,
            onTap: () {
              if (def != null) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => VirtualAssetDetailScreen(
                      definition: def,
                      isOwned: true,
                      isEquipped: asset.status == 'equipped',
                      onToggleEquip: (equip) =>
                          _viewModel.toggleEquip(def.id, equip),
                    ),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildShopGrid(RaverThemeData theme) {
    return LoadPhaseBuilder<List<VirtualAssetDefinition>>(
      phase: _viewModel.allPhase,
      onLoading: () =>
          const Center(child: CircularProgressIndicator.adaptive()),
      onEmpty: () => EmptyStateView(
        icon: Icons.storefront_outlined,
        title: lt('商店为空', 'Shop Empty', 'ショップは空です'),
      ),
      onFailure: (error) => ErrorStateView(
        title: lt('加载失败', 'Failed to Load', '読み込みに失敗しました'),
        error: error,
        onRetry: _viewModel.load,
        retryLabel: lt('重试', 'Retry', '再試行'),
      ),
      onSuccess: (_) => GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.85,
        ),
        itemCount: _viewModel.allAssets.length,
        itemBuilder: (context, index) {
          final def = _viewModel.allAssets[index];
          final isOwned =
              _viewModel.myAssets.any((a) => a.definitionId == def.id);

          return _AssetGridItem(
            name: def.name,
            previewUrl: def.previewImageUrl,
            isEquipped: false,
            isOwned: isOwned,
            theme: theme,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => VirtualAssetDetailScreen(
                    definition: def,
                    isOwned: isOwned,
                    isEquipped: false,
                    onToggleEquip: isOwned
                        ? (equip) =>
                            _viewModel.toggleEquip(def.id, equip)
                        : null,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _AssetGridItem extends StatelessWidget {
  const _AssetGridItem({
    required this.name,
    required this.previewUrl,
    required this.isEquipped,
    required this.theme,
    required this.onTap,
    this.isOwned = false,
  });

  final String name;
  final String previewUrl;
  final bool isEquipped;
  final bool isOwned;
  final RaverThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: theme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isEquipped ? theme.accent : theme.cardBorder,
            width: isEquipped ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                child: previewUrl.isNotEmpty
                    ? RemoteCoverImage(
                        url: previewUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      )
                    : Container(
                        color: theme.cardBorder,
                        child: Icon(Icons.diamond_outlined,
                            color: theme.secondaryText),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                children: [
                  Text(
                    name,
                    style: RaverTypography.caption(
                      color: theme.primaryText,
                      weight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isEquipped)
                    Text(
                      lt('已装备', 'Equipped', '装備中'),
                      style: RaverTypography.caption(
                        color: theme.accent,
                        weight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
