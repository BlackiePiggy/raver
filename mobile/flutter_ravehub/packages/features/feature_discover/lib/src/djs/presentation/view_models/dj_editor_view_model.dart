import 'package:flutter/foundation.dart';
import 'package:raver_models/raver_models.dart';

import '../../data/dj_api.dart';

/// ViewModel for DJ create / edit flows.
///
/// When [djId] is non-null the view model operates in *edit* mode:
/// [loadDJ] fetches the existing record and populates all fields.
/// Otherwise it starts empty for creation.
class DjEditorViewModel extends ChangeNotifier {
  DjEditorViewModel({required DjApi djApi}) : _djApi = djApi;

  final DjApi _djApi;

  // ---- state ----

  String? _djId;
  String? get djId => _djId;

  String _displayName = '';
  String get displayName => _displayName;

  String _bio = '';
  String get bio => _bio;

  String _nationality = '';
  String get nationality => _nationality;

  List<String> _genres = [];
  List<String> get genres => List.unmodifiable(_genres);

  String _spotifyUrl = '';
  String get spotifyUrl => _spotifyUrl;

  String _soundcloudUrl = '';
  String get soundcloudUrl => _soundcloudUrl;

  String _instagramUrl = '';
  String get instagramUrl => _instagramUrl;

  String _avatarUrl = '';
  String get avatarUrl => _avatarUrl;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _isSaved = false;
  bool get isSaved => _isSaved;

  // ---- loading ----

  Future<void> loadDJ(String id) async {
    _djId = id;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final dj = await _djApi.fetchDJ(id);
      _displayName = dj.name;
      _bio = dj.bio;
      _nationality = dj.country;
      _genres = List<String>.from(dj.genres ?? []);
      _spotifyUrl = dj.spotifyUrl;
      _soundcloudUrl = dj.soundcloudUrl;
      _instagramUrl = dj.instagramUrl;
      _avatarUrl = dj.avatarUrl;
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  // ---- field setters ----

  void setDisplayName(String value) {
    _displayName = value;
    notifyListeners();
  }

  void setBio(String value) {
    _bio = value;
    notifyListeners();
  }

  void setNationality(String value) {
    _nationality = value;
    notifyListeners();
  }

  void setSpotifyUrl(String value) {
    _spotifyUrl = value;
    notifyListeners();
  }

  void setSoundcloudUrl(String value) {
    _soundcloudUrl = value;
    notifyListeners();
  }

  void setInstagramUrl(String value) {
    _instagramUrl = value;
    notifyListeners();
  }

  void addGenre(String genre) {
    if (genre.trim().isEmpty) return;
    _genres.add(genre.trim());
    notifyListeners();
  }

  void removeGenre(int index) {
    if (index < 0 || index >= _genres.length) return;
    _genres.removeAt(index);
    notifyListeners();
  }

  // ---- avatar upload ----

  Future<void> uploadAvatar(String localPath) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final url = await _djApi.uploadDjAvatar(localPath);
      _avatarUrl = url;
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
        'name': _displayName,
        'bio': _bio,
        'country': _nationality,
        'genres': _genres,
        'spotifyUrl': _spotifyUrl,
        'soundcloudUrl': _soundcloudUrl,
        'instagramUrl': _instagramUrl,
        'avatarUrl': _avatarUrl,
      };

      if (_djId != null) {
        await _djApi.updateDJ(_djId!, payload);
      } else {
        final created = await _djApi.createDJ(payload);
        _djId = created.id;
      }
      _isSaved = true;
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }
}
