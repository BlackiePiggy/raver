import 'package:flutter/foundation.dart';

import '../../data/events_api_service.dart';
import 'event_upload_view_model.dart';

class EventEditorViewModel extends ChangeNotifier {
  EventEditorViewModel({required EventsApiService api, String? eventId})
      : _api = api,
        _eventId = eventId;

  final EventsApiService _api;

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  String? _eventId;
  String? get eventId => _eventId;

  bool get isEditMode => _eventId != null;

  String _title = '';
  String get title => _title;

  String _description = '';
  String get description => _description;

  String _eventType = 'club_night';
  String get eventType => _eventType;

  DateTime? _startDate;
  DateTime? get startDate => _startDate;

  DateTime? _endDate;
  DateTime? get endDate => _endDate;

  String _timezone = '';
  String get timezone => _timezone;

  String _venueName = '';
  String get venueName => _venueName;

  String _venueCity = '';
  String get venueCity => _venueCity;

  String _venueCountry = '';
  String get venueCountry => _venueCountry;

  double? _venueLatitude;
  double? get venueLatitude => _venueLatitude;

  double? _venueLongitude;
  double? get venueLongitude => _venueLongitude;

  String _ticketUrl = '';
  String get ticketUrl => _ticketUrl;

  int? _maxCapacity;
  int? get maxCapacity => _maxCapacity;

  String? _posterUrl;
  String? get posterUrl => _posterUrl;

  String? _lineupImageUrl;
  String? get lineupImageUrl => _lineupImageUrl;

  String? get coverImageUrl => imageUrl(EventUploadImageZone.cover);

  final Map<EventUploadImageZone, List<EventUploadImageAsset>> _imageAssets =
      {};
  List<EventUploadImageAsset> get imageAssets => List.unmodifiable(
        EventUploadImageZone.values.expand(imageAssetsFor),
      );

  List<EventUploadImageAsset> imageAssetsFor(EventUploadImageZone zone) =>
      List.unmodifiable(_imageAssets[zone] ?? const []);

  String? imageUrl(EventUploadImageZone zone) =>
      imageAssetsFor(zone).isEmpty ? null : imageAssetsFor(zone).first.url;

  final List<LineupEntry> _lineup = [];
  List<LineupEntry> get lineup => List.unmodifiable(_lineup);

  final List<ScheduleEntry> _schedule = [];
  List<ScheduleEntry> get schedule => List.unmodifiable(_schedule);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _isSaved = false;
  bool get isSaved => _isSaved;

  // ---------------------------------------------------------------------------
  // Load (edit mode)
  // ---------------------------------------------------------------------------

