/// Networking layer with Dio client and BFF interceptors for RaveHub.
///
/// This package provides a fully configured HTTP client, interceptors for
/// authentication, BFF envelope unwrapping, and media upload utilities.
///
/// ```dart
/// import 'package:raver_network/raver_network.dart';
///
/// final dio = DioClientFactory.create(
///   baseUrl: 'https://api.ravehub.io',
///   tokenStore: tokenStore,
///   refreshGate: refreshGate,
///   languageProvider: () => 'en',
/// );
/// ```
library raver_network;

// Client
export 'src/client/auth_interceptor.dart';
export 'src/client/bff_envelope_interceptor.dart';
export 'src/client/dio_client_factory.dart';
export 'src/client/language_interceptor.dart';
export 'src/client/logging_interceptor.dart';
export 'src/client/service_error_mapper.dart';

// Upload
export 'src/upload/multipart_upload_service.dart';
export 'src/upload/oss_url_processor.dart';
