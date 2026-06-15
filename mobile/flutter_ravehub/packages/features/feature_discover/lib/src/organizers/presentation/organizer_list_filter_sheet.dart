import 'package:flutter/material.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';

/// A bottom-sheet filter for the organizer list, allowing users to filter
/// organizers by country/region.
class OrganizerListFilterSheet extends StatefulWidget {
  /// Creates an [OrganizerListFilterSheet].
  const OrganizerListFilterSheet({
    super.key,
    this.initialCountry,
    this.onApply,
  });

  /// Pre-filled country value (if any).
  final String? initialCountry;

  /// Called when the user taps "Apply" with the selected country.
  final void Function(String? country)? onApply;

  /// Shows this filter as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    String? initialCountry,
    void Function(String? country)? onApply,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OrganizerListFilterSheet(
        initialCountry: initialCountry,
        onApply: onApply,
      ),
    );
  }

  @override
  State<OrganizerListFilterSheet> createState() =>
      _OrganizerListFilterSheetState();
}

class _OrganizerListFilterSheetState extends State<OrganizerListFilterSheet> {
  late final TextEditingController _countryController;

  @override
  void initState() {
    super.initState();
    _countryController = TextEditingController(
      text: widget.initialCountry ?? '',
    );
  }

  @override
  void dispose() {
    _countryController.dispose();
    super.dispose();
  }

  void _reset() {
    _countryController.clear();
    setState(() {});
  }

  void _apply() {
    final text = _countryController.text.trim();
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
            lt('筛选主办方', 'Filter Organizers', '主催者フィルター'),
            style: RaverTypography.title(color: theme.primaryText),
          ),
          const SizedBox(height: 16),

          // Country label
          Text(
            lt('国家/地区', 'Country/Region', '国/地域'),
            style: RaverTypography.label(color: theme.secondaryText),
          ),
          const SizedBox(height: 8),

          // Country text field
          TextField(
            controller: _countryController,
            style: TextStyle(color: theme.primaryText),
            decoration: InputDecoration(
              hintText: lt('搜索国家', 'Search country', '国を検索'),
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
