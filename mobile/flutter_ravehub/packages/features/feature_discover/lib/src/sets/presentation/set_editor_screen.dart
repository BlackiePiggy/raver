import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_platform/raver_platform.dart';

import '../data/set_api.dart';
import 'tracklist_editor_screen.dart';
import 'view_models/set_editor_view_model.dart';

/// Create or edit a DJ Set.
///
/// Pass [setId] to load an existing set for editing. When `null` the screen
/// operates in creation mode.
class SetEditorScreen extends StatefulWidget {
  const SetEditorScreen({
    super.key,
    this.setId,
    required this.setApi,
  });

  final String? setId;
  final SetApi setApi;

  @override
  State<SetEditorScreen> createState() => _SetEditorScreenState();
}

class _SetEditorScreenState extends State<SetEditorScreen> {
  late final SetEditorViewModel _vm;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _djIdCtrl;
  late final TextEditingController _eventIdCtrl;
  final _mediaPicker = MediaPickerService();

  @override
  void initState() {
    super.initState();
    _vm = SetEditorViewModel(setApi: widget.setApi);
    _titleCtrl = TextEditingController();
    _descCtrl = TextEditingController();
    _djIdCtrl = TextEditingController();
    _eventIdCtrl = TextEditingController();

    _vm.addListener(_onVmChanged);
    if (widget.setId != null) {
      _vm.loadSet(widget.setId!);
    }
  }

  void _onVmChanged() {
    if (!mounted) return;
    setState(() {});

    // Populate controllers when set data arrives.
    if (_vm.setId != null && _titleCtrl.text.isEmpty && _vm.title.isNotEmpty) {
      _titleCtrl.text = _vm.title;
      _descCtrl.text = _vm.description;
      _djIdCtrl.text = _vm.djId ?? '';
      _eventIdCtrl.text = _vm.eventId ?? '';
    }

    if (_vm.isSaved) {
      ToastBanner.show(
        context,
        message: lt('保存成功', 'Saved successfully', '保存しました'),
        type: ToastType.success,
      );
      context.pop();
    }

    if (_vm.errorMessage != null && !_vm.isLoading) {
      ToastBanner.show(
        context,
        message: _vm.errorMessage!,
        type: ToastType.error,
      );
    }
  }

  @override
  void dispose() {
    _vm.removeListener(_onVmChanged);
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _djIdCtrl.dispose();
    _eventIdCtrl.dispose();
    _vm.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _vm.recordedAt ?? now,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (picked != null) {
      _vm.setRecordedAt(picked);
    }
  }

  Future<void> _pickAudio() async {
    final path = await _mediaPicker.pickVideo();
    if (path != null) {
      _vm.uploadAudio(path);
    }
  }

  Future<void> _pickVideo() async {
    final path = await _mediaPicker.pickVideo();
    if (path != null) {
      _vm.uploadVideo(path);
    }
  }

  void _openTracklistEditor() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => TracklistEditorScreen(viewModel: _vm),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    final isEdit = widget.setId != null;

