import 'package:raver_models/raver_models.dart';

import 'profile_api.dart';

class ProfileRepository {
  ProfileRepository(this._api);

  final ProfileApi _api;

  Future<UserProfile> fetchMe() => _api.fetchMe();

  Future<BFFListPage<Post>> fetchMyPosts({
    required int page,
    int limit = 20,
  }) =>
      _api.fetchMyPosts(page: page, limit: limit);

  Future<BFFListPage<Post>> fetchMySaves({
    required int page,
    int limit = 20,
    String? type,
  }) =>
      _api.fetchMySaves(page: page, limit: limit, type: type);

  Future<Map<String, dynamic>> fetchContributions() =>
      _api.fetchContributions();

  Future<UserProfile> fetchUserProfile({required String userId}) =>
      _api.fetchUserProfile(userId: userId);

  Future<BFFListPage<Post>> fetchUserPosts({
    required String userId,
    required int page,
    int limit = 20,
  }) =>
      _api.fetchUserPosts(userId: userId, page: page, limit: limit);

  Future<void> followUser({required String userId}) =>
      _api.followUser(userId: userId);

  Future<void> unfollowUser({required String userId}) =>
      _api.unfollowUser(userId: userId);

  Future<void> reportUser({
    required String userId,
    required String reason,
  }) =>
      _api.reportUser(userId: userId, reason: reason);

  Future<void> blockUser({required String userId}) =>
      _api.blockUser(userId: userId);

  Future<UserProfile> updateProfile({
    String? displayName,
    String? bio,
    String? gender,
    String? birthday,
    String? city,
    String? avatarUrl,
  }) =>
      _api.updateProfile(
        displayName: displayName,
        bio: bio,
        gender: gender,
        birthday: birthday,
        city: city,
        avatarUrl: avatarUrl,
      );

  Future<bool> checkDisplayName({required String name}) =>
      _api.checkDisplayName(name: name);

  Future<void> updateSecurity({
    String? currentPassword,
    String? newPassword,
    String? phone,
    String? email,
  }) =>
      _api.updateSecurity(
        currentPassword: currentPassword,
        newPassword: newPassword,
        phone: phone,
        email: email,
      );

  Future<List<AuthSessionItem>> fetchDevices() => _api.fetchDevices();

  Future<void> removeDevice({required String deviceId}) =>
      _api.removeDevice(deviceId: deviceId);
}
