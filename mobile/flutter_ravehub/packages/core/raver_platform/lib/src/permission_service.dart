import 'package:permission_handler/permission_handler.dart';

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

  /// Requests photo library permission.
  ///
  /// Returns `true` if the permission is granted after the request.
  Future<bool> requestPhotos() async {
    final status = await Permission.photos.request();
    return status.isGranted;
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

  /// Requests notification permission.
  ///
  /// Returns `true` if the permission is granted after the request.
  Future<bool> requestNotification() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Checks the current status of the camera permission without prompting.
  Future<PermissionStatus> checkCamera() async {
    return Permission.camera.status;
  }

  /// Checks the current status of the photo library permission without
  /// prompting.
  Future<PermissionStatus> checkPhotos() async {
    return Permission.photos.status;
  }

  /// Checks the current status of the location permission without prompting.
  Future<PermissionStatus> checkLocation() async {
    return Permission.locationWhenInUse.status;
  }

  /// Checks the current status of the notification permission without
  /// prompting.
  Future<PermissionStatus> checkNotification() async {
    return Permission.notification.status;
  }

  /// Opens the platform-specific app settings screen so the user can
  /// manually toggle permissions that were permanently denied.
  Future<void> openSettings() async {
    await openAppSettings();
  }
}
