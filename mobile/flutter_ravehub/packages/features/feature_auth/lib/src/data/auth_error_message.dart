import 'dart:convert';

import 'package:dio/dio.dart';

/// Converts auth transport/API failures into user-facing text.
///
/// Mirrors the iOS auth service behavior: prefer the BFF error envelope, then
/// fall back to known auth codes and finally to the transport description.
String authUserFacingError(Object error) {
  if (error is DioException) {
    return _fromPayload(error.response?.data) ??
        _fromDioException(error) ??
        _fallbackMessage(error.message);
  }
  if (error is FormatException) {
    return '接口返回格式不匹配，请检查 BFF 契约';
  }
  return _fallbackMessage(error.toString());
}

String? _fromDioException(DioException error) {
  return switch (error.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout =>
      '请求超时，请稍后重试',
    DioExceptionType.connectionError => '网络连接失败，请检查网络后重试',
    DioExceptionType.cancel => null,
    _ => _fallbackMessage(error.message),
  };
}

String? _fromPayload(dynamic payload) {
  if (payload == null) return null;
  if (payload is String) {
    final trimmed = payload.trim();
    if (trimmed.isEmpty) return null;
    try {
      return _fromPayload(jsonDecode(trimmed)) ?? trimmed;
    } on FormatException {
      return trimmed;
    }
  }
  if (payload is Map) {
    final directMessage = _stringValue(payload['error']) ??
        _stringValue(payload['message']) ??
        _stringValue(payload['detail']);
    if (directMessage != null) return directMessage;

    final data = payload['data'];
    if (data is Map) {
      final nestedMessage = _fromPayload(data);
      if (nestedMessage != null) return nestedMessage;
    }

    final code = _stringValue(payload['code']);
    if (code != null) return _messageForCode(code);
  }
  return null;
}

String? _messageForCode(String code) {
  return switch (code) {
    'AUTH_SESSION_REVOKED' ||
    'AUTH_SESSION_IDLE_EXPIRED' ||
    'AUTH_SESSION_ABSOLUTE_EXPIRED' ||
    'AUTH_REFRESH_TOKEN_INVALID_OR_EXPIRED' ||
    'AUTH_REFRESH_EXPIRED' ||
    'AUTH_REFRESH_TOKEN_MISSING' =>
      '登录状态已失效，请重新登录',
    'AUTH_ACCOUNT_INACTIVE' || 'ACCOUNT_INACTIVE' => '账号已删除或停用，请重新登录其他账号。',
    'AUTH_DISPLAY_NAME_TAKEN' => '该昵称已被使用',
    'AUTH_CODE_EXPIRED' ||
    'AUTH_VERIFICATION_CODE_EXPIRED' ||
    'AUTH_SMS_CODE_EXPIRED' ||
    'AUTH_EMAIL_CODE_EXPIRED' =>
      '验证码已过期，请重新发送',
    'AUTH_INVALID_CODE' ||
    'AUTH_CODE_INVALID' ||
    'AUTH_VERIFICATION_CODE_INVALID' ||
    'AUTH_SMS_CODE_INVALID' ||
    'AUTH_EMAIL_CODE_INVALID' =>
      '验证码无效，请重新输入',
    'AUTH_EMAIL_ALREADY_EXISTS' => '该邮箱已注册',
    'AUTH_INVALID_CREDENTIALS' || 'AUTH_PASSWORD_INVALID' => '账号或密码不正确',
    _ => null,
  };
}

String _fallbackMessage(String? message) {
  final cleaned = _clean(message);
  if (cleaned == null) return '请求失败';
  return cleaned;
}

String? _stringValue(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String? _clean(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed
      .replaceFirst(RegExp(r'^Exception:\s*'), '')
      .replaceFirst(RegExp(r'^FormatException:\s*'), '')
      .replaceFirst(RegExp(r'^DioException \[[^\]]+\]:\s*'), '')
      .trim();
}
