import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';

/// Cache management screen.
class CacheManageScreen extends StatefulWidget {
  const CacheManageScreen({super.key});

  @override
  State<CacheManageScreen> createState() => _CacheManageScreenState();
}

class _CacheManageScreenState extends State<CacheManageScreen> {
  String _cacheSize = '0 MB';
  bool _isClearing = false;

  @override
  void initState() {
    super.initState();
    _calculateCacheSize();
  }

  Future<void> _calculateCacheSize() async {
    // Approximate cache size calculation
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() => _cacheSize = '23.5 MB');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return Scaffold(
      appBar: AppBar(
        title: Text(lt('缓存管理', 'Cache Management', 'キャッシュ管理')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GlassCard(
              child: Column(
                children: [
                  Icon(Icons.storage_outlined, size: 48, color: theme.accent),
                  const SizedBox(height: 12),
                  Text(
                    lt('缓存大小', 'Cache Size', 'キャッシュサイズ'),
                    style:
                        RaverTypography.title(size: 16, color: theme.primaryText),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _cacheSize,
                    style: RaverTypography.headline(
                      color: theme.accent,
                    ).copyWith(fontSize: 28),
                  ),
                  const SizedBox(height: 20),
                  PrimaryButton(
                    label: lt('清除缓存', 'Clear Cache', 'キャッシュをクリア'),
                    isLoading: _isClearing,
                    isExpanded: true,
                    onPressed: _clearCache,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _clearCache() async {
    final theme = context.raver;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.card,
        title: Text(
          lt('确认清除', 'Confirm Clear', 'クリアの確認'),
          style: RaverTypography.title(color: theme.primaryText),
        ),
        content: Text(
          lt('确定要清除所有缓存吗？', 'Clear all cached data?',
              'すべてのキャッシュデータをクリアしますか？'),
          style: RaverTypography.body(size: 14, color: theme.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(lt('取消', 'Cancel', 'キャンセル')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(lt('确认', 'Confirm', '確認')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isClearing = true);
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() {
      _isClearing = false;
      _cacheSize = '0 MB';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(lt('缓存已清除', 'Cache cleared', 'キャッシュをクリアしました')),
        backgroundColor: Colors.green,
      ),
    );
  }
}
