import 'package:dio/dio.dart';
import 'package:raver_core/raver_core.dart';

/// Error thrown when the BFF response envelope indicates an application-level
/// error (i.e. the envelope contains a non-null `errorCode`).
class BffError implements Exception {
  /// Creates a [BffError].
  BffError({this.errorCode, required this.message});

  /// The machine-readable error code from the BFF envelope.
  final String? errorCode;

  /// The human-readable error message.
  final String message;

  @override
  String toString() => 'BffError($errorCode: $message)';
}

/// Key used to store pagination metadata in [Response.extra].
const String kPaginationExtraKey = 'bff_pagination';

/// Dio interceptor that unwraps the standard BFF response envelope.
///
/// The RaveHub backend wraps every JSON response in an envelope:
///
/// ```json
/// {
///   "data": <T>,
///   "pagination": { "page": 1, "pageSize": 20, "total": 100 },
///   "errorCode": null,
///   "message": "OK"
/// }
/// ```
///
/// This interceptor:
///  * On success responses: extracts `data` and replaces `response.data`,
///    and stores `pagination` (if present) in `response.extra`.
///  * On error responses with a body: parses `errorCode` and `message` and
///    throws a [BffError].
///  * On 403 responses: additionally parses account enforcement restrictions
///    and throws a [ServiceError.accountEnforcementRestricted].
class BffEnvelopeInterceptor extends Interceptor {
  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final body = response.data;

    // Only process Map bodies that look like a BFF envelope.
    if (body is! Map<String, dynamic>) {
      return handler.next(response);
    }

    // Check for an application-level error in the envelope.
    final errorCode = body['errorCode'] as String?;
    if (errorCode != null && errorCode.isNotEmpty) {
      final message =
          body['message'] as String? ?? 'An unknown error occurred';

      // On 403, check for enforcement restriction data and throw a typed
      // ServiceError so the UI layer can present a specialised screen.
      if (response.statusCode == 403) {
        _handleEnforcementRestriction(body);
      }

      throw BffError(errorCode: errorCode, message: message);
    }

    // Extract the inner data payload.
    if (body.containsKey('data')) {
      response.data = body['data'];
    }

    // Stash pagination metadata in extras for downstream consumers.
    final pagination = body['pagination'];
    if (pagination is Map<String, dynamic>) {
      response.extra[kPaginationExtraKey] = pagination;
    }

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final response = err.response;
    if (response == null) {
      return handler.next(err);
    }

    final body = response.data;
    if (body is! Map<String, dynamic>) {
      return handler.next(err);
    }

    // On 403, check for enforcement restriction data.
    if (response.statusCode == 403) {
      _handleEnforcementRestriction(body);
    }

    final errorCode = body['errorCode'] as String?;
    final message =
        body['message'] as String? ?? 'An unknown error occurred';

    throw BffError(errorCode: errorCode, message: message);
  }

  /// Parses enforcement restriction data from the response body and throws
  /// [ServiceError.accountEnforcementRestricted] if present.
  void _handleEnforcementRestriction(Map<String, dynamic> body) {
    final restrictionData = body['restriction'];
    if (restrictionData is Map<String, dynamic>) {
      final restriction = AccountEnforcementRestriction(
        scope: restrictionData['scope'] as String? ?? 'unknown',
        displayReason: restrictionData['displayReason'] as String?,
      );
      throw ServiceError.accountEnforcementRestricted(restriction);
    }
  }
}
