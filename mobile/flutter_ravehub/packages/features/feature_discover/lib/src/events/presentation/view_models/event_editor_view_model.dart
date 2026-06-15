import 'package:flutter/foundation.dart';
import 'package:raver_models/raver_models.dart';

import '../../data/events_api_service.dart';

class EventEditorViewModel extends ChangeNotifier {
  EventEditorViewModel({
    required EventsApiService api,
    String? eventId,
  })  : _api = api,
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
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final url = await _api.uploadEventPoster(localPath);
      _posterUrl = url;
    } catch (e) {
      _errorMessage = e.toString();
    }
    _isLoading = false;
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
      final payload = _buildPayload();
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

  Map<String, dynamic> _buildPayload() {
    return {
      'name': _title,
      'description': _description,
      'eventType': _eventType,
      if (_startDate != null) 'startDate': _startDate!.toIso8601String(),
      if (_endDate != null) 'endDate': _endDate!.toIso8601String(),
      if (_timezone.isNotEmpty) 'timezone': _timezone,
      'location': {
        'name': _venueName,
        'city': _venueCity,
        'country': _venueCountry,
        if (_venueLatitude != null) 'latitude': _venueLatitude,
        if (_venueLongitude != null) 'longitude': _venueLongitude,
      },
      if (_posterUrl != null) 'coverImageUrl': _posterUrl,
      if (_ticketUrl.isNotEmpty) 'ticketUrl': _ticketUrl,
      if (_maxCapacity != null) 'maxCapacity': _maxCapacity,
    };
  }
}
