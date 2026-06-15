import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';

/// QR code screen for the current user.
class QrCodeScreen extends StatelessWidget {
  const QrCodeScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    final profileUrl = 'https://ravehub.top/users/$userId';

    return Scaffold(
      appBar: AppBar(
        title: Text(lt('我的二维码', 'My QR Code', 'マイQRコード')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // QR placeholder (CustomPainter-based simple QR visualization)
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: CustomPaint(
                  painter: _SimpleQRPainter(data: profileUrl),
                  child: Center(
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: theme.accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.music_note,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                lt('扫码访问个人主页', 'Scan to visit profile',
                    'スキャンしてプロフィールにアクセス'),
                style:
                    RaverTypography.body(size: 14, color: theme.secondaryText),
              ),
              const SizedBox(height: 8),
              SelectableText(
                profileUrl,
                style: RaverTypography.caption(
                  color: theme.accent,
                  weight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      // TODO: Save to gallery
                    },
                    icon: const Icon(Icons.save_alt, size: 18),
                    label: Text(lt('保存', 'Save', '保存')),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: theme.cardBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: () {
                      // TODO: Share
                    },
                    icon: const Icon(Icons.share_outlined, size: 18),
                    label: Text(lt('分享', 'Share', 'シェア')),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: theme.cardBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Simple QR-like pattern painter using deterministic pattern from data.
class _SimpleQRPainter extends CustomPainter {
  _SimpleQRPainter({required this.data});

  final String data;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black;
    const padding = 16.0;
    const modules = 21;
    final moduleSize =
        (size.width - padding * 2) / modules;

    // Generate a deterministic pattern from data hash
    var hash = data.hashCode;
    for (var row = 0; row < modules; row++) {
      for (var col = 0; col < modules; col++) {
        // Always fill finder patterns (corners)
        final isFinderPattern =
            (row < 7 && col < 7) ||
            (row < 7 && col >= modules - 7) ||
            (row >= modules - 7 && col < 7);

        final isFilled = isFinderPattern
            ? _isFinderFilled(row, col, modules)
            : (hash = hash * 31 + row * col + 1) % 3 != 0;

        if (isFilled) {
          canvas.drawRect(
            Rect.fromLTWH(
              padding + col * moduleSize,
              padding + row * moduleSize,
              moduleSize - 0.5,
              moduleSize - 0.5,
            ),
            paint,
          );
        }
      }
    }
  }

  bool _isFinderFilled(int row, int col, int modules) {
    // Normalize to top-left corner
    final r = row >= modules - 7 ? row - (modules - 7) : row;
    final c = col >= modules - 7 ? col - (modules - 7) : col;

    // Outer ring
    if (r == 0 || r == 6 || c == 0 || c == 6) return true;
    // Inner solid
    if (r >= 2 && r <= 4 && c >= 2 && c <= 4) return true;
    return false;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
