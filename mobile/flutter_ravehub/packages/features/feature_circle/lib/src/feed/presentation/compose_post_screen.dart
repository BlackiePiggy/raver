import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';

import '../view_models/compose_post_view_model.dart';
import '../../_shared/circle_service_locator.dart';

/// Screen for composing and publishing a new social post.
class ComposePostScreen extends StatefulWidget {
  const ComposePostScreen({super.key});

  @override
  State<ComposePostScreen> createState() => _ComposePostScreenState();
}

class _ComposePostScreenState extends State<ComposePostScreen> {
  late final ComposePostViewModel _viewModel;
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

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.background,
        leading: IconButton(
          icon: Icon(Icons.close, color: theme.primaryText),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Text input
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
                  size: 16,
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
                size: 16,
                color: theme.primaryText,
              ),
              maxLines: 8,
              minLines: 4,
              maxLength: _viewModel.maxTextLength,
            ),

            const SizedBox(height: 16),

            // Image previews
            if (_viewModel.imagePaths.isNotEmpty) ...[
              _buildImagePreviewGrid(theme),
              const SizedBox(height: 16),
            ],

            // Video preview
            if (_viewModel.videoPath != null) ...[
              _buildVideoPreview(theme),
              const SizedBox(height: 16),
            ],

            // Event tag
            if (_viewModel.eventName != null) ...[
              _buildEventTag(theme),
              const SizedBox(height: 16),
            ],

            // Location
            if (_viewModel.location != null) ...[
              _buildLocationTag(theme),
              const SizedBox(height: 16),
            ],

            Divider(color: theme.cardBorder),
            const SizedBox(height: 8),

            // Action buttons
            _buildToolbar(theme),

            // Error message
            if (_viewModel.errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _viewModel.errorMessage!,
                style: RaverTypography.caption(
                  color: Colors.red,
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
              child: Icon(
                Icons.image,
                color: theme.secondaryText,
                size: 32,
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
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddImageButton(RaverThemeData theme) {
    return GestureDetector(
      onTap: () {
        // TODO: Use MediaPickerService to pick images
      },
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
          Center(
            child: Icon(
              Icons.videocam,
              color: theme.secondaryText,
              size: 40,
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
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 16,
                ),
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
            style: RaverTypography.label(
              size: 13,
              color: theme.primaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(RaverThemeData theme) {
    return Row(
      children: [
        _ToolbarButton(
          icon: Icons.image_outlined,
          label: lt('图片', 'Photo', '写真'),
          theme: theme,
          onTap: () {
            // TODO: Use MediaPickerService
          },
        ),
        const SizedBox(width: 16),
        _ToolbarButton(
          icon: Icons.videocam_outlined,
          label: lt('视频', 'Video', '動画'),
          theme: theme,
          onTap: () {
            // TODO: Use MediaPickerService
          },
        ),
        const SizedBox(width: 16),
        _ToolbarButton(
          icon: Icons.event_outlined,
          label: lt('活动', 'Event', 'イベント'),
          theme: theme,
          onTap: () {
            // TODO: Event picker
          },
        ),
        const SizedBox(width: 16),
        _ToolbarButton(
          icon: Icons.location_on_outlined,
          label: lt('位置', 'Location', '場所'),
          theme: theme,
          onTap: () {
            // TODO: Location picker
          },
        ),
      ],
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: theme.secondaryText),
          const SizedBox(height: 4),
          Text(
            label,
            style: RaverTypography.caption(
              size: 11,
              color: theme.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}
