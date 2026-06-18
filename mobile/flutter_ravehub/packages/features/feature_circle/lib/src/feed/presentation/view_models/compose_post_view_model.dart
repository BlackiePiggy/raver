import 'package:flutter/foundation.dart';

import '../../data/feed_repository.dart';

enum ComposePostPhase { idle, uploading, success, failure }

class ComposePostViewModel extends ChangeNotifier {
  ComposePostViewModel({required FeedRepository repository})
      : _repository = repository;

  final FeedRepository _repository;

  ComposePostPhase _phase = ComposePostPhase.idle;
  ComposePostPhase get phase => _phase;

  String _text = '';
  String get text => _text;

  final List<String> _imagePaths = [];
  List<String> get imagePaths => List.unmodifiable(_imagePaths);

  String? _videoPath;
  String? get videoPath => _videoPath;

  String? _eventId;
  String? get eventId => _eventId;

  String? _eventName;
  String? get eventName => _eventName;

  String? _location;
  String? get location => _location;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool get canSubmit =>
      (_text.trim().isNotEmpty ||
          _imagePaths.isNotEmpty ||
          _videoPath != null) &&
      _text.length <= maxTextLength &&
      _phase != ComposePostPhase.uploading;

  int get maxTextLength => 500;
  int get maxImages => 9;

  void setText(String value) {
    _text = value;
    notifyListeners();
  }

  void addImages(List<String> paths) {
    final remaining = maxImages - _imagePaths.length;
    _imagePaths.addAll(paths.take(remaining));
    // Clear video if images are added
    if (_imagePaths.isNotEmpty) {
      _videoPath = null;
    }
    notifyListeners();
  }

  void removeImage(int index) {
    if (index >= 0 && index < _imagePaths.length) {
      _imagePaths.removeAt(index);
      notifyListeners();
    }
  }

  void setVideo(String path) {
    _videoPath = path;
    // Clear images if video is set
    _imagePaths.clear();
    notifyListeners();
  }

  void removeVideo() {
    _videoPath = null;
    notifyListeners();
  }

  void setEvent(String id, String name) {
    _eventId = id;
    _eventName = name;
    notifyListeners();
  }

  void clearEvent() {
    _eventId = null;
    _eventName = null;
    notifyListeners();
  }

  void setLocation(String value) {
    _location = value.isEmpty ? null : value;
    notifyListeners();
  }

  Future<bool> submit() async {
    if (!canSubmit) return false;

    _phase = ComposePostPhase.uploading;
    _errorMessage = null;
    notifyListeners();

    try {
      final mediaUrls = <String>[];
      for (final path in _imagePaths) {
        final uploaded = await _repository.uploadPostImage(path: path);
        if (uploaded.url.isNotEmpty) mediaUrls.add(uploaded.url);
      }
      final videoPath = _videoPath;
      if (videoPath != null) {
        final uploaded = await _repository.uploadPostVideo(path: videoPath);
        if (uploaded.url.isNotEmpty) mediaUrls.add(uploaded.url);
      }
      await _repository.createPost(
        text: _text.trim(),
        mediaUrls: mediaUrls,
        eventId: _eventId,
        location: _location,
      );
      _phase = ComposePostPhase.success;
      notifyListeners();
      return true;
    } catch (e) {
      _phase = ComposePostPhase.failure;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
