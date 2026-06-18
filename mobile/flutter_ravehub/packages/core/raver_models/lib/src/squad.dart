class SquadProfile {
  final String id;
  final String name;
  final String avatarUrl;
  final String description;
  final int memberCount;
  final List<SquadMemberProfile>? members;
  final String? myRole;
  final String groupId;

  const SquadProfile({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.description,
    required this.memberCount,
    this.members,
    this.myRole,
    required this.groupId,
  });

  factory SquadProfile.fromJson(Map<String, dynamic> json) => SquadProfile(
    id: _string(json['id']),
    name: _string(json['name']),
    avatarUrl: _string(json['avatarUrl'] ?? json['avatarURL']),
    description: _string(json['description']),
    memberCount: _int(json['memberCount']),
    members: (json['members'] as List<dynamic>?)
        ?.map((e) => SquadMemberProfile.fromJson(e as Map<String, dynamic>))
        .toList(),
    myRole: json['myRole'] as String?,
    groupId: _string(json['groupId'] ?? json['groupID'] ?? json['id']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'avatarUrl': avatarUrl,
    'description': description,
    'memberCount': memberCount,
    if (members != null) 'members': members!.map((e) => e.toJson()).toList(),
    if (myRole != null) 'myRole': myRole,
    'groupId': groupId,
  };

  SquadProfile copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    String? description,
    int? memberCount,
    List<SquadMemberProfile>? members,
    String? myRole,
    String? groupId,
  }) => SquadProfile(
    id: id ?? this.id,
    name: name ?? this.name,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    description: description ?? this.description,
    memberCount: memberCount ?? this.memberCount,
    members: members ?? this.members,
    myRole: myRole ?? this.myRole,
    groupId: groupId ?? this.groupId,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SquadProfile && other.id == id && other.name == name;
  }

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'SquadProfile(id: $id, name: $name)';
}

class SquadMemberProfile {
  final String userId;
  final String displayName;
  final String avatarUrl;
  final String role;
  final String joinedAt;

  const SquadMemberProfile({
    required this.userId,
    required this.displayName,
    required this.avatarUrl,
    required this.role,
    required this.joinedAt,
  });

  factory SquadMemberProfile.fromJson(Map<String, dynamic> json) =>
      SquadMemberProfile(
        userId: _string(json['userId'] ?? json['id']),
        displayName: _string(
          json['displayName'] ?? json['nickname'] ?? json['username'],
        ),
        avatarUrl: _string(json['avatarUrl'] ?? json['avatarURL']),
        role: _string(json['role'], fallback: 'member'),
        joinedAt: _string(json['joinedAt']),
      );

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'displayName': displayName,
    'avatarUrl': avatarUrl,
    'role': role,
    'joinedAt': joinedAt,
  };

  SquadMemberProfile copyWith({
    String? userId,
    String? displayName,
    String? avatarUrl,
    String? role,
    String? joinedAt,
  }) => SquadMemberProfile(
    userId: userId ?? this.userId,
    displayName: displayName ?? this.displayName,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    role: role ?? this.role,
    joinedAt: joinedAt ?? this.joinedAt,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SquadMemberProfile && other.userId == userId;
  }

  @override
  int get hashCode => userId.hashCode;

  @override
  String toString() =>
      'SquadMemberProfile(userId: $userId, displayName: $displayName)';
}

class SquadOfflineActivity {
  final String id;
  final String squadId;
  final String eventId;
  final String eventName;
  final String status;
  final String startedAt;
  final String endedAt;
  final List<SquadOfflineActivityParticipant>? participants;

  const SquadOfflineActivity({
    required this.id,
    required this.squadId,
    required this.eventId,
    required this.eventName,
    required this.status,
    required this.startedAt,
    required this.endedAt,
    this.participants,
  });

  factory SquadOfflineActivity.fromJson(Map<String, dynamic> json) =>
      SquadOfflineActivity(
        id: _string(json['id']),
        squadId: _string(json['squadId'] ?? json['squadID']),
        eventId: _string(json['eventId'] ?? json['eventID']),
        eventName: _string(json['eventName']),
        status: _string(json['status'], fallback: 'active'),
        startedAt: _string(json['startedAt']),
        endedAt: _string(json['endedAt']),
        participants: (json['participants'] as List<dynamic>?)
            ?.map(
              (e) => SquadOfflineActivityParticipant.fromJson(
                e as Map<String, dynamic>,
              ),
            )
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'squadId': squadId,
    'eventId': eventId,
    'eventName': eventName,
    'status': status,
    'startedAt': startedAt,
    'endedAt': endedAt,
    if (participants != null)
      'participants': participants!.map((e) => e.toJson()).toList(),
  };

  SquadOfflineActivity copyWith({
    String? id,
    String? squadId,
    String? eventId,
    String? eventName,
    String? status,
    String? startedAt,
    String? endedAt,
    List<SquadOfflineActivityParticipant>? participants,
  }) => SquadOfflineActivity(
    id: id ?? this.id,
    squadId: squadId ?? this.squadId,
    eventId: eventId ?? this.eventId,
    eventName: eventName ?? this.eventName,
    status: status ?? this.status,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt ?? this.endedAt,
    participants: participants ?? this.participants,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SquadOfflineActivity && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'SquadOfflineActivity(id: $id, eventName: $eventName)';
}

class SquadOfflineActivityParticipant {
  final String userId;
  final String displayName;
  final String avatarUrl;
  final double? latitude;
  final double? longitude;
  final String lastLocationAt;

  const SquadOfflineActivityParticipant({
    required this.userId,
    required this.displayName,
    required this.avatarUrl,
    this.latitude,
    this.longitude,
    required this.lastLocationAt,
  });

  factory SquadOfflineActivityParticipant.fromJson(Map<String, dynamic> json) =>
      SquadOfflineActivityParticipant(
        userId: _string(json['userId'] ?? json['id']),
        displayName: _string(
          json['displayName'] ?? json['nickname'] ?? json['username'],
        ),
        avatarUrl: _string(json['avatarUrl'] ?? json['avatarURL']),
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        lastLocationAt: _string(json['lastLocationAt']),
      );

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'displayName': displayName,
    'avatarUrl': avatarUrl,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
    'lastLocationAt': lastLocationAt,
  };

  SquadOfflineActivityParticipant copyWith({
    String? userId,
    String? displayName,
    String? avatarUrl,
    double? latitude,
    double? longitude,
    String? lastLocationAt,
  }) => SquadOfflineActivityParticipant(
    userId: userId ?? this.userId,
    displayName: displayName ?? this.displayName,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    lastLocationAt: lastLocationAt ?? this.lastLocationAt,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SquadOfflineActivityParticipant && other.userId == userId;
  }

  @override
  int get hashCode => userId.hashCode;

  @override
  String toString() =>
      'SquadOfflineActivityParticipant(userId: $userId, displayName: $displayName)';
}

String _string(Object? value, {String fallback = ''}) {
  if (value == null) return fallback;
  if (value is String) return value;
  return value.toString();
}

int _int(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}
