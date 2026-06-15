import 'package:flutter/foundation.dart';
import 'package:raver_models/raver_models.dart';

import '../../profile_me/data/profile_repository.dart';

class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel({required ProfileRepository repository})
      : _repository = repository;

  final ProfileRepository _repository;

  // Devices
  List<AuthSessionItem> _devices = [];
  List<AuthSessionItem> get devices => _devices;
  bool _isLoadingDevices = false;
  bool get isLoadingDevices => _isLoadingDevices;

  String? _error;
  String? get error => _error;

  bool _isLoggingOut = false;
  bool get isLoggingOut => _isLoggingOut;

  Future<void> loadDevices() async {
    _isLoadingDevices = true;
    notifyListeners();

    try {
      _devices = await _repository.fetchDevices();
    } catch (e) {
      _error = e.toString();
    }
    _isLoadingDevices = false;
    notifyListeners();
  }

  Future<void> removeDevice(String deviceId) async {
    try {
      await _repository.removeDevice(deviceId: deviceId);
      _devices.removeWhere((d) => d.id == deviceId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> updateSecurity({
    String? currentPassword,
    String? newPassword,
    String? phone,
    String? email,
  }) async {
    try {
      await _repository.updateSecurity(
        currentPassword: currentPassword,
        newPassword: newPassword,
        phone: phone,
        email: email,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void setLoggingOut(bool value) {
    _isLoggingOut = value;
    notifyListeners();
  }
}