    return Scaffold(
      backgroundColor: theme.background,
      appBar: RaverNavigationChrome(
        title: lt('编辑Set', 'Edit Set', 'セット編集'),
        trailing: TextButton(
          onPressed: _vm.isLoading ? null : _vm.save,
          child: _vm.isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  lt('保存', 'Save', '保存'),
                  style: RaverTypography.label(
                    size: 15,
                    color: theme.accent,
                    weight: FontWeight.w600,
                  ),
                ),
        ),
      ),
      body: _vm.isLoading && isEdit && _vm.title.isEmpty
          ? const Center(child: CircularProgressIndicator.adaptive())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ---- Title ----
                  _buildLabel(
                      theme, lt('标题', 'Title', 'タイトル')),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleCtrl,
                    onChanged: _vm.setTitle,
                    decoration: _inputDecoration(
                      theme,
                      hintText: lt('输入标题', 'Enter title', 'タイトルを入力'),
                    ),
                    style: RaverTypography.body(
                        size: 16, color: theme.primaryText),
                  ),
                  const SizedBox(height: 20),

                  // ---- Description ----
                  _buildLabel(
                      theme, lt('描述', 'Description', '説明')),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descCtrl,
                    onChanged: _vm.setDescription,
                    maxLines: 3,
                    decoration: _inputDecoration(
                      theme,
                      hintText:
                          lt('添加描述', 'Add description', '説明を追加'),
                    ),
                    style: RaverTypography.body(
                        size: 16, color: theme.primaryText),
                  ),
                  const SizedBox(height: 20),

                  // ---- Recorded Date ----
                  _buildLabel(
                      theme, lt('录制日期', 'Recorded Date', '録音日')),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.cardBorder),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _vm.recordedAt != null
                                  ? '${_vm.recordedAt!.year}-${_vm.recordedAt!.month.toString().padLeft(2, '0')}-${_vm.recordedAt!.day.toString().padLeft(2, '0')}'
                                  : lt('选择日期', 'Select date',
                                      '日付を選択'),
                              style: RaverTypography.body(
                                size: 16,
                                color: _vm.recordedAt != null
                                    ? theme.primaryText
                                    : theme.secondaryText,
                              ),
                            ),
                          ),
                          Icon(Icons.calendar_today,
                              size: 18, color: theme.secondaryText),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ---- DJ ID ----
                  _buildLabel(
                      theme, lt('关联DJ ID', 'DJ ID', 'DJ ID')),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _djIdCtrl,
                    onChanged: (v) => _vm.setDjId(v.isEmpty ? null : v),
                    decoration: _inputDecoration(
                      theme,
                      hintText: lt(
                          '输入DJ ID', 'Enter DJ ID', 'DJ IDを入力'),
                    ),
                    style: RaverTypography.body(
                        size: 16, color: theme.primaryText),
                  ),
                  const SizedBox(height: 20),

                  // ---- Event ID ----
                  _buildLabel(theme,
                      lt('关联活动 ID', 'Event ID', 'イベントID')),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _eventIdCtrl,
                    onChanged: (v) => _vm.setEventId(v.isEmpty ? null : v),
                    decoration: _inputDecoration(
                      theme,
                      hintText: lt('输入活动 ID', 'Enter Event ID',
                          'イベントIDを入力'),
                    ),
                    style: RaverTypography.body(
                        size: 16, color: theme.primaryText),
                  ),
                  const SizedBox(height: 20),

                  // ---- Audio upload ----
                  _buildLabel(theme, lt('音频', 'Audio', 'オーディオ')),
                  const SizedBox(height: 8),
                  _buildMediaCard(
                    theme,
                    url: _vm.audioUrl,
                    icon: Icons.audiotrack,
                    placeholder: lt('点击上传音频', 'Tap to upload audio',
                        'タップして音声をアップロード'),
                    onTap: _pickAudio,
                  ),
                  const SizedBox(height: 16),

                  // ---- Video upload ----
                  _buildLabel(theme, lt('视频', 'Video', 'ビデオ')),
                  const SizedBox(height: 8),
                  _buildMediaCard(
                    theme,
                    url: _vm.videoUrl,
                    icon: Icons.videocam,
                    placeholder: lt('点击上传视频', 'Tap to upload video',
                        'タップして動画をアップロード'),
                    onTap: _pickVideo,
                  ),
                  const SizedBox(height: 24),

                  // ---- Tracklist preview ----
                  _buildLabel(
                    theme,
                    '${lt("曲目列表", "Tracklist", "トラックリスト")} (${_vm.tracklist.length})',
                  ),
                  const SizedBox(height: 8),
                  if (_vm.tracklist.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.cardBorder),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          lt('还没有曲目', 'No tracks yet', '曲目なし'),
                          style: RaverTypography.body(
                              size: 14, color: theme.secondaryText),
                        ),
                      ),
                    )
                  else
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ReorderableListView.builder(
                        shrinkWrap: true,
                        itemCount: _vm.tracklist.length,
                        onReorder: _vm.reorderTrack,
                        itemBuilder: (context, index) {
                          final track = _vm.tracklist[index];
                          return ListTile(
                            key: ValueKey('track_$index'),
                            leading: const Icon(Icons.drag_handle, size: 20),
                            title: Text(
                              track['title'] as String? ?? '',
                              style: TextStyle(
                                  fontSize: 14, color: theme.primaryText),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              track['artist'] as String? ?? '',
                              style: TextStyle(
                                  fontSize: 12, color: theme.secondaryText),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _formatSeconds(
                                      track['startSecond'] as int? ?? 0),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                    color: theme.secondaryText,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.close,
                                      size: 18, color: theme.secondaryText),
                                  onPressed: () => _vm.removeTrack(index),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: lt('编辑曲目', 'Edit Tracklist', '曲目編集'),
                    icon: Icons.queue_music,
                    isExpanded: true,
                    onPressed: _openTracklistEditor,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  // ---- helpers ----

  Widget _buildLabel(RaverThemeData theme, String text) {
    return Text(
      text,
      style: RaverTypography.label(
        size: 14,
        color: theme.secondaryText,
        weight: FontWeight.w500,
      ),
    );
  }

  InputDecoration _inputDecoration(
    RaverThemeData theme, {
    String? hintText,
  }) {
    return InputDecoration(
      hintText: hintText,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.cardBorder),
      ),
    );
  }

  Widget _buildMediaCard(
    RaverThemeData theme, {
    required String url,
    required IconData icon,
    required String placeholder,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: theme.card,
          border: Border.all(color: theme.cardBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 24, color: theme.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                url.isNotEmpty
                    ? Uri.tryParse(url)?.pathSegments.last ?? url
                    : placeholder,
                style: RaverTypography.body(
                  size: 14,
                  color:
                      url.isNotEmpty ? theme.primaryText : theme.secondaryText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (url.isNotEmpty)
              Icon(Icons.check_circle, size: 18, color: theme.accent),
          ],
        ),
      ),
    );
  }

  String _formatSeconds(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '$m:${sec.toString().padLeft(2, '0')}';
  }
}
