import 'package:dio/dio.dart';

/// Dio interceptor that sets the `Accept-Language` header on every outgoing
/// request based on the app's current language setting.
///
/// The language value is obtained lazily through [languageProvider] so that
/// locale changes (e.g. the user switches language in settings) are
/// automatically picked up without recreating the Dio client.
class LanguageInterceptor extends Interceptor {
  /// Creates a [LanguageInterceptor].
  ///
  /// [languageProvider] is called on every request to obtain the current
  /// language/locale string (e.g. `"en"`, `"zh-Hans"`).
  LanguageInterceptor({required String Function() languageProvider})
      : _languageProvider = languageProvider;

  final String Function() _languageProvider;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final language = _languageProvider();
    if (language.isNotEmpty) {
      options.headers['Accept-Language'] = language;
    }
    handler.next(options);
  }
}
