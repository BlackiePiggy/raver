import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';
import 'package:raver_platform/raver_platform.dart';

import '../../../_shared/circle_service_locator.dart';
import '../../data/circle_id_api.dart';

class CircleIdShareSheet extends StatefulWidget {
  const CircleIdShareSheet({
    super.key,
    required this.card,
    required this.onShared,
  });

  final CircleIdCard card;
  final ValueChanged<Post> onShared;

  @override
  State<CircleIdShareSheet> createState() => _CircleIdShareSheetState();
}

class _CircleIdShareSheetState extends State<CircleIdShareSheet> {
  ShareLinkPayload? _payload;
  bool _isLoading = true;
  Object? _error;
  String? _busyAction;

  @override
  void initState() {
    super.initState();
    _loadInitialLink();
  }

  Future<void> _loadInitialLink() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await _resolveLink(channel: 'share_panel');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e;
      });
    }
  }

  Future<ShareLinkPayload> _resolveLink({required String channel}) async {
    final card = widget.card;
    final subtitle = [
      if (card.contributorName.isNotEmpty) card.contributorName,
      ...card.djs.map((dj) => dj.name),
      if (card.event != null) card.event!.name,
    ].take(3).join(' · ');
    final canonicalUrl = 'https://ravehub.top/circle/id/${card.id}';
    final payload = await CircleServiceLocator.feedRepository.resolveShareLink(
      targetType: 'circle_id',
      targetId: card.id,
      title: card.songName,
      subtitle: subtitle,
      imageUrl: card.event?.coverImageUrl,
      canonicalUrl: canonicalUrl,
      deepLink: 'raver://circle/id/${card.id}',
      fallbackUrl: canonicalUrl,
      channel: channel,
    );
    if (mounted) {
      setState(() {
        _payload = payload;
        _isLoading = false;
        _error = null;
      });
    }
    return payload;
  }

  Future<void> _copyLink() async {
    await _runAction('copy', () async {
      final payload = _payload ?? await _resolveLink(channel: 'copy_link');
      final post = await CircleServiceLocator.feedRepository.sharePost(
        postId: widget.card.id,
        channel: 'copy_link',
      );
      widget.onShared(post);
      await ClipboardService.copyText(payload.shortUrl);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lt('已复制链接', 'Link copied', 'リンクをコピーしました'))),
      );
    });
  }

  Future<void> _shareNative() async {
    await _runAction('native', () async {
      final payload = _payload ?? await _resolveLink(channel: 'system_share');
      final post = await CircleServiceLocator.feedRepository.sharePost(
        postId: widget.card.id,
        channel: 'system_share',
      );
      widget.onShared(post);
      await ShareService.shareUrl(
        payload.shortUrl,
        subject: widget.card.songName,
      );
    });
  }

  Future<void> _showQrCode() async {
    await _runAction('qr', () async {
      final payload = _payload ?? await _resolveLink(channel: 'view_qr');
      if (!mounted) return;
      await _showShareAsset(
        title: lt('分享二维码', 'Share QR Code', '共有QRコード'),
        imageUrl: payload.qrCodeUrl,
        subtitle: payload.shortUrl,
        emptyMessage: lt(
          '二维码暂未生成，请稍后再试。',
          'The QR code is not ready yet. Please try again later.',
          'QRコードはまだ準備できていません。時間をおいて再試行してください。',
        ),
      );
    });
  }

  Future<void> _showPoster() async {
    await _runAction('poster', () async {
      final payload = _payload ?? await _resolveLink(channel: 'view_poster');
      if (!mounted) return;
      await _showShareAsset(
        title: lt('分享海报', 'Share Poster', '海報を共有'),
        imageUrl: payload.posterUrl,
        subtitle: payload.shortUrl,
        fallbackFileName: 'ravehub-circle-id-${widget.card.id}.png',
        fallbackImageBytes: () => _captureLocalPoster(payload.shortUrl),
        emptyMessage: lt(
          '分享海报生成失败，请复制链接分享。',
          'Poster generation failed. Please copy the link instead.',
          '共有海報の生成に失敗しました。リンクをコピーして共有してください。',
        ),
      );
    });
  }

  Future<Uint8List> _captureLocalPoster(String shortUrl) {
    final card = widget.card;
    final subtitle = [
      if (card.contributorName.isNotEmpty) card.contributorName,
      ...card.djs.map((dj) => dj.name),
      if (card.event != null) card.event!.name,
    ].take(3).join(' · ');
    return ShareCardGenerator.capture(
      card: _CircleIdLocalShareCard(
        title: card.songName,
        subtitle: subtitle.isEmpty
            ? lt('RaveHub 音乐识别', 'RaveHub Track ID', 'RaveHub Track ID')
            : subtitle,
        eventName: card.event?.name ?? '',
        shortUrl: shortUrl,
      ),
      size: const Size(390, 520),
    );
  }

  Future<void> _runAction(String action, Future<void> Function() run) async {
    if (_busyAction != null) return;
    setState(() => _busyAction = action);
    try {
      await run();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lt(
              '操作失败，请稍后重试',
              'Action failed. Please try again.',
              '操作に失敗しました。もう一度お試しください。',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busyAction = null);
    }
  }

  Future<void> _showShareAsset({
    required String title,
    required String imageUrl,
    required String subtitle,
    required String emptyMessage,
    Future<Uint8List> Function()? fallbackImageBytes,
    String fallbackFileName = 'ravehub-circle-id-share.png',
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ShareAssetSheet(
        title: title,
        imageUrl: imageUrl,
        subtitle: subtitle,
        emptyMessage: emptyMessage,
        fallbackImageBytes: fallbackImageBytes,
        fallbackFileName: fallbackFileName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    final card = widget.card;

    return Container(
      decoration: BoxDecoration(
        color: theme.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                lt('分享 ID', 'Share ID', 'IDを共有'),
                style: RaverTypography.title(
                  size: 20,
                  color: theme.primaryText,
                ),
              ),
              const SizedBox(height: 14),
              _SharePreviewCard(card: card),
              const SizedBox(height: 14),
              if (_isLoading)
                const Center(child: CircularProgressIndicator.adaptive())
              else if (_error != null)
                ErrorStateView(
                  title: lt(
                    '分享链接加载失败',
                    'Share Link Failed',
                    '共有リンクの読み込みに失敗しました',
                  ),
                  error: _error,
                  onRetry: _loadInitialLink,
                  retryLabel: lt('重试', 'Retry', '再試行'),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: _ShareActionButton(
                        icon: Icons.link,
                        label: lt('复制链接', 'Copy Link', 'リンクをコピー'),
                        isBusy: _busyAction == 'copy',
                        onTap: _copyLink,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ShareActionButton(
                        icon: Icons.ios_share,
                        label: lt('更多', 'More', 'その他'),
                        isBusy: _busyAction == 'native',
                        onTap: _shareNative,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ShareActionButton(
                        icon: Icons.qr_code_2,
                        label: lt('二维码', 'QR Code', 'QRコード'),
                        isBusy: _busyAction == 'qr',
                        onTap: _showQrCode,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ShareActionButton(
                        icon: Icons.photo_outlined,
                        label: lt('海报', 'Poster', '海報'),
                        isBusy: _busyAction == 'poster',
                        onTap: _showPoster,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _SharePreviewCard extends StatelessWidget {
  const _SharePreviewCard({required this.card});

  final CircleIdCard card;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    final subtitle = [
      if (card.contributorName.isNotEmpty) card.contributorName,
      ...card.djs.map((dj) => dj.name),
      if (card.event != null) card.event!.name,
    ].take(3).join(' · ');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.cardBorder),
      ),
      child: Row(
        children: [
          _AssetThumb(url: card.event?.coverImageUrl ?? '', size: 54),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.songName,
                  style: RaverTypography.label(
                    size: 15,
                    color: theme.primaryText,
                    weight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: RaverTypography.caption(color: theme.secondaryText),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'ID',
              style: RaverTypography.caption(
                color: theme.accent,
                weight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleIdLocalShareCard extends StatelessWidget {
  const _CircleIdLocalShareCard({
    required this.title,
    required this.subtitle,
    required this.eventName,
    required this.shortUrl,
  });

  final String title;
  final String subtitle;
  final String eventName;
  final String shortUrl;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF8B5CF6);
    const cyan = Color(0xFF36D6F6);
    return Container(
      width: 390,
      height: 520,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF11131F), Color(0xFF20142E), Color(0xFF05050A)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.44), width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: accent.withValues(alpha: 0.38)),
                ),
                child: const Icon(Icons.graphic_eq, color: cyan, size: 28),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'RAVEHUB ID',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              height: 1.08,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.76),
              fontSize: 15,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (eventName.trim().isNotEmpty) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                const Icon(Icons.event_available, color: accent, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    eventName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Text(
              shortUrl,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.28,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'RAVEHUB',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.38),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 3.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareActionButton extends StatelessWidget {
  const _ShareActionButton({
    required this.icon,
    required this.label,
    required this.isBusy,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isBusy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    final isEnabled = onTap != null && !isBusy;
    return InkWell(
      onTap: isEnabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 78,
        decoration: BoxDecoration(
          color: theme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.cardBorder),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isBusy)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(icon, color: theme.accent, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: RaverTypography.caption(
                color: isEnabled ? theme.primaryText : theme.secondaryText,
                weight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareAssetSheet extends StatefulWidget {
  const _ShareAssetSheet({
    required this.title,
    required this.imageUrl,
    required this.subtitle,
    required this.emptyMessage,
    required this.fallbackFileName,
    this.fallbackImageBytes,
  });

  final String title;
  final String imageUrl;
  final String subtitle;
  final String emptyMessage;
  final Future<Uint8List> Function()? fallbackImageBytes;
  final String fallbackFileName;

  @override
  State<_ShareAssetSheet> createState() => _ShareAssetSheetState();
}

class _ShareAssetSheetState extends State<_ShareAssetSheet> {
  String? _busyAction;
  late Future<Uint8List>? _fallbackBytesFuture;

  bool get _hasImage => widget.imageUrl.isNotEmpty;
  bool get _hasFallback => widget.fallbackImageBytes != null;

  @override
  void initState() {
    super.initState();
    _fallbackBytesFuture = _hasImage ? null : widget.fallbackImageBytes?.call();
  }

  Future<Uint8List> _downloadImageBytes() async {
    if (!_hasImage) {
      final fallback = _fallbackBytesFuture;
      if (fallback != null) return fallback;
      throw StateError(
          'Share asset URL is empty and no fallback is available.');
    }
    final response = await CircleServiceLocator.dio.get<List<int>>(
      widget.imageUrl,
      options: Options(responseType: ResponseType.bytes),
    );
    final data = response.data;
    if (data == null || data.isEmpty) {
      throw StateError('Share asset download returned no bytes.');
    }
    return Uint8List.fromList(data);
  }

  String get _fileName {
    final uri = Uri.tryParse(widget.imageUrl);
    final lastSegment =
        uri?.pathSegments.isNotEmpty == true ? uri!.pathSegments.last : '';
    final sanitized = lastSegment.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    if (sanitized.isNotEmpty && sanitized.contains('.')) return sanitized;
    return widget.fallbackFileName;
  }

  String get _mimeType {
    final lowerName = _fileName.toLowerCase();
    if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lowerName.endsWith('.webp')) return 'image/webp';
    return 'image/png';
  }

  Future<void> _runAssetAction(
    String action,
    Future<void> Function() run,
  ) async {
    if (_busyAction != null) return;
    setState(() => _busyAction = action);
    try {
      await run();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lt(
              '操作失败，请稍后重试',
              'Action failed. Please try again.',
              '操作に失敗しました。もう一度お試しください。',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busyAction = null);
    }
  }

  Future<void> _saveImage() {
    return _runAssetAction('save', () async {
      final bytes = await _downloadImageBytes();
      await GallerySaveService.saveImageBytes(bytes, name: _fileName);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lt('已保存到相册', 'Saved to gallery', 'ギャラリーに保存しました')),
        ),
      );
    });
  }

  Future<void> _shareImage() {
    return _runAssetAction('share', () async {
      final bytes = await _downloadImageBytes();
      await ShareService.shareBytes(
        bytes,
        fileName: _fileName,
        mimeType: _mimeType,
        text: widget.subtitle,
      );
    });
  }

  Future<void> _copyLink() {
    return _runAssetAction('copy', () async {
      await ClipboardService.copyText(widget.subtitle);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lt('已复制链接', 'Link copied', 'リンクをコピーしました'))),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    return Container(
      decoration: BoxDecoration(
        color: theme.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                widget.title,
                style: RaverTypography.title(
                  size: 20,
                  color: theme.primaryText,
                ),
              ),
              const SizedBox(height: 14),
              if (!_hasImage)
                _FallbackShareAssetPreview(
                  bytesFuture: _fallbackBytesFuture,
                  emptyMessage: widget.emptyMessage,
                )
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: CachedNetworkImage(
                    imageUrl: widget.imageUrl,
                    width: double.infinity,
                    height: 360,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const SizedBox(
                      height: 220,
                      child: Center(
                        child: CircularProgressIndicator.adaptive(),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        widget.emptyMessage,
                        textAlign: TextAlign.center,
                        style: RaverTypography.body(color: theme.secondaryText),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                widget.subtitle,
                textAlign: TextAlign.center,
                style: RaverTypography.caption(color: theme.secondaryText),
              ),
              if (_hasImage || _hasFallback) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _ShareActionButton(
                        icon: Icons.save_alt,
                        label: GallerySaveService.isSupported
                            ? lt('保存', 'Save', '保存')
                            : lt('仅 App 可保存', 'App Only', 'アプリのみ'),
                        isBusy: _busyAction == 'save',
                        onTap:
                            GallerySaveService.isSupported ? _saveImage : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ShareActionButton(
                        icon: Icons.ios_share,
                        label: lt('分享', 'Share', 'シェア'),
                        isBusy: _busyAction == 'share',
                        onTap: _shareImage,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ShareActionButton(
                        icon: Icons.link,
                        label: lt('复制链接', 'Copy Link', 'リンクをコピー'),
                        isBusy: _busyAction == 'copy',
                        onTap: _copyLink,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FallbackShareAssetPreview extends StatelessWidget {
  const _FallbackShareAssetPreview({
    required this.bytesFuture,
    required this.emptyMessage,
  });

  final Future<Uint8List>? bytesFuture;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    final future = bytesFuture;
    if (future == null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          emptyMessage,
          textAlign: TextAlign.center,
          style: RaverTypography.body(color: theme.secondaryText),
        ),
      );
    }
    return FutureBuilder<Uint8List>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator.adaptive()),
          );
        }
        final bytes = snapshot.data;
        if (snapshot.hasError || bytes == null || bytes.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              emptyMessage,
              textAlign: TextAlign.center,
              style: RaverTypography.body(color: theme.secondaryText),
            ),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.memory(
            bytes,
            width: double.infinity,
            height: 360,
            fit: BoxFit.contain,
          ),
        );
      },
    );
  }
}

class _AssetThumb extends StatelessWidget {
  const _AssetThumb({required this.url, required this.size});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.cardBorder,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.music_note, color: theme.secondaryText),
    );
    if (url.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => fallback,
      ),
    );
  }
}
