import 'package:flutter/material.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';

import 'view_models/set_editor_view_model.dart';

/// Full-screen tracklist editor.
///
/// Accepts a [SetEditorViewModel] and mutates its tracklist in-place.
/// The caller (SetEditorScreen) already listens to the view model, so the
/// parent UI stays in sync automatically.
class TracklistEditorScreen extends StatefulWidget {
  const TracklistEditorScreen({super.key, required this.viewModel});

  final SetEditorViewModel viewModel;

  @override
  State<TracklistEditorScreen> createState() => _TracklistEditorScreenState();
}

class _TracklistEditorScreenState extends State<TracklistEditorScreen> {
  SetEditorViewModel get _vm => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _vm.addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _vm.removeListener(_onChanged);
    super.dispose();
  }

  void _showTrackSheet({int? editIndex}) {
    final theme = context.raver;
    final existing = editIndex == null ? null : _vm.tracklist[editIndex];
    final titleCtrl = TextEditingController(
      text: existing?['title'] as String? ?? '',
    );
    final artistCtrl = TextEditingController(
      text: existing?['artist'] as String? ?? '',
    );
    final startCtrl = TextEditingController(
      text: _formatSeconds(existing?['startSecond'] as int? ?? 0),
    );
    final endCtrl = TextEditingController(
      text: existing?['endSecond'] is int
          ? _formatSeconds(existing!['endSecond'] as int)
          : '',
    );
    final spotifyCtrl = TextEditingController(
      text: existing?['spotifyUrl'] as String? ?? '',
    );
    final neteaseCtrl = TextEditingController(
      text: existing?['neteaseUrl'] as String? ?? '',
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              editIndex == null
                  ? lt('添加曲目', 'Add Track', 'トラック追加')
                  : lt('编辑曲目', 'Edit Track', 'トラック編集'),
              style: RaverTypography.title(color: theme.primaryText),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: titleCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: lt('曲名', 'Title', 'タイトル'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.cardBorder),
                ),
              ),
              style: TextStyle(color: theme.primaryText),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: artistCtrl,
              decoration: InputDecoration(
                labelText: lt('艺术家', 'Artist', 'アーティスト'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.cardBorder),
                ),
              ),
              style: TextStyle(color: theme.primaryText),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: startCtrl,
              decoration: InputDecoration(
                labelText: lt('开始时间', 'Start Time', '開始時間'),
                hintText: '0:00',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.cardBorder),
                ),
              ),
              keyboardType: TextInputType.datetime,
              style: TextStyle(color: theme.primaryText),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: endCtrl,
              decoration: InputDecoration(
                labelText: lt('结束时间（可选）', 'End Time (optional)', '終了時間（任意）'),
                hintText: '3:30',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.cardBorder),
                ),
              ),
              keyboardType: TextInputType.datetime,
              style: TextStyle(color: theme.primaryText),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: spotifyCtrl,
              decoration: InputDecoration(
                labelText: lt('Spotify 链接（可选）', 'Spotify link (optional)',
                    'Spotifyリンク（任意）'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.cardBorder),
                ),
              ),
              keyboardType: TextInputType.url,
              style: TextStyle(color: theme.primaryText),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: neteaseCtrl,
              decoration: InputDecoration(
                labelText: lt(
                    '网易云链接（可选）', 'NetEase link (optional)', 'NetEaseリンク（任意）'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.cardBorder),
                ),
              ),
              keyboardType: TextInputType.url,
              style: TextStyle(color: theme.primaryText),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: editIndex == null
                  ? lt('添加', 'Add', '追加')
                  : lt('保存', 'Save', '保存'),
              isExpanded: true,
              onPressed: () {
                final title = titleCtrl.text.trim();
                if (title.isEmpty) return;
                final payload = (
                  title: title,
                  artist: artistCtrl.text.trim(),
                  startSecond: _parseTimeInput(startCtrl.text.trim()),
                  endSecond: endCtrl.text.trim().isEmpty
                      ? null
                      : _parseTimeInput(endCtrl.text.trim()),
                  spotifyUrl: spotifyCtrl.text.trim(),
                  neteaseUrl: neteaseCtrl.text.trim(),
                );
                if (editIndex == null) {
                  _vm.addTrack(
                    title: payload.title,
                    artist: payload.artist,
                    startSecond: payload.startSecond,
                    endSecond: payload.endSecond,
                    spotifyUrl: payload.spotifyUrl,
                    neteaseUrl: payload.neteaseUrl,
                  );
                } else {
                  _vm.updateTrack(
                    editIndex,
                    title: payload.title,
                    artist: payload.artist,
                    startSecond: payload.startSecond,
                    endSecond: payload.endSecond,
                    spotifyUrl: payload.spotifyUrl,
                    neteaseUrl: payload.neteaseUrl,
                  );
                }
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  int _parseTimeInput(String input) {
    if (input.isEmpty) return 0;
    final parts = input.split(':');
    if (parts.length == 2) {
      return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
    }
    if (parts.length == 3) {
      return (int.tryParse(parts[0]) ?? 0) * 3600 +
          (int.tryParse(parts[1]) ?? 0) * 60 +
          (int.tryParse(parts[2]) ?? 0);
    }
    return int.tryParse(input) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    final tracks = _vm.tracklist;

    return Scaffold(
      backgroundColor: theme.background,
      appBar: RaverNavigationChrome(
        title: lt('编辑曲目', 'Edit Tracklist', '曲目編集'),
        trailing: TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            lt('完成', 'Done', '完了'),
            style: RaverTypography.label(
              size: 15,
              color: theme.accent,
              weight: FontWeight.w600,
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: theme.accent,
        onPressed: _showTrackSheet,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: tracks.isEmpty
          ? EmptyStateView(
              icon: Icons.queue_music,
              title: lt('还没有曲目', 'No tracks yet', '曲目なし'),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: tracks.length,
              onReorder: _vm.reorderTrack,
              itemBuilder: (context, index) {
                final track = tracks[index];
                return ListTile(
                  key: ValueKey('tracklist_$index'),
                  onTap: () => _showTrackSheet(editIndex: index),
                  leading: const Icon(Icons.drag_handle, size: 20),
                  title: Text(
                    track['title'] as String? ?? '',
                    style: TextStyle(fontSize: 15, color: theme.primaryText),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    [
                      track['artist'] as String? ?? '',
                      if ((track['spotifyUrl'] as String? ?? '').isNotEmpty)
                        'Spotify',
                      if ((track['neteaseUrl'] as String? ?? '').isNotEmpty)
                        'NetEase',
                    ].where((text) => text.isNotEmpty).join(' · '),
                    style: TextStyle(fontSize: 13, color: theme.secondaryText),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatSeconds(track['startSecond'] as int? ?? 0),
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: theme.secondaryText,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline,
                            size: 20, color: theme.secondaryText),
                        onPressed: () => _vm.removeTrack(index),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  String _formatSeconds(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '$m:${sec.toString().padLeft(2, '0')}';
  }
}
