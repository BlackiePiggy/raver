import 'package:permission_handler/permission_handler.dart';

/// App-facing permission states without leaking plugin-specific types.
enum RaverPermissionStatus {
  /// Permission has been granted.
  granted,

  /// Permission is denied but can still be requested.
  denied,

  /// Permission is denied and must be changed in system Settings.
  permanentlyDenied,

  /// Permission is restricted by parental controls, device policy, or OS rules.
  restricted,

  /// Permission is partially granted, such as limited photo library access.
  limited,

  /// Permission is provisionally granted.
  provisional,
}

/// Wraps [permission_handler] to provide a clean API for requesting and
/// checking runtime permissions across iOS and Android.
class PermissionService {
  /// Requests camera permission.
  ///
  /// Returns `true` if the permission is granted after the request.
  Future<bool> requestCamera() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// Requests camera permission and returns the app-facing status.
  Future<RaverPermissionStatus> requestCameraStatus() async {
    return _mapStatus(await Permission.camera.request());
  }

  /// Requests photo library permission.
  ///
  /// Returns `true` if the permission is granted after the request.
  Future<bool> requestPhotos() async {
    final status = await Permission.photos.request();
    return status.isGranted;
  }

  /// Requests photo library permission and returns the app-facing status.
  Future<RaverPermissionStatus> requestPhotosStatus() async {
    return _mapStatus(await Permission.photos.request());
  }

  /// Requests microphone permission.
  ///
  /// Returns `true` if the permission is granted after the request.
  Future<bool> requestMicrophone() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Requests location permission.
  ///
  /// Requests [Permission.locationWhenInUse] which is the least-privileged
  /// level sufficient for most features.
  ///
  /// Returns `true` if the permission is granted after the request.
  Future<bool> requestLocation() async {
    final status = await Permission.locationWhenInUse.request();
    return status.isGranted;
  }

  /// Requests location permission and returns the app-facing status.
  Future<RaverPermissionStatus> requestLocationStatus() async {
    return _mapStatus(await Permission.locationWhenInUse.request());
  }

  /// Requests notification permission.
  ///
  /// Returns `true` if the permission is granted after the request.
  Future<bool> requestNotification() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Requests notification permission and returns the app-facing status.
  Future<RaverPermissionStatus> requestNotificationStatus() async {
    return _mapStatus(await Permission.notification.request());
  }

  /// Checks the current status of the camera permission without prompting.
  Future<PermissionStatus> checkCamera() async {
    return Permission.camera.status;
  }

  /// Checks the current camera status without prompting.
  Future<RaverPermissionStatus> cameraStatus() async {
    return _mapStatus(await Permission.camera.status);
  }

  /// Checks the current status of the photo library permission without
  /// prompting.
  Future<PermissionStatus> checkPhotos() async {
    return Permission.photos.status;
  }

  /// Checks the current photo library status without prompting.
  Future<RaverPermissionStatus> photosStatus() async {
    return _mapStatus(await Permission.photos.status);
  }

  /// Checks the current status of the location permission without prompting.
  Future<PermissionStatus> checkLocation() async {
    return Permission.locationWhenInUse.status;
  }

  /// Checks the current location status without prompting.
  Future<RaverPermissionStatus> locationStatus() async {
    return _mapStatus(await Permission.locationWhenInUse.status);
  }

  /// Checks the current status of the notification permission without
  /// prompting.
  Future<PermissionStatus> checkNotification() async {
    return Permission.notification.status;
  }

  /// Checks the current notification status without prompting.
  Future<RaverPermissionStatus> notificationStatus() async {
    return _mapStatus(await Permission.notification.status);
  }

  /// Opens the platform-specific app settings screen so the user can
  /// manually toggle permissions that were permanently denied.
  Future<void> openSettings() async {
    await openAppSettings();
  }

  static RaverPermissionStatus _mapStatus(PermissionStatus status) {
    if (status.isGranted) return RaverPermissionStatus.granted;
    if (status.isLimited) return RaverPermissionStatus.limited;
    if (status.isProvisional) return RaverPermissionStatus.provisional;
    if (status.isPermanentlyDenied) {
      return RaverPermissionStatus.permanentlyDenied;
    }
    if (status.isRestricted) return RaverPermissionStatus.restricted;
    return RaverPermissionStatus.denied;
  }
}
