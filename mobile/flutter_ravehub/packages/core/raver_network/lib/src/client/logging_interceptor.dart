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
      ..writeln('Headers: ${_redactMap(options.headers)}');

    if (options.data != null) {
      buffer.writeln('Body: ${_redactValue(options.data)}');
    }

    developer.log(buffer.toString(), name: 'RaveNetwork');
    handler.next(options);
  }

  @override
  void onResponse(
      Response<dynamic> response, ResponseInterceptorHandler handler) {
    final buffer = StringBuffer()
      ..writeln(
        '<--- ${response.statusCode} '
        '${response.requestOptions.method.toUpperCase()} '
        '${response.requestOptions.uri}',
      )
      ..writeln('Data: ${_redactValue(response.data)}');

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
      buffer.writeln('Error body: ${_redactValue(err.response?.data)}');
    }

    developer.log(buffer.toString(), name: 'RaveNetwork');
    handler.next(err);
  }

  Object? _redactValue(Object? value) {
    if (value is Map) return _redactMap(value);
    if (value is List) return value.map(_redactValue).toList(growable: false);
    return value;
  }

  Map<dynamic, dynamic> _redactMap(Map<dynamic, dynamic> map) {
    return map.map((key, value) {
      final keyText = key.toString().toLowerCase();
      if (_sensitiveKeys.any(keyText.contains)) {
        return MapEntry(key, '<redacted>');
      }
      return MapEntry(key, _redactValue(value));
    });
  }
}

const _sensitiveKeys = <String>[
  'authorization',
  'cookie',
  'password',
  'token',
  'secret',
  'credential',
];