  Future<void> loadEvent(String id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final event = await _api.fetchEvent(id: id);
      _eventId = id;
      _title = event.name;
      _description = event.description;
      _eventType = event.eventType;
      _startDate = DateTime.tryParse(event.startDate);
      _endDate = DateTime.tryParse(event.endDate);
      _timezone = event.schedule?.timezoneId ?? '';
      _venueName = event.location?.name ?? '';
      _venueCity = event.location?.city ?? '';
      _venueCountry = event.location?.country ?? '';
      _venueLatitude = event.location?.latitude;
      _venueLongitude = event.location?.longitude;
      _ticketUrl = event.ticketUrl ?? '';
      _maxCapacity = event.maxCapacity;
      _posterUrl = event.coverImageUrl;
      _lineupImageUrl = event.lineupImageUrl;
      _restoreImageAssets(
        posterUrl: event.coverImageUrl,
        lineupImageUrl: event.lineupImageUrl,
      );
      _lineup
        ..clear()
        ..addAll(
          (event.lineupArtists ?? const []).map(
            (artist) => LineupEntry(
              djId: artist.djId,
              djName: artist.name,
              isB2B: artist.isB2B,
            ),
          ),
        );
      _schedule
        ..clear()
        ..addAll(
          (event.lineupSlots ?? const []).map(
            (slot) => ScheduleEntry(
              stageId: slot.id,
              stageName: slot.stageName,
              startTime: DateTime.tryParse(slot.startTime),
              endTime: DateTime.tryParse(slot.endTime),
              djId: slot.djId,
              djName: slot.artistName,
            ),
          ),
        );
    } catch (e) {
      _errorMessage = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Field updates
  // ---------------------------------------------------------------------------

  void updateTitle(String value) {
    _title = value;
    notifyListeners();
  }

  void updateDescription(String value) {
    _description = value;
    notifyListeners();
  }

  void updateEventType(String value) {
    _eventType = value;
    notifyListeners();
  }

  void updateStartDate(DateTime? value) {
    _startDate = value;
    notifyListeners();
  }

  void updateEndDate(DateTime? value) {
    _endDate = value;
    notifyListeners();
  }

  void updateTimezone(String value) {
    _timezone = value;
    notifyListeners();
  }

  void updateVenueName(String value) {
    _venueName = value;
    notifyListeners();
  }

  void updateVenueCity(String value) {
    _venueCity = value;
    notifyListeners();
  }

  void updateVenueCountry(String value) {
    _venueCountry = value;
    notifyListeners();
  }

  void updateVenueLatitude(double? value) {
    _venueLatitude = value;
    notifyListeners();
  }

  void updateVenueLongitude(double? value) {
    _venueLongitude = value;
    notifyListeners();
  }

  void updateTicketUrl(String value) {
    _ticketUrl = value;
    notifyListeners();
  }

  void updateMaxCapacity(int? value) {
    _maxCapacity = value;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Poster upload
  // ---------------------------------------------------------------------------

  Future<void> uploadPoster(String localPath) async {
    await uploadEventImage(EventUploadImageZone.poster, localPath);
  }

  Future<void> uploadEventImage(
    EventUploadImageZone zone,
    String localPath,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final url = await _api.uploadEventPoster(
        localPath,
        eventId: _eventId,
        usage: zone.name,
      );
      if (zone == EventUploadImageZone.poster) {
        _posterUrl = url;
      } else if (zone == EventUploadImageZone.lineup) {
        _lineupImageUrl = url;
      }
      _setImageAsset(
        zone,
        url: url,
        fileName: _fileNameFromPath(localPath),
      );
    } catch (e) {
      _errorMessage = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  void removeImageAsset(EventUploadImageZone zone) {
    _imageAssets.remove(zone);
    if (zone == EventUploadImageZone.poster) {
      _posterUrl = null;
    } else if (zone == EventUploadImageZone.lineup) {
      _lineupImageUrl = null;
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Save
  // ---------------------------------------------------------------------------

  Future<void> save() async {
    _isLoading = true;
    _errorMessage = null;
    _isSaved = false;
    notifyListeners();

    try {
      final payload = buildPayload();
      if (isEditMode) {
        await _api.updateEvent(_eventId!, payload);
      } else {
        final created = await _api.createEvent(payload);
        _eventId = created.id;
      }
      _isSaved = true;
    } catch (e) {
      _errorMessage = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  Map<String, dynamic> buildPayload() {
    final uploadModel = EventUploadViewModel(api: _api)
      ..title = _title
      ..description = _description
      ..eventType = _eventType
      ..startDate = _startDate
      ..endDate = _endDate
      ..timezone = _timezone
      ..venueName = _venueName
      ..venueCity = _venueCity
      ..venueCountry = _venueCountry
      ..venueLatitude = _venueLatitude
      ..venueLongitude = _venueLongitude
      ..ticketUrl = _ticketUrl
      ..maxCapacity = _maxCapacity;
    try {
      uploadModel.addLineupEntries(_lineup);
      for (final slot in _schedule) {
        uploadModel.addScheduleEntry(
          stageId: slot.stageId,
          stageName: slot.stageName,
          startTime: slot.startTime,
          endTime: slot.endTime,
          djId: slot.djId,
          djName: slot.djName,
        );
      }
      final payload = uploadModel.buildCreatePayload();
      final primaryCoverUrl = _posterUrl ?? coverImageUrl;
      if (primaryCoverUrl != null && primaryCoverUrl.trim().isNotEmpty) {
        payload['coverImageUrl'] = primaryCoverUrl;
      }
      if (_lineupImageUrl != null && _lineupImageUrl!.trim().isNotEmpty) {
        payload['lineupImageUrl'] = _lineupImageUrl;
      }
      if (imageAssets.isNotEmpty) {
        payload['imageAssets'] = imageAssets
            .asMap()
            .entries
            .map((entry) => entry.value.toJson(entry.key + 1))
            .toList();
      }
      return payload;
    } finally {
      uploadModel.dispose();
    }
  }

  void _restoreImageAssets({
    required String posterUrl,
    required String lineupImageUrl,
  }) {
    _imageAssets.clear();
    if (posterUrl.trim().isNotEmpty) {
      _setImageAsset(
        EventUploadImageZone.poster,
        url: posterUrl,
        fileName: 'event-poster.jpg',
      );
    }
    if (lineupImageUrl.trim().isNotEmpty) {
      _setImageAsset(
        EventUploadImageZone.lineup,
        url: lineupImageUrl,
        fileName: 'event-lineup.jpg',
      );
    }
  }

  void _setImageAsset(
    EventUploadImageZone zone, {
    required String url,
    required String fileName,
  }) {
    _imageAssets[zone] = [
      EventUploadImageAsset(
        zone: zone,
        url: url,
        sortOrder: EventUploadImageZone.values.indexOf(zone) + 1,
        fileName: fileName,
      ),
    ];
  }
}

String _fileNameFromPath(String path) {
  final normalized = path.replaceAll('\\', '/');
  final fileName = normalized.split('/').last.trim();
  return fileName.isEmpty ? 'event-image.jpg' : fileName;
}
