enum VirtualAssetType {
  avatarFrame,
  profileBadge,
  chatBubbleSkin,
  titleMedal,
  unknown;

  static final _snakeCaseMap = <String, VirtualAssetType>{
    'avatar_frame': avatarFrame,
    'profile_badge': profileBadge,
    'chat_bubble_skin': chatBubbleSkin,
    'title_medal': titleMedal,
    'unknown': unknown,
  };

  static final _toSnakeCase = <VirtualAssetType, String>{
    for (final entry in _snakeCaseMap.entries) entry.value: entry.key,
  };

  static VirtualAssetType fromJson(String v) =>
      _snakeCaseMap[v] ?? VirtualAssetType.unknown;

  String toJson() => _toSnakeCase[this] ?? name;
}

class VirtualAssetDefinition {
  final String id;
  final String code;
  final VirtualAssetType type;
  final String name;
  final String previewImageUrl;

  const VirtualAssetDefinition({
    required this.id,
    required this.code,
    required this.type,
    required this.name,
    required this.previewImageUrl,
  });

  factory VirtualAssetDefinition.fromJson(Map<String, dynamic> json) =>
      VirtualAssetDefinition(
        id: json['id'] as String,
        code: json['code'] as String,
        type: VirtualAssetType.fromJson(json['type'] as String),
        name: json['name'] as String,
        previewImageUrl: json['previewImageUrl'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'type': type.toJson(),
        'name': name,
        'previewImageUrl': previewImageUrl,
      };

  VirtualAssetDefinition copyWith({
    String? id,
    String? code,
    VirtualAssetType? type,
    String? name,
    String? previewImageUrl,
  }) =>
      VirtualAssetDefinition(
        id: id ?? this.id,
        code: code ?? this.code,
        type: type ?? this.type,
        name: name ?? this.name,
        previewImageUrl: previewImageUrl ?? this.previewImageUrl,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VirtualAssetDefinition &&
        other.id == id &&
        other.code == code;
  }

  @override
  int get hashCode => Object.hash(id, code);

  @override
  String toString() =>
      'VirtualAssetDefinition(id: $id, code: $code, type: $type, name: $name)';
}

class UserVirtualAsset {
  final String id;
  final String definitionId;
  final VirtualAssetType type;
  final String status;

  const UserVirtualAsset({
    required this.id,
    required this.definitionId,
    required this.type,
    required this.status,
  });

  factory UserVirtualAsset.fromJson(Map<String, dynamic> json) =>
      UserVirtualAsset(
        id: json['id'] as String,
        definitionId: json['definitionId'] as String,
        type: VirtualAssetType.fromJson(json['type'] as String),
        status: json['status'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'definitionId': definitionId,
        'type': type.toJson(),
        'status': status,
      };

  UserVirtualAsset copyWith({
    String? id,
    String? definitionId,
    VirtualAssetType? type,
    String? status,
  }) =>
      UserVirtualAsset(
        id: id ?? this.id,
        definitionId: definitionId ?? this.definitionId,
        type: type ?? this.type,
        status: status ?? this.status,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserVirtualAsset &&
        other.id == id &&
        other.definitionId == definitionId;
  }

  @override
  int get hashCode => Object.hash(id, definitionId);

  @override
  String toString() =>
      'UserVirtualAsset(id: $id, definitionId: $definitionId, type: $type, status: $status)';
}

class UserAssetAppearance {
  final String frameDefinitionId;
  final String medalDefinitionId;
  final List<String>? badgeDefinitionIds;

  const UserAssetAppearance({
    required this.frameDefinitionId,
    required this.medalDefinitionId,
    this.badgeDefinitionIds,
  });

  factory UserAssetAppearance.fromJson(Map<String, dynamic> json) =>
      UserAssetAppearance(
        frameDefinitionId: json['frameDefinitionId'] as String,
        medalDefinitionId: json['medalDefinitionId'] as String,
        badgeDefinitionIds: (json['badgeDefinitionIds'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'frameDefinitionId': frameDefinitionId,
        'medalDefinitionId': medalDefinitionId,
        if (badgeDefinitionIds != null)
          'badgeDefinitionIds': badgeDefinitionIds,
      };

  UserAssetAppearance copyWith({
    String? frameDefinitionId,
    String? medalDefinitionId,
    List<String>? badgeDefinitionIds,
  }) =>
      UserAssetAppearance(
        frameDefinitionId: frameDefinitionId ?? this.frameDefinitionId,
        medalDefinitionId: medalDefinitionId ?? this.medalDefinitionId,
        badgeDefinitionIds: badgeDefinitionIds ?? this.badgeDefinitionIds,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserAssetAppearance &&
        other.frameDefinitionId == frameDefinitionId &&
        other.medalDefinitionId == medalDefinitionId;
  }

  @override
  int get hashCode => Object.hash(frameDefinitionId, medalDefinitionId);

  @override
  String toString() =>
      'UserAssetAppearance(frameDefinitionId: $frameDefinitionId, medalDefinitionId: $medalDefinitionId)';
}
