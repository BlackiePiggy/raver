import 'dart:developer' as developer;

import 'package:dio/dio.dart';

/// Dio interceptor that logs HTTP request/response details to the console.
///
/// Only intended for debug builds. Add this interceptor conditionally:
/// ```dart
/// if (kDebugMode) LoggingInterceptor()
/// ```
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final buffer = StringBuffer()
      ..writeln('---> ${options.method.toUpperCase()} ${options.uri}')
      ..writeln('Headers: ${options.headers}');

    if (options.data != null) {
      buffer.writeln('Body: ${options.data}');
    }

    developer.log(buffer.toString(), name: 'RaveNetwork');
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    final buffer = StringBuffer()
      ..writeln(
        '<--- ${response.statusCode} '
        '${response.requestOptions.method.toUpperCase()} '
        '${response.requestOptions.uri}',
      )
      ..writeln('Data: ${response.data}');

    developer.log(buffer.toString(), name: 'RaveNetwork');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final buffer = StringBuffer()
      ..writeln(
        '<--- ERROR ${err.response?.statusCode ?? 'N/A'} '
        '${err.requestOptions.method.toUpperCase()} '
        '${err.requestOptions.uri}',
      )
      ..writeln('Message: ${err.message}');

    if (err.response?.data != null) {
      buffer.writeln('Error body: ${err.response?.data}');
    }

    developer.log(buffer.toString(), name: 'RaveNetwork');
    handler.next(err);
  }
}
