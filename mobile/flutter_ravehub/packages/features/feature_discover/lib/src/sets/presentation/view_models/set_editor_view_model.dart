import 'package:flutter/foundation.dart';

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

  String _djName = '';
  String get djName => _djName;

  String? _eventId;
  String? get eventId => _eventId;

  String _eventName = '';
  String get eventName => _eventName;

  String _venue = '';
  String get venue => _venue;

  DateTime? _recordedAt;
  DateTime? get recordedAt => _recordedAt;

  int? _duration;
  int? get duration => _duration;

  String _audioUrl = '';
  String get audioUrl => _audioUrl;

  String _videoUrl = '';
  String get videoUrl => _videoUrl;

  String _videoAuthorName = '';
  String get videoAuthorName => _videoAuthorName;

  String _thumbnailUrl = '';
  String get thumbnailUrl => _thumbnailUrl;

  String _previewTitle = '';
  String get previewTitle => _previewTitle;

  bool _isPreviewingVideo = false;
  bool get isPreviewingVideo => _isPreviewingVideo;

  bool _rightsConfirmed = false;
  bool get rightsConfirmed => _rightsConfirmed;

  List<Map<String, dynamic>> _tracklist = [];
  List<Map<String, dynamic>> get tracklist =>
      List<Map<String, dynamic>>.unmodifiable(_tracklist);

  bool _tracklistDirty = false;

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
      _djName = djSet.djName;
      _eventId = djSet.eventId.isNotEmpty ? djSet.eventId : null;
      _eventName = djSet.eventName;
      _venue = djSet.venue;
      _duration = djSet.duration > 0 ? djSet.duration : null;
      _audioUrl = djSet.audioUrl;
      _videoUrl = djSet.videoUrl;
      _videoAuthorName = djSet.videoAuthorName;
      _thumbnailUrl = djSet.thumbnailUrl;
      _rightsConfirmed = true;

      if (djSet.tracks != null) {
        _tracklist = djSet.tracks!
            .map(
              (t) => <String, dynamic>{
                'title': t.title,
                'artist': t.artist,
                'startSecond': _parseStartTime(t.startTime),
                'endSecond': t.endTime,
                'status': t.status.isNotEmpty ? t.status : 'released',
                'spotifyUrl': t.spotifyUrl,
                'neteaseUrl': t.neteaseUrl,
              },
            )
            .toList();
      }
      _tracklistDirty = false;
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
      return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
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

  void setDjSelection({String? id, required String name}) {
    _djId = id?.isNotEmpty == true ? id : null;
    _djName = name;
    notifyListeners();
  }

  void setEventId(String? value) {
    _eventId = value;
    notifyListeners();
  }

  void setEventName(String value) {
    _eventName = value;
    notifyListeners();
  }

  void setVenue(String value) {
    _venue = value;
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

  void setVideoUrl(String value) {
    _videoUrl = value;
    if (value.trim() != _lastPreviewedVideoUrl) {
      _previewTitle = '';
      _videoAuthorName = '';
    }
    notifyListeners();
  }

  void setThumbnailUrl(String value) {
    _thumbnailUrl = value;
    notifyListeners();
  }

  void setRightsConfirmed(bool value) {
    _rightsConfirmed = value;
    notifyListeners();
  }

  String _lastPreviewedVideoUrl = '';

  // ---- YouTube preview ----

  Future<void> previewVideo() async {
    final url = _videoUrl.trim();
    if (url.isEmpty) {
      _errorMessage = '请先粘贴 YouTube 视频链接';
      notifyListeners();
      return;
    }

    _isPreviewingVideo = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await _setApi.previewVideo(url);
      final platform = data['platform']?.toLowerCase().trim() ?? '';
      if (platform != 'youtube') {
        _errorMessage = '当前发布仅支持 YouTube 视频链接';
        return;
      }

      final parsedTitle = data['title']?.trim() ?? '';
      final parsedDescription = data['description']?.trim() ?? '';
      final parsedThumbnail = data['thumbnailUrl']?.trim() ?? '';
      final authorName = data['authorName']?.trim() ?? '';

      if (_title.trim().isEmpty && parsedTitle.isNotEmpty) {
        _title = parsedTitle;
      }
      if (_description.trim().isEmpty && parsedDescription.isNotEmpty) {
        _description = parsedDescription;
      }
      if (_thumbnailUrl.trim().isEmpty && parsedThumbnail.isNotEmpty) {
        _thumbnailUrl = parsedThumbnail;
      }
      _previewTitle = parsedTitle;
      _videoAuthorName = authorName;
      _lastPreviewedVideoUrl = url;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isPreviewingVideo = false;
      notifyListeners();
    }
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

  Future<void> uploadThumbnail(String localPath) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final url = await _setApi.uploadSetThumbnail(localPath);
      _thumbnailUrl = url;
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
    int? endSecond,
    String status = 'released',
    String spotifyUrl = '',
    String neteaseUrl = '',
  }) {
    _tracklist.add({
      'title': title,
      'artist': artist ?? '',
      'startSecond': startSecond,
      'endSecond': endSecond,
      'status': status,
      'spotifyUrl': spotifyUrl,
      'neteaseUrl': neteaseUrl,
    });
    _tracklistDirty = true;
    notifyListeners();
  }

  void removeTrack(int index) {
    if (index < 0 || index >= _tracklist.length) return;
    _tracklist.removeAt(index);
    _tracklistDirty = true;
    notifyListeners();
  }

  void reorderTrack(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = _tracklist.removeAt(oldIndex);
    _tracklist.insert(newIndex, item);
    _tracklistDirty = true;
    notifyListeners();
  }

  void updateTrack(
    int index, {
    required String title,
    String artist = '',
    int startSecond = 0,
    int? endSecond,
    String status = 'released',
    String spotifyUrl = '',
    String neteaseUrl = '',
  }) {
    if (index < 0 || index >= _tracklist.length) return;
    _tracklist[index] = {
      'title': title,
      'artist': artist,
      'startSecond': startSecond,
      'endSecond': endSecond,
      'status': status,
      'spotifyUrl': spotifyUrl,
      'neteaseUrl': neteaseUrl,
    };
    _tracklistDirty = true;
    notifyListeners();
  }

  Future<void> autoLinkTracks() async {
    final id = _setId;
    if (id == null || id.isEmpty || _isLoading) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _setApi.autoLinkTracks(id);
      final refreshed = await _setApi.fetchSet(id);
      _tracklist = (refreshed.tracks ?? const [])
          .map(
            (t) => <String, dynamic>{
              'title': t.title,
              'artist': t.artist,
              'startSecond': _parseStartTime(t.startTime),
              'endSecond': t.endTime,
              'status': t.status.isNotEmpty ? t.status : 'released',
              'spotifyUrl': t.spotifyUrl,
              'neteaseUrl': t.neteaseUrl,
            },
          )
          .toList();
      _tracklistDirty = false;
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoading = false;
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
        'title': _title.trim(),
        if (_description.trim().isNotEmpty) 'description': _description.trim(),
        if (_djId != null && _djId!.isNotEmpty) 'djId': _djId,
        if (_eventId != null && _eventId!.isNotEmpty) 'eventId': _eventId,
        if (_eventName.trim().isNotEmpty) 'eventName': _eventName.trim(),
        if (_venue.trim().isNotEmpty) 'venue': _venue.trim(),
        if (_recordedAt != null) 'recordedAt': _recordedAt!.toIso8601String(),
        if (_duration != null) 'duration': _duration,
        if (_audioUrl.isNotEmpty) 'audioUrl': _audioUrl,
        'videoUrl': _videoUrl.trim(),
        if (_videoAuthorName.trim().isNotEmpty)
          'videoAuthorName': _videoAuthorName.trim(),
        if (_thumbnailUrl.trim().isNotEmpty)
          'thumbnailUrl': _thumbnailUrl.trim(),
        'rightsConfirmed': _rightsConfirmed,
      };

      if (_title.trim().isEmpty) {
        throw StateError('请填写标题');
      }
      if (_videoUrl.trim().isEmpty) {
        throw StateError('请填写 YouTube 视频链接');
      }
      if (!_rightsConfirmed) {
        throw StateError('请先确认你拥有发布权利，或链接来源合法且可公开引用。');
      }
      if (_youtubeVideoId(_videoUrl) == null) {
        throw StateError('当前仅支持合法的 YouTube 视频链接');
      }

      if (_setId != null) {
        await _setApi.updateSet(_setId!, payload);
      } else {
        final created = await _setApi.createSet(payload);
        _setId = created.id;
      }
      if (_tracklistDirty) {
        await _setApi.replaceTracks(_setId!, _buildTrackPayload());
        _tracklistDirty = false;
      }
      _isSaved = true;
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  List<Map<String, dynamic>> _buildTrackPayload() {
    final rows = <Map<String, dynamic>>[];
    for (var i = 0; i < _tracklist.length; i += 1) {
      final row = _tracklist[i];
      final title = (row['title'] as String? ?? '').trim();
      final artist = (row['artist'] as String? ?? '').trim();
      if (title.isEmpty || artist.isEmpty) continue;
      rows.add({
        'position': i + 1,
        'startTime': row['startSecond'] as int? ?? 0,
        if (row['endSecond'] is int) 'endTime': row['endSecond'],
        'title': title,
        'artist': artist,
        'status': (row['status'] as String? ?? 'released').trim().isEmpty
            ? 'released'
            : (row['status'] as String? ?? 'released').trim(),
        if ((row['spotifyUrl'] as String? ?? '').trim().isNotEmpty)
          'spotifyUrl': (row['spotifyUrl'] as String).trim(),
        if ((row['neteaseUrl'] as String? ?? '').trim().isNotEmpty)
          'neteaseUrl': (row['neteaseUrl'] as String).trim(),
      });
    }
    return rows;
  }
}

String? _youtubeVideoId(String raw) {
  final value = raw.trim();
  if (RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(value)) return value;
  final patterns = <RegExp>[
    RegExp(r'(?:youtube\.com/watch\?v=|youtu\.be/)([A-Za-z0-9_-]{11})'),
    RegExp(r'youtube\.com/embed/([A-Za-z0-9_-]{11})'),
    RegExp(r'youtube\.com/shorts/([A-Za-z0-9_-]{11})'),
    RegExp(r'youtube-nocookie\.com/embed/([A-Za-z0-9_-]{11})'),
  ];
  for (final pattern in patterns) {
    final match = pattern.firstMatch(value);
    if (match != null) return match.group(1);
  }
  return null;
}
