import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:raver_models/raver_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/events_api_service.dart';

/// Steps for the multi-step event upload wizard.
enum EventUploadStep { basicInfo, poster, lineup, schedule, tickets }

enum EventUploadImageUploadPhase {
  uploading,
  failed,
  cancelled;
}

class EventUploadImageUploadState {
  const EventUploadImageUploadState({
    required this.zone,
    required this.localPath,
    required this.fileName,
    required this.phase,
    this.progress = 0,
    this.errorMessage,
  });

  final EventUploadImageZone zone;
  final String localPath;
  final String fileName;
  final EventUploadImageUploadPhase phase;
  final double progress;
  final String? errorMessage;

  bool get isUploading => phase == EventUploadImageUploadPhase.uploading;
  bool get canRetry =>
      phase == EventUploadImageUploadPhase.failed ||
      phase == EventUploadImageUploadPhase.cancelled;

  EventUploadImageUploadState copyWith({
    EventUploadImageUploadPhase? phase,
    double? progress,
    String? errorMessage,
  }) =>
      EventUploadImageUploadState(
        zone: zone,
        localPath: localPath,
        fileName: fileName,
        phase: phase ?? this.phase,
        progress: progress ?? this.progress,
        errorMessage: errorMessage,
      );
}

class EventUploadValidationIssue {
  const EventUploadValidationIssue({
    required this.step,
    required this.message,
    required this.fieldLabel,
  });

  final EventUploadStep step;
  final String message;
  final String fieldLabel;
}

enum EventUploadImageZone {
  poster,
  lineup,
  cover;

  String get backendType => switch (this) {
        EventUploadImageZone.poster => 'poster',
        EventUploadImageZone.lineup => 'luall',
        EventUploadImageZone.cover => 'cover',
      };

  String get defaultLabel => switch (this) {
        EventUploadImageZone.poster => 'POSTER',
        EventUploadImageZone.lineup => 'LINE-UP',
        EventUploadImageZone.cover => 'COVER',
      };
}

class EventUploadImageAsset {
  EventUploadImageAsset({
    required this.zone,
    required this.url,
    required this.sortOrder,
    required this.fileName,
  });

  final EventUploadImageZone zone;
  final String url;
  final int sortOrder;
  final String fileName;

  Map<String, dynamic> toJson(int order) => {
        'url': url,
        'type': zone.backendType,
        'label': zone.defaultLabel,
        'sort': order,
        'order': order,
        'source': 'flutter-event-upload',
        'fileName': fileName,
      };

  Map<String, dynamic> toDraftJson() => {
        'zone': zone.name,
        'url': url,
        'sortOrder': sortOrder,
        'fileName': fileName,
      };

  factory EventUploadImageAsset.fromDraftJson(Map<String, dynamic> json) {
    final zoneName = json['zone'] as String? ?? '';
    return EventUploadImageAsset(
      zone: EventUploadImageZone.values.firstWhere(
        (zone) => zone.name == zoneName,
        orElse: () => EventUploadImageZone.poster,
      ),
      url: json['url'] as String? ?? '',
      sortOrder: _intFromJson(json['sortOrder']) ?? 1,
      fileName: json['fileName'] as String? ?? 'event-image.jpg',
    );
  }
}

/// A single lineup entry in the wizard.
class LineupEntry {
  LineupEntry({this.djId = '', this.djName = '', this.isB2B = false});

  String djId;
  String djName;
  bool isB2B;

  Map<String, dynamic> toJson() => {
        if (djId.isNotEmpty) 'djId': djId,
        'djName': djName,
        'isB2B': isB2B,
      };

  Map<String, dynamic> toLineupArtistJson(int sortOrder) => {
        if (djId.isNotEmpty) 'djId': djId,
        if (djId.isNotEmpty) 'memberDjIds': [djId],
        'memberNames': [djName],
        'djName': djName,
        'sortOrder': sortOrder,
      };

  factory LineupEntry.fromJson(Map<String, dynamic> json) => LineupEntry(
        djId: json['djId'] as String? ?? '',
        djName: json['djName'] as String? ?? '',
        isB2B: json['isB2B'] as bool? ?? false,
      );
}

/// A single schedule slot in the wizard.
class ScheduleEntry {
  ScheduleEntry({
    this.stageId = '',
    this.stageName = '',
    this.startTime,
    this.endTime,
    this.djId = '',
    this.djName = '',
  });

  String stageId;
  String stageName;
  DateTime? startTime;
  DateTime? endTime;
  String djId;
  String djName;

