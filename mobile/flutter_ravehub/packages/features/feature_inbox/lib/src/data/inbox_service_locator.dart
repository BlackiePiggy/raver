import 'package:dio/dio.dart';
import 'package:raver_core/raver_core.dart';
import 'package:raver_models/raver_models.dart';

import '../data/notification_api.dart';
import '../data/notification_repository.dart';

typedef UnreadCountSync = void Function(NotificationUnreadCount counts);

/// Service locator for the Inbox feature module.
class InboxServiceLocator {
  InboxServiceLocator._();

  static Dio? _dio;
  static UnreadCountSync? _unreadCountSync;

  static Dio get dio {
    _dio ??= Dio(
      BaseOptions(
        baseUrl: AppConfig.bffBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    return _dio!;
  }

  static void configureDio(Dio dio) {
    _dio = dio;
    _notificationApi = null;
    _notificationRepository = null;
  }

  static void configureUnreadCountSync(UnreadCountSync? sync) {
    _unreadCountSync = sync;
  }

  static void syncUnreadCounts(NotificationUnreadCount counts) {
    _unreadCountSync?.call(counts);
  }

  static NotificationApiService? _notificationApi;
  static NotificationApiService get notificationApi =>
      _notificationApi ??= NotificationApiService(dio);

  static NotificationRepository? _notificationRepository;
  static NotificationRepository get notificationRepository =>
      _notificationRepository ??= NotificationRepository(notificationApi);
}
