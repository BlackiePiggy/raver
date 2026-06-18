import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_platform/raver_platform.dart';

import 'event_lineup_import_screen.dart';
import 'view_models/event_upload_view_model.dart';
import '../../_shared/discover_service_locator.dart';

class EventUploadFlowScreen extends StatefulWidget {
  const EventUploadFlowScreen({super.key});

  @override
  State<EventUploadFlowScreen> createState() => _EventUploadFlowScreenState();
}

class _EventUploadFlowScreenState extends State<EventUploadFlowScreen> {
  late final EventUploadViewModel _vm;
  bool _showDraftRestoreBanner = false;

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
    _restoreDraft();
  }

  Future<void> _restoreDraft() async {
    final restored = await _vm.restoreDraft();
    if (!mounted || !restored) return;
    _syncControllersFromViewModel();
    setState(() => _showDraftRestoreBanner = true);
  }

  void _onChanged() {
    if (!mounted) return;

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
    _vm.scheduleDraftSave();
  }

  void _syncControllersFromViewModel() {
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

  Future<void> _onNext() async {
    _syncBasicInfo();
    if (_vm.currentStep == EventUploadStep.tickets) {
      await _vm.submit();
    } else {
      _vm.nextStep();
    }
  }

  void _onBack() {
    _syncBasicInfo();
    if (_vm.currentStepIndex == 0) {
      _vm.scheduleDraftSave(immediate: true);
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
            if (_showDraftRestoreBanner && _vm.hasRestoredDraft)
              _buildDraftRestoreBanner(theme),
            Expanded(
              child: Stack(
                children: [
                  _vm.isSubmitted
                      ? _buildSubmissionSuccess(theme)
                      : _buildCurrentStep(theme),
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
            if (!_vm.isSubmitted) _buildBottomBar(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildDraftRestoreBanner(RaverThemeData theme) {
    final savedAt = _vm.lastSavedAt == null
        ? ''
        : lt(
            '保存于 ${_formatDateTime(_vm.lastSavedAt)}',
            'Saved ${_formatDateTime(_vm.lastSavedAt)}',
            '${_formatDateTime(_vm.lastSavedAt)} 保存',
          );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: theme.card,
        border: Border(bottom: BorderSide(color: theme.cardBorder)),
      ),
      child: Row(
        children: [
          Icon(Icons.history, size: 20, color: theme.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              lt('已恢复上次草稿', 'Draft restored', '下書きを復元しました') +
                  (savedAt.isEmpty ? '' : ' · $savedAt'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: RaverTypography.caption(color: theme.secondaryText),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _showDraftRestoreBanner = false),
            child: Text(lt('继续编辑', 'Keep', '続ける')),
          ),
          TextButton(
            onPressed: _discardRestoredDraft,
            child: Text(lt('丢弃', 'Discard', '破棄')),
          ),
        ],
      ),
    );
  }

  Future<void> _discardRestoredDraft() async {
    await _vm.discardDraft();
    if (!mounted) return;
    _syncControllersFromViewModel();
    setState(() => _showDraftRestoreBanner = false);
    ToastBanner.show(
      context,
      message: lt('已丢弃草稿', 'Draft discarded', '下書きを破棄しました'),
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
            initialValue: _vm.eventType,
            decoration: InputDecoration(
              labelText: lt('活动类型', 'Event Type', 'イベントタイプ'),
            ),
            items: _eventTypes
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                _vm.eventType = v;
                _vm.scheduleDraftSave();
                setState(() {});
              }
            },
          ),
          const SizedBox(height: 12),
          _buildDatePickerRow(
            theme,
            label: lt('开始时间', 'Start', '開始'),
            value: _vm.startDate,
            onPicked: (dt) {
              _vm.startDate = dt;
              _vm.scheduleDraftSave();
              setState(() {});
            },
          ),
          const SizedBox(height: 12),
          _buildDatePickerRow(
            theme,
            label: lt('结束时间', 'End', '終了'),
            value: _vm.endDate,
            onPicked: (dt) {
              _vm.endDate = dt;
              _vm.scheduleDraftSave();
              setState(() {});
            },
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

  // ---------------------------------------------------------------------------
  // Step 1: Poster
  // ---------------------------------------------------------------------------

  Widget _buildPosterStep(RaverThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lt('活动图片', 'Event Images', 'イベント画像'),
            style: RaverTypography.title(size: 18, color: theme.primaryText),
          ),
          const SizedBox(height: 8),
          Text(
            lt(
              '海报会优先作为活动主图，阵容图会写入 lineupImageUrl。',
              'Poster is used first as the event cover; lineup writes lineupImageUrl.',
              'ポスターが優先カバーになり、ラインナップ画像は lineupImageUrl に保存されます。',
            ),
            style: RaverTypography.caption(color: theme.secondaryText),
          ),
          const SizedBox(height: 18),
          _buildImageZoneCard(
            theme,
            zone: EventUploadImageZone.poster,
            title: lt('海报', 'Poster', 'ポスター'),
            subtitle: lt('活动主视觉', 'Primary event artwork', 'メイン画像'),
          ),
          const SizedBox(height: 14),
          _buildImageZoneCard(
            theme,
            zone: EventUploadImageZone.lineup,
            title: lt('阵容图', 'Lineup Image', 'ラインナップ画像'),
            subtitle: lt('DJ阵容或海报截图', 'DJ lineup or poster crop', 'DJラインナップ画像'),
          ),
          const SizedBox(height: 14),
          _buildImageZoneCard(
            theme,
            zone: EventUploadImageZone.cover,
            title: lt('封面', 'Cover', 'カバー'),
            subtitle: lt('无海报时作为封面备选', 'Fallback cover when no poster is set',
                'ポスターがない場合のカバー'),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildImageZoneCard(
    RaverThemeData theme, {
    required EventUploadImageZone zone,
    required String title,
    required String subtitle,
  }) {
    final assets = _vm.imageAssetsFor(zone);
    final uploadState = _vm.imageUploadStateFor(zone);
    final hasImage = assets.isNotEmpty;
    final hasUploadState = uploadState != null;
    final primaryUrl = hasImage ? assets.first.url : '';
    return Container(
      height: assets.length > 1
          ? (hasUploadState ? 298 : 246)
          : (hasUploadState ? 232 : 180),
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (hasImage)
                  GestureDetector(
                    onTap: () => _previewEventImages(zone, 0),
                    child: RemoteCoverImage(url: primaryUrl, fit: BoxFit.cover),
                  )
                else
                  GestureDetector(
                    onTap: () => _pickEventImage(zone),
                    child: CustomPaint(
                      painter: _DashedBorderPainter(color: theme.cardBorder),
                      child: Center(
                        child: Icon(
                          Icons.cloud_upload_outlined,
                          size: 38,
                          color: theme.secondaryText,
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
                          onPressed: () => _previewEventImages(zone, 0),
                        ),
                      if (hasImage) const SizedBox(width: 8),
                      _imageActionButton(
                        icon: Icons.add_photo_alternate_outlined,
                        label: lt('添加图片', 'Add image', '画像追加'),
                        onPressed: () => _pickEventImage(zone),
                      ),
                      if (hasImage) ...[
                        const SizedBox(width: 8),
                        _imageActionButton(
                          icon: Icons.delete_outline,
                          label: lt('删除主图', 'Remove primary', 'メイン削除'),
                          onPressed: () => _vm.removeImageAsset(zone, 0),
                        ),
                      ],
                    ],
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 14,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color:
                          Colors.black.withValues(alpha: hasImage ? 0.55 : 0),
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
                                    color: hasImage
                                        ? Colors.white
                                        : theme.primaryText,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  hasImage
                                      ? lt(
                                          '${assets.length} 张图片 · 第一张作为主图',
                                          '${assets.length} images · First image is primary',
                                          '${assets.length} 枚 · 先頭がメイン',
                                        )
                                      : subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: RaverTypography.caption(
                                    size: 12,
                                    color: hasImage
                                        ? Colors.white70
                                        : theme.secondaryText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(
                            hasImage
                                ? Icons.photo_library
                                : Icons.add_photo_alternate,
                            color: hasImage ? Colors.white : theme.accent,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (uploadState != null) _buildImageUploadStatus(theme, uploadState),
          if (assets.length > 1)
            SizedBox(
              height: 66,
              child: ListView.separated(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                scrollDirection: Axis.horizontal,
                itemCount: assets.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final asset = assets[index];
                  return SizedBox(
                    width: 138,
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => _previewEventImages(zone, index),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: RemoteCoverImage(
                                url: asset.url,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        _miniImageButton(
                          icon: Icons.chevron_left,
                          enabled: index > 0,
                          onPressed: () => _vm.reorderImageAsset(
                            zone,
                            oldIndex: index,
                            newIndex: index - 1,
                          ),
                        ),
                        _miniImageButton(
                          icon: Icons.chevron_right,
                          enabled: index < assets.length - 1,
                          onPressed: () => _vm.reorderImageAsset(
                            zone,
                            oldIndex: index,
                            newIndex: index + 1,
                          ),
                        ),
                        _miniImageButton(
                          icon: Icons.close,
                          enabled: true,
                          onPressed: () => _vm.removeImageAsset(zone, index),
                        ),
                      ],
                    ),
                  );
                },
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

  Widget _miniImageButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 26, height: 40),
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon, size: 18),
    );
  }

  Widget _buildImageUploadStatus(
    RaverThemeData theme,
    EventUploadImageUploadState state,
  ) {
    final isUploading = state.phase == EventUploadImageUploadPhase.uploading;
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.background,
        border: Border(top: BorderSide(color: theme.cardBorder)),
      ),
      child: Row(
        children: [
          Icon(
            isUploading ? Icons.cloud_upload_outlined : Icons.error_outline,
            size: 18,
            color: isUploading ? theme.accent : const Color(0xFFD93636),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${_uploadStateLabel(state.phase)} · ${state.fileName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RaverTypography.caption(color: theme.primaryText),
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: isUploading ? state.progress.clamp(0, 1) : null,
                  minHeight: 3,
                  backgroundColor: theme.cardBorder,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isUploading ? theme.accent : const Color(0xFFD93636),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isUploading)
            _miniImageButton(
              icon: Icons.close,
              enabled: true,
              onPressed: () => _vm.cancelImageUpload(state.zone),
            )
          else
            _miniImageButton(
              icon: Icons.refresh,
              enabled: state.canRetry,
              onPressed: () => _vm.retryImageUpload(state.zone),
            ),
        ],
      ),
    );
  }

  String _uploadStateLabel(EventUploadImageUploadPhase phase) =>
      switch (phase) {
        EventUploadImageUploadPhase.uploading =>
          lt('上传中', 'Uploading', 'アップロード中'),
        EventUploadImageUploadPhase.failed =>
          lt('上传失败', 'Upload failed', 'アップロード失敗'),
        EventUploadImageUploadPhase.cancelled =>
          lt('已取消', 'Cancelled', 'キャンセル済み'),
      };

  Future<void> _pickEventImage(EventUploadImageZone zone) async {
    final path = await MediaPickerService.pickImage();
    if (path == null) return;
    await _vm.uploadEventImage(zone, path);
  }

  Future<void> _previewEventImages(EventUploadImageZone zone, int index) async {
    final urls = _vm.imageAssetsFor(zone).map((asset) => asset.url).toList();
    if (urls.isEmpty) return;
    await MediaPreviewOverlay.show(
      context,
      mediaUrls: urls,
      initialIndex: index.clamp(0, urls.length - 1).toInt(),
      heroTagPrefix: 'event-upload-${zone.name}',
    );
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
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: PrimaryButton(
                      label: lt('AI导入', 'AI Import', 'AI取込'),
                      variant: PrimaryButtonVariant.outline,
                      onPressed: _openLineupImport,
                      isExpanded: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton.filled(
                    tooltip: lt('添加DJ', 'Add DJ', 'DJ追加'),
                    style: IconButton.styleFrom(
                      backgroundColor: theme.accent,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _showAddLineupDialog(theme),
                    icon: const Icon(Icons.add),
                  ),
                ],
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
                                  onPressed: () => _vm.removeLineupEntry(index),
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
      ],
    );
  }

  Future<void> _openLineupImport() async {
    _syncBasicInfo();
    final imported = await Navigator.of(context).push<List<LineupEntry>>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => EventLineupImportScreen(
          startDate: _vm.startDate,
          endDate: _vm.endDate,
        ),
      ),
    );
    if (!mounted || imported == null || imported.isEmpty) return;
    final added = _vm.addLineupEntries(imported);
    ToastBanner.show(
      context,
      message: added == 0
          ? lt(
              '导入结果已在阵容中',
              'Imported DJs are already in the lineup',
              'インポート結果は既にラインナップにあります',
            )
          : lt(
              '已导入 $added 位DJ',
              'Imported $added DJs',
              '$added 人のDJをインポートしました',
            ),
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
    final visibleEntries = _vm.visibleScheduleEntries;
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
              if (_vm.lineupArtistsMissingFromSchedule.isNotEmpty) ...[
                const SizedBox(height: 12),
                PrimaryButton(
                  label: lt(
                    '从时间表补齐阵容 (${_vm.lineupArtistsMissingFromSchedule.length})',
                    'Fill lineup from schedule (${_vm.lineupArtistsMissingFromSchedule.length})',
                    'タイムテーブルから補完 (${_vm.lineupArtistsMissingFromSchedule.length})',
                  ),
                  variant: PrimaryButtonVariant.outline,
                  onPressed: _fillLineupFromSchedule,
                  isExpanded: true,
                ),
              ],
              const SizedBox(height: 12),
              _buildScheduleFilters(theme),
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
                    : visibleEntries.isEmpty
                        ? Center(
                            child: Text(
                              lt(
                                '当前筛选下暂无排程',
                                'No slots for this filter',
                                'この条件のスロットはありません',
                              ),
                              style: RaverTypography.body(
                                size: 14,
                                color: theme.secondaryText,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: visibleEntries.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = visibleEntries[index];
                              return _buildScheduleEntryTile(
                                theme,
                                index: item.index,
                                entry: item.entry,
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

  Widget _buildScheduleFilters(RaverThemeData theme) {
    final days = _vm.scheduleDayOptions;
    final stages = _vm.scheduleStageOptions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (days.isNotEmpty)
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: days.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _scheduleFilterChip(
                    theme,
                    label: lt('全部日期', 'All days', '全日'),
                    selected: _vm.selectedScheduleDayKey == null,
                    onSelected: () => _vm.selectScheduleDay(null),
                  );
                }
                final day = days[index - 1];
                return _scheduleFilterChip(
                  theme,
                  label: '${day.label} · ${_formatMonthDay(day.date)}',
                  selected: _vm.selectedScheduleDayKey == day.key,
                  onSelected: () => _vm.selectScheduleDay(day.key),
                );
              },
            ),
          ),
        if (stages.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: stages.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _scheduleFilterChip(
                    theme,
                    label: lt('全部舞台', 'All stages', '全ステージ'),
                    selected: _vm.selectedScheduleStage == null,
                    onSelected: () => _vm.selectScheduleStage(null),
                  );
                }
                final stage = stages[index - 1];
                return _scheduleFilterChip(
                  theme,
                  label: stage,
                  selected: _vm.selectedScheduleStage == stage,
                  onSelected: () => _vm.selectScheduleStage(stage),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _scheduleFilterChip(
    RaverThemeData theme, {
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      labelStyle: RaverTypography.caption(
        color: selected ? Colors.white : theme.secondaryText,
        weight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      selectedColor: theme.accent,
      backgroundColor: theme.card,
      side: BorderSide(color: selected ? theme.accent : theme.cardBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      showCheckmark: false,
    );
  }

  Widget _buildScheduleEntryTile(
    RaverThemeData theme, {
    required int index,
    required ScheduleEntry entry,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.cardBorder),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatTime(entry.startTime),
                  style: RaverTypography.label(
                    size: 15,
                    color: theme.primaryText,
                    weight: FontWeight.w700,
                  ),
                ),
                Text(
                  _formatTime(entry.endTime),
                  style: RaverTypography.caption(color: theme.secondaryText),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(width: 3, height: 44, color: theme.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.djName.trim().isEmpty ? '-' : entry.djName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RaverTypography.label(
                    size: 15,
                    color: theme.primaryText,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.stageName.trim().isEmpty ? 'Main Stage' : entry.stageName} · ${entry.startTime == null ? '-' : _formatMonthDay(entry.startTime!)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RaverTypography.caption(color: theme.secondaryText),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: lt('移动', 'Move', '移動'),
            icon:
                Icon(Icons.drive_file_move_outline, color: theme.secondaryText),
            onPressed: () => _showMoveScheduleSheet(theme, index, entry),
          ),
          IconButton(
            tooltip: lt('删除', 'Delete', '削除'),
            icon: Icon(Icons.delete_outline, color: theme.secondaryText),
            onPressed: () => _vm.removeScheduleEntry(index),
          ),
        ],
      ),
    );
  }

  Future<void> _showMoveScheduleSheet(
    RaverThemeData theme,
    int index,
    ScheduleEntry entry,
  ) async {
    final stages = _vm.scheduleStageOptions;
    final stageCtrl = TextEditingController(
      text: entry.stageName.trim().isEmpty ? 'Main Stage' : entry.stageName,
    );
    String? selectedDayKey = entry.startTime == null
        ? _vm.selectedScheduleDayKey
        : '${entry.startTime!.year}-${entry.startTime!.month.toString().padLeft(2, '0')}-${entry.startTime!.day.toString().padLeft(2, '0')}';
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lt('移动排程', 'Move slot', 'スロット移動'),
                      style: RaverTypography.title(
                        size: 18,
                        color: theme.primaryText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedDayKey,
                      decoration: InputDecoration(
                        labelText: lt('日期', 'Day', '日付'),
                      ),
                      items: _vm.scheduleDayOptions
                          .map(
                            (day) => DropdownMenuItem(
                              value: day.key,
                              child: Text(
                                '${day.label} · ${_formatMonthDay(day.date)}',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setSheetState(() => selectedDayKey = value),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: stageCtrl,
                      decoration: InputDecoration(
                        labelText: lt('舞台', 'Stage', 'ステージ'),
                        suffixIcon: stages.isEmpty
                            ? null
                            : PopupMenuButton<String>(
                                icon: const Icon(Icons.arrow_drop_down),
                                onSelected: (value) => stageCtrl.text = value,
                                itemBuilder: (_) => [
                                  for (final stage in stages)
                                    PopupMenuItem(
                                      value: stage,
                                      child: Text(stage),
                                    ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: lt('保存', 'Save', '保存'),
                      onPressed: () {
                        _vm.moveScheduleEntry(
                          index: index,
                          dayKey: selectedDayKey,
                          stageName: stageCtrl.text,
                        );
                        Navigator.pop(ctx);
                      },
                      isExpanded: true,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    stageCtrl.dispose();
  }

  void _fillLineupFromSchedule() {
    final added = _vm.fillLineupFromSchedule();
    ToastBanner.show(
      context,
      message: added == 0
          ? lt(
              '时间表里的DJ已在阵容中',
              'All timetable DJs are already in the lineup',
              'タイムテーブルのDJは既にラインナップにあります',
            )
          : lt(
              '已补齐 $added 位DJ',
              'Added $added DJs',
              '$added 人のDJを追加しました',
            ),
    );
  }

  Future<void> _showAddScheduleDialog(RaverThemeData theme) async {
    final selectedDate = _vm.selectedScheduleDayDate;
    final selectedStage = _vm.selectedScheduleStage;
    final stageCtrl = TextEditingController(text: selectedStage ?? '');
    final djCtrl = TextEditingController();
    DateTime? startTime = selectedDate == null
        ? null
        : DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 22);
    DateTime? endTime = selectedDate == null
        ? null
        : DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 23);

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
                      onPicked: (dt) => setDialogState(() => startTime = dt),
                    ),
                    const SizedBox(height: 12),
                    _DialogDatePicker(
                      label: lt('结束时间', 'End', '終了'),
                      value: endTime,
                      onPicked: (dt) => setDialogState(() => endTime = dt),
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
          if (_vm.validationIssues.isNotEmpty) ...[
            _buildValidationIssuesCard(theme),
            const SizedBox(height: 20),
          ],
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
                  if (_vm.lineupArtistsMissingFromSchedule.isNotEmpty)
                    _reviewRow(
                      theme,
                      lt('待补齐', 'Missing', '補完待ち'),
                      '${_vm.lineupArtistsMissingFromSchedule.length} ${lt('位DJ', 'DJs', 'DJs')}',
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

  Widget _buildValidationIssuesCard(RaverThemeData theme) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 20,
                  color: Color(0xFFD93636),
                ),
                const SizedBox(width: 8),
                Text(
                  lt('需要修正', 'Needs attention', '修正が必要です'),
                  style: RaverTypography.label(
                    size: 15,
                    color: theme.primaryText,
                    weight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._vm.validationIssues.map(
              (issue) => InkWell(
                onTap: () {
                  _vm.goToStep(issue.step);
                  setState(() {});
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_stepTitle(issue.step)} · ${issue.message}',
                          style: RaverTypography.body(
                            size: 14,
                            color: theme.primaryText,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right, color: theme.secondaryText),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmissionSuccess(RaverThemeData theme) {
    final event = _vm.createdEvent;
    final eventId = event?.id ?? '';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 42),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: theme.accent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_rounded, size: 42, color: theme.accent),
          ),
          const SizedBox(height: 22),
          Text(
            lt('活动已提交', 'Event submitted', 'イベントを送信しました'),
            textAlign: TextAlign.center,
            style: RaverTypography.title(size: 22, color: theme.primaryText),
          ),
          const SizedBox(height: 8),
          Text(
            lt(
              '我们已收到你的活动信息。审核通过后会进入活动详情页和列表。',
              'Your event has been received. Once approved, it will appear in event detail and lists.',
              'イベント情報を受け取りました。承認後、詳細と一覧に表示されます。',
            ),
            textAlign: TextAlign.center,
            style: RaverTypography.body(size: 14, color: theme.secondaryText),
          ),
          const SizedBox(height: 24),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _reviewRow(
                    theme,
                    lt('标题', 'Title', 'タイトル'),
                    event?.name.isNotEmpty == true ? event!.name : _vm.title,
                  ),
                  _reviewRow(
                    theme,
                    lt('状态', 'Status', 'ステータス'),
                    lt('已提交审核', 'Submitted for review', '審査中'),
                  ),
                  if (eventId.isNotEmpty) _reviewRow(theme, 'ID', eventId),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (eventId.isNotEmpty) ...[
            PrimaryButton(
              label: lt('查看活动', 'View Event', 'イベントを見る'),
              onPressed: () => context.go('/events/$eventId'),
              isExpanded: true,
            ),
            const SizedBox(height: 12),
          ],
          PrimaryButton(
            label: lt('完成', 'Done', '完了'),
            variant: PrimaryButtonVariant.outline,
            onPressed: () => context.pop(true),
            isExpanded: true,
          ),
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
              label:
                  isLast ? lt('提交', 'Submit', '送信') : lt('下一步', 'Next', '次へ'),
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

  static String _formatMonthDay(DateTime dt) {
    return '${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
  }

  String _stepTitle(EventUploadStep step) => switch (step) {
        EventUploadStep.basicInfo => lt('基本信息', 'Basic Info', '基本情報'),
        EventUploadStep.poster => lt('活动图片', 'Event Images', 'イベント画像'),
        EventUploadStep.lineup => lt('阵容', 'Lineup', 'ラインナップ'),
        EventUploadStep.schedule => lt('时间表', 'Schedule', 'スケジュール'),
        EventUploadStep.tickets => lt('票务', 'Tickets', 'チケット'),
      };
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
