import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:ravehub/di/app_providers.dart';
import 'package:ravehub/router/share_link_resolver.dart';

/// Resolves `/s/{code}` share links through the live BFF before navigating.
class ShareLinkRedirectScreen extends ConsumerStatefulWidget {
  const ShareLinkRedirectScreen({super.key, required this.uri});

  final Uri uri;

  @override
  ConsumerState<ShareLinkRedirectScreen> createState() =>
      _ShareLinkRedirectScreenState();
}

class _ShareLinkRedirectScreenState
    extends ConsumerState<ShareLinkRedirectScreen> {
  Object? _error;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    setState(() => _error = null);
    try {
      final resolver = ShareLinkResolver(ref.read(dioProvider));
      final path = await resolver.resolve(widget.uri);
      if (!mounted) return;
      if (path == null || path.isEmpty) {
        throw StateError('Share link did not resolve to an app route.');
      }
      context.go(path);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(lt('分享链接', 'Share Link', '共有リンク')),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ErrorStateView(
              title: lt(
                '分享链接打开失败',
                'Unable to Open Share Link',
                '共有リンクを開けません',
              ),
              error: error,
              onRetry: _resolve,
              retryLabel: lt('重试', 'Retry', '再試行'),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Center(
        child: CircularProgressIndicator.adaptive(
          semanticsLabel: lt('正在打开分享链接', 'Opening share link', '共有リンクを開いています'),
        ),
      ),
    );
  }
}
