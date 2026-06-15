import 'package:flutter/material.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';

import '../view_models/events_list_view_model.dart';

/// Advanced filter bottom sheet for the events list.
///
/// Allows filtering by city, date range, event type, and brand/label.
/// Returns an [EventFilterResult] when "Apply" is tapped.
class EventFilterResult {
  const EventFilterResult({
    this.city,
    this.dateRange,
    this.selectedTypes = const [],
    this.brand,
  });

  final String? city;
  final DateTimeRange? dateRange;
  final List<EventTypeFilter> selectedTypes;
  final String? brand;
}

class EventFilterSheet extends StatefulWidget {
  const EventFilterSheet({
    super.key,
    this.initialResult,
  });

  final EventFilterResult? initialResult;

  /// Shows the filter sheet and returns the result, or `null` if dismissed.
  static Future<EventFilterResult?> show(
    BuildContext context, {
    EventFilterResult? initialResult,
  }) {
    return showModalBottomSheet<EventFilterResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EventFilterSheet(initialResult: initialResult),
    );
  }

  @override
  State<EventFilterSheet> createState() => _EventFilterSheetState();
}

class _EventFilterSheetState extends State<EventFilterSheet> {
  late final TextEditingController _cityController;
  late final TextEditingController _brandController;
  DateTimeRange? _dateRange;
  final Set<EventTypeFilter> _selectedTypes = {};

  @override
  void initState() {
    super.initState();
    final initial = widget.initialResult;
    _cityController = TextEditingController(text: initial?.city ?? '');
    _brandController = TextEditingController(text: initial?.brand ?? '');
    _dateRange = initial?.dateRange;
    if (initial != null) {
      _selectedTypes.addAll(initial.selectedTypes);
    }
  }

  @override
  void dispose() {
    _cityController.dispose();
    _brandController.dispose();
    super.dispose();
  }

  void _reset() {
    setState(() {
      _cityController.clear();
      _brandController.clear();
      _dateRange = null;
      _selectedTypes.clear();
    });
  }

  void _apply() {
    final result = EventFilterResult(
      city: _cityController.text.trim().isEmpty
          ? null
          : _cityController.text.trim(),
      dateRange: _dateRange,
      selectedTypes: _selectedTypes.toList(),
      brand: _brandController.text.trim().isEmpty
          ? null
          : _brandController.text.trim(),
    );
    Navigator.of(context).pop(result);
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _dateRange,
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.background,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      lt('高级筛选', 'Advanced Filters', '詳細フィルター'),
                      style: RaverTypography.title(
                        size: 18,
                        color: theme.primaryText,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Icon(
                        Icons.close,
                        size: 22,
                        color: theme.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    // City
                    _buildSectionTitle(
                      theme,
                      lt('城市', 'City', '都市'),
                    ),
                    const SizedBox(height: 8),
                    _buildTextField(
                      theme,
                      _cityController,
                      lt('搜索城市…', 'Search city…', '都市を検索…'),
                    ),
                    const SizedBox(height: 20),

                    // Date range
                    _buildSectionTitle(
                      theme,
                      lt('日期范围', 'Date Range', '日付範囲'),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickDateRange,
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: theme.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: theme.cardBorder),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.date_range,
                              size: 18,
                              color: theme.secondaryText,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _dateRange != null
                                  ? '${_formatDate(_dateRange!.start)} ~ ${_formatDate(_dateRange!.end)}'
                                  : lt('选择日期范围',
                                      'Select date range',
                                      '日付範囲を選択'),
                              style: RaverTypography.body(
                                size: 14,
                                color: _dateRange != null
                                    ? theme.primaryText
                                    : theme.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Event type
                    _buildSectionTitle(
                      theme,
                      lt('活动类型', 'Event Type', 'イベントタイプ'),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: EventTypeFilter.values
                          .where((t) => t != EventTypeFilter.all)
                          .map((type) {
                        final isSelected = _selectedTypes.contains(type);
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedTypes.remove(type);
                              } else {
                                _selectedTypes.add(type);
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.accent
                                  : theme.card,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? theme.accent
                                    : theme.cardBorder,
                              ),
                            ),
                            child: Text(
                              type.label,
                              style: RaverTypography.label(
                                size: 13,
                                color: isSelected
                                    ? Colors.white
                                    : theme.primaryText,
                                weight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Brand / Label
                    _buildSectionTitle(
                      theme,
                      lt('厂牌', 'Label / Brand', 'レーベル'),
                    ),
                    const SizedBox(height: 8),
                    _buildTextField(
                      theme,
                      _brandController,
                      lt('搜索厂牌…', 'Search label…', 'レーベルを検索…'),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
              // Bottom action bar
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                decoration: BoxDecoration(
                  color: theme.background,
                  border: Border(
                    top: BorderSide(color: theme.cardBorder, width: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _reset,
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: theme.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.cardBorder),
                          ),
                          child: Center(
                            child: Text(
                              lt('重置', 'Reset', 'リセット'),
                              style: RaverTypography.label(
                                size: 15,
                                color: theme.primaryText,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onTap: _apply,
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: theme.accent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              lt('应用筛选', 'Apply Filters', 'フィルターを適用'),
                              style: RaverTypography.label(
                                size: 15,
                                color: Colors.white,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(RaverThemeData theme, String text) {
    return Text(
      text,
      style: RaverTypography.label(
        size: 14,
        color: theme.primaryText,
        weight: FontWeight.w600,
      ),
    );
  }

  Widget _buildTextField(
    RaverThemeData theme,
    TextEditingController controller,
    String hint,
  ) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.cardBorder),
      ),
      child: TextField(
        controller: controller,
        style: RaverTypography.body(size: 14, color: theme.primaryText),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: RaverTypography.body(
            size: 14,
            color: theme.secondaryText,
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          prefixIcon: Icon(
            Icons.search,
            size: 18,
            color: theme.secondaryText,
          ),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 24, minHeight: 24),
        ),
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
