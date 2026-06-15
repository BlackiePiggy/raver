import 'package:flutter/foundation.dart';
import 'package:raver_models/raver_models.dart';

import '../../data/events_api_service.dart';

/// Steps for the multi-step event upload wizard.
enum EventUploadStep {
  basicInfo,
  poster,
  lineup,
  schedule,
  tickets,
}

/// A single lineup entry in the wizard.
class LineupEntry {
  LineupEntry({
    this.djId = '',
    this.djName = '',
    this.isB2B = false,
  });

  String djId;
  String djName;
  bool isB2B;

  Map<String, dynamic> toJson() => {
        if (djId.isNotEmpty) 'djId': djId,
        'djName': djName,
        'isB2B': isB2B,
      };
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
}

class EventUploadViewModel extends ChangeNotifier {
  EventUploadViewModel({required EventsApiService api}) : _api = api;

  final EventsApiService _api;

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

  String? _posterUrl;
  String? get posterUrl => _posterUrl;

  Future<void> uploadPoster(String localPath) async {
    _isUploading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final url = await _api.uploadEventPoster(localPath);
      _posterUrl = url;
    } catch (e) {
      _errorMessage = e.toString();
    }
    _isUploading = false;
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
    _lineup.add(LineupEntry(djId: djId, djName: djName, isB2B: isB2B));
    notifyListeners();
  }

  void removeLineupEntry(int index) {
    if (index >= 0 && index < _lineup.length) {
      _lineup.removeAt(index);
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Schedule
  // ---------------------------------------------------------------------------

  final List<ScheduleEntry> _schedule = [];
  List<ScheduleEntry> get schedule => List.unmodifiable(_schedule);

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
    notifyListeners();
  }

  void removeScheduleEntry(int index) {
    if (index >= 0 && index < _schedule.length) {
      _schedule.removeAt(index);
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  void nextStep() {
    final idx = currentStepIndex;
    if (idx < totalSteps - 1) {
      _currentStep = EventUploadStep.values[idx + 1];
      notifyListeners();
    }
  }

  void prevStep() {
    final idx = currentStepIndex;
    if (idx > 0) {
      _currentStep = EventUploadStep.values[idx - 1];
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Submit
  // ---------------------------------------------------------------------------

  Future<void> submit() async {
    _isUploading = true;
    _errorMessage = null;
    _isSubmitted = false;
    notifyListeners();

    try {
      final payload = <String, dynamic>{
        'name': title,
        'description': description,
        'eventType': eventType,
        if (startDate != null) 'startDate': startDate!.toIso8601String(),
        if (endDate != null) 'endDate': endDate!.toIso8601String(),
        if (timezone.isNotEmpty) 'timezone': timezone,
        'location': {
          'name': venueName,
          'city': venueCity,
          'country': venueCountry,
          if (venueLatitude != null) 'latitude': venueLatitude,
          if (venueLongitude != null) 'longitude': venueLongitude,
        },
        if (_posterUrl != null) 'coverImageUrl': _posterUrl,
        if (ticketUrl.isNotEmpty) 'ticketUrl': ticketUrl,
        if (maxCapacity != null) 'maxCapacity': maxCapacity,
        if (_lineup.isNotEmpty)
          'lineup': _lineup.map((e) => e.toJson()).toList(),
        if (_schedule.isNotEmpty)
          'schedule': _schedule.map((e) => e.toJson()).toList(),
      };

      await _api.createEvent(payload);
      _isSubmitted = true;
    } catch (e) {
      _errorMessage = e.toString();
    }
    _isUploading = false;
    notifyListeners();
  }
}
