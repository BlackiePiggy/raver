import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';
import 'package:raver_platform/raver_platform.dart';

import 'view_models/compose_post_view_model.dart';
import 'widgets/local_media_preview.dart';
import '../../_shared/circle_service_locator.dart';

/// Screen for composing and publishing a new social post.
class ComposePostScreen extends StatefulWidget {
  const ComposePostScreen({super.key});

  @override
  State<ComposePostScreen> createState() => _ComposePostScreenState();
}

class _ComposePostScreenState extends State<ComposePostScreen> {
  late final ComposePostViewModel _viewModel;
  final MediaPickerService _mediaPicker = MediaPickerService();
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _viewModel = ComposePostViewModel(
      repository: CircleServiceLocator.feedRepository,
    );
    _viewModel.addListener(_rebuild);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _viewModel.removeListener(_rebuild);
    _textController.dispose();
    _locationController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final success = await _viewModel.submit();
    if (success && mounted) {
      context.pop(true);
    }
  }

  Future<void> _pickImages() async {
    final remaining = _viewModel.maxImages - _viewModel.imagePaths.length;
    if (remaining <= 0) return;
    final paths = await _mediaPicker.pickMultipleImages(maxCount: remaining);
    if (paths.isNotEmpty) _viewModel.addImages(paths);
  }

  Future<void> _pickVideo() async {
    final path = await _mediaPicker.pickVideo();
    if (path != null && path.isNotEmpty) _viewModel.setVideo(path);
  }

  Future<void> _showEventPicker() async {
    final selected = await showModalBottomSheet<WebEvent>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: context.raver.background,
      builder: (_) => _ComposeEventPickerSheet(
        onSearch: (search) =>
            CircleServiceLocator.circleIdRepository.searchEvents(
          search: search,
        ),
      ),
    );
    if (selected != null) {
      _viewModel.setEvent(selected.id, selected.name);
    }
  }

  Future<void> _showLocationSheet() async {
    _locationController.text = _viewModel.location ?? '';
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: context.raver.background,
      builder: (context) {
        final theme = context.raver;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lt('添加位置', 'Add Location', '場所を追加'),
                style: RaverTypography.title(
                  size: 18,
                  color: theme.primaryText,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _locationController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: lt('输入场地或城市', 'Venue or city', '会場または都市'),
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  filled: true,
                  fillColor: theme.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: theme.cardBorder),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: lt('完成', 'Done', '完了'),
                  onPressed: () {
                    _viewModel.setLocation(_locationController.text.trim());
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.background,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: theme.primaryText),
          onPressed: () => context.pop(),
        ),
        title: Text(
          lt('发布动态', 'New Post', '新しい投稿'),
          style: RaverTypography.title(size: 17, color: theme.primaryText),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: _viewModel.canSubmit ? _submit : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _viewModel.canSubmit
                      ? theme.accent
                      : theme.accent.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: _viewModel.phase == ComposePostPhase.uploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        lt('发布', 'Post', '投稿'),
                        style: RaverTypography.label(
                          size: 14,
                          color: Colors.white,
                          weight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ],
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlassCard(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: theme.accent.withValues(alpha: 0.18),
                        child: Icon(
                          Icons.person_rounded,
                          color: theme.accent,
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          lt('发布到动态', 'Post to Feed', 'フィードに投稿'),
                          style: RaverTypography.label(
                            size: 14,
                            color: theme.primaryText,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.public_rounded,
                        size: 17,
                        color: theme.secondaryText,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _textController,
                    onChanged: _viewModel.setText,
                    decoration: InputDecoration(
                      hintText: lt(
                        '分享你的故事...',
                        'Share your story...',
                        'あなたのストーリーをシェア...',
                      ),
                      hintStyle: RaverTypography.body(
                        size: 17,
                        color: theme.secondaryText,
                      ),
                      border: InputBorder.none,
                      counterText:
                          '${_viewModel.text.length}/${_viewModel.maxTextLength}',
                      counterStyle: RaverTypography.caption(
                        color: _viewModel.text.length > _viewModel.maxTextLength
                            ? Colors.red
                            : theme.secondaryText,
                      ),
                    ),
                    style: RaverTypography.body(
                      size: 17,
                      color: theme.primaryText,
                    ),
                    maxLines: 9,
                    minLines: 5,
                    maxLength: _viewModel.maxTextLength,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_viewModel.imagePaths.isNotEmpty) ...[
              _buildImagePreviewGrid(theme),
              const SizedBox(height: 16),
            ],
            if (_viewModel.videoPath != null) ...[
              _buildVideoPreview(theme),
              const SizedBox(height: 16),
            ],
            if (_viewModel.eventName != null ||
                _viewModel.location != null) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_viewModel.eventName != null) _buildEventTag(theme),
                  if (_viewModel.location != null) _buildLocationTag(theme),
                ],
              ),
              const SizedBox(height: 16),
            ],
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: _buildToolbar(theme),
            ),
            if (_viewModel.errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.20)),
                ),
                child: Text(
                  _viewModel.errorMessage!,
                  style: RaverTypography.caption(color: Colors.red),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreviewGrid(RaverThemeData theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ..._viewModel.imagePaths.asMap().entries.map(
              (entry) => _buildImageThumb(entry.key, entry.value, theme),
            ),
        if (_viewModel.imagePaths.length < _viewModel.maxImages)
          _buildAddImageButton(theme),
      ],
    );
  }

  Widget _buildImageThumb(int index, String path, RaverThemeData theme) {
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: theme.card,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.cardBorder),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: buildLocalImagePreview(
                path: path,
                fit: BoxFit.cover,
                errorWidget: Icon(
                  Icons.image,
                  color: theme.secondaryText,
                  size: 32,
                ),
              ),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: () => _viewModel.removeImage(index),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddImageButton(RaverThemeData theme) {
    return GestureDetector(
      onTap: _pickImages,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: theme.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.cardBorder, style: BorderStyle.solid),
        ),
        child: Icon(Icons.add_photo_alternate, color: theme.secondaryText),
      ),
    );
  }

  Widget _buildVideoPreview(RaverThemeData theme) {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.cardBorder),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Center(
              child: Text(
                _fileName(_viewModel.videoPath!),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: RaverTypography.caption(color: theme.secondaryText),
              ),
            ),
          ),
          Center(
            child: Icon(
              Icons.play_circle_fill_rounded,
              color: theme.primaryText.withValues(alpha: 0.62),
              size: 48,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: _viewModel.removeVideo,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventTag(RaverThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event, size: 16, color: theme.accent),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              _viewModel.eventName!,
              style: RaverTypography.label(
                size: 13,
                color: theme.accent,
                weight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: _viewModel.clearEvent,
            child: Icon(Icons.close, size: 16, color: theme.accent),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationTag(RaverThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on, size: 16, color: theme.secondaryText),
          const SizedBox(width: 6),
          Text(
            _viewModel.location!,
            style: RaverTypography.label(size: 13, color: theme.primaryText),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(RaverThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _ToolbarButton(
          icon: Icons.image_outlined,
          label: lt('图片', 'Photo', '写真'),
          theme: theme,
          onTap: _pickImages,
        ),
        _ToolbarButton(
          icon: Icons.videocam_outlined,
          label: lt('视频', 'Video', '動画'),
          theme: theme,
          onTap: _pickVideo,
        ),
        _ToolbarButton(
          icon: Icons.event_outlined,
          label: lt('活动', 'Event', 'イベント'),
          theme: theme,
          onTap: _showEventPicker,
        ),
        _ToolbarButton(
          icon: Icons.location_on_outlined,
          label: lt('位置', 'Location', '場所'),
          theme: theme,
          onTap: _showLocationSheet,
        ),
      ],
    );
  }

  String _fileName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final index = normalized.lastIndexOf('/');
    return index >= 0 ? normalized.substring(index + 1) : normalized;
  }
}

