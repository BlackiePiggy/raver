import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_platform/raver_platform.dart';

/// QR code screen for the current user.
class QrCodeScreen extends StatefulWidget {
  const QrCodeScreen({super.key, required this.userId});

  final String userId;

  @override
  State<QrCodeScreen> createState() => _QrCodeScreenState();
}

class _QrCodeScreenState extends State<QrCodeScreen> {
  final _qrKey = GlobalKey();
  bool _isSaving = false;
  bool _isSharing = false;

  String get _profileUrl => 'https://ravehub.top/users/${widget.userId}';

  Future<void> _copyLink() async {
    await ClipboardService.copyText(_profileUrl);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(lt('已复制链接', 'Link copied', 'リンクをコピーしました'))),
    );
  }

  Future<void> _shareQrImage() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      final bytes = await _captureQrCard();
      await ShareService.shareBytes(
        bytes,
        fileName: 'ravehub-profile-${widget.userId}.png',
        mimeType: 'image/png',
        text: _profileUrl,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lt(
              '分享二维码失败，请稍后重试',
              'Failed to share QR code. Please try again.',
              'QRコードの共有に失敗しました。もう一度お試しください。',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _saveQrImage() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final bytes = await _captureQrCard();
      await GallerySaveService.saveImageBytes(
        bytes,
        name: 'ravehub-profile-${widget.userId}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lt('已保存到相册', 'Saved to gallery', 'ギャラリーに保存しました')),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lt(
              '保存二维码失败，请检查相册权限',
              'Failed to save QR code. Please check photo permissions.',
              'QRコードの保存に失敗しました。写真の権限を確認してください。',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<Uint8List> _captureQrCard() async {
    final boundary =
        _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('QR card is not ready');
    }
    final image = await boundary.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null) {
      throw StateError('Failed to encode QR card');
    }
    return byteData.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    final canSaveToGallery = GallerySaveService.isSupported;

    return Scaffold(
      appBar: AppBar(
        title: Text(lt('我的二维码', 'My QR Code', 'マイQRコード')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RepaintBoundary(
                key: _qrKey,
                child: _QrShareCard(profileUrl: _profileUrl, theme: theme),
              ),
              const SizedBox(height: 20),
              Text(
                lt('扫码访问个人主页', 'Scan to visit profile', 'スキャンしてプロフィールにアクセス'),
                style: RaverTypography.body(
                  size: 14,
                  color: theme.secondaryText,
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(
                _profileUrl,
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
                    onPressed: !canSaveToGallery || _isSaving
                        ? null
                        : _saveQrImage,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_alt, size: 18),
                    label: Text(
                      canSaveToGallery
                          ? lt('保存', 'Save', '保存')
                          : lt('仅 App 可保存', 'App Only', 'アプリのみ'),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: theme.cardBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: _isSharing ? null : _shareQrImage,
                    icon: _isSharing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.ios_share, size: 18),
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
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _copyLink,
                icon: const Icon(Icons.link, size: 18),
                label: Text(lt('复制链接', 'Copy Link', 'リンクをコピー')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QrShareCard extends StatelessWidget {
  const _QrShareCard({required this.profileUrl, required this.theme});

  final String profileUrl;
  final RaverThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              QrImageView(
                data: profileUrl,
                version: QrVersions.auto,
                size: 220,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Colors.black,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Colors.black,
                ),
                errorCorrectionLevel: QrErrorCorrectLevel.H,
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.accent,
                  border: Border.all(color: Colors.white, width: 4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.music_note,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'RaveHub',
            style: RaverTypography.label(
              size: 16,
              color: Colors.black,
              weight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            profileUrl,
            style: RaverTypography.caption(
              color: Colors.black54,
              weight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
