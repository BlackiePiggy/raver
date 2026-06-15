import 'package:dio/dio.dart';
import 'package:raver_core/raver_core.dart';

import '../data/notification_api.dart';
import '../data/notification_repository.dart';

/// Service locator for the Inbox feature module.
class InboxServiceLocator {
  InboxServiceLocator._();

  static Dio? _dio;

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
  }

  static NotificationApiService? _notificationApi;
  static NotificationApiService get notificationApi =>
      _notificationApi ??= NotificationApiService(dio);

  static NotificationRepository? _notificationRepository;
  static NotificationRepository get notificationRepository =>
      _notificationRepository ??= NotificationRepository(notificationApi);
}
