class Session {
  final String token;
  final String refreshToken;
  final int accessTokenExpiresIn;
  final UserSummary user;

  const Session({
    required this.token,
    required this.refreshToken,
    required this.accessTokenExpiresIn,
    required this.user,
  });

  factory Session.fromJson(Map<String, dynamic> json) => Session(
        token: json['token'] as String,
        refreshToken: json['refreshToken'] as String,
        accessTokenExpiresIn: json['accessTokenExpiresIn'] as int,
        user: UserSummary.fromJson(json['user'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'token': token,
        'refreshToken': refreshToken,
        'accessTokenExpiresIn': accessTokenExpiresIn,
        'user': user.toJson(),
      };

  Session copyWith({
    String? token,
    String? refreshToken,
    int? accessTokenExpiresIn,
    UserSummary? user,
  }) =>
      Session(
        token: token ?? this.token,
        refreshToken: refreshToken ?? this.refreshToken,
        accessTokenExpiresIn: accessTokenExpiresIn ?? this.accessTokenExpiresIn,
        user: user ?? this.user,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Session &&
        other.token == token &&
        other.refreshToken == refreshToken &&
        other.accessTokenExpiresIn == accessTokenExpiresIn &&
        other.user == user;
  }

  @override
  int get hashCode =>
      Object.hash(token, refreshToken, accessTokenExpiresIn, user);

  @override
  String toString() =>
      'Session(token: $token, refreshToken: $refreshToken, accessTokenExpiresIn: $accessTokenExpiresIn, user: $user)';
}

class UserSummary {
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String? bio;

  const UserSummary({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.bio,
  });

  factory UserSummary.fromJson(Map<String, dynamic> json) => UserSummary(
        id: json['id'] as String,
        username: json['username'] as String,
        displayName: json['displayName'] as String,
        avatarUrl: json['avatarUrl'] as String? ?? json['avatarURL'] as String?,
        bio: json['bio'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'displayName': displayName,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
        if (bio != null) 'bio': bio,
      };

  UserSummary copyWith({
    String? id,
    String? username,
    String? displayName,
    String? avatarUrl,
    String? bio,
  }) =>
      UserSummary(
        id: id ?? this.id,
        username: username ?? this.username,
        displayName: displayName ?? this.displayName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        bio: bio ?? this.bio,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserSummary &&
        other.id == id &&
        other.username == username &&
        other.displayName == displayName &&
        other.avatarUrl == avatarUrl &&
        other.bio == bio;
  }

  @override
  int get hashCode => Object.hash(id, username, displayName, avatarUrl, bio);

  @override
  String toString() =>
      'UserSummary(id: $id, username: $username, displayName: $displayName, avatarUrl: $avatarUrl, bio: $bio)';
}

class UserProfile {
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String? backgroundUrl;
  final String? bio;
  final int followerCount;
  final int followingCount;
  final int friendCount;
  final int postCount;
  final String ageBand;
  final bool? isFollowing;
  final bool? isBlocked;

  const UserProfile({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.backgroundUrl,
    this.bio,
    required this.followerCount,
    required this.followingCount,
    required this.friendCount,
    this.postCount = 0,
    required this.ageBand,
    this.isFollowing,
    this.isBlocked,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: _stringFromJson(json, const ['id']),
        username: _stringFromJson(json, const ['username']),
        displayName: _stringFromJson(
          json,
          const ['displayName', 'display_name', 'name'],
        ),
        avatarUrl: _optionalStringFromJson(
          json,
          const ['avatarUrl', 'avatarURL', 'avatar_url'],
        ),
        backgroundUrl: json['backgroundUrl'] as String? ??
            json['backgroundURL'] as String? ??
            json['background_url'] as String? ??
            json['backgroundImageUrl'] as String? ??
            json['backgroundImageURL'] as String? ??
            json['background_image_url'] as String?,
        bio: _optionalStringFromJson(json, const ['bio']),
        followerCount: _intFromJson(
          json,
          const ['followerCount', 'follower_count', 'followers'],
        ),
        followingCount: _intFromJson(
          json,
          const ['followingCount', 'following_count', 'followings'],
        ),
        friendCount: _intFromJson(
          json,
          const ['friendCount', 'friend_count', 'friends'],
        ),
        postCount: _intFromJson(
          json,
          const ['postCount', 'post_count', 'posts'],
        ),
        ageBand: _stringFromJson(json, const ['ageBand', 'age_band']),
        isFollowing: _optionalBoolFromJson(
          json,
          const ['isFollowing', 'is_following'],
        ),
        isBlocked: _optionalBoolFromJson(
          json,
          const ['isBlocked', 'is_blocked'],
        ),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'displayName': displayName,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
        if (backgroundUrl != null) 'backgroundUrl': backgroundUrl,
        if (bio != null) 'bio': bio,
        'followerCount': followerCount,
        'followingCount': followingCount,
        'friendCount': friendCount,
        'postCount': postCount,
        'ageBand': ageBand,
        if (isFollowing != null) 'isFollowing': isFollowing,
        if (isBlocked != null) 'isBlocked': isBlocked,
      };

  UserProfile copyWith({
    String? id,
    String? username,
    String? displayName,
    String? avatarUrl,
    String? backgroundUrl,
    String? bio,
    int? followerCount,
    int? followingCount,
    int? friendCount,
    int? postCount,
    String? ageBand,
    bool? isFollowing,
    bool? isBlocked,
  }) =>
      UserProfile(
        id: id ?? this.id,
        username: username ?? this.username,
        displayName: displayName ?? this.displayName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        backgroundUrl: backgroundUrl ?? this.backgroundUrl,
        bio: bio ?? this.bio,
        followerCount: followerCount ?? this.followerCount,
        followingCount: followingCount ?? this.followingCount,
        friendCount: friendCount ?? this.friendCount,
        postCount: postCount ?? this.postCount,
        ageBand: ageBand ?? this.ageBand,
        isFollowing: isFollowing ?? this.isFollowing,
        isBlocked: isBlocked ?? this.isBlocked,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfile &&
        other.id == id &&
        other.username == username &&
        other.displayName == displayName &&
        other.avatarUrl == avatarUrl &&
        other.backgroundUrl == backgroundUrl &&
        other.bio == bio &&
        other.followerCount == followerCount &&
        other.followingCount == followingCount &&
        other.friendCount == friendCount &&
        other.ageBand == ageBand &&
        other.isFollowing == isFollowing &&
        other.isBlocked == isBlocked;
  }

  @override
  int get hashCode => Object.hash(
        id,
        username,
        displayName,
        avatarUrl,
        backgroundUrl,
        bio,
        followerCount,
        followingCount,
        friendCount,
        ageBand,
        isFollowing,
        isBlocked,
      );

  @override
  String toString() =>
      'UserProfile(id: $id, username: $username, displayName: $displayName, avatarUrl: $avatarUrl, backgroundUrl: $backgroundUrl, bio: $bio, followerCount: $followerCount, followingCount: $followingCount, friendCount: $friendCount, ageBand: $ageBand, isFollowing: $isFollowing, isBlocked: $isBlocked)';
}

class AuthSessionItem {
  final String id;
  final String deviceInfo;
  final String ipAddress;
  final String lastActiveAt;
  final String createdAt;
  final bool isCurrent;

  const AuthSessionItem({
    required this.id,
    required this.deviceInfo,
    required this.ipAddress,
    required this.lastActiveAt,
    required this.createdAt,
    required this.isCurrent,
  });

  factory AuthSessionItem.fromJson(Map<String, dynamic> json) =>
      AuthSessionItem(
        id: json['id'] as String,
        deviceInfo: json['deviceInfo'] as String,
        ipAddress: json['ipAddress'] as String,
        lastActiveAt: json['lastActiveAt'] as String,
        createdAt: json['createdAt'] as String,
        isCurrent: json['isCurrent'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'deviceInfo': deviceInfo,
        'ipAddress': ipAddress,
        'lastActiveAt': lastActiveAt,
        'createdAt': createdAt,
        'isCurrent': isCurrent,
      };

  AuthSessionItem copyWith({
    String? id,
    String? deviceInfo,
    String? ipAddress,
    String? lastActiveAt,
    String? createdAt,
    bool? isCurrent,
  }) =>
      AuthSessionItem(
        id: id ?? this.id,
        deviceInfo: deviceInfo ?? this.deviceInfo,
        ipAddress: ipAddress ?? this.ipAddress,
        lastActiveAt: lastActiveAt ?? this.lastActiveAt,
        createdAt: createdAt ?? this.createdAt,
        isCurrent: isCurrent ?? this.isCurrent,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuthSessionItem &&
        other.id == id &&
        other.deviceInfo == deviceInfo &&
        other.ipAddress == ipAddress &&
        other.lastActiveAt == lastActiveAt &&
        other.createdAt == createdAt &&
        other.isCurrent == isCurrent;
  }

  @override
  int get hashCode => Object.hash(
        id,
        deviceInfo,
        ipAddress,
        lastActiveAt,
        createdAt,
        isCurrent,
      );

  @override
  String toString() =>
      'AuthSessionItem(id: $id, deviceInfo: $deviceInfo, ipAddress: $ipAddress, lastActiveAt: $lastActiveAt, createdAt: $createdAt, isCurrent: $isCurrent)';
}

String _stringFromJson(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is String) return value;
  }
  return '';
}

String? _optionalStringFromJson(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is String) return value;
  }
  return null;
}

int _intFromJson(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
  }
  return 0;
}

bool? _optionalBoolFromJson(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is bool) return value;
  }
  return null;
}
