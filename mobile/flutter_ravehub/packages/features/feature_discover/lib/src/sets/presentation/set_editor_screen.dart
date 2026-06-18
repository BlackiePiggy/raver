import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';
import 'package:raver_platform/raver_platform.dart';

import '../../_shared/discover_service_locator.dart';
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
    this.openTracklistOnLoad = false,
  });

  final String? setId;
  final SetApi setApi;
  final bool openTracklistOnLoad;

  @override
  State<SetEditorScreen> createState() => _SetEditorScreenState();
}

class _SetEditorScreenState extends State<SetEditorScreen> {
  late final SetEditorViewModel _vm;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _djIdCtrl;
  late final TextEditingController _eventIdCtrl;
  late final TextEditingController _eventNameCtrl;
  late final TextEditingController _venueCtrl;
  late final TextEditingController _videoUrlCtrl;
  late final TextEditingController _thumbnailUrlCtrl;
  final _mediaPicker = MediaPickerService();
  bool _didAutoOpenTracklist = false;

  @override
  void initState() {
    super.initState();
    _vm = SetEditorViewModel(setApi: widget.setApi);
    _titleCtrl = TextEditingController();
    _descCtrl = TextEditingController();
    _djIdCtrl = TextEditingController();
    _eventIdCtrl = TextEditingController();
    _eventNameCtrl = TextEditingController();
    _venueCtrl = TextEditingController();
    _videoUrlCtrl = TextEditingController();
    _thumbnailUrlCtrl = TextEditingController();

    _vm.addListener(_onVmChanged);
    if (widget.setId != null) {
      _vm.loadSet(widget.setId!);
    } else if (widget.openTracklistOnLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openTracklistEditor();
      });
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
      _eventNameCtrl.text = _vm.eventName;
      _venueCtrl.text = _vm.venue;
      _videoUrlCtrl.text = _vm.videoUrl;
      _thumbnailUrlCtrl.text = _vm.thumbnailUrl;
    }

    if (widget.openTracklistOnLoad &&
        !_didAutoOpenTracklist &&
        !_vm.isLoading &&
        _vm.setId != null) {
      _didAutoOpenTracklist = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openTracklistEditor();
      });
    }

    _syncControllerIfEmpty(_titleCtrl, _vm.title);
    _syncControllerIfEmpty(_descCtrl, _vm.description);
    _syncControllerIfEmpty(_djIdCtrl, _vm.djId ?? '');
    _syncControllerIfEmpty(_eventIdCtrl, _vm.eventId ?? '');
    _syncControllerIfEmpty(_eventNameCtrl, _vm.eventName);
    _syncControllerIfEmpty(_thumbnailUrlCtrl, _vm.thumbnailUrl);

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
    _eventNameCtrl.dispose();
    _venueCtrl.dispose();
    _videoUrlCtrl.dispose();
    _thumbnailUrlCtrl.dispose();
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

  Future<void> _pickThumbnail() async {
    final path = await _mediaPicker.pickImageInstance();
    if (path != null) {
      _vm.uploadThumbnail(path);
    }
  }

  void _syncControllerIfEmpty(TextEditingController controller, String value) {
    if (controller.text.isEmpty && value.isNotEmpty) {
      controller.text = value;
    }
  }

  void _openTracklistEditor() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => TracklistEditorScreen(viewModel: _vm)),
    );
  }

  Future<void> _showDjBindingSheet() async {
    final selected = await showModalBottomSheet<WebDJ>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DjBindingSheet(initialQuery: _vm.djName),
    );
    if (selected == null) return;
    _vm.setDjSelection(id: selected.id, name: selected.name);
    _djIdCtrl.text = selected.id;
  }

  Future<void> _showEventBindingSheet() async {
    final selected = await showModalBottomSheet<WebEvent>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EventBindingSheet(initialQuery: _vm.eventName),
    );
    if (selected == null) return;
    _vm
      ..setEventId(selected.id)
      ..setEventName(selected.name);
    _eventIdCtrl.text = selected.id;
    _eventNameCtrl.text = selected.name;
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
                  // ---- Thumbnail upload ----
                  _buildLabel(theme, lt('封面', 'Cover', 'カバー')),
                  const SizedBox(height: 8),
                  _buildThumbnailCard(theme),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _thumbnailUrlCtrl,
                    onChanged: _vm.setThumbnailUrl,
                    textInputAction: TextInputAction.next,
                    decoration: _inputDecoration(
                      theme,
                      hintText: lt('封面 URL', 'Cover URL', 'カバーURL'),
                    ),
                    style: RaverTypography.body(
                      size: 16,
                      color: theme.primaryText,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ---- Title ----
                  _buildLabel(theme, lt('标题', 'Title', 'タイトル')),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleCtrl,
                    onChanged: _vm.setTitle,
                    decoration: _inputDecoration(
                      theme,
                      hintText: lt('输入标题', 'Enter title', 'タイトルを入力'),
                    ),
                    style: RaverTypography.body(
                      size: 16,
                      color: theme.primaryText,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ---- Description ----
                  _buildLabel(theme, lt('描述', 'Description', '説明')),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descCtrl,
                    onChanged: _vm.setDescription,
                    maxLines: 3,
                    decoration: _inputDecoration(
                      theme,
                      hintText: lt('添加描述', 'Add description', '説明を追加'),
                    ),
                    style: RaverTypography.body(
                      size: 16,
                      color: theme.primaryText,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ---- YouTube preview ----
                  _buildLabel(
                      theme, lt('YouTube 视频', 'YouTube Video', 'YouTube動画')),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _videoUrlCtrl,
                    onChanged: _vm.setVideoUrl,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _vm.previewVideo(),
                    autocorrect: false,
                    decoration: _inputDecoration(
                      theme,
                      hintText: lt(
                        '粘贴 YouTube 视频链接',
                        'Paste YouTube video link',
                        'YouTube動画リンクを貼り付け',
                      ),
                    ),
                    style: RaverTypography.body(
                      size: 16,
                      color: theme.primaryText,
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _vm.isPreviewingVideo || _vm.videoUrl.isEmpty
                        ? null
                        : _vm.previewVideo,
                    icon: _vm.isPreviewingVideo
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_circle_outline, size: 18),
                    label: Text(
                      _vm.isPreviewingVideo
                          ? lt('解析中...', 'Parsing...', '解析中...')
                          : lt('解析 YouTube 信息', 'Parse YouTube Info',
                              'YouTube情報を解析'),
                    ),
                  ),
                  if (_vm.previewTitle.isNotEmpty ||
                      _vm.videoAuthorName.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _buildYouTubePreviewCard(theme),
                  ],
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: _vm.rightsConfirmed,
                    onChanged: (value) =>
                        _vm.setRightsConfirmed(value ?? false),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      lt(
                        '我确认该 YouTube 视频来源合法且允许公开引用/嵌入。',
                        'I confirm this YouTube video source is lawful and allows public reference/embedding.',
                        'このYouTube動画の出典が合法で、公開参照/埋め込みが許可されていることを確認します。',
                      ),
                      style: RaverTypography.body(
                        size: 13,
                        color: theme.secondaryText,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ---- Recorded Date ----
                  _buildLabel(theme, lt('录制日期', 'Recorded Date', '録音日')),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
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
                                  : lt('选择日期', 'Select date', '日付を選択'),
                              style: RaverTypography.body(
                                size: 16,
                                color: _vm.recordedAt != null
                                    ? theme.primaryText
                                    : theme.secondaryText,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.calendar_today,
                            size: 18,
                            color: theme.secondaryText,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ---- Venue ----
                  _buildLabel(theme, lt('场地', 'Venue', '会場')),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _venueCtrl,
                    onChanged: _vm.setVenue,
                    decoration: _inputDecoration(
                      theme,
                      hintText: lt('输入场地', 'Enter venue', '会場を入力'),
                    ),
                    style: RaverTypography.body(
                      size: 16,
                      color: theme.primaryText,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ---- DJ ID ----
                  _buildLabel(theme, lt('关联 DJ', 'Linked DJ', '関連DJ')),
                  const SizedBox(height: 8),
                  _buildBindingSummary(
                    theme,
                    icon: Icons.person_search,
                    emptyText: lt(
                      '未关联 DJ（可留空）',
                      'No DJ linked (optional)',
                      'DJ未関連（任意）',
                    ),
                    valueText:
                        _vm.djName.isNotEmpty ? _vm.djName : (_vm.djId ?? ''),
                    actionText: lt('搜索并选择 DJ', 'Search DJ', 'DJを検索'),
                    onSearch: _showDjBindingSheet,
                    onClear: () {
                      _vm.setDjSelection(id: null, name: '');
                      _djIdCtrl.clear();
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _djIdCtrl,
                    onChanged: (v) {
                      _vm.setDjId(v.isEmpty ? null : v);
                      if (v.isEmpty) {
                        _vm.setDjSelection(id: null, name: '');
                      }
                    },
                    decoration: _inputDecoration(
                      theme,
                      hintText: lt('输入DJ ID', 'Enter DJ ID', 'DJ IDを入力'),
                    ),
                    style: RaverTypography.body(
                      size: 16,
                      color: theme.primaryText,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ---- Event ID ----
                  _buildLabel(theme, lt('关联活动', 'Linked Event', '関連イベント')),
                  const SizedBox(height: 8),
                  _buildBindingSummary(
                    theme,
                    icon: Icons.event_available,
                    emptyText: lt(
                      '未绑定活动',
                      'No event linked',
                      'イベント未紐付け',
                    ),
                    valueText: _vm.eventName.isNotEmpty
                        ? _vm.eventName
                        : (_vm.eventId ?? ''),
                    actionText: lt('搜索并选择活动', 'Search Event', 'イベントを検索'),
                    onSearch: _showEventBindingSheet,
                    onClear: () {
                      _vm
                        ..setEventId(null)
                        ..setEventName('');
                      _eventIdCtrl.clear();
                      _eventNameCtrl.clear();
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _eventIdCtrl,
                    onChanged: (v) => _vm.setEventId(v.isEmpty ? null : v),
                    decoration: _inputDecoration(
                      theme,
                      hintText: lt('输入活动 ID', 'Enter Event ID', 'イベントIDを入力'),
                    ),
                    style: RaverTypography.body(
                      size: 16,
                      color: theme.primaryText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _eventNameCtrl,
                    onChanged: _vm.setEventName,
                    decoration: _inputDecoration(
                      theme,
                      hintText: lt(
                        '输入活动名称',
                        'Enter event name',
                        'イベント名を入力',
                      ),
                    ),
                    style: RaverTypography.body(
                      size: 16,
                      color: theme.primaryText,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ---- Audio upload ----
                  _buildLabel(theme, lt('音频', 'Audio', 'オーディオ')),
                  const SizedBox(height: 8),
                  _buildMediaCard(
                    theme,
                    url: _vm.audioUrl,
                    icon: Icons.audiotrack,
                    placeholder: lt(
                      '点击上传音频',
                      'Tap to upload audio',
                      'タップして音声をアップロード',
                    ),
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
                    placeholder: lt(
                      '点击上传视频',
                      'Tap to upload video',
                      'タップして動画をアップロード',
                    ),
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
                            size: 14,
                            color: theme.secondaryText,
                          ),
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
                                fontSize: 14,
                                color: theme.primaryText,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              track['artist'] as String? ?? '',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.secondaryText,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _formatSeconds(
                                    track['startSecond'] as int? ?? 0,
                                  ),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                    color: theme.secondaryText,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.close,
                                    size: 18,
                                    color: theme.secondaryText,
                                  ),
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

  InputDecoration _inputDecoration(RaverThemeData theme, {String? hintText}) {
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

  Widget _buildBindingSummary(
    RaverThemeData theme, {
    required IconData icon,
    required String emptyText,
    required String valueText,
    required String actionText,
    required VoidCallback onSearch,
    required VoidCallback onClear,
  }) {
    final hasValue = valueText.trim().isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.card,
        border: Border.all(color: theme.cardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hasValue ? valueText : emptyText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: RaverTypography.body(
                size: 14,
                color: hasValue ? theme.primaryText : theme.secondaryText,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onSearch,
            child: Text(actionText),
          ),
          if (hasValue)
            IconButton(
              tooltip: lt('清除', 'Clear', 'クリア'),
              onPressed: onClear,
              icon: Icon(Icons.close, size: 18, color: theme.secondaryText),
            ),
        ],
      ),
    );
  }

  Widget _buildThumbnailCard(RaverThemeData theme) {
    final hasThumbnail = _vm.thumbnailUrl.isNotEmpty;
    return GestureDetector(
      onTap: _pickThumbnail,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: theme.card,
            border: Border.all(color: theme.cardBorder),
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasThumbnail)
                Image.network(
                  _vm.thumbnailUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _thumbnailFallback(theme),
                )
              else
                _thumbnailFallback(theme),
              Positioned(
                right: 12,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasThumbnail ? Icons.edit : Icons.add_photo_alternate,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        hasThumbnail
                            ? lt('更换封面', 'Change cover', 'カバー変更')
                            : lt('上传封面', 'Upload cover', 'カバーをアップロード'),
                        style: RaverTypography.label(
                          size: 12,
                          color: Colors.white,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildYouTubePreviewCard(RaverThemeData theme) {
    final title = _vm.previewTitle.isNotEmpty
        ? _vm.previewTitle
        : lt('已解析视频信息', 'Video metadata parsed', '動画情報を解析しました');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.card,
        border: Border.all(color: theme.cardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 112,
              height: 64,
              child: _vm.thumbnailUrl.isNotEmpty
                  ? Image.network(
                      _vm.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _previewThumbnailFallback(theme),
                    )
                  : _previewThumbnailFallback(theme),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: RaverTypography.label(
                    size: 13,
                    color: theme.primaryText,
                    weight: FontWeight.w600,
                  ),
                ),
                if (_vm.videoAuthorName.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    lt(
                      '发布人：${_vm.videoAuthorName}',
                      'Publisher: ${_vm.videoAuthorName}',
                      '投稿者: ${_vm.videoAuthorName}',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RaverTypography.body(
                      size: 12,
                      color: theme.secondaryText,
                    ),
                  ),
                ],
                if (_vm.thumbnailUrl.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    lt('封面已自动填充', 'Cover auto-filled', 'カバーを自動入力しました'),
                    style: RaverTypography.body(
                      size: 12,
                      color: theme.secondaryText,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewThumbnailFallback(RaverThemeData theme) {
    return Container(
      color: theme.background,
      child: Icon(Icons.play_circle_fill, color: theme.accent, size: 28),
    );
  }

  Widget _thumbnailFallback(RaverThemeData theme) {
    return Container(
      color: theme.card,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image, size: 36, color: theme.secondaryText),
          const SizedBox(height: 8),
          Text(
            lt('点击上传 Set 封面', 'Tap to upload set cover', 'Setカバーをアップロード'),
            style: RaverTypography.body(size: 14, color: theme.secondaryText),
          ),
        ],
      ),
    );
  }

  String _formatSeconds(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '$m:${sec.toString().padLeft(2, '0')}';
  }
}

class _DjBindingSheet extends StatefulWidget {
  const _DjBindingSheet({required this.initialQuery});

  final String initialQuery;

  @override
  State<_DjBindingSheet> createState() => _DjBindingSheetState();
}

class _DjBindingSheetState extends State<_DjBindingSheet> {
  late final TextEditingController _controller;
  List<WebDJ> _items = const [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _search();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final page = await DiscoverServiceLocator.djApi.fetchDJs(
        page: 1,
        limit: 20,
        search:
            _controller.text.trim().isEmpty ? null : _controller.text.trim(),
        sortBy: _controller.text.trim().isEmpty ? 'random' : 'relevance',
      );
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    return _BindingSheetFrame(
      title: lt('搜索并选择 DJ', 'Search and Select DJ', 'DJを検索して選択'),
      child: Column(
        children: [
          _BindingSearchField(
            controller: _controller,
            hintText: lt('输入 DJ 名称', 'Enter DJ name', 'DJ名を入力'),
            isLoading: _isLoading,
            onSubmitted: _search,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoading && _items.isEmpty
                ? const Center(child: CircularProgressIndicator.adaptive())
                : _errorMessage != null
                    ? _BindingError(message: _errorMessage!, onRetry: _search)
                    : _items.isEmpty
                        ? _BindingEmpty(
                            text: lt('没有找到 DJ', 'No DJs found', 'DJが見つかりません'),
                          )
                        : ListView.separated(
                            itemCount: _items.length,
                            separatorBuilder: (_, __) =>
                                Divider(color: theme.cardBorder, height: 1),
                            itemBuilder: (context, index) {
                              final dj = _items[index];
                              return ListTile(
                                onTap: () => Navigator.pop(context, dj),
                                leading: ClipOval(
                                  child: SizedBox(
                                    width: 40,
                                    height: 40,
                                    child: dj.avatarUrl.isNotEmpty
                                        ? RemoteCoverImage(
                                            url: dj.avatarUrl,
                                            fit: BoxFit.cover,
                                          )
                                        : _BindingAvatarFallback(
                                            text: dj.name,
                                          ),
                                  ),
                                ),
                                title: Text(
                                  dj.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: RaverTypography.label(
                                    size: 15,
                                    color: theme.primaryText,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  [
                                    if (dj.country.isNotEmpty) dj.country,
                                    if ((dj.genres ?? const []).isNotEmpty)
                                      (dj.genres ?? const [])
                                          .take(3)
                                          .join(', '),
                                  ].join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: RaverTypography.body(
                                    size: 12,
                                    color: theme.secondaryText,
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _EventBindingSheet extends StatefulWidget {
  const _EventBindingSheet({required this.initialQuery});

  final String initialQuery;

  @override
  State<_EventBindingSheet> createState() => _EventBindingSheetState();
}

class _EventBindingSheetState extends State<_EventBindingSheet> {
  late final TextEditingController _controller;
  List<WebEvent> _items = const [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _search();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final page = await DiscoverServiceLocator.eventsApi.fetchEvents(
        page: 1,
        limit: 20,
        search:
            _controller.text.trim().isEmpty ? null : _controller.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    return _BindingSheetFrame(
      title: lt('搜索并选择活动', 'Search and Select Event', 'イベントを検索して選択'),
      child: Column(
        children: [
          _BindingSearchField(
            controller: _controller,
            hintText: lt('输入活动名称', 'Enter event name', 'イベント名を入力'),
            isLoading: _isLoading,
            onSubmitted: _search,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoading && _items.isEmpty
                ? const Center(child: CircularProgressIndicator.adaptive())
                : _errorMessage != null
                    ? _BindingError(message: _errorMessage!, onRetry: _search)
                    : _items.isEmpty
                        ? _BindingEmpty(
                            text: lt(
                              '没有找到活动',
                              'No events found',
                              'イベントが見つかりません',
                            ),
                          )
                        : ListView.separated(
                            itemCount: _items.length,
                            separatorBuilder: (_, __) =>
                                Divider(color: theme.cardBorder, height: 1),
                            itemBuilder: (context, index) {
                              final event = _items[index];
                              return ListTile(
                                onTap: () => Navigator.pop(context, event),
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: event.coverImageUrl.isNotEmpty
                                        ? RemoteCoverImage(
                                            url: event.coverImageUrl,
                                            fit: BoxFit.cover,
                                          )
                                        : _BindingAvatarFallback(
                                            text: event.name,
                                          ),
                                  ),
                                ),
                                title: Text(
                                  event.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: RaverTypography.label(
                                    size: 15,
                                    color: theme.primaryText,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  [
                                    if (event.location?.city.isNotEmpty == true)
                                      event.location!.city,
                                    _shortDate(event.startDate),
                                  ].where((v) => v.isNotEmpty).join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: RaverTypography.body(
                                    size: 12,
                                    color: theme.secondaryText,
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  String _shortDate(String raw) {
    if (raw.length >= 10) return raw.substring(0, 10);
    return raw;
  }
}

class _BindingSheetFrame extends StatelessWidget {
  const _BindingSheetFrame({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      builder: (context, scrollController) {
        return Container(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            16 + MediaQuery.of(context).padding.bottom,
          ),
          decoration: BoxDecoration(
            color: theme.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Column(
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.cardBorder,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: RaverTypography.title(
                        size: 18,
                        color: theme.primaryText,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: theme.secondaryText),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: PrimaryScrollController(
                  controller: scrollController,
                  child: child,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BindingSearchField extends StatelessWidget {
  const _BindingSearchField({
    required this.controller,
    required this.hintText,
    required this.isLoading,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final String hintText;
  final bool isLoading;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => onSubmitted(),
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: IconButton(
          onPressed: isLoading ? null : onSubmitted,
          icon: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.arrow_forward),
        ),
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
    );
  }
}

class _BindingError extends StatelessWidget {
  const _BindingError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: theme.secondaryText, size: 36),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: RaverTypography.body(size: 13, color: theme.secondaryText),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: onRetry,
            child: Text(lt('重试', 'Retry', '再試行')),
          ),
        ],
      ),
    );
  }
}

class _BindingEmpty extends StatelessWidget {
  const _BindingEmpty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    return Center(
      child: Text(
        text,
        style: RaverTypography.body(size: 14, color: theme.secondaryText),
      ),
    );
  }
}

class _BindingAvatarFallback extends StatelessWidget {
  const _BindingAvatarFallback({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    final initial = text.trim().isEmpty ? '?' : text.trim()[0].toUpperCase();
    return Container(
      color: theme.card,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: RaverTypography.label(
          size: 16,
          color: theme.secondaryText,
          weight: FontWeight.w700,
        ),
      ),
    );
  }
}
