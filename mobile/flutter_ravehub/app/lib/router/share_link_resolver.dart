import 'package:dio/dio.dart';
import 'package:raver_models/raver_models.dart';
import 'package:ravehub/router/deep_link_handler.dart';

/// Resolves live share links into in-app GoRouter paths.
class ShareLinkResolver {
  ShareLinkResolver(this._dio);

  final Dio _dio;

  /// Resolves an incoming app/universal link to a GoRouter path.
  ///
  /// Canonical links are handled locally. Short links under `/s/{code}` are
  /// resolved through the live BFF to match the native iOS app.
  Future<String?> resolve(Uri uri, {String channel = 'universal_link'}) async {
    final localPath = DeepLinkHandler.toAppPath(uri);
    if (!_isShortShareLink(uri)) return localPath;

    final code = uri.pathSegments[1].trim();
    if (code.isEmpty) return null;

    final payload = await getLink(code);
    await recordOpenEvent(
      code: payload.code.isNotEmpty ? payload.code : code,
      channel: channel,
      incomingUrl: uri.toString(),
    );

    final target = _payloadTargetUri(payload);
    if (target == null) return localPath;

    final withShareCode = _appendShareCode(
      target,
      payload.code.isNotEmpty ? payload.code : code,
    );
    return DeepLinkHandler.toAppPath(withShareCode);
  }

  Future<ShareLinkPayload> getLink(String code) async {
    final response = await _dio.get<dynamic>('/v1/share-links/$code');
    return ShareLinkPayload.fromJson(LiveApiPayload.object(response.data));
  }

  Future<void> recordOpenEvent({
    required String code,
    required String channel,
    required String incomingUrl,
  }) async {
    await _dio.post<void>(
      '/v1/share-links/$code/events',
      data: {
        'eventType': 'app_open',
        'channel': channel,
        'platform': 'flutter',
        'metadata': {
          'source': channel,
          'incomingURL': incomingUrl,
        },
      },
    );
  }

  bool _isShortShareLink(Uri uri) {
    final isAllowedHost =
        uri.host == 'ravehub.top' || uri.host == 'www.ravehub.top';
    return (uri.scheme == 'https' || uri.scheme == 'http') &&
        isAllowedHost &&
        uri.pathSegments.length >= 2 &&
        uri.pathSegments.first.toLowerCase() == 's';
  }

  Uri? _payloadTargetUri(ShareLinkPayload payload) {
    for (final value in [
      payload.deepLink,
      payload.canonicalUrl,
      payload.fallbackUrl,
    ]) {
      final uri = Uri.tryParse(value);
      if (uri != null && value.isNotEmpty) return uri;
    }
    return null;
  }

  Uri _appendShareCode(Uri uri, String code) {
    if (code.isEmpty || uri.queryParameters.containsKey('shareCode')) {
      return uri;
    }
    return uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        'shareCode': code,
      },
    );
  }
}
