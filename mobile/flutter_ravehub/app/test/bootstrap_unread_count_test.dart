import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ravehub/bootstrap.dart';
import 'package:ravehub/di/app_providers.dart';
import 'package:raver_models/raver_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppBootstrap unread badge sync', () {
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

    test('restores an existing token session during launch and syncs badges',
        () async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({
        'raver_access_token': 'stored-access-token',
        'raver_refresh_token': 'stored-refresh-token',
        'raver_token_expires_at': DateTime.now()
            .add(const Duration(hours: 1))
            .toUtc()
            .toIso8601String(),
      });

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
                      'community_unread_count': 1,
                      'followed_events_unread_count': 2,
                      'followed_djs_unread_count': 3,
                      'followed_brands_unread_count': 4,
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

      await AppBootstrap.run(container);

      final appState = container.read(appStateProvider);
      expect(appState.isLoggedIn, isTrue);
      expect(appState.session?.token, 'stored-access-token');
      expect(appState.session?.refreshToken, 'stored-refresh-token');
      expect(unreadRequestCount, 1);
      expect(appState.totalUnreadCount, 10);
      expect(appBadgeCalls, hasLength(1));
      expect(appBadgeCalls.single.method, 'setBadgeCount');
      expect(appBadgeCalls.single.arguments, {'count': 10});
    });

    test('skips live unread count request when no session exists', () async {
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

      await AppBootstrap.syncUnreadCountsIfNeeded(container);

      expect(requestCount, 0);
      expect(container.read(appStateProvider).totalUnreadCount, 0);
      expect(appBadgeCalls, isEmpty);
    });

    test('updates app shell badge counts from live unread count response',
        () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.ravehub.top'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              expect(options.path, '/v1/notification-center/unread-count');
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: const {
                    'community': 4,
                    'followedEvents': 6,
                    'followedDJs': 8,
                    'followedBrands': 10,
                  },
                ),
              );
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

      await AppBootstrap.syncUnreadCountsIfNeeded(container);

      final appState = container.read(appStateProvider);
      expect(appState.communityUnreadCount, 4);
      expect(appState.followedEventsUnreadCount, 6);
      expect(appState.followedDJsUnreadCount, 8);
      expect(appState.followedBrandsUnreadCount, 10);
      expect(appState.totalUnreadCount, 28);
      expect(appBadgeCalls, hasLength(1));
      expect(appBadgeCalls.single.arguments, {'count': 28});
    });

    test('accepts iOS live unread count aliases when syncing badges', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.ravehub.top'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              expect(options.path, '/v1/notification-center/unread-count');
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: const {
                    'community_unread_count': '1',
                    'followed_events_unread_count': '2',
                    'followed_djs_unread_count': '3',
                    'followed_brands_unread_count': '4',
                  },
                ),
              );
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

      await AppBootstrap.syncUnreadCountsIfNeeded(container);

      final appState = container.read(appStateProvider);
      expect(appState.communityUnreadCount, 1);
      expect(appState.followedEventsUnreadCount, 2);
      expect(appState.followedDJsUnreadCount, 3);
      expect(appState.followedBrandsUnreadCount, 4);
      expect(appState.totalUnreadCount, 10);
      expect(appBadgeCalls, hasLength(1));
      expect(appBadgeCalls.single.arguments, {'count': 10});
    });

    test('foreground push payload refreshes unread badges and resolves path',
        () async {
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
                      'community': 5,
                      'followedEvents': 0,
                      'followedDJs': 1,
                      'followedBrands': 0,
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

      final path = await AppBootstrap.handleForegroundPushMessageData(
        container,
        const {'targetType': 'followed_dj'},
      );

      expect(path, '/inbox/followed-djs');
      expect(unreadRequestCount, 1);
      final appState = container.read(appStateProvider);
      expect(appState.communityUnreadCount, 5);
      expect(appState.followedDJsUnreadCount, 1);
      expect(appState.totalUnreadCount, 6);
      expect(appBadgeCalls, hasLength(1));
      expect(appBadgeCalls.single.arguments, {'count': 6});
    });
  });
}
