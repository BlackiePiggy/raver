import 'package:dio/dio.dart';
import 'package:raver_models/raver_models.dart';

class ProfileApi {
  ProfileApi(this._dio);

  final Dio _dio;

  /// Fetch current user's profile.
  Future<UserProfile> fetchMe() async {
    final response = await _dio.get<Map<String, dynamic>>('/v1/users/me');
    return UserProfile.fromJson(response.data!);
  }

  /// Fetch current user's posts.
  Future<BFFListPage<Post>> fetchMyPosts({
    required int page,
    int limit = 20,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/users/me/posts',
      queryParameters: {'page': page, 'limit': limit},
    );
    return BFFListPage.fromJson(
      response.data!,
      (json) => Post.fromJson(json! as Map<String, dynamic>),
    );
  }

  /// Fetch current user's saves.
  Future<BFFListPage<Post>> fetchMySaves({
    required int page,
    int limit = 20,
    String? type,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/users/me/saves',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (type != null) 'type': type,
      },
    );
    return BFFListPage.fromJson(
      response.data!,
      (json) => Post.fromJson(json! as Map<String, dynamic>),
    );
  }

  /// Fetch contribution statistics.
  Future<Map<String, dynamic>> fetchContributions() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/users/me/contributions',
    );
    return response.data!;
  }

  /// Fetch another user's profile.
  Future<UserProfile> fetchUserProfile({required String userId}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/users/$userId',
    );
    return UserProfile.fromJson(response.data!);
  }

  /// Fetch another user's posts.
  Future<BFFListPage<Post>> fetchUserPosts({
    required String userId,
    required int page,
    int limit = 20,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/users/$userId/posts',
      queryParameters: {'page': page, 'limit': limit},
    );
    return BFFListPage.fromJson(
      response.data!,
      (json) => Post.fromJson(json! as Map<String, dynamic>),
    );
  }

  /// Follow a user.
  Future<void> followUser({required String userId}) async {
    await _dio.post<void>('/v1/users/$userId/follow');
  }

  /// Unfollow a user.
  Future<void> unfollowUser({required String userId}) async {
    await _dio.delete<void>('/v1/users/$userId/follow');
  }

  /// Report a user.
  Future<void> reportUser({
    required String userId,
    required String reason,
  }) async {
    await _dio.post<void>(
      '/v1/users/$userId/report',
      data: {'reason': reason},
    );
  }

  /// Block a user.
  Future<void> blockUser({required String userId}) async {
    await _dio.post<void>('/v1/users/$userId/block');
  }

  /// Update profile.
  Future<UserProfile> updateProfile({
    String? displayName,
    String? bio,
    String? gender,
    String? birthday,
    String? city,
    String? avatarUrl,
    String? backgroundUrl,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/v1/profile/me',
      data: {
        if (displayName != null) 'displayName': displayName,
        if (bio != null) 'bio': bio,
        if (gender != null) 'gender': gender,
        if (birthday != null) 'birthday': birthday,
        if (city != null) 'location': city,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
        if (backgroundUrl != null) 'backgroundURL': backgroundUrl,
      },
    );
    return UserProfile.fromJson(response.data!);
  }

  /// Update the current user's home-city location.
  Future<void> updateLocation({required String location}) async {
    await _dio.patch<void>(
      '/v1/profile/me',
      data: {'location': location},
    );
  }

  /// Delete the current account and invalidate local credentials server-side.
  Future<void> deleteAccount() async {
    await _dio.delete<void>('/v1/auth/account');
  }

  /// Upload the current user's avatar image.
  Future<String> uploadMyAvatar(String localPath) async {
    final formData = FormData.fromMap({
      'avatar': await MultipartFile.fromFile(localPath),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/profile/me/avatar',
      data: formData,
    );
    final data = response.data ?? const <String, dynamic>{};
    final url = data['avatarURL'] ?? data['avatarUrl'] ?? data['url'];
    if (url is String && url.isNotEmpty) return url;
    throw StateError('Avatar upload response did not include a URL.');
  }

  /// Upload the current user's profile background image.
  Future<String> uploadMyBackground(String localPath) async {
    final formData = FormData.fromMap({
      'background': await MultipartFile.fromFile(localPath),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/profile/me/background',
      data: formData,
    );
    final data = response.data ?? const <String, dynamic>{};
    final url = data['backgroundURL'] ?? data['backgroundUrl'] ?? data['url'];
    if (url is String && url.isNotEmpty) return url;
    throw StateError('Background upload response did not include a URL.');
  }

  /// Logs out the current session by invalidating the refresh token.
  Future<void> logout({required String refreshToken}) async {
    await _dio.post<void>(
      '/v1/auth/logout',
      data: {'refreshToken': refreshToken},
    );
  }

  /// Check display name availability.
  Future<bool> checkDisplayName({required String name}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/users/check-display-name',
      queryParameters: {'name': name},
    );
    return response.data!['available'] as bool? ?? false;
  }

  /// Update security settings.
  Future<void> updateSecurity({
    String? currentPassword,
    String? newPassword,
    String? phone,
    String? email,
  }) async {
    await _dio.put<void>(
      '/v1/users/me/security',
      data: {
        if (currentPassword != null) 'currentPassword': currentPassword,
        if (newPassword != null) 'newPassword': newPassword,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
      },
    );
  }

  /// Fetch devices.
  Future<List<AuthSessionItem>> fetchDevices() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/users/me/devices',
    );
    final items = response.data!['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => AuthSessionItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Remove a device.
  Future<void> removeDevice({required String deviceId}) async {
    await _dio.delete<void>('/v1/users/me/devices/$deviceId');
  }
}
