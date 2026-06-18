import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';
import 'package:raver_platform/raver_platform.dart';

import '../data/news_api.dart';
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
  late final TextEditingController _sourceController;
  late final TextEditingController _summaryController;
  late final TextEditingController _linkController;
  late final TextEditingController _contentController;
  late final TextEditingController _djSearchController;
  late final TextEditingController _eventSearchController;
  final MediaPickerService _mediaPicker = MediaPickerService();
  List<WebDJ> _djSearchResults = const [];
  List<WebEvent> _eventSearchResults = const [];
  bool _isSearchingDjs = false;
  bool _isSearchingEvents = false;
  String? _djSearchError;
  String? _eventSearchError;

  static const _categories = [
    'festival',
    'scene',
    'gear',
    'industry',
    'community',
  ];

  @override
  void initState() {
    super.initState();
    _vm = NewsEditorViewModel(api: NewsApi(DiscoverServiceLocator.dio));
    _vm.addListener(_onViewModelChanged);

    _titleController = TextEditingController();
    _sourceController = TextEditingController();
    _summaryController = TextEditingController();
    _linkController = TextEditingController();
    _contentController = TextEditingController();
    _djSearchController = TextEditingController();
    _eventSearchController = TextEditingController();

    if (widget.articleId != null) {
      _vm.loadArticle(widget.articleId!).then((_) {
        if (!mounted) return;
        _titleController.text = _vm.title;
        _sourceController.text = _vm.source;
        _summaryController.text = _vm.summary;
        _linkController.text = _vm.link;
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
    _sourceController.dispose();
    _summaryController.dispose();
    _linkController.dispose();
    _contentController.dispose();
    _djSearchController.dispose();
    _eventSearchController.dispose();
    _vm.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadCover() async {
    final path = await _mediaPicker.pickImageInstance();
    if (path != null) {
      await _vm.uploadCover(path);
    }
  }

  Future<void> _save() async {
    final success = await _vm.save();
    if (success && mounted) {
      if (_vm.submittedForReview) {
        ToastBanner.show(
          context,
          message: _vm.submissionMessage.isNotEmpty
              ? _vm.submissionMessage
              : lt('已提交审核', 'Submitted for review', '審査に送信しました'),
          type: ToastType.success,
        );
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      if (!mounted) return;
      context.pop(true);
    } else if (!success && _vm.errorMessage != null && mounted) {
      ToastBanner.show(
        context,
        message: _vm.errorMessage!,
        type: ToastType.error,
      );
    }
  }

  Future<void> _searchDjs() async {
    setState(() {
      _isSearchingDjs = true;
      _djSearchError = null;
    });
    try {
      final items = await _vm.searchDJs(_djSearchController.text);
      if (!mounted) return;
      setState(() {
        _djSearchResults = items;
        _isSearchingDjs = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _djSearchError = e.toString();
        _isSearchingDjs = false;
      });
    }
  }

  Future<void> _searchEvents() async {
    setState(() {
      _isSearchingEvents = true;
      _eventSearchError = null;
    });
    try {
      final items = await _vm.searchEvents(_eventSearchController.text);
      if (!mounted) return;
      setState(() {
        _eventSearchResults = items;
        _isSearchingEvents = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _eventSearchError = e.toString();
        _isSearchingEvents = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return Scaffold(
      backgroundColor: theme.background,
      appBar: RaverNavigationChrome(
        title: widget.articleId == null
            ? lt('发布新闻', 'Publish News', 'ニュース投稿')
            : lt('编辑新闻', 'Edit News', 'ニュース編集'),
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

                // Source
                TextFormField(
                  controller: _sourceController,
                  onChanged: (v) => _vm.updateField(source: v),
                  style: RaverTypography.body(color: theme.primaryText),
                  decoration: InputDecoration(
                    labelText: lt('来源', 'Source', 'ソース'),
                    hintText: lt('例如 Resident Advisor', 'e.g. Resident Advisor',
                        '例: Resident Advisor'),
                    labelStyle: RaverTypography.label(
                      color: theme.secondaryText,
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

                // Summary
                TextFormField(
                  controller: _summaryController,
                  onChanged: (v) => _vm.updateField(summary: v),
                  minLines: 2,
                  maxLines: 4,
                  style: RaverTypography.body(color: theme.primaryText),
                  decoration: _outlinedDecoration(
                    theme,
                    labelText: lt('摘要', 'Summary', '概要'),
                    hintText: lt('可选摘要', 'Optional summary', '任意の概要'),
                  ),
                ),
                const SizedBox(height: 12),

                // Link
                TextFormField(
                  controller: _linkController,
                  onChanged: (v) => _vm.updateField(link: v),
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.next,
                  style: RaverTypography.body(color: theme.primaryText),
                  decoration: _outlinedDecoration(
                    theme,
                    labelText: lt('原文链接', 'Source Link', 'リンク'),
                    hintText: 'https://',
                  ),
                ),
                const SizedBox(height: 16),

                _buildEntityBindingSection(theme),
                const SizedBox(height: 16),

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
                    labelText: lt(
                      '正文(Markdown，可选)',
                      'Content (Markdown, optional)',
                      '本文(任意)',
                    ),
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

  Widget _buildEntityBindingSection(RaverThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lt('关联实体', 'Related Entities', '関連エンティティ'),
          style: RaverTypography.label(
            size: 14,
            color: theme.secondaryText,
            weight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        _buildSelectedChips(
          theme,
          label: lt('已关联 DJ', 'Bound DJs', '関連DJ'),
          namesById: {
            for (final dj in _vm.boundDjs) dj.id: dj.name,
          },
          ids: _vm.boundDjIds,
          onDeleted: _vm.removeBoundDj,
        ),
        const SizedBox(height: 8),
        _buildSearchBox(
          theme,
          controller: _djSearchController,
          hintText: lt('搜索 DJ', 'Search DJs', 'DJを検索'),
          isLoading: _isSearchingDjs,
          onSearch: _searchDjs,
        ),
        _buildDjResults(theme),
        const SizedBox(height: 16),
        _buildSelectedChips(
          theme,
          label: lt('已关联活动', 'Bound Events', '関連イベント'),
          namesById: {
            for (final event in _vm.boundEvents) event.id: event.name,
          },
          ids: _vm.boundEventIds,
          onDeleted: _vm.removeBoundEvent,
        ),
        const SizedBox(height: 8),
        _buildSearchBox(
          theme,
          controller: _eventSearchController,
          hintText: lt('搜索活动', 'Search Events', 'イベントを検索'),
          isLoading: _isSearchingEvents,
          onSearch: _searchEvents,
        ),
        _buildEventResults(theme),
      ],
    );
  }

  Widget _buildSelectedChips(
    RaverThemeData theme, {
    required String label,
    required Map<String, String> namesById,
    required List<String> ids,
    required ValueChanged<String> onDeleted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: RaverTypography.caption(color: theme.secondaryText),
        ),
        const SizedBox(height: 6),
        if (ids.isEmpty)
          Text(
            lt('未选择', 'None selected', '未選択'),
            style: RaverTypography.body(
              size: 13,
              color: theme.secondaryText.withValues(alpha: 0.7),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final id in ids)
                Chip(
                  label: Text(
                    (namesById[id]?.isNotEmpty == true) ? namesById[id]! : id,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onDeleted: () => onDeleted(id),
                  backgroundColor: theme.card,
                  side: BorderSide(color: theme.cardBorder),
                  labelStyle: RaverTypography.caption(
                    color: theme.primaryText,
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildSearchBox(
    RaverThemeData theme, {
    required TextEditingController controller,
    required String hintText,
    required bool isLoading,
    required VoidCallback onSearch,
  }) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            onSubmitted: (_) => onSearch(),
            textInputAction: TextInputAction.search,
            style: RaverTypography.body(color: theme.primaryText),
            decoration: _outlinedDecoration(theme, hintText: hintText),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          onPressed: isLoading ? null : onSearch,
          icon: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.search),
        ),
      ],
    );
  }

  Widget _buildDjResults(RaverThemeData theme) {
    if (_djSearchError != null) {
      return _buildSearchError(theme, _djSearchError!, _searchDjs);
    }
    if (_djSearchResults.isEmpty) return const SizedBox.shrink();
    return _buildResultList(
      theme,
      children: [
        for (final dj in _djSearchResults.take(6))
          _buildResultTile(
            theme,
            title: dj.name,
            subtitle: [
              if (dj.country.isNotEmpty) dj.country,
              if ((dj.genres ?? const []).isNotEmpty)
                (dj.genres ?? const []).take(3).join(', '),
            ].join(' · '),
            imageUrl: dj.avatarUrl,
            isSelected: _vm.boundDjIds.contains(dj.id),
            onTap: () => _vm.addBoundDj(dj),
          ),
      ],
    );
  }

  Widget _buildEventResults(RaverThemeData theme) {
    if (_eventSearchError != null) {
      return _buildSearchError(theme, _eventSearchError!, _searchEvents);
    }
    if (_eventSearchResults.isEmpty) return const SizedBox.shrink();
    return _buildResultList(
      theme,
      children: [
        for (final event in _eventSearchResults.take(6))
          _buildResultTile(
            theme,
            title: event.name,
            subtitle: [
              if (event.startDate.isNotEmpty) event.startDate,
              if (event.location?.name.isNotEmpty == true) event.location!.name,
            ].join(' · '),
            imageUrl: event.coverImageUrl,
            isSelected: _vm.boundEventIds.contains(event.id),
            onTap: () => _vm.addBoundEvent(event),
          ),
      ],
    );
  }

  Widget _buildResultList(
    RaverThemeData theme, {
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: theme.card,
        border: Border.all(color: theme.cardBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildResultTile(
    RaverThemeData theme, {
    required String title,
    required String subtitle,
    required String imageUrl,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      dense: true,
      onTap: isSelected ? null : onTap,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 40,
          height: 40,
          child: imageUrl.isNotEmpty
              ? RemoteCoverImage(url: imageUrl, fit: BoxFit.cover)
              : ColoredBox(
                  color: theme.background,
                  child: Icon(Icons.image_outlined, color: theme.secondaryText),
                ),
        ),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: RaverTypography.label(
          size: 14,
          color: theme.primaryText,
          weight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle.trim().isEmpty
          ? null
          : Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: RaverTypography.caption(color: theme.secondaryText),
            ),
      trailing: Icon(
        isSelected ? Icons.check_circle : Icons.add_circle_outline,
        color: isSelected ? theme.accent : theme.secondaryText,
      ),
    );
  }

  Widget _buildSearchError(
    RaverThemeData theme,
    String message,
    VoidCallback onRetry,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: RaverTypography.caption(color: Colors.red),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(lt('重试', 'Retry', '再試行')),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDropdown(RaverThemeData theme) {
    return DropdownButtonFormField<String>(
      initialValue:
          _categories.contains(_vm.category) ? _vm.category : 'festival',
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

  InputDecoration _outlinedDecoration(
    RaverThemeData theme, {
    String? labelText,
    String? hintText,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      labelStyle: RaverTypography.label(color: theme.secondaryText),
      hintStyle: RaverTypography.body(
        color: theme.secondaryText.withValues(alpha: 0.55),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: theme.cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: theme.cardBorder),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  String _categoryLabel(String category) {
    return switch (category) {
      'festival' => lt('音乐节', 'Festival', 'フェス'),
      'scene' => lt('现场场景', 'Live Scene', 'シーン'),
      'gear' => lt('设备', 'Gear', '機材'),
      'industry' => lt('行业', 'Industry', '業界'),
      'community' => lt('社区', 'Community', 'コミュニティ'),
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
