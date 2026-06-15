import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';

import '../data/dj_api.dart';

enum _DjImportMode { spotify, discogs, manual }

/// Screen providing three ways to add a DJ: import from Spotify, import from
/// Discogs, or create manually.
class DjImportScreen extends StatefulWidget {
  const DjImportScreen({super.key, required this.djApi});

  final DjApi djApi;

  @override
  State<DjImportScreen> createState() => _DjImportScreenState();
}

class _DjImportScreenState extends State<DjImportScreen> {
  _DjImportMode _mode = _DjImportMode.spotify;
  final _spotifyController = TextEditingController();
  final _discogsController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _spotifyController.dispose();
    _discogsController.dispose();
    super.dispose();
  }

  Future<void> _importFromSpotify() async {
    final input = _spotifyController.text.trim();
    if (input.isEmpty) return;

    // Extract artist ID from URL if needed
    String artistId = input;
    final uri = Uri.tryParse(input);
    if (uri != null && uri.host.contains('spotify')) {
      final segments = uri.pathSegments;
      final artistIdx = segments.indexOf('artist');
      if (artistIdx >= 0 && artistIdx + 1 < segments.length) {
        artistId = segments[artistIdx + 1];
      }
    }

    setState(() => _isLoading = true);
    try {
      final dj =
          await widget.djApi.importFromSpotify(spotifyArtistId: artistId);
      if (mounted) {
        context.push('/djs/${dj.id}');
      }
    } catch (e) {
      if (mounted) {
        ToastBanner.show(
          context,
          message: e.toString(),
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _importFromDiscogs() async {
    final input = _discogsController.text.trim();
    if (input.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final dj =
          await widget.djApi.importFromDiscogs(discogsArtistId: input);
      if (mounted) {
        context.push('/djs/${dj.id}');
      }
    } catch (e) {
      if (mounted) {
        ToastBanner.show(
          context,
          message: e.toString(),
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return Scaffold(
      backgroundColor: theme.background,
      appBar: RaverNavigationChrome(
        title: lt('导入DJ', 'Import DJ', 'DJインポート'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RaverSegmentedControl(
              segments: [
                'Spotify',
                'Discogs',
                lt('手动', 'Manual', '手動'),
              ],
              selectedIndex: _mode.index,
              onChanged: (index) {
                setState(() => _mode = _DjImportMode.values[index]);
              },
            ),
            const SizedBox(height: 24),
            Expanded(child: _buildContent(theme)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(RaverThemeData theme) {
    switch (_mode) {
      case _DjImportMode.spotify:
        return _buildSpotifyTab(theme);
      case _DjImportMode.discogs:
        return _buildDiscogsTab(theme);
      case _DjImportMode.manual:
        return _buildManualTab(theme);
    }
  }

  Widget _buildSpotifyTab(RaverThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _spotifyController,
          decoration: InputDecoration(
            labelText: lt(
              'Spotify 艺术家 ID 或 URL',
              'Spotify Artist ID or URL',
              'Spotify アーティスト ID または URL',
            ),
            hintText: 'e.g. 3WGpXCj9YhhfX11TToZcXP',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.cardBorder),
            ),
          ),
          style: RaverTypography.body(size: 16, color: theme.primaryText),
        ),
        const SizedBox(height: 8),
        Text(
          lt(
            '打开 Spotify 应用，进入艺术家主页，点击分享 > 复制链接即可获取 ID。',
            'Open the Spotify app, go to the artist page, tap Share > Copy Link to get the ID.',
            'Spotifyアプリを開き、アーティストページに移動し、共有 > リンクをコピーでIDを取得できます。',
          ),
          style: RaverTypography.caption(color: theme.secondaryText),
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: lt('搜索', 'Search', '検索'),
          icon: Icons.search,
          isLoading: _isLoading && _mode == _DjImportMode.spotify,
          isExpanded: true,
          onPressed: _spotifyController.text.trim().isEmpty
              ? null
              : _importFromSpotify,
        ),
      ],
    );
  }

  Widget _buildDiscogsTab(RaverThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _discogsController,
          decoration: InputDecoration(
            labelText: lt(
              'Discogs 艺术家 ID',
              'Discogs Artist ID',
              'Discogs アーティスト ID',
            ),
            hintText: 'e.g. 12345',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.cardBorder),
            ),
          ),
          style: RaverTypography.body(size: 16, color: theme.primaryText),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: lt('导入', 'Import', 'インポート'),
          icon: Icons.download,
          isLoading: _isLoading && _mode == _DjImportMode.discogs,
          isExpanded: true,
          onPressed: _discogsController.text.trim().isEmpty
              ? null
              : _importFromDiscogs,
        ),
      ],
    );
  }

  Widget _buildManualTab(RaverThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Text(
          lt(
            '手动创建一个新的 DJ 档案。',
            'Create a new DJ profile manually.',
            '新しいDJプロフィールを手動で作成します。',
          ),
          style: RaverTypography.body(size: 15, color: theme.secondaryText),
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: lt('创建DJ', 'Create DJ Manually', 'DJを手動作成'),
          icon: Icons.add,
          isExpanded: true,
          onPressed: () => context.push('/djs/editor'),
        ),
      ],
    );
  }
}
