import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ravehub/di/app_providers.dart';
import 'package:ravehub/lifecycle/app_lifecycle_sync_controller.dart';
import 'package:raver_models/raver_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppLifecycleSyncController', () {
    const appBadgeChannel = MethodChannel('com.ravehub.app_badge');
    final appBadgeCalls = <MethodCall>[];

    setUp(() {
      appBadgeCalls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(appBadgeChannel, (call) async {
        appBadgeCalls.add(call);
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(appBadgeChannel, null);
    });

    test('syncs unread counts and system badge when app resumes', () async {
      var unreadRequestCount = 0;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.ravehub.top'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.path == '/v1/notification-center/unread-count') {
                unreadRequestCount += 1;
                handler.resolve(
                  Response<Map<String, dynamic>>(
                    requestOptions: options,
                    statusCode: 200,
                    data: const {
                      'community': 2,
                      'followedEvents': 4,
                      'followedDJs': 6,
                      'followedBrands': 8,
                    },
                  ),
                );
                return;
              }
              handler.reject(DioException(requestOptions: options));
            },
          ),
        );
      final container = ProviderContainer(
        overrides: [dioProvider.overrideWithValue(dio)],
      );
      addTearDown(container.dispose);
      container.read(appStateProvider.notifier).setSession(
            const Session(
              token: 'access-token',
              refreshToken: 'refresh-token',
              accessTokenExpiresIn: 3600,
              user: UserSummary(
                id: 'user-1',
                username: 'tester',
                displayName: 'Tester',
              ),
            ),
          );

      final controller = AppLifecycleSyncController(container: container);
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await controller.lastSync;

      final appState = container.read(appStateProvider);
      expect(unreadRequestCount, 1);
      expect(appState.totalUnreadCount, 20);
      expect(appBadgeCalls, hasLength(1));
      expect(appBadgeCalls.single.arguments, {'count': 20});
    });

    test('does not sync unread counts for paused lifecycle state', () async {
      var requestCount = 0;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.ravehub.top'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requestCount += 1;
              handler.reject(DioException(requestOptions: options));
            },
          ),
        );
      final container = ProviderContainer(
        overrides: [dioProvider.overrideWithValue(dio)],
      );
      addTearDown(container.dispose);
      container.read(appStateProvider.notifier).setSession(
            const Session(
              token: 'access-token',
              refreshToken: 'refresh-token',
              accessTokenExpiresIn: 3600,
              user: UserSummary(
                id: 'user-1',
                username: 'tester',
                displayName: 'Tester',
              ),
            ),
          );

      final controller = AppLifecycleSyncController(container: container);
      controller.didChangeAppLifecycleState(AppLifecycleState.paused);
      await controller.lastSync;

      expect(requestCount, 0);
      expect(appBadgeCalls, isEmpty);
    });
  });
}