  Map<String, dynamic> toJson() => {
        if (stageId.isNotEmpty) 'stageId': stageId,
        'stageName': stageName,
        if (startTime != null) 'startTime': startTime!.toIso8601String(),
        if (endTime != null) 'endTime': endTime!.toIso8601String(),
        if (djId.isNotEmpty) 'djId': djId,
        'djName': djName,
      };

  Map<String, dynamic> toLineupSlotJson({
    required int sortOrder,
    required _EventDayInfo? eventDay,
  }) {
    final resolvedEndTime = _normalizedSlotEndTime(startTime, endTime);
    final normalizedStageName = stageName.trim();
    final normalizedDjName = djName.trim();
    final normalizedDjId = djId.trim();
    return {
      if (stageId.trim().isNotEmpty) 'id': stageId.trim(),
      if (eventDay != null) ...{
        'eventDayId': eventDay.eventDayId,
        'weekIndex': eventDay.weekIndex,
        'dayIndexInWeek': eventDay.dayIndexInWeek,
        'overallDayIndex': eventDay.overallDayIndex,
        'localDate': eventDay.dateText,
      },
      if (normalizedDjId.isNotEmpty) 'djId': normalizedDjId,
      if (normalizedDjId.isNotEmpty) 'memberDjIds': [normalizedDjId],
      if (normalizedDjName.isNotEmpty) 'memberNames': [normalizedDjName],
      'djName': normalizedDjName,
      'stageName':
          normalizedStageName.isEmpty ? 'Main Stage' : normalizedStageName,
      'sortOrder': sortOrder,
      if (startTime != null) 'startTime': _localDateTimeText(startTime!),
      if (resolvedEndTime != null)
        'endTime': _localDateTimeText(resolvedEndTime),
    };
  }

  factory ScheduleEntry.fromJson(Map<String, dynamic> json) => ScheduleEntry(
        stageId: json['stageId'] as String? ?? '',
        stageName: json['stageName'] as String? ?? '',
        startTime: _dateTimeFromJson(json['startTime']),
        endTime: _dateTimeFromJson(json['endTime']),
        djId: json['djId'] as String? ?? '',
        djName: json['djName'] as String? ?? '',
      );
}

class ScheduleDayOption {
  const ScheduleDayOption({
    required this.key,
    required this.label,
    required this.date,
  });

  final String key;
  final String label;
  final DateTime date;
}

class IndexedScheduleEntry {
  const IndexedScheduleEntry({
    required this.index,
    required this.entry,
  });

  final int index;
  final ScheduleEntry entry;
}

class EventUploadViewModel extends ChangeNotifier {
  EventUploadViewModel({
    required EventsApiService api,
    String draftKey = _defaultDraftKey,
  })  : _api = api,
        _draftKey = draftKey;

  static const _defaultDraftKey = 'event_upload_draft.create.default';

  final EventsApiService _api;
  final String _draftKey;
  Timer? _draftSaveTimer;

  // ---------------------------------------------------------------------------
  // Wizard state
  // ---------------------------------------------------------------------------

  EventUploadStep _currentStep = EventUploadStep.basicInfo;
  EventUploadStep get currentStep => _currentStep;

  int get currentStepIndex => EventUploadStep.values.indexOf(_currentStep);
  int get totalSteps => EventUploadStep.values.length;

  bool _isUploading = false;
  bool get isUploading => _isUploading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _isSubmitted = false;
  bool get isSubmitted => _isSubmitted;

  WebEvent? _createdEvent;
  WebEvent? get createdEvent => _createdEvent;

  bool _hasRestoredDraft = false;
  bool get hasRestoredDraft => _hasRestoredDraft;

  DateTime? _lastSavedAt;
  DateTime? get lastSavedAt => _lastSavedAt;

  List<EventUploadValidationIssue> _validationIssues = const [];
  List<EventUploadValidationIssue> get validationIssues =>
      List.unmodifiable(_validationIssues);

  // ---------------------------------------------------------------------------
  // Basic info fields
  // ---------------------------------------------------------------------------

  String title = '';
  String description = '';
  String eventType = 'club_night';
  DateTime? startDate;
  DateTime? endDate;
  String timezone = '';
  String venueName = '';
  String venueCity = '';
  String venueCountry = '';
  double? venueLatitude;
  double? venueLongitude;
  String ticketUrl = '';
  int? maxCapacity;

  // ---------------------------------------------------------------------------
  // Poster
  // ---------------------------------------------------------------------------

  final Map<EventUploadImageZone, List<EventUploadImageAsset>> _imageAssets =
      {};
  final Map<EventUploadImageZone, EventUploadImageUploadState>
      _imageUploadStates = {};
  final Map<EventUploadImageZone, CancelToken> _imageUploadCancelTokens = {};

