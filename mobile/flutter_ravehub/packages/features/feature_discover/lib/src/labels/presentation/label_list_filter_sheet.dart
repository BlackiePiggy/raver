import 'package:flutter/material.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';

/// A bottom-sheet filter for the label list, allowing users to filter
/// labels by genre.
class LabelListFilterSheet extends StatefulWidget {
  /// Creates a [LabelListFilterSheet].
  const LabelListFilterSheet({
    super.key,
    this.initialGenre,
    this.onApply,
  });

  /// Pre-filled genre value (if any).
  final String? initialGenre;

  /// Called when the user taps "Apply" with the selected genre.
  final void Function(String? genre)? onApply;

  /// Shows this filter as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    String? initialGenre,
    void Function(String? genre)? onApply,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LabelListFilterSheet(
        initialGenre: initialGenre,
        onApply: onApply,
      ),
    );
  }

  @override
  State<LabelListFilterSheet> createState() => _LabelListFilterSheetState();
}

class _LabelListFilterSheetState extends State<LabelListFilterSheet> {
  late final TextEditingController _genreController;

  @override
  void initState() {
    super.initState();
    _genreController = TextEditingController(
      text: widget.initialGenre ?? '',
    );
  }

  @override
  void dispose() {
    _genreController.dispose();
    super.dispose();
  }

  void _reset() {
    _genreController.clear();
    setState(() {});
  }

  void _apply() {
    final text = _genreController.text.trim();
    widget.onApply?.call(text.isEmpty ? null : text);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            lt('筛选厂牌', 'Filter Labels', 'レーベルフィルター'),
            style: RaverTypography.title(color: theme.primaryText),
          ),
          const SizedBox(height: 16),

          // Genre label
          Text(
            lt('音乐风格', 'Genre', 'ジャンル'),
            style: RaverTypography.label(color: theme.secondaryText),
          ),
          const SizedBox(height: 8),

          // Genre text field
          TextField(
            controller: _genreController,
            style: TextStyle(color: theme.primaryText),
            decoration: InputDecoration(
              hintText: lt('搜索风格', 'Search genre', 'ジャンルを検索'),
              hintStyle: TextStyle(color: theme.secondaryText),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: theme.cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: theme.accent),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _reset,
                  child: Text(lt('重置', 'Reset', 'リセット')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton(
                  label: lt('应用', 'Apply', '適用'),
                  onPressed: _apply,
                ),
              ),
            ],
          ),

          // Bottom safe area padding
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}