class _ComposeEventPickerSheet extends StatefulWidget {
  const _ComposeEventPickerSheet({required this.onSearch});

  final Future<List<WebEvent>> Function(String search) onSearch;

  @override
  State<_ComposeEventPickerSheet> createState() =>
      _ComposeEventPickerSheetState();
}

class _ComposeEventPickerSheetState extends State<_ComposeEventPickerSheet> {
  final TextEditingController _controller = TextEditingController();
  List<WebEvent> _events = const [];
  bool _isLoading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final events = await widget.onSearch(_controller.text.trim());
      if (!mounted) return;
      setState(() => _events = events);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lt('选择活动', 'Select Event', 'イベントを選択'),
                style: RaverTypography.title(
                  size: 18,
                  color: theme.primaryText,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _load(),
                decoration: InputDecoration(
                  hintText: lt(
                    '搜索活动名/城市/国家',
                    'Search event/city/country',
                    'イベント名/都市/国を検索',
                  ),
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward_rounded),
                    onPressed: _load,
                  ),
                  filled: true,
                  fillColor: theme.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: theme.cardBorder),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _buildEventPickerBody(theme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventPickerBody(RaverThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    if (_error != null) {
      return ErrorStateView(
        title: lt('活动加载失败', 'Events Failed to Load', 'イベントの読み込みに失敗しました'),
        error: _error,
        onRetry: _load,
        retryLabel: lt('重试', 'Retry', '再試行'),
      );
    }
    if (_events.isEmpty) {
      return EmptyStateView(
        icon: Icons.event_busy_outlined,
        title: lt('没有匹配活动', 'No Matching Events', '一致するイベントがありません'),
      );
    }
    return ListView.separated(
      itemCount: _events.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: theme.cardBorder),
      itemBuilder: (context, index) {
        final event = _events[index];
        final subtitle = [
          if (event.startDate.isNotEmpty) event.startDate,
          if (event.location?.city.isNotEmpty == true) event.location!.city,
        ].join(' · ');
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 48,
              height: 48,
              child: event.coverImageUrl.isNotEmpty
                  ? RemoteCoverImage(
                      url: event.coverImageUrl, fit: BoxFit.cover)
                  : ColoredBox(
                      color: theme.card,
                      child: Icon(Icons.event, color: theme.secondaryText),
                    ),
            ),
          ),
          title: Text(
            event.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: subtitle.isEmpty
              ? null
              : Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
          onTap: () => Navigator.of(context).pop(event),
        );
      },
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.theme,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final RaverThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 68,
        height: 54,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: theme.primaryText),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: RaverTypography.caption(
                size: 11,
                color: theme.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