  String? get posterUrl => imageUrl(EventUploadImageZone.poster);
  String? get lineupImageUrl => imageUrl(EventUploadImageZone.lineup);
  String? get coverImageUrl => imageUrl(EventUploadImageZone.cover);
  List<EventUploadImageAsset> get imageAssets => List.unmodifiable(
        EventUploadImageZone.values.expand(imageAssetsFor),
      );

  List<EventUploadImageAsset> imageAssetsFor(EventUploadImageZone zone) =>
      List.unmodifiable(_imageAssets[zone] ?? const []);

  EventUploadImageUploadState? imageUploadStateFor(
    EventUploadImageZone zone,
  ) =>
      _imageUploadStates[zone];

  String? imageUrl(EventUploadImageZone zone) =>
      imageAssetsFor(zone).firstOrNull?.url;

  Future<void> uploadPoster(String localPath) async {
    await uploadEventImage(EventUploadImageZone.poster, localPath);
  }

  Future<void> uploadEventImage(
    EventUploadImageZone zone,
    String localPath,
  ) async {
    _imageUploadCancelTokens[zone]?.cancel('superseded');
    final cancelToken = CancelToken();
    _imageUploadCancelTokens[zone] = cancelToken;
    _imageUploadStates[zone] = EventUploadImageUploadState(
      zone: zone,
      localPath: localPath,
      fileName: _fileNameFromPath(localPath),
      phase: EventUploadImageUploadPhase.uploading,
    );
    _errorMessage = null;
    notifyListeners();

    try {
      final url = await _api.uploadEventPoster(
        localPath,
        usage: zone.name,
        cancelToken: cancelToken,
        onSendProgress: (sent, total) {
          if (total <= 0 || _imageUploadCancelTokens[zone] != cancelToken) {
            return;
          }
          _imageUploadStates[zone] = _imageUploadStates[zone]?.copyWith(
                progress: (sent / total).clamp(0, 1).toDouble(),
              ) ??
              EventUploadImageUploadState(
                zone: zone,
                localPath: localPath,
                fileName: _fileNameFromPath(localPath),
                phase: EventUploadImageUploadPhase.uploading,
                progress: (sent / total).clamp(0, 1).toDouble(),
              );
          notifyListeners();
        },
      );
      if (_imageUploadCancelTokens[zone] != cancelToken) return;
      final assets = _imageAssets.putIfAbsent(zone, () => []);
      assets.add(
        EventUploadImageAsset(
          zone: zone,
          url: url,
          sortOrder: assets.length + 1,
          fileName: _fileNameFromPath(localPath),
        ),
      );
      _imageUploadStates.remove(zone);
      scheduleDraftSave();
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        _imageUploadStates[zone] = _imageUploadStates[zone]?.copyWith(
              phase: EventUploadImageUploadPhase.cancelled,
              errorMessage: '已取消上传',
            ) ??
            EventUploadImageUploadState(
              zone: zone,
              localPath: localPath,
              fileName: _fileNameFromPath(localPath),
              phase: EventUploadImageUploadPhase.cancelled,
              errorMessage: '已取消上传',
            );
      } else {
        _errorMessage = e.toString();
        _imageUploadStates[zone] = _imageUploadStates[zone]?.copyWith(
              phase: EventUploadImageUploadPhase.failed,
              errorMessage: e.toString(),
            ) ??
            EventUploadImageUploadState(
              zone: zone,
              localPath: localPath,
              fileName: _fileNameFromPath(localPath),
              phase: EventUploadImageUploadPhase.failed,
              errorMessage: e.toString(),
            );
      }
    } finally {
      if (_imageUploadCancelTokens[zone] == cancelToken) {
        _imageUploadCancelTokens.remove(zone);
      }
      notifyListeners();
    }
  }

  void cancelImageUpload(EventUploadImageZone zone) {
    final token = _imageUploadCancelTokens.remove(zone);
    token?.cancel('cancelled by user');
    final state = _imageUploadStates[zone];
    if (state != null && state.isUploading) {
      _imageUploadStates[zone] = state.copyWith(
        phase: EventUploadImageUploadPhase.cancelled,
        errorMessage: '已取消上传',
      );
      notifyListeners();
    }
  }

  Future<void> retryImageUpload(EventUploadImageZone zone) async {
    final state = _imageUploadStates[zone];
    if (state == null || !state.canRetry) return;
    await uploadEventImage(zone, state.localPath);
  }

  void removeImageAsset(EventUploadImageZone zone, int index) {
    final assets = _imageAssets[zone];
    if (assets == null || index < 0 || index >= assets.length) return;
    assets.removeAt(index);
    if (assets.isEmpty) {
      _imageAssets.remove(zone);
    } else {
      _imageAssets[zone] = _renumberImageAssets(assets);
    }
    scheduleDraftSave();
    notifyListeners();
  }

  void reorderImageAsset(
    EventUploadImageZone zone, {
    required int oldIndex,
    required int newIndex,
  }) {
    final assets = _imageAssets[zone];
    if (assets == null ||
        oldIndex < 0 ||
        oldIndex >= assets.length ||
        newIndex < 0 ||
        newIndex >= assets.length ||
        oldIndex == newIndex) {
      return;
    }
    final reordered = List<EventUploadImageAsset>.from(assets);
    final item = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, item);
    _imageAssets[zone] = _renumberImageAssets(reordered);
    scheduleDraftSave();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Lineup
  // ---------------------------------------------------------------------------

  final List<LineupEntry> _lineup = [];
  List<LineupEntry> get lineup => List.unmodifiable(_lineup);

  void addLineupEntry({
    required String djName,
    String djId = '',
    bool isB2B = false,
  }) {
    final normalizedName = djName.trim();
    if (normalizedName.isEmpty) return;
    _lineup.add(
      LineupEntry(djId: djId.trim(), djName: normalizedName, isB2B: isB2B),
    );
    scheduleDraftSave();
    notifyListeners();
  }

  int addLineupEntries(Iterable<LineupEntry> entries) {
    var added = 0;
    final seen = _lineup.map(_lineupIdentityKey).toSet();
    for (final entry in entries) {
      final normalizedName = entry.djName.trim();
      if (normalizedName.isEmpty) continue;
      final normalizedEntry = LineupEntry(
        djId: entry.djId.trim(),
        djName: normalizedName,
        isB2B: entry.isB2B,
      );
      final key = _lineupIdentityKey(normalizedEntry);
      if (seen.contains(key)) continue;
      seen.add(key);
      _lineup.add(normalizedEntry);
      added += 1;
    }
    if (added > 0) {
      scheduleDraftSave();
      notifyListeners();
    }
    return added;
  }

  void removeLineupEntry(int index) {
    if (index >= 0 && index < _lineup.length) {
      _lineup.removeAt(index);
      scheduleDraftSave();
      notifyListeners();
    }
  }

  List<String> get lineupArtistsMissingFromSchedule {
    final lineupKeys = _lineup.map(_lineupIdentityKey).toSet();
    final missing = <String>[];
    final seen = <String>{};
    for (final entry in _schedule) {
      final normalizedName = entry.djName.trim();
      if (normalizedName.isEmpty) continue;
      final key = _lineupIdentityKey(
        LineupEntry(djId: entry.djId, djName: normalizedName),
      );
      if (lineupKeys.contains(key) || seen.contains(key)) continue;
      seen.add(key);
      missing.add(normalizedName);
    }
    return missing;
  }

  int fillLineupFromSchedule() {
    return addLineupEntries(
      _schedule.map(
        (slot) => LineupEntry(djId: slot.djId, djName: slot.djName),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Schedule
  // ---------------------------------------------------------------------------

  final List<ScheduleEntry> _schedule = [];
  List<ScheduleEntry> get schedule => List.unmodifiable(_schedule);

  String? _selectedScheduleDayKey;
  String? get selectedScheduleDayKey => _selectedScheduleDayKey;

  String? _selectedScheduleStage;
  String? get selectedScheduleStage => _selectedScheduleStage;

  List<ScheduleDayOption> get scheduleDayOptions {
    final days = _buildEventDays(
      start: startDate ?? _earliestScheduleTime(),
      end: endDate ?? _latestScheduleTime() ?? startDate,
    );
    return [
      for (final day in days)
        ScheduleDayOption(
          key: day.dateText,
          label: 'Day ${day.overallDayIndex}',
          date: DateTime.parse(day.dateText),
        ),
    ];
  }

  DateTime? get selectedScheduleDayDate {
    final key = _selectedScheduleDayKey;
    if (key == null) return null;
    for (final option in scheduleDayOptions) {
      if (option.key == key) return option.date;
    }
    return null;
  }

  List<String> get scheduleStageOptions {
    final stages = <String>[];
    for (final entry in _schedule) {
      final stageName = _normalizedStageName(entry.stageName);
      if (!stages.contains(stageName)) stages.add(stageName);
    }
    if (_selectedScheduleStage != null &&
        !stages.contains(_selectedScheduleStage)) {
      _selectedScheduleStage = null;
    }
    return List.unmodifiable(stages);
  }

  List<IndexedScheduleEntry> get visibleScheduleEntries {
    return _schedule.asMap().entries.where((entry) {
      final slot = entry.value;
      final selectedDay = _selectedScheduleDayKey;
      if (selectedDay != null && _scheduleDateKey(slot) != selectedDay) {
        return false;
      }
      final selectedStage = _selectedScheduleStage;
      if (selectedStage != null &&
          _normalizedStageName(slot.stageName) != selectedStage) {
        return false;
      }
      return true;
    }).map((entry) {
      return IndexedScheduleEntry(index: entry.key, entry: entry.value);
    }).toList();
  }

  void selectScheduleDay(String? key) {
    final normalizedKey =
        key != null && scheduleDayOptions.any((option) => option.key == key)
            ? key
            : null;
    if (_selectedScheduleDayKey == normalizedKey) return;
    _selectedScheduleDayKey = normalizedKey;
    notifyListeners();
  }

  void selectScheduleStage(String? stageName) {
    final normalizedStage =
        stageName == null ? null : _normalizedStageName(stageName);
    if (_selectedScheduleStage == normalizedStage) return;
    _selectedScheduleStage = normalizedStage;
    notifyListeners();
  }

  void addScheduleEntry({
    required String stageName,
    required DateTime? startTime,
    required DateTime? endTime,
    String djName = '',
    String stageId = '',
    String djId = '',
  }) {
    _schedule.add(
      ScheduleEntry(
        stageId: stageId,
        stageName: stageName,
        startTime: startTime,
        endTime: endTime,
        djId: djId,
        djName: djName,
      ),
    );
    scheduleDraftSave();
    notifyListeners();
  }

  void removeScheduleEntry(int index) {
    if (index >= 0 && index < _schedule.length) {
      _schedule.removeAt(index);
      scheduleDraftSave();
      notifyListeners();
    }
  }

  void moveScheduleEntry({
    required int index,
    String? dayKey,
    String? stageName,
  }) {
    if (index < 0 || index >= _schedule.length) return;
    final entry = _schedule[index];
    final targetDate =
        dayKey == null ? null : scheduleDayOptions.firstWhereOrNull(dayKey);
    if (targetDate != null) {
      entry.startTime = _moveDateTimeToDate(entry.startTime, targetDate.date);
      entry.endTime = _moveDateTimeToDate(entry.endTime, targetDate.date);
    }
    if (stageName != null && stageName.trim().isNotEmpty) {
      entry.stageName = _normalizedStageName(stageName);
    }
    scheduleDraftSave();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  void nextStep() {
    final idx = currentStepIndex;
    if (idx < totalSteps - 1) {
      _currentStep = EventUploadStep.values[idx + 1];
      scheduleDraftSave(immediate: true);
      notifyListeners();
    }
  }

  void prevStep() {
    final idx = currentStepIndex;
    if (idx > 0) {
      _currentStep = EventUploadStep.values[idx - 1];
      scheduleDraftSave(immediate: true);
      notifyListeners();
    }
  }

  void goToStep(EventUploadStep step) {
    if (_currentStep == step) return;
    _currentStep = step;
    scheduleDraftSave(immediate: true);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Submit
  // ---------------------------------------------------------------------------

  Future<bool> submit() async {
    final issues = validateForSubmit();
    if (issues.isNotEmpty) {
      _validationIssues = issues;
      _currentStep = issues.first.step;
      _errorMessage = issues.first.message;
      notifyListeners();
      return false;
    }

    _isUploading = true;
    _errorMessage = null;
    _isSubmitted = false;
    _createdEvent = null;
    notifyListeners();

    try {
      _createdEvent = await _api.createEvent(buildCreatePayload());
      _isSubmitted = true;
      await clearDraft();
      _validationIssues = const [];
      _isUploading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isUploading = false;
      notifyListeners();
      return false;
    }
  }

  List<EventUploadValidationIssue> validateForSubmit() {
    final issues = <EventUploadValidationIssue>[];
    if (title.trim().isEmpty) {
      issues.add(
        const EventUploadValidationIssue(
          step: EventUploadStep.basicInfo,
          fieldLabel: 'Title',
          message: '请填写活动标题',
        ),
      );
    }
    if (startDate == null) {
      issues.add(
        const EventUploadValidationIssue(
          step: EventUploadStep.basicInfo,
          fieldLabel: 'Start',
          message: '请选择开始时间',
        ),
      );
    }
    if (endDate == null) {
      issues.add(
        const EventUploadValidationIssue(
          step: EventUploadStep.basicInfo,
          fieldLabel: 'End',
          message: '请选择结束时间',
        ),
      );
    }
    if (startDate != null && endDate != null && endDate!.isBefore(startDate!)) {
      issues.add(
        const EventUploadValidationIssue(
          step: EventUploadStep.basicInfo,
          fieldLabel: 'End',
          message: '结束时间不能早于开始时间',
        ),
      );
    }
    if (venueName.trim().isEmpty) {
      issues.add(
        const EventUploadValidationIssue(
          step: EventUploadStep.basicInfo,
          fieldLabel: 'Venue',
          message: '请填写场地名称',
        ),
      );
    }
    if (_imageUploadStates.values.any((state) => state.isUploading)) {
      issues.add(
        const EventUploadValidationIssue(
          step: EventUploadStep.poster,
          fieldLabel: 'Images',
          message: '请等待图片上传完成',
        ),
      );
    }
    return issues;
  }

  void scheduleDraftSave({bool immediate = false}) {
    _draftSaveTimer?.cancel();
    if (immediate) {
      unawaited(saveDraft());
      return;
    }
    _draftSaveTimer = Timer(
      const Duration(milliseconds: 600),
      () => unawaited(saveDraft()),
    );
  }

  Future<void> saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_draftKey, jsonEncode(toDraftJson()));
    _lastSavedAt = DateTime.now();
    notifyListeners();
  }

  Future<bool> restoreDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey);
    if (raw == null || raw.trim().isEmpty) return false;
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return false;
    _restoreFromDraftJson(decoded);
    _hasRestoredDraft = true;
    _lastSavedAt = _dateTimeFromJson(decoded['updatedAt']);
    notifyListeners();
    return true;
  }

  Future<void> clearDraft() async {
    _draftSaveTimer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
    _hasRestoredDraft = false;
    _lastSavedAt = null;
  }

  Future<void> discardDraft() async {
    await clearDraft();
    _resetForm();
    notifyListeners();
  }

  Map<String, dynamic> toDraftJson() => {
        'schemaVersion': 1,
        'updatedAt': DateTime.now().toIso8601String(),
        'currentStep': currentStep.name,
        'title': title,
        'description': description,
        'eventType': eventType,
        if (startDate != null) 'startDate': startDate!.toIso8601String(),
        if (endDate != null) 'endDate': endDate!.toIso8601String(),
        'timezone': timezone,
        'venueName': venueName,
        'venueCity': venueCity,
        'venueCountry': venueCountry,
        if (venueLatitude != null) 'venueLatitude': venueLatitude,
        if (venueLongitude != null) 'venueLongitude': venueLongitude,
        'ticketUrl': ticketUrl,
        if (maxCapacity != null) 'maxCapacity': maxCapacity,
        'imageAssets': imageAssets.map((asset) => asset.toDraftJson()).toList(),
        'lineup': _lineup.map((entry) => entry.toJson()).toList(),
        'schedule': _schedule.map((entry) => entry.toJson()).toList(),
      };

  void _restoreFromDraftJson(Map<String, dynamic> json) {
    title = json['title'] as String? ?? '';
    description = json['description'] as String? ?? '';
    eventType = json['eventType'] as String? ?? 'club_night';
    startDate = _dateTimeFromJson(json['startDate']);
    endDate = _dateTimeFromJson(json['endDate']);
    timezone = json['timezone'] as String? ?? '';
    venueName = json['venueName'] as String? ?? '';
    venueCity = json['venueCity'] as String? ?? '';
    venueCountry = json['venueCountry'] as String? ?? '';
    venueLatitude = _doubleFromJson(json['venueLatitude']);
    venueLongitude = _doubleFromJson(json['venueLongitude']);
    ticketUrl = json['ticketUrl'] as String? ?? '';
    maxCapacity = _intFromJson(json['maxCapacity']);

    final rawStep = json['currentStep'] as String? ?? '';
    _currentStep = EventUploadStep.values.firstWhere(
      (step) => step.name == rawStep,
      orElse: () => EventUploadStep.basicInfo,
    );

    _imageAssets
      ..clear()
      ..addAll(_imageAssetsFromDraft(json['imageAssets']));
    _lineup
      ..clear()
      ..addAll(
        (json['lineup'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(LineupEntry.fromJson)
            .where((entry) => entry.djName.trim().isNotEmpty),
      );
    _schedule
      ..clear()
      ..addAll(
        (json['schedule'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(ScheduleEntry.fromJson),
      );
  }

  void _resetForm() {
    _currentStep = EventUploadStep.basicInfo;
    _isUploading = false;
    for (final token in _imageUploadCancelTokens.values) {
      token.cancel('form reset');
    }
    _imageUploadCancelTokens.clear();
    _imageUploadStates.clear();
    _errorMessage = null;
    _isSubmitted = false;
    _createdEvent = null;
    _validationIssues = const [];
    title = '';
    description = '';
    eventType = 'club_night';
    startDate = null;
    endDate = null;
    timezone = '';
    venueName = '';
    venueCity = '';
    venueCountry = '';
    venueLatitude = null;
    venueLongitude = null;
    ticketUrl = '';
    maxCapacity = null;
    _imageAssets.clear();
    _lineup.clear();
    _schedule.clear();
  }

  Map<String, dynamic> buildCreatePayload() {
    final resolvedTimeZone = timezone.trim().isEmpty ? 'UTC' : timezone.trim();
    final resolvedStartDate = startDate ?? _earliestScheduleTime();
    final resolvedEndDate =
        endDate ?? _latestScheduleTime() ?? resolvedStartDate;
    final eventDays = _buildEventDays(
      start: resolvedStartDate,
      end: resolvedEndDate,
    );
    final eventDayByDate = {
      for (final day in eventDays) day.dateText: day,
    };
    final lineupSlots = _schedule
        .asMap()
        .entries
        .where((entry) => entry.value.djName.trim().isNotEmpty)
        .map((entry) {
      final slot = entry.value;
      final day = slot.startTime == null
          ? eventDays.firstOrNull
          : eventDayByDate[_dateText(slot.startTime!)] ?? eventDays.firstOrNull;
      return slot.toLineupSlotJson(sortOrder: entry.key + 1, eventDay: day);
    }).toList();
    final stageOrder = _stageOrder();

    return <String, dynamic>{
      'name': title,
      'description': description,
      'eventType': eventType,
      if (resolvedStartDate != null) 'startDate': _dateText(resolvedStartDate),
      if (resolvedEndDate != null) 'endDate': _dateText(resolvedEndDate),
      'schedule': {
        'mode': eventDays.length > 1 ? 'multi_day' : 'single_day',
        'timeZone': resolvedTimeZone,
        'dayRolloverHour': 6,
      },
      if (eventDays.isNotEmpty) ...{
        'weeks': [
          {
            'id': 'draft-week-1',
            'weekIndex': 1,
            'startDate': eventDays.first.dateText,
            'endDate': eventDays.last.dateText,
            'sortOrder': 1,
          },
        ],
        'eventDays': eventDays.map((day) => day.toJson()).toList(),
      },
      'timeZone': resolvedTimeZone,
      'dayRolloverHour': 6,
      if (stageOrder.isNotEmpty) 'stageOrder': stageOrder,
      'location': {
        'name': venueName,
        'city': venueCity,
        'country': venueCountry,
        if (venueLatitude != null) 'latitude': venueLatitude,
        if (venueLongitude != null) 'longitude': venueLongitude,
      },
      if (_primaryCoverUrl != null) 'coverImageUrl': _primaryCoverUrl,
      if (lineupImageUrl != null) 'lineupImageUrl': lineupImageUrl,
      if (imageAssets.isNotEmpty)
        'imageAssets': imageAssets
            .asMap()
            .entries
            .map((entry) => entry.value.toJson(entry.key + 1))
            .toList(),
      if (ticketUrl.isNotEmpty) 'ticketUrl': ticketUrl,
      if (maxCapacity != null) 'maxCapacity': maxCapacity,
      if (_lineup.isNotEmpty)
        'lineupArtists': _lineup
            .asMap()
            .entries
            .map((entry) => entry.value.toLineupArtistJson(entry.key + 1))
            .toList(),
      if (lineupSlots.isNotEmpty) 'lineupSlots': lineupSlots,
      if (_lineup.isNotEmpty || lineupSlots.isNotEmpty)
        'lineupSyncMode': 'incremental_fill',
    };
  }

  DateTime? _earliestScheduleTime() {
    final times = _schedule
        .map((entry) => entry.startTime)
        .whereType<DateTime>()
        .toList()
      ..sort();
    return times.firstOrNull;
  }

  DateTime? _latestScheduleTime() {
    final times = _schedule
        .map((entry) => _normalizedSlotEndTime(entry.startTime, entry.endTime))
        .whereType<DateTime>()
        .toList()
      ..sort();
    return times.lastOrNull;
  }

  List<String> _stageOrder() {
    final stages = <String>[];
    for (final entry in _schedule) {
      final stageName = entry.stageName.trim().isEmpty
          ? 'Main Stage'
          : entry.stageName.trim();
      if (!stages.contains(stageName)) stages.add(stageName);
    }
    return stages;
  }

  String? get _primaryCoverUrl => posterUrl ?? coverImageUrl;

  @override
  void dispose() {
    _draftSaveTimer?.cancel();
    for (final token in _imageUploadCancelTokens.values) {
      token.cancel('disposed');
    }
    super.dispose();
  }
}

String _lineupIdentityKey(LineupEntry entry) {
  final id = entry.djId.trim().toLowerCase();
  if (id.isNotEmpty) return 'id:$id';
  return 'name:${entry.djName.trim().toLowerCase()}';
}

String _normalizedStageName(String value) {
  final normalized = value.trim();
  return normalized.isEmpty ? 'Main Stage' : normalized;
}

String? _scheduleDateKey(ScheduleEntry entry) {
  final start = entry.startTime;
  if (start == null) return null;
  return _dateText(start);
}

DateTime? _moveDateTimeToDate(DateTime? value, DateTime date) {
  if (value == null) return null;
  return DateTime(
    date.year,
    date.month,
    date.day,
    value.hour,
    value.minute,
    value.second,
    value.millisecond,
    value.microsecond,
  );
}

List<EventUploadImageAsset> _renumberImageAssets(
  List<EventUploadImageAsset> assets,
) {
  return assets
      .asMap()
      .entries
      .map(
        (entry) => EventUploadImageAsset(
          zone: entry.value.zone,
          url: entry.value.url,
          sortOrder: entry.key + 1,
          fileName: entry.value.fileName,
        ),
      )
      .toList();
}

Map<EventUploadImageZone, List<EventUploadImageAsset>> _imageAssetsFromDraft(
  Object? value,
) {
  final grouped = <EventUploadImageZone, List<EventUploadImageAsset>>{};
  for (final asset in (value as List<dynamic>? ?? [])
      .whereType<Map<String, dynamic>>()
      .map(EventUploadImageAsset.fromDraftJson)
      .where((asset) => asset.url.trim().isNotEmpty)) {
    grouped.putIfAbsent(asset.zone, () => []).add(asset);
  }
  return {
    for (final entry in grouped.entries)
      entry.key: _renumberImageAssets(
        [...entry.value]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
      ),
  };
}

DateTime? _normalizedSlotEndTime(DateTime? start, DateTime? end) {
  if (start == null || end == null) return end;
  if (end.isAfter(start)) return end;
  return end.add(const Duration(days: 1));
}

List<_EventDayInfo> _buildEventDays({DateTime? start, DateTime? end}) {
  if (start == null) return const [];
  final normalizedEnd = end == null || end.isBefore(start) ? start : end;
  final startDate = DateTime(start.year, start.month, start.day);
  final endDate = DateTime(
    normalizedEnd.year,
    normalizedEnd.month,
    normalizedEnd.day,
  );
  final days = <_EventDayInfo>[];
  var cursor = startDate;
  while (!cursor.isAfter(endDate)) {
    final index = days.length + 1;
    days.add(
      _EventDayInfo(
        eventDayId: 'd$index',
        weekIndex: 1,
        dayIndexInWeek: index,
        overallDayIndex: index,
        dateText: _dateText(cursor),
      ),
    );
    cursor = cursor.add(const Duration(days: 1));
  }
  return days;
}

String _dateText(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${value.year}-${twoDigits(value.month)}-${twoDigits(value.day)}';
}

String _localDateTimeText(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${_dateText(value)}T${twoDigits(value.hour)}:${twoDigits(value.minute)}:${twoDigits(value.second)}';
}

String _fileNameFromPath(String path) {
  final normalized = path.replaceAll('\\', '/');
  final fileName = normalized.split('/').last.trim();
  return fileName.isEmpty ? 'event-image.jpg' : fileName;
}

DateTime? _dateTimeFromJson(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return DateTime.tryParse(value);
}

double? _doubleFromJson(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

int? _intFromJson(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

class _EventDayInfo {
  const _EventDayInfo({
    required this.eventDayId,
    required this.weekIndex,
    required this.dayIndexInWeek,
    required this.overallDayIndex,
    required this.dateText,
  });

  final String eventDayId;
  final int weekIndex;
  final int dayIndexInWeek;
  final int overallDayIndex;
  final String dateText;

  Map<String, dynamic> toJson() => {
        'id': 'draft-$eventDayId',
        'eventDayId': eventDayId,
        'weekIndex': weekIndex,
        'dayIndexInWeek': dayIndexInWeek,
        'overallDayIndex': overallDayIndex,
        'label': 'Day $overallDayIndex',
        'date': dateText,
        'sortOrder': overallDayIndex,
      };
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

extension _ScheduleDayLookup on List<ScheduleDayOption> {
  ScheduleDayOption? firstWhereOrNull(String key) {
    for (final option in this) {
      if (option.key == key) return option;
    }
    return null;
  }
}
