import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_platform/raver_platform.dart';

import '../../data/news_api.dart';
import '../../_shared/discover_service_locator.dart';
import 'view_models/news_editor_view_model.dart';

/// Screen for creating or editing a news article.
class NewsEditorScreen extends StatefulWidget {
  const NewsEditorScreen({super.key, this.articleId});

  /// If non-null, the screen loads and edits an existing article.
  final String? articleId;

  @override
  State<NewsEditorScreen> createState() => _NewsEditorScreenState();
}

class _NewsEditorScreenState extends State<NewsEditorScreen> {
  late final NewsEditorViewModel _vm;
  late final TextEditingController _titleController;
  late final TextEditingController _tagsController;
  late final TextEditingController _contentController;
  final MediaPickerService _mediaPicker = MediaPickerService();

  static const _categories = [
    'news',
    'interview',
    'review',
    'event_recap',
    'tutorial',
    'feature',
  ];

  @override
  void initState() {
    super.initState();
    _vm = NewsEditorViewModel(api: NewsApi(DiscoverServiceLocator.dio));
    _vm.addListener(_onViewModelChanged);

    _titleController = TextEditingController();
    _tagsController = TextEditingController();
    _contentController = TextEditingController();

    if (widget.articleId != null) {
      _vm.loadArticle(widget.articleId!).then((_) {
        _titleController.text = _vm.title;
        _tagsController.text = _vm.tags.join(', ');
        _contentController.text = _vm.content;
      });
    }
  }

  void _onViewModelChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _vm.removeListener(_onViewModelChanged);
    _titleController.dispose();
    _tagsController.dispose();
    _contentController.dispose();
    _vm.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadCover() async {
    final path = await _mediaPicker.pickImage();
    if (path != null) {
      await _vm.uploadCover(path);
    }
  }

  Future<void> _save() async {
    final success = await _vm.save();
    if (success && mounted) {
      context.pop(true);
    } else if (!success && _vm.errorMessage != null && mounted) {
      ToastBanner.show(
        context,
        message: _vm.errorMessage!,
        type: ToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return Scaffold(
      backgroundColor: theme.background,
      appBar: RaverNavigationChrome(
        title: lt('发布新闻', 'Publish News', 'ニュース投稿'),
        trailing: _vm.isLoading
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : IconButton(
                onPressed: _vm.canSave ? _save : null,
                icon: Icon(
                  Icons.check,
                  color: _vm.canSave
                      ? theme.accent
                      : theme.secondaryText.withValues(alpha: 0.3),
                ),
              ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover image upload area
                _buildCoverImageArea(theme),
                const SizedBox(height: 16),

                // Title
                TextFormField(
                  controller: _titleController,
                  onChanged: (v) => _vm.updateField(title: v),
                  style: RaverTypography.title(
                    size: 20,
                    color: theme.primaryText,
                  ),
                  decoration: InputDecoration(
                    hintText: lt('标题', 'Title', 'タイトル'),
                    hintStyle: RaverTypography.title(
                      size: 20,
                      color: theme.secondaryText,
                    ),
                    border: InputBorder.none,
                  ),
                ),
                const SizedBox(height: 12),

                // Category dropdown
                _buildCategoryDropdown(theme),
                const SizedBox(height: 12),

                // Tags
                TextFormField(
                  controller: _tagsController,
                  onChanged: (v) {
                    final parsed = v
                        .split(',')
                        .map((s) => s.trim())
                        .where((s) => s.isNotEmpty)
                        .toList();
                    _vm.updateField(tags: parsed);
                  },
                  style: RaverTypography.body(color: theme.primaryText),
                  decoration: InputDecoration(
                    hintText: lt(
                      '标签(逗号分隔)',
                      'Tags (comma-separated)',
                      'タグ(カンマ区切り)',
                    ),
                    hintStyle: RaverTypography.body(
                      color: theme.secondaryText,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: theme.cardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: theme.cardBorder),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Content (Markdown body)
                TextFormField(
                  controller: _contentController,
                  onChanged: (v) => _vm.updateField(content: v),
                  minLines: 10,
                  maxLines: null,
                  style: RaverTypography.body(
                    color: theme.primaryText,
                  ).copyWith(fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    labelText: lt('正文(Markdown)', 'Content (Markdown)', '本文'),
                    labelStyle: RaverTypography.label(
                      color: theme.secondaryText,
                    ),
                    hintText: lt(
                      '使用 Markdown 格式撰写正文...',
                      'Write your content in Markdown...',
                      'Markdown形式で本文を書く...',
                    ),
                    hintStyle: RaverTypography.body(
                      color: theme.secondaryText.withValues(alpha: 0.5),
                    ).copyWith(fontFamily: 'monospace'),
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: theme.cardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: theme.cardBorder),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),

                // Error message
                if (_vm.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _vm.errorMessage!,
                    style: RaverTypography.caption(color: Colors.red),
                  ),
                ],

                const SizedBox(height: 80),
              ],
            ),
          ),

          // Loading overlay
          if (_vm.isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.2),
                child: const Center(
                  child: CircularProgressIndicator.adaptive(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCoverImageArea(RaverThemeData theme) {
    if (_vm.coverImageUrl != null && _vm.coverImageUrl!.isNotEmpty) {
      return GestureDetector(
        onTap: _pickAndUploadCover,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 200,
            width: double.infinity,
            child: RemoteCoverImage(
              url: _vm.coverImageUrl!,
              height: 200,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _pickAndUploadCover,
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.cardBorder,
            style: BorderStyle.solid,
            width: 1.5,
          ),
          color: theme.card.withValues(alpha: 0.3),
        ),
        child: CustomPaint(
          painter: _DashedBorderPainter(color: theme.cardBorder),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_photo_alternate_outlined,
                size: 40,
                color: theme.secondaryText,
              ),
              const SizedBox(height: 8),
              Text(
                lt('上传封面图', 'Upload Cover Image', 'カバー画像をアップロード'),
                style: RaverTypography.label(
                  size: 14,
                  color: theme.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown(RaverThemeData theme) {
    return DropdownButtonFormField<String>(
      value: _vm.category,
      onChanged: (v) {
        if (v != null) _vm.updateField(category: v);
      },
      items: _categories.map((c) {
        return DropdownMenuItem(
          value: c,
          child: Text(
            _categoryLabel(c),
            style: RaverTypography.body(color: theme.primaryText),
          ),
        );
      }).toList(),
      decoration: InputDecoration(
        labelText: lt('分类', 'Category', 'カテゴリー'),
        labelStyle: RaverTypography.label(color: theme.secondaryText),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: theme.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: theme.cardBorder),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
      dropdownColor: theme.card,
    );
  }

  String _categoryLabel(String category) {
    return switch (category) {
      'news' => lt('新闻', 'News', 'ニュース'),
      'interview' => lt('采访', 'Interview', 'インタビュー'),
      'review' => lt('评测', 'Review', 'レビュー'),
      'event_recap' => lt('活动回顾', 'Event Recap', 'イベントまとめ'),
      'tutorial' => lt('教程', 'Tutorial', 'チュートリアル'),
      'feature' => lt('特稿', 'Feature', '特集'),
      _ => category,
    };
  }
}

/// Paints a dashed rectangular border.
class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashWidth = 8.0;
    const dashSpace = 4.0;
    final rrect = RRect.fromLTRBR(
      0,
      0,
      size.width,
      size.height,
      const Radius.circular(12),
    );

    final path = Path()..addRRect(rrect);
    final dashPath = Path();

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dashWidth).clamp(0.0, metric.length);
        dashPath.addPath(
          metric.extractPath(distance, end),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }

    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color;
}
