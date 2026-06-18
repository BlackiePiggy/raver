import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_platform/raver_platform.dart';

import 'view_models/event_editor_view_model.dart';
import 'view_models/event_upload_view_model.dart';
import '../../_shared/discover_service_locator.dart';

class EventEditorScreen extends StatefulWidget {
  const EventEditorScreen({super.key, this.eventId});

  final String? eventId;

  @override
  State<EventEditorScreen> createState() => _EventEditorScreenState();
}

class _EventEditorScreenState extends State<EventEditorScreen> {
  late final EventEditorViewModel _vm;
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _timezoneCtrl;
  late final TextEditingController _venueNameCtrl;
  late final TextEditingController _venueCityCtrl;
  late final TextEditingController _venueCountryCtrl;
  late final TextEditingController _latCtrl;
  late final TextEditingController _lngCtrl;
  late final TextEditingController _ticketUrlCtrl;
  late final TextEditingController _capacityCtrl;

  static const _eventTypes = [
    'club_night',
    'festival',
    'concert',
    'outdoor',
    'underground',
    'pool_party',
    'boat_party',
    'warehouse',
  ];

  @override
  void initState() {
    super.initState();
    _vm = EventEditorViewModel(
      api: DiscoverServiceLocator.eventsApi,
      eventId: widget.eventId,
    );

    _titleCtrl = TextEditingController();
    _descCtrl = TextEditingController();
    _timezoneCtrl = TextEditingController();
    _venueNameCtrl = TextEditingController();
    _venueCityCtrl = TextEditingController();
    _venueCountryCtrl = TextEditingController();
    _latCtrl = TextEditingController();
    _lngCtrl = TextEditingController();
    _ticketUrlCtrl = TextEditingController();
    _capacityCtrl = TextEditingController();

    _vm.addListener(_onViewModelChanged);

    if (widget.eventId != null) {
      _vm.loadEvent(widget.eventId!);
    }
  }

  void _onViewModelChanged() {
    if (!mounted) return;

    // Sync text controllers when loading completes (edit mode).
    if (_vm.isEditMode && _titleCtrl.text.isEmpty && _vm.title.isNotEmpty) {
      _titleCtrl.text = _vm.title;
      _descCtrl.text = _vm.description;
      _timezoneCtrl.text = _vm.timezone;
      _venueNameCtrl.text = _vm.venueName;
      _venueCityCtrl.text = _vm.venueCity;
      _venueCountryCtrl.text = _vm.venueCountry;
      _latCtrl.text = _vm.venueLatitude?.toString() ?? '';
      _lngCtrl.text = _vm.venueLongitude?.toString() ?? '';
      _ticketUrlCtrl.text = _vm.ticketUrl;
      _capacityCtrl.text = _vm.maxCapacity?.toString() ?? '';
    }

    if (_vm.isSaved) {
      context.pop(true);
      return;
    }

    if (_vm.errorMessage != null) {
      ToastBanner.show(context, message: _vm.errorMessage!);
    }

    setState(() {});
  }

  @override
  void dispose() {
    _vm.removeListener(_onViewModelChanged);
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _timezoneCtrl.dispose();
    _venueNameCtrl.dispose();
    _venueCityCtrl.dispose();
    _venueCountryCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _ticketUrlCtrl.dispose();
    _capacityCtrl.dispose();
    _vm.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    _syncFieldsToVm();
    await _vm.save();
  }

  void _syncFieldsToVm() {
    _vm.updateTitle(_titleCtrl.text.trim());
    _vm.updateDescription(_descCtrl.text.trim());
    _vm.updateTimezone(_timezoneCtrl.text.trim());
    _vm.updateVenueName(_venueNameCtrl.text.trim());
    _vm.updateVenueCity(_venueCityCtrl.text.trim());
    _vm.updateVenueCountry(_venueCountryCtrl.text.trim());
    _vm.updateVenueLatitude(double.tryParse(_latCtrl.text.trim()));
    _vm.updateVenueLongitude(double.tryParse(_lngCtrl.text.trim()));
    _vm.updateTicketUrl(_ticketUrlCtrl.text.trim());
    _vm.updateMaxCapacity(int.tryParse(_capacityCtrl.text.trim()));
  }

