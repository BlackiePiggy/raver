import 'package:flutter/foundation.dart';
import 'package:raver_models/raver_models.dart';

import '../../profile_me/data/profile_repository.dart';

class EditProfileViewModel extends ChangeNotifier {
  EditProfileViewModel({required ProfileRepository repository})
      : _repository = repository;

  final ProfileRepository _repository;

  UserProfile? _profile;
  UserProfile? get profile => _profile;

  String _displayName = '';
  String get displayName => _displayName;

  String _bio = '';
  String get bio => _bio;

  String _gender = '';
  String get gender => _gender;

  String _birthday = '';
  String get birthday => _birthday;

  String _city = '';
  String get city => _city;

  String? _avatarUrl;
  String? get avatarUrl => _avatarUrl;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  bool _isNameAvailable = true;
  bool get isNameAvailable => _isNameAvailable;

  bool _isCheckingName = false;
  bool get isCheckingName => _isCheckingName;

  String? _error;
  String? get error => _error;

  bool _saveSuccess = false;
  bool get saveSuccess => _saveSuccess;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();

    try {
      _profile = await _repository.fetchMe();
      _displayName = _profile!.displayName;
      _bio = _profile!.bio ?? '';
      _avatarUrl = _profile!.avatarUrl;
      _gender = '';
      _birthday = '';
      _city = '';
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  void setDisplayName(String value) {
    _displayName = value;
    _isNameAvailable = true;
    notifyListeners();
  }

  void setBio(String value) {
    _bio = value;
    notifyListeners();
  }

  void setGender(String value) {
    _gender = value;
    notifyListeners();
  }

  void setBirthday(String value) {
    _birthday = value;
    notifyListeners();
  }

  void setCity(String value) {
    _city = value;
    notifyListeners();
  }

  void setAvatarUrl(String? value) {
    _avatarUrl = value;
    notifyListeners();
  }

  Future<void> checkDisplayName() async {
    if (_displayName.isEmpty ||
        _displayName == _profile?.displayName) {
      _isNameAvailable = true;
      notifyListeners();
      return;
    }

    _isCheckingName = true;
    notifyListeners();

    try {
      _isNameAvailable =
          await _repository.checkDisplayName(name: _displayName);
    } catch (_) {
      _isNameAvailable = true;
    }
    _isCheckingName = false;
    notifyListeners();
  }

  Future<void> save() async {
    if (_isSaving) return;
    _isSaving = true;
    _error = null;
    _saveSuccess = false;
    notifyListeners();

    try {
      await _repository.updateProfile(
        displayName: _displayName.isNotEmpty ? _displayName : null,
        bio: _bio,
        gender: _gender.isNotEmpty ? _gender : null,
        birthday: _birthday.isNotEmpty ? _birthday : null,
        city: _city.isNotEmpty ? _city : null,
        avatarUrl: _avatarUrl,
      );
      _saveSuccess = true;
    } catch (e) {
      _error = e.toString();
    }
    _isSaving = false;
    notifyListeners();
  }
}
