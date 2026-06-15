import 'package:flutter/foundation.dart';
import 'package:raver_models/raver_models.dart';

import '../../data/set_api.dart';

/// ViewModel for DJ-Set create / edit flows.
///
/// When [setId] is non-null the view model operates in *edit* mode:
/// [loadSet] fetches the existing record. Otherwise it starts empty.
class SetEditorViewModel extends ChangeNotifier {
  SetEditorViewModel({required SetApi setApi}) : _setApi = setApi;

  final SetApi _setApi;

  // ---- state ----

  String? _setId;
  String? get setId => _setId;

  String _title = '';
  String get title => _title;

  String _description = '';
  String get description => _description;

  String? _djId;
  String? get djId => _djId;

  String? _eventId;
  String? get eventId => _eventId;

  DateTime? _recordedAt;
  DateTime? get recordedAt => _recordedAt;

  int? _duration;
  int? get duration => _duration;

  String _audioUrl = '';
  String get audioUrl => _audioUrl;

  String _videoUrl = '';
  String get videoUrl => _videoUrl;

  List<Map<String, dynamic>> _tracklist = [];
  List<Map<String, dynamic>> get tracklist =>
      List<Map<String, dynamic>>.unmodifiable(_tracklist);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _isSaved = false;
  bool get isSaved => _isSaved;

  // ---- loading ----

  Future<void> loadSet(String id) async {
    _setId = id;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final djSet = await _setApi.fetchSet(id);
      _title = djSet.title;
      _description = djSet.description;
      _djId = djSet.djId.isNotEmpty ? djSet.djId : null;
      _eventId = djSet.eventId.isNotEmpty ? djSet.eventId : null;
      _duration = djSet.duration > 0 ? djSet.duration : null;
      _audioUrl = djSet.audioUrl;
      _videoUrl = djSet.videoUrl;

      if (djSet.tracks != null) {
        _tracklist = djSet.tracks!
            .map((t) => <String, dynamic>{
                  'title': t.title,
                  'artist': t.artist,
                  'startSecond': _parseStartTime(t.startTime),
                })
            .toList();
      }
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  int _parseStartTime(String startTime) {
    if (startTime.isEmpty) return 0;
    final parts = startTime.split(':');
    if (parts.length == 2) {
      return (int.tryParse(parts[0]) ?? 0) * 60 +
          (int.tryParse(parts[1]) ?? 0);
    }
    if (parts.length == 3) {
      return (int.tryParse(parts[0]) ?? 0) * 3600 +
          (int.tryParse(parts[1]) ?? 0) * 60 +
          (int.tryParse(parts[2]) ?? 0);
    }
    return int.tryParse(startTime) ?? 0;
  }

  // ---- field setters ----

  void setTitle(String value) {
    _title = value;
    notifyListeners();
  }

  void setDescription(String value) {
    _description = value;
    notifyListeners();
  }

  void setDjId(String? value) {
    _djId = value;
    notifyListeners();
  }

  void setEventId(String? value) {
    _eventId = value;
    notifyListeners();
  }

  void setRecordedAt(DateTime? value) {
    _recordedAt = value;
    notifyListeners();
  }

  void setDuration(int? value) {
    _duration = value;
    notifyListeners();
  }

  // ---- media uploads ----

  Future<void> uploadAudio(String localPath) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final url = await _setApi.uploadSetAudio(localPath);
      _audioUrl = url;
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> uploadVideo(String localPath) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final url = await _setApi.uploadSetVideo(localPath);
      _videoUrl = url;
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  // ---- tracklist management ----

  void addTrack({
    required String title,
    String? artist,
    int startSecond = 0,
  }) {
    _tracklist.add({
      'title': title,
      'artist': artist ?? '',
      'startSecond': startSecond,
    });
    notifyListeners();
  }

  void removeTrack(int index) {
    if (index < 0 || index >= _tracklist.length) return;
    _tracklist.removeAt(index);
    notifyListeners();
  }

  void reorderTrack(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = _tracklist.removeAt(oldIndex);
    _tracklist.insert(newIndex, item);
    notifyListeners();
  }

  // ---- save ----

  Future<void> save() async {
    if (_isLoading) return;
    _isLoading = true;
    _isSaved = false;
    _errorMessage = null;
    notifyListeners();

    try {
      final payload = <String, dynamic>{
        'title': _title,
        'description': _description,
        if (_djId != null && _djId!.isNotEmpty) 'djId': _djId,
        if (_eventId != null && _eventId!.isNotEmpty) 'eventId': _eventId,
        if (_recordedAt != null) 'recordedAt': _recordedAt!.toIso8601String(),
        if (_duration != null) 'duration': _duration,
        'audioUrl': _audioUrl,
        'videoUrl': _videoUrl,
        'tracklist': _tracklist,
      };

      if (_setId != null) {
        await _setApi.updateSet(_setId!, payload);
      } else {
        final created = await _setApi.createSet(payload);
        _setId = created.id;
      }
      _isSaved = true;
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }
}
