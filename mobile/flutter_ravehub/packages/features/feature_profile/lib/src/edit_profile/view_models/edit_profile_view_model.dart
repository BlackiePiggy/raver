import 'package:flutter/foundation.dart';
import 'package:raver_i18n/raver_i18n.dart';
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

  String? _backgroundUrl;
  String? get backgroundUrl => _backgroundUrl;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  bool _isUploadingAvatar = false;
  bool get isUploadingAvatar => _isUploadingAvatar;

  bool _isUploadingBackground = false;
  bool get isUploadingBackground => _isUploadingBackground;

  bool _isNameAvailable = true;
  bool get isNameAvailable => _isNameAvailable;

  String? _displayNameError;
  String? get displayNameError => _displayNameError;

  bool _isCheckingName = false;
  bool get isCheckingName => _isCheckingName;

  String? _error;
  String? get error => _error;

  bool _saveSuccess = false;
  bool get saveSuccess => _saveSuccess;

  bool get canSave =>
      !_isSaving &&
      !_isCheckingName &&
      !_isUploadingAvatar &&
      !_isUploadingBackground &&
      _validateInputs(updateState: false) == null;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();

    try {
      _profile = await _repository.fetchMe();
      _displayName = _profile!.displayName;
      _bio = _profile!.bio ?? '';
      _avatarUrl = _profile!.avatarUrl;
      _backgroundUrl = _profile!.backgroundUrl;
      _gender = '';
      _birthday = '';
      _city = '';
      _error = null;
      _displayNameError = null;
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  void setDisplayName(String value) {
    _displayName = value;
    _isNameAvailable = true;
    _displayNameError = _displayNameValidationError(value.trim());
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

  void setBackgroundUrl(String? value) {
    _backgroundUrl = value;
    notifyListeners();
  }

  Future<bool> uploadAvatar(String localPath) async {
    if (_isUploadingAvatar) return false;
    _isUploadingAvatar = true;
    _error = null;
    notifyListeners();

    try {
      _avatarUrl = await _repository.uploadMyAvatar(localPath);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isUploadingAvatar = false;
      notifyListeners();
    }
  }

  Future<bool> uploadBackground(String localPath) async {
    if (_isUploadingBackground) return false;
    _isUploadingBackground = true;
    _error = null;
    notifyListeners();

    try {
      _backgroundUrl = await _repository.uploadMyBackground(localPath);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isUploadingBackground = false;
      notifyListeners();
    }
  }

  Future<void> checkDisplayName() async {
    final candidate = _displayName.trim();
    final validationError = _displayNameValidationError(candidate);
    if (validationError != null) {
      _displayNameError = validationError;
      _isNameAvailable = false;
      notifyListeners();
      return;
    }

    if (candidate == _profile?.displayName) {
      _isNameAvailable = true;
      _displayNameError = null;
      notifyListeners();
      return;
    }

    _isCheckingName = true;
    _displayNameError = null;
    notifyListeners();

    try {
      _isNameAvailable = await _repository.checkDisplayName(name: candidate);
      _displayNameError = _isNameAvailable
          ? null
          : lt('昵称已被使用', 'Name is taken', '名前は既に使用されています');
    } catch (_) {
      _isNameAvailable = true;
      _displayNameError = null;
    }
    _isCheckingName = false;
    notifyListeners();
  }

  Future<void> save() async {
    if (_isSaving) return;
    _saveSuccess = false;
    final validationError = _validateInputs(updateState: true);
    if (validationError != null) {
      _error = validationError;
      notifyListeners();
      return;
    }

    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      final trimmedDisplayName = _displayName.trim();
      final trimmedBio = _bio.trim();
      final trimmedCity = _city.trim();
      await _repository.updateProfile(
        displayName: trimmedDisplayName,
        bio: trimmedBio,
        gender: _gender.isNotEmpty ? _gender : null,
        birthday: _birthday.isNotEmpty ? _birthday : null,
        city: trimmedCity.isNotEmpty ? trimmedCity : null,
        avatarUrl: _avatarUrl,
        backgroundUrl: _backgroundUrl,
      );
      _saveSuccess = true;
    } catch (e) {
      _error = e.toString();
    }
    _isSaving = false;
    notifyListeners();
  }

  String? _validateInputs({required bool updateState}) {
    final displayNameError = _displayNameValidationError(_displayName.trim());
    final bioError = _bio.trim().length > 200
        ? lt('个人简介最多 200 个字符', 'Bio must be 200 characters or fewer',
            '自己紹介は200文字以内にしてください')
        : null;
    final availabilityError = !_isNameAvailable
        ? lt('昵称已被使用', 'Name is taken', '名前は既に使用されています')
        : null;
    final error = displayNameError ?? bioError ?? availabilityError;
    if (updateState) {
      _displayNameError = displayNameError ?? availabilityError;
    }
    return error;
  }

  String? _displayNameValidationError(String value) {
    if (value.length < 2 || value.length > 24) {
      return lt(
          '昵称需为 2-24 个字符', 'Name must be 2-24 characters', '名前は2〜24文字にしてください');
    }
    return null;
  }
}
