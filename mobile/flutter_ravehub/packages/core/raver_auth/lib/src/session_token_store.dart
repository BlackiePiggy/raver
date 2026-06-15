import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage keys for authentication tokens.
abstract final class _Keys {
  static const accessToken = 'raver_access_token';
  static const refreshToken = 'raver_refresh_token';
  static const tokenExpiresAt = 'raver_token_expires_at';
}

/// Manages secure persistence of OAuth tokens using platform-native storage.
///
/// Ported from iOS `SessionTokenStore.swift`. All token values are stored via
/// [FlutterSecureStorage], which delegates to Keychain (iOS) and EncryptedSharedPreferences
/// (Android).
class SessionTokenStore {
  /// Creates a [SessionTokenStore].
  ///
  /// An optional [FlutterSecureStorage] instance can be injected for testing.
  SessionTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  /// Reads the persisted access token, or `null` if none is stored.
  Future<String?> readAccessToken() =>
      _storage.read(key: _Keys.accessToken);

  /// Reads the persisted refresh token, or `null` if none is stored.
  Future<String?> readRefreshToken() =>
      _storage.read(key: _Keys.refreshToken);

  /// Reads the access token expiration timestamp, or `null` if none is stored.
  ///
  /// The value is stored as an ISO-8601 string and parsed back to a [DateTime].
  Future<DateTime?> readAccessTokenExpiresAt() async {
    final raw = await _storage.read(key: _Keys.tokenExpiresAt);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  /// Persists a fresh set of tokens received from the auth server.
  ///
  /// [accessToken] and [refreshToken] are stored directly. [expiresIn] is
  /// interpreted as seconds from now and converted to an absolute [DateTime].
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required int expiresIn,
  }) async {
    final expiresAt = DateTime.now().add(Duration(seconds: expiresIn));

    await Future.wait([
      _storage.write(key: _Keys.accessToken, value: accessToken),
      _storage.write(key: _Keys.refreshToken, value: refreshToken),
      _storage.write(
        key: _Keys.tokenExpiresAt,
        value: expiresAt.toUtc().toIso8601String(),
      ),
    ]);
  }

  /// Removes all stored tokens.
  Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: _Keys.accessToken),
      _storage.delete(key: _Keys.refreshToken),
      _storage.delete(key: _Keys.tokenExpiresAt),
    ]);
  }

  /// Returns `true` if both an access token and a refresh token are present.
  Future<bool> hasTokens() async {
    final results = await Future.wait([
      _storage.read(key: _Keys.accessToken),
      _storage.read(key: _Keys.refreshToken),
    ]);
    return results[0] != null && results[1] != null;
  }
}
