import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raver_platform/raver_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PushNotificationService', () {
    test('checks notification status without prompting by default', () async {
      var checkedSettings = false;
      var requestedPermission = false;
      var configuredForegroundPresentation = false;
      var requestedToken = false;

      final service = PushNotificationService.testing(
        getNotificationSettings: () async {
          checkedSettings = true;
          return _settings(AuthorizationStatus.notDetermined);
        },
        requestPermission: () async {
          requestedPermission = true;
          return _settings(AuthorizationStatus.authorized);
        },
        setForegroundNotificationPresentationOptions: () async {
          configuredForegroundPresentation = true;
        },
        getToken: () async {
          requestedToken = true;
          return 'token';
        },
      );

      final token = await service.getPushToken();

      expect(token, isNull);
      expect(checkedSettings, isTrue);
      expect(requestedPermission, isFalse);
      expect(configuredForegroundPresentation, isTrue);
      expect(requestedToken, isFalse);
    });

    test('requests permission only when explicit user intent is passed',
        () async {
      var checkedSettings = false;
      var requestedPermission = false;

      final service = PushNotificationService.testing(
        getNotificationSettings: () async {
          checkedSettings = true;
          return _settings(AuthorizationStatus.notDetermined);
        },
        requestPermission: () async {
          requestedPermission = true;
          return _settings(AuthorizationStatus.authorized);
        },
        setForegroundNotificationPresentationOptions: () async {},
        getToken: () async => 'fcm-token',
      );

      final token = await service.getPushToken(requestPermission: true);

      expect(token, 'fcm-token');
      expect(checkedSettings, isFalse);
      expect(requestedPermission, isTrue);
    });

    test('does not fetch a token when notification permission is denied',
        () async {
      var requestedToken = false;

      final service = PushNotificationService.testing(
        getNotificationSettings: () async {
          return _settings(AuthorizationStatus.denied);
        },
        requestPermission: () async {
          return _settings(AuthorizationStatus.denied);
        },
        setForegroundNotificationPresentationOptions: () async {},
        getToken: () async {
          requestedToken = true;
          return 'fcm-token';
        },
      );

      final token = await service.getPushToken(requestPermission: true);

      expect(token, isNull);
      expect(requestedToken, isFalse);
    });
  });
}

NotificationSettings _settings(AuthorizationStatus status) {
  return NotificationSettings(
    alert: AppleNotificationSetting.enabled,
    announcement: AppleNotificationSetting.notSupported,
    authorizationStatus: status,
    badge: AppleNotificationSetting.enabled,
    carPlay: AppleNotificationSetting.notSupported,
    lockScreen: AppleNotificationSetting.enabled,
    notificationCenter: AppleNotificationSetting.enabled,
    showPreviews: AppleShowPreviewSetting.always,
    timeSensitive: AppleNotificationSetting.notSupported,
    criticalAlert: AppleNotificationSetting.notSupported,
    sound: AppleNotificationSetting.enabled,
    providesAppNotificationSettings: AppleNotificationSetting.notSupported,
  );
}
