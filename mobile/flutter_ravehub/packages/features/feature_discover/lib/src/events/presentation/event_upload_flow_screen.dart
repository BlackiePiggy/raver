import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_platform/raver_platform.dart';

import '../view_models/event_upload_view_model.dart';
import '../../_shared/discover_service_locator.dart';

class EventUploadFlowScreen extends StatefulWidget {
  const EventUploadFlowScreen({super.key});

  @override
  State<EventUploadFlowScreen> createState() => _EventUploadFlowScreenState();
}

class _EventUploadFlowScreenState extends State<EventUploadFlowScreen> {
  late final EventUploadViewModel _vm;

  // Basic info controllers
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _timezoneCtrl = TextEditingController();
  final _venueNameCtrl = TextEditingController();
  final _venueCityCtrl = TextEditingController();
  final _venueCountryCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  final _ticketUrlCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();

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
    _vm = EventUploadViewModel(api: DiscoverServiceLocator.eventsApi);
    _vm.addListener(_onChanged);
  }

  void _onChanged() {
    if (!mounted) return;

    if (_vm.isSubmitted) {
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
    _vm.removeListener(_onChanged);
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

  void _syncBasicInfo() {
    _vm.title = _titleCtrl.text.trim();
    _vm.description = _descCtrl.text.trim();
    _vm.timezone = _timezoneCtrl.text.trim();
    _vm.venueName = _venueNameCtrl.text.trim();
    _vm.venueCity = _venueCityCtrl.text.trim();
    _vm.venueCountry = _venueCountryCtrl.text.trim();
    _vm.venueLatitude = double.tryParse(_latCtrl.text.trim());
    _vm.venueLongitude = double.tryParse(_lngCtrl.text.trim());
    _vm.ticketUrl = _ticketUrlCtrl.text.trim();
    _vm.maxCapacity = int.tryParse(_capacityCtrl.text.trim());
  }

  void _onNext() {
    _syncBasicInfo();
    if (_vm.currentStep == EventUploadStep.tickets) {
      _vm.submit();
    } else {
      _vm.nextStep();
    }
  }

  void _onBack() {
    if (_vm.currentStepIndex == 0) {
      context.pop();
    } else {
      _vm.prevStep();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    final progress = (_vm.currentStepIndex + 1) / _vm.totalSteps;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar
            LinearProgressIndicator(
              value: progress,
              backgroundColor: theme.cardBorder,
              valueColor: AlwaysStoppedAnimation<Color>(theme.accent),
            ),
            Expanded(
              child: Stack(
                children: [
                  _buildCurrentStep(theme),
                  if (_vm.isUploading)
                    Container(
                      color: Colors.black.withValues(alpha: 0.3),
                      child: const Center(
                        child: CircularProgressIndicator.adaptive(),
                      ),
                    ),
                ],
              ),
            ),
            _buildBottomBar(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStep(RaverThemeData theme) {
    return switch (_vm.currentStep) {
      EventUploadStep.basicInfo => _buildBasicInfoStep(theme),
      EventUploadStep.poster => _buildPosterStep(theme),
      EventUploadStep.lineup => _buildLineupStep(theme),
      EventUploadStep.schedule => _buildScheduleStep(theme),
      EventUploadStep.tickets => _buildTicketsStep(theme),
    };
  }

  // ---------------------------------------------------------------------------
  // Step 0: Basic Info
  // ---------------------------------------------------------------------------

  Widget _buildBasicInfoStep(RaverThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lt('基本信息', 'Basic Info', '基本情報'),
            style: RaverTypography.title(size: 18, color: theme.primaryText),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _titleCtrl,
            decoration: InputDecoration(
              labelText: lt('标题', 'Title', 'タイトル'),
            ),
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
            value: _vm.eventType,
            decoration: InputDecoration(
              labelText: lt('活动类型', 'Event Type', 'イベントタイプ'),
            ),
            items: _eventTypes
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                _vm.eventType = v;
                setState(() {});
              }
            },
          ),
          const SizedBox(height: 12),
          _buildDatePickerRow(
            theme,
            label: lt('开始时间', 'Start', '開始'),
            value: _vm.startDate,
            onPicked: (dt) => setState(() => _vm.startDate = dt),
          ),
          const SizedBox(height: 12),
          _buildDatePickerRow(
            theme,
            label: lt('结束时间', 'End', '終了'),
            value: _vm.endDate,
            onPicked: (dt) => setState(() => _vm.endDate = dt),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _timezoneCtrl,
            decoration: InputDecoration(
              labelText: lt('时区', 'Timezone', 'タイムゾーン'),
              hintText: 'Asia/Shanghai',
            ),
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
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildDatePickerRow(
    RaverThemeData theme, {
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime> onPicked,
  }) {
    return GestureDetector(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (date == null || !mounted) return;
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(value ?? DateTime.now()),
        );
        if (time == null) return;
        onPicked(
          DateTime(date.year, date.month, date.day, time.hour, time.minute),
        );
      },
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
              value != null
                  ? _formatDateTime(value)
                  : lt('选择', 'Select', '選択'),
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

  // ---------------------------------------------------------------------------
  // Step 1: Poster
  // ---------------------------------------------------------------------------

  Widget _buildPosterStep(RaverThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lt('上传海报', 'Upload Poster', 'ポスターをアップロード'),
            style: RaverTypography.title(size: 18, color: theme.primaryText),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _vm.posterUrl != null && _vm.posterUrl!.isNotEmpty
                ? GestureDetector(
                    onTap: _pickPoster,
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: SizedBox(
                            width: double.infinity,
                            child: RemoteCoverImage(
                              url: _vm.posterUrl!,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : GestureDetector(
                    onTap: _pickPoster,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.cardBorder),
                      ),
                      child: CustomPaint(
                        painter: _DashedBorderPainter(color: theme.cardBorder),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.cloud_upload_outlined,
                                size: 48,
                                color: theme.secondaryText,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                lt('点击上传海报', 'Tap to Upload', 'タップしてアップロード'),
                                style: RaverTypography.body(
                                  size: 16,
                                  color: theme.secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickPoster() async {
    final path = await MediaPickerService.pickImage();
    if (path == null) return;
    await _vm.uploadPoster(path);
  }

  // ---------------------------------------------------------------------------
  // Step 2: Lineup
  // ---------------------------------------------------------------------------

  Widget _buildLineupStep(RaverThemeData theme) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lt('阵容', 'Lineup', 'ラインナップ'),
                style:
                    RaverTypography.title(size: 18, color: theme.primaryText),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _vm.lineup.isEmpty
                    ? Center(
                        child: Text(
                          lt('暂未添加DJ', 'No DJs added yet', 'まだDJが追加されていません'),
                          style: RaverTypography.body(
                            size: 14,
                            color: theme.secondaryText,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _vm.lineup.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final entry = _vm.lineup[index];
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: theme.cardBorder),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.djName,
                                        style: RaverTypography.label(
                                          size: 15,
                                          color: theme.primaryText,
                                          weight: FontWeight.w600,
                                        ),
                                      ),
                                      if (entry.isB2B)
                                        Text(
                                          'B2B',
                                          style: RaverTypography.caption(
                                            color: theme.accent,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_outline,
                                    color: theme.secondaryText,
                                  ),
                                  onPressed: () =>
                                      _vm.removeLineupEntry(index),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            backgroundColor: theme.accent,
            onPressed: () => _showAddLineupDialog(theme),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Future<void> _showAddLineupDialog(RaverThemeData theme) async {
    final nameCtrl = TextEditingController();
    bool isB2B = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(lt('添加DJ', 'Add DJ', 'DJ追加')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: lt('DJ名称', 'DJ Name', 'DJ名'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: isB2B,
                        onChanged: (v) =>
                            setDialogState(() => isB2B = v ?? false),
                      ),
                      Text('B2B'),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(lt('取消', 'Cancel', 'キャンセル')),
                ),
                TextButton(
                  onPressed: () {
                    if (nameCtrl.text.trim().isNotEmpty) {
                      _vm.addLineupEntry(
                        djName: nameCtrl.text.trim(),
                        isB2B: isB2B,
                      );
                    }
                    Navigator.pop(ctx);
                  },
                  child: Text(lt('添加', 'Add', '追加')),
                ),
              ],
            );
          },
        );
      },
    );
    nameCtrl.dispose();
  }

  // ---------------------------------------------------------------------------
  // Step 3: Schedule
  // ---------------------------------------------------------------------------

  Widget _buildScheduleStep(RaverThemeData theme) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lt('时间表', 'Schedule', 'スケジュール'),
                style:
                    RaverTypography.title(size: 18, color: theme.primaryText),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _vm.schedule.isEmpty
                    ? Center(
                        child: Text(
                          lt('暂无排程', 'No schedule entries', 'スケジュールなし'),
                          style: RaverTypography.body(
                            size: 14,
                            color: theme.secondaryText,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _vm.schedule.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final entry = _vm.schedule[index];
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: theme.cardBorder),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.stageName,
                                        style: RaverTypography.label(
                                          size: 14,
                                          color: theme.accent,
                                          weight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        entry.djName,
                                        style: RaverTypography.label(
                                          size: 15,
                                          color: theme.primaryText,
                                          weight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${_formatTime(entry.startTime)} - ${_formatTime(entry.endTime)}',
                                        style: RaverTypography.caption(
                                          color: theme.secondaryText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_outline,
                                    color: theme.secondaryText,
                                  ),
                                  onPressed: () =>
                                      _vm.removeScheduleEntry(index),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            backgroundColor: theme.accent,
            onPressed: () => _showAddScheduleDialog(theme),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Future<void> _showAddScheduleDialog(RaverThemeData theme) async {
    final stageCtrl = TextEditingController();
    final djCtrl = TextEditingController();
    DateTime? startTime;
    DateTime? endTime;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(lt('添加排程', 'Add Schedule', 'スケジュール追加')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: stageCtrl,
                      decoration: InputDecoration(
                        labelText: lt('舞台', 'Stage', 'ステージ'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: djCtrl,
                      decoration: InputDecoration(
                        labelText: lt('DJ名称', 'DJ Name', 'DJ名'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DialogDatePicker(
                      label: lt('开始时间', 'Start', '開始'),
                      value: startTime,
                      onPicked: (dt) =>
                          setDialogState(() => startTime = dt),
                    ),
                    const SizedBox(height: 12),
                    _DialogDatePicker(
                      label: lt('结束时间', 'End', '終了'),
                      value: endTime,
                      onPicked: (dt) =>
                          setDialogState(() => endTime = dt),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(lt('取消', 'Cancel', 'キャンセル')),
                ),
                TextButton(
                  onPressed: () {
                    if (stageCtrl.text.trim().isNotEmpty) {
                      _vm.addScheduleEntry(
                        stageName: stageCtrl.text.trim(),
                        djName: djCtrl.text.trim(),
                        startTime: startTime,
                        endTime: endTime,
                      );
                    }
                    Navigator.pop(ctx);
                  },
                  child: Text(lt('添加', 'Add', '追加')),
                ),
              ],
            );
          },
        );
      },
    );
    stageCtrl.dispose();
    djCtrl.dispose();
  }

  // ---------------------------------------------------------------------------
  // Step 4: Tickets + Review
  // ---------------------------------------------------------------------------

  Widget _buildTicketsStep(RaverThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lt('票务', 'Tickets', 'チケット'),
            style: RaverTypography.title(size: 18, color: theme.primaryText),
          ),
          const SizedBox(height: 16),
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
          const SizedBox(height: 24),
          Text(
            lt('活动概览', 'Review', '確認'),
            style: RaverTypography.title(size: 18, color: theme.primaryText),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _reviewRow(theme, lt('标题', 'Title', 'タイトル'), _vm.title),
                  _reviewRow(
                    theme,
                    lt('类型', 'Type', 'タイプ'),
                    _vm.eventType,
                  ),
                  _reviewRow(
                    theme,
                    lt('开始', 'Start', '開始'),
                    _formatDateTime(_vm.startDate),
                  ),
                  _reviewRow(
                    theme,
                    lt('结束', 'End', '終了'),
                    _formatDateTime(_vm.endDate),
                  ),
                  _reviewRow(
                    theme,
                    lt('场地', 'Venue', '会場'),
                    _vm.venueName,
                  ),
                  _reviewRow(
                    theme,
                    lt('阵容', 'Lineup', 'ラインナップ'),
                    '${_vm.lineup.length} ${lt('位DJ', 'DJs', 'DJs')}',
                  ),
                  _reviewRow(
                    theme,
                    lt('排程', 'Schedule', 'スケジュール'),
                    '${_vm.schedule.length} ${lt('个时段', 'slots', 'スロット')}',
                  ),
                  _reviewRow(
                    theme,
                    lt('海报', 'Poster', 'ポスター'),
                    _vm.posterUrl != null
                        ? lt('已上传', 'Uploaded', 'アップロード済み')
                        : lt('未上传', 'Not uploaded', '未アップロード'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _reviewRow(RaverThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: RaverTypography.caption(color: theme.secondaryText),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: RaverTypography.body(size: 14, color: theme.primaryText),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom navigation
  // ---------------------------------------------------------------------------

  Widget _buildBottomBar(RaverThemeData theme) {
    final isLast = _vm.currentStep == EventUploadStep.tickets;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.background,
        border: Border(top: BorderSide(color: theme.cardBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: PrimaryButton(
              label: lt('返回', 'Back', '戻る'),
              variant: PrimaryButtonVariant.outline,
              onPressed: _onBack,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: PrimaryButton(
              label: isLast
                  ? lt('提交', 'Submit', '送信')
                  : lt('下一步', 'Next', '次へ'),
              onPressed: _vm.isUploading ? null : _onNext,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static String _formatDateTime(DateTime? dt) {
    if (dt == null) return '-';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  static String _formatTime(DateTime? dt) {
    if (dt == null) return '--:--';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ---------------------------------------------------------------------------
// Dialog-level date picker widget
// ---------------------------------------------------------------------------

class _DialogDatePicker extends StatelessWidget {
  const _DialogDatePicker({
    required this.label,
    required this.value,
    required this.onPicked,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onPicked;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (date == null) return;
        if (!context.mounted) return;
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(value ?? DateTime.now()),
        );
        if (time == null) return;
        onPicked(
          DateTime(date.year, date.month, date.day, time.hour, time.minute),
        );
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(
          value != null
              ? '${value!.year}-${value!.month.toString().padLeft(2, '0')}-${value!.day.toString().padLeft(2, '0')} '
                  '${value!.hour.toString().padLeft(2, '0')}:${value!.minute.toString().padLeft(2, '0')}'
              : lt('选择', 'Select', '選択'),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dashed border painter (reused from editor screen pattern)
// ---------------------------------------------------------------------------

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
      const Radius.circular(16),
    );
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashWidth).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dashWidth + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color;
}