  Future<void> _pickStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _vm.startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_vm.startDate ?? DateTime.now()),
    );
    if (time == null) return;
    _vm.updateStartDate(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  Future<void> _pickEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _vm.endDate ?? _vm.startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_vm.endDate ?? DateTime.now()),
    );
    if (time == null) return;
    _vm.updateEndDate(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  Future<void> _pickEventImage(EventUploadImageZone zone) async {
    final path = await MediaPickerService.pickImage();
    if (path == null) return;
    await _vm.uploadEventImage(zone, path);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return Scaffold(
      body: RaverNavigationChrome(
        title: lt('编辑活动', 'Edit Event', 'イベント編集'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _vm.isLoading ? null : _onSave,
          ),
        ],
        child: Stack(
          children: [
            Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      theme,
                      lt('基本信息', 'Basic Info', '基本情報'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _titleCtrl,
                      decoration: InputDecoration(
                        labelText: lt('标题', 'Title', 'タイトル'),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? lt('请输入标题', 'Title is required', 'タイトルを入力してください')
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descCtrl,
                      decoration: InputDecoration(
                        labelText: lt('描述', 'Description', '説明'),
                      ),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _vm.eventType,
                      decoration: InputDecoration(
                        labelText: lt('活动类型', 'Event Type', 'イベントタイプ'),
                      ),
                      items: _eventTypes
                          .map(
                            (t) => DropdownMenuItem(value: t, child: Text(t)),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) _vm.updateEventType(v);
                      },
                    ),
                    const SizedBox(height: 24),
                    _buildSectionHeader(
                      theme,
                      lt('时间', 'Time', '時間'),
                    ),
                    const SizedBox(height: 12),
                    _buildDateRow(
                      theme,
                      label: lt('开始时间', 'Start', '開始'),
                      value: _vm.startDate,
                      onTap: _pickStartDate,
                    ),
                    const SizedBox(height: 12),
                    _buildDateRow(
                      theme,
                      label: lt('结束时间', 'End', '終了'),
                      value: _vm.endDate,
                      onTap: _pickEndDate,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _timezoneCtrl,
                      decoration: InputDecoration(
                        labelText: lt('时区', 'Timezone', 'タイムゾーン'),
                        hintText: 'Asia/Shanghai',
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSectionHeader(
                      theme,
                      lt('地点', 'Venue', '会場'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _venueNameCtrl,
                      decoration: InputDecoration(
                        labelText: lt('场地名称', 'Venue Name', '会場名'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _venueCityCtrl,
                      decoration: InputDecoration(
                        labelText: lt('城市', 'City', '都市'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _venueCountryCtrl,
                      decoration: InputDecoration(
                        labelText: lt('国家', 'Country', '国'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _latCtrl,
                            decoration: InputDecoration(
                              labelText: lt('纬度', 'Latitude', '緯度'),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _lngCtrl,
                            decoration: InputDecoration(
                              labelText: lt('经度', 'Longitude', '経度'),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSectionHeader(
                      theme,
                      lt('活动图片', 'Event Images', 'イベント画像'),
                    ),
                    const SizedBox(height: 12),
                    _buildImageZoneCard(
                      theme,
                      zone: EventUploadImageZone.poster,
                      title: lt('海报', 'Poster', 'ポスター'),
                      subtitle: lt('活动主视觉', 'Primary event artwork', 'メイン画像'),
                    ),
                    const SizedBox(height: 12),
                    _buildImageZoneCard(
                      theme,
                      zone: EventUploadImageZone.lineup,
                      title: lt('阵容图', 'Lineup Image', 'ラインナップ画像'),
                      subtitle: lt('DJ阵容或海报截图', 'DJ lineup or poster crop',
                          'DJラインナップ画像'),
                    ),
                    const SizedBox(height: 12),
                    _buildImageZoneCard(
                      theme,
                      zone: EventUploadImageZone.cover,
                      title: lt('封面', 'Cover', 'カバー'),
                      subtitle: lt(
                          '无海报时作为封面备选',
                          'Fallback cover when no poster is set',
                          'ポスターがない場合のカバー'),
                    ),
                    const SizedBox(height: 24),
                    _buildSectionHeader(
                      theme,
                      lt('票务', 'Tickets', 'チケット'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _ticketUrlCtrl,
                      decoration: InputDecoration(
                        labelText: lt('购票链接', 'Ticket URL', 'チケットURL'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _capacityCtrl,
                      decoration: InputDecoration(
                        labelText: lt('最大容量', 'Max Capacity', '最大収容人数'),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            if (_vm.isLoading)
              Container(
                color: Colors.black.withValues(alpha: 0.3),
                child: const Center(
                  child: CircularProgressIndicator.adaptive(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(RaverThemeData theme, String text) {
    return Text(
      text,
      style: RaverTypography.title(size: 16, color: theme.primaryText),
    );
  }

  Widget _buildDateRow(
    RaverThemeData theme, {
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: theme.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.cardBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: RaverTypography.body(
                size: 14,
                color: theme.secondaryText,
              ),
            ),
            Text(
              value != null ? _formatDateTime(value) : lt('选择', 'Select', '選択'),
              style: RaverTypography.body(
                size: 14,
                color: value != null ? theme.primaryText : theme.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageZoneCard(
    RaverThemeData theme, {
    required EventUploadImageZone zone,
    required String title,
    required String subtitle,
  }) {
    final url = _vm.imageUrl(zone);
    final hasImage = url != null && url.isNotEmpty;
    return Container(
      height: 138,
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasImage)
            GestureDetector(
              onTap: () => _previewEventImage(zone),
              child: RemoteCoverImage(url: url, fit: BoxFit.cover),
            )
          else
            GestureDetector(
              onTap: () => _pickEventImage(zone),
              child: CustomPaint(
                painter: _DashedBorderPainter(color: theme.cardBorder),
                child: Center(
                  child: Icon(
                    Icons.cloud_upload_outlined,
                    color: theme.secondaryText,
                    size: 32,
                  ),
                ),
              ),
            ),
          Positioned(
            top: 10,
            right: 10,
            child: Row(
              children: [
                if (hasImage)
                  _imageActionButton(
                    icon: Icons.visibility_outlined,
                    label: lt('预览', 'Preview', 'プレビュー'),
                    onPressed: () => _previewEventImage(zone),
                  ),
                if (hasImage) const SizedBox(width: 8),
                _imageActionButton(
                  icon: hasImage
                      ? Icons.edit_outlined
                      : Icons.add_photo_alternate_outlined,
                  label: hasImage
                      ? lt('替换', 'Replace', '差し替え')
                      : lt('添加图片', 'Add image', '画像追加'),
                  onPressed: () => _pickEventImage(zone),
                ),
                if (hasImage) ...[
                  const SizedBox(width: 8),
                  _imageActionButton(
                    icon: Icons.delete_outline,
                    label: lt('删除', 'Delete', '削除'),
                    onPressed: () => _vm.removeImageAsset(zone),
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: hasImage ? 0.55 : 0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: EdgeInsets.all(hasImage ? 10 : 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: RaverTypography.label(
                              size: 15,
                              color:
                                  hasImage ? Colors.white : theme.primaryText,
                              weight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hasImage ? lt('已设置', 'Set', '設定済み') : subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: RaverTypography.caption(
                              color: hasImage
                                  ? Colors.white70
                                  : theme.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      hasImage ? Icons.photo : Icons.add_photo_alternate,
                      color: hasImage ? Colors.white : theme.accent,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.54),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }

  Future<void> _previewEventImage(EventUploadImageZone zone) async {
    final url = _vm.imageUrl(zone);
    if (url == null || url.isEmpty) return;
    await MediaPreviewOverlay.show(
      context,
      mediaUrls: [url],
      heroTagPrefix: 'event-edit-${zone.name}',
    );
  }

  static String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashWidth = 6.0;
    const dashGap = 4.0;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(12),
    );
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashWidth).clamp(0.0, metric.length);
        canvas.drawPath(
          metric.extractPath(distance, end),
          paint,
        );
        distance += dashWidth + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color;
}
