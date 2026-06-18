import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:ravehub/di/app_providers.dart';
import 'package:ravehub/router/share_link_resolver.dart';

/// Camera scanner for RaveHub QR codes and universal links.
class DeepLinkScanScreen extends ConsumerStatefulWidget {
  const DeepLinkScanScreen({super.key});

  @override
  ConsumerState<DeepLinkScanScreen> createState() => _DeepLinkScanScreenState();
}

class _DeepLinkScanScreenState extends ConsumerState<DeepLinkScanScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );

  bool _isResolving = false;
  Object? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isResolving) return;
    final rawValue = capture.barcodes
        .map((barcode) => barcode.rawValue?.trim())
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .firstOrNull;
    if (rawValue == null) return;

    final uri = Uri.tryParse(rawValue);
    if (uri == null || !uri.hasScheme) {
      _showScanError(
        lt(
          '无法识别这个二维码',
          'This QR code is not a supported link.',
          'このQRコードは対応していないリンクです。',
        ),
      );
      return;
    }

    setState(() {
      _isResolving = true;
      _error = null;
    });
    await _controller.stop();

    try {
      final resolver = ShareLinkResolver(ref.read(dioProvider));
      final path = await resolver.resolve(uri, channel: 'qr_scan');
      if (!mounted) return;
      if (path == null || path.isEmpty) {
        throw StateError('Scanned link did not resolve to an app route.');
      }
      context.go(path);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isResolving = false;
        _error = error;
      });
      await _controller.start();
    }
  }

  void _showScanError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    final error = _error;
    return Scaffold(
      appBar: AppBar(
        title: Text(lt('扫一扫', 'Scan', 'スキャン')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _ScannerErrorView(
              error: error,
              onRetry: () => _controller.start(),
            ),
          ),
          const _ScannerFrameOverlay(),
          Positioned(
            left: 20,
            right: 20,
            bottom: 34,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isResolving)
                    _ScannerStatusPill(
                      icon: const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      label: lt(
                        '正在打开链接',
                        'Opening link',
                        'リンクを開いています',
                      ),
                    )
                  else if (error != null)
                    _ScannerStatusPill(
                      icon: const Icon(Icons.error_outline, size: 18),
                      label: lt(
                        '打开失败，请重新扫码',
                        'Unable to open. Scan again.',
                        '開けませんでした。もう一度スキャンしてください。',
                      ),
                    )
                  else
                    _ScannerStatusPill(
                      icon: const Icon(Icons.qr_code_scanner, size: 18),
                      label: lt(
                        '对准 RaveHub 二维码或分享链接',
                        'Point at a RaveHub QR code or share link',
                        'RaveHubのQRコードまたは共有リンクに合わせてください',
                      ),
                    ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton.filledTonal(
                        tooltip: lt('手电筒', 'Torch', 'ライト'),
                        onPressed: _controller.toggleTorch,
                        icon: Icon(Icons.flash_on, color: theme.primaryText),
                      ),
                      const SizedBox(width: 16),
                      IconButton.filledTonal(
                        tooltip: lt('切换摄像头', 'Switch Camera', 'カメラ切替'),
                        onPressed: _controller.switchCamera,
                        icon: Icon(Icons.cameraswitch, color: theme.primaryText),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerFrameOverlay extends StatelessWidget {
  const _ScannerFrameOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 250,
          height: 250,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
      ),
    );
  }
}

class _ScannerStatusPill extends StatelessWidget {
  const _ScannerStatusPill({required this.icon, required this.label});

  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.64),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: RaverTypography.caption(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScannerErrorView extends StatelessWidget {
  const _ScannerErrorView({required this.error, required this.onRetry});

  final MobileScannerException error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ErrorStateView(
          title: lt(
            '相机不可用',
            'Camera Unavailable',
            'カメラを使用できません',
          ),
          error: error,
          onRetry: onRetry,
          retryLabel: lt('重试', 'Retry', '再試行'),
        ),
      ),
    );
  }
}
