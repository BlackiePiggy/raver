import 'package:flutter/foundation.dart';
import 'package:raver_models/raver_models.dart';
import 'package:raver_design_system/raver_design_system.dart';

import '../data/events_repository.dart';

class EventDetailViewModel extends ChangeNotifier {
  EventDetailViewModel({
    required String eventId,
    required EventsRepository repository,
  })  : _eventId = eventId,
        _repository = repository;

  final String _eventId;
  final EventsRepository _repository;

  LoadPhase<WebEvent> _phase = const LoadPhase.loading();
  LoadPhase<WebEvent> get phase => _phase;

  WebEvent? _event;
  WebEvent? get event => _event;

  List<WebEventLineupArtist> _lineup = [];
  List<WebEventLineupArtist> get lineup => _lineup;

  List<WebEventLineupSlot> _timetable = [];
  List<WebEventLineupSlot> get timetable => _timetable;

  bool _isFavorited = false;
  bool get isFavorited => _isFavorited;

  bool _isTogglingFavorite = false;
  bool get isTogglingFavorite => _isTogglingFavorite;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _phase = const LoadPhase.loading();
    notifyListeners();

    try {
      final event = await _repository.fetchEvent(id: _eventId);
      _event = event;
      _isFavorited = event.isFavorited ?? false;
      _phase = LoadPhase.success(event);
      notifyListeners();

      await _loadSecondaryData();
    } catch (e) {
      _phase = LoadPhase.failure(e);
      notifyListeners();
    }
  }

  Future<void> _loadSecondaryData() async {
    try {
      final results = await Future.wait([
        _repository.fetchEventLineup(eventId: _eventId),
        _repository.fetchEventTimetable(eventId: _eventId),
      ]);
      _lineup = results[0] as List<WebEventLineupArtist>;
      _timetable = results[1] as List<WebEventLineupSlot>;
      notifyListeners();
    } catch (_) {
      // Non-critical; the detail view still shows without lineup/timetable.
    }
  }

  Future<void> toggleFavorite() async {
    if (_isTogglingFavorite) return;
    _isTogglingFavorite = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _repository.toggleFavorite(
        eventId: _eventId,
        currentlyFavorited: _isFavorited,
      );
      _isFavorited = result;
    } catch (e) {
      _errorMessage = e.toString();
    }
    _isTogglingFavorite = false;
    notifyListeners();
  }
}
