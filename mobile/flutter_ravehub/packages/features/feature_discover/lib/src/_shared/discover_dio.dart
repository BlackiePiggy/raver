import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:raver_core/raver_core.dart';

final discoverDioProvider = Provider<Dio>((ref) => createDiscoverDio());

Dio createDiscoverDio() {
  return Dio(
    BaseOptions(
      baseUrl: AppConfig.bffBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ),
  );
}
