import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
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
  String _memoryCacheSize = '0 B';
  int _memoryCacheEntries = 0;
  String _diskCacheStatus = '';
  bool _isClearing = false;

  @override
  void initState() {
    super.initState();
    _refreshCacheStats();
  }

  void _refreshCacheStats() {
    final imageCache = PaintingBinding.instance.imageCache;
    setState(() {
      _memoryCacheEntries = imageCache.currentSize;
      _memoryCacheSize = _formatBytes(imageCache.currentSizeBytes);
      _diskCacheStatus = lt(
        '图片磁盘缓存由系统缓存管理器维护',
        'Image disk cache is managed by the system cache manager',
        '画像ディスクキャッシュはシステムキャッシュマネージャーで管理されています',
      );
    });
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
                    lt('缓存状态', 'Cache Status', 'キャッシュ状態'),
                    style: RaverTypography.title(
                      size: 16,
                      color: theme.primaryText,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _CacheMetricRow(
                    icon: Icons.memory_rounded,
                    label: lt('内存图片缓存', 'Memory image cache', 'メモリ画像キャッシュ'),
                    value: '$_memoryCacheSize / $_memoryCacheEntries',
                    helper: lt(
                      '当前 Flutter 图片缓存占用',
                      'Current Flutter image cache usage',
                      '現在の Flutter 画像キャッシュ使用量',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _CacheMetricRow(
                    icon: Icons.folder_copy_outlined,
                    label: lt('磁盘图片缓存', 'Disk image cache', 'ディスク画像キャッシュ'),
                    value: lt('可清理', 'Clearable', 'クリア可能'),
                    helper: _diskCacheStatus,
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
          lt('确定要清除所有缓存吗？', 'Clear all cached data?', 'すべてのキャッシュデータをクリアしますか？'),
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
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    await DefaultCacheManager().emptyCache();
    if (!mounted) return;
    setState(() {
      _isClearing = false;
      _memoryCacheSize = '0 B';
      _memoryCacheEntries = 0;
      _diskCacheStatus = lt(
        '图片磁盘缓存已清理',
        'Image disk cache cleared',
        '画像ディスクキャッシュをクリアしました',
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(lt('缓存已清除', 'Cache cleared', 'キャッシュをクリアしました')),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(1)} GB';
  }
}

class _CacheMetricRow extends StatelessWidget {
  const _CacheMetricRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.helper,
  });

  final IconData icon;
  final String label;
  final String value;
  final String helper;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: theme.accent, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: RaverTypography.title(
                  size: 14,
                  color: theme.primaryText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                helper,
                style: RaverTypography.body(
                  size: 12,
                  color: theme.secondaryText,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: RaverTypography.title(size: 13, color: theme.accent),
          textAlign: TextAlign.right,
        ),
      ],
    );
  }
}
