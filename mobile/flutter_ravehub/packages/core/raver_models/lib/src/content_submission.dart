class ContentSubmissionSummary {
  final String id;
  final String entityType;
  final String entityName;
  final String status;
  final String? statusLabel;
  final String createdAt;
  final String updatedAt;

  const ContentSubmissionSummary({
    required this.id,
    required this.entityType,
    required this.entityName,
    required this.status,
    this.statusLabel,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ContentSubmissionSummary.fromJson(Map<String, dynamic> json) =>
      ContentSubmissionSummary(
        id: json['id'] as String,
        entityType: json['entityType'] as String,
        entityName: json['entityName'] as String,
        status: json['status'] as String,
        statusLabel: _readSubmissionStatusLabel(json),
        createdAt: json['createdAt'] as String,
        updatedAt: json['updatedAt'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'entityType': entityType,
        'entityName': entityName,
        'status': status,
        if (statusLabel != null) 'statusLabel': statusLabel,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  ContentSubmissionSummary copyWith({
    String? id,
    String? entityType,
    String? entityName,
    String? status,
    String? statusLabel,
    String? createdAt,
    String? updatedAt,
  }) =>
      ContentSubmissionSummary(
        id: id ?? this.id,
        entityType: entityType ?? this.entityType,
        entityName: entityName ?? this.entityName,
        status: status ?? this.status,
        statusLabel: statusLabel ?? this.statusLabel,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ContentSubmissionSummary &&
        other.id == id &&
        other.entityType == entityType &&
        other.status == status;
  }

  @override
  int get hashCode => Object.hash(id, entityType, status);

  @override
  String toString() =>
      'ContentSubmissionSummary(id: $id, entityType: $entityType, entityName: $entityName, status: $status)';
}

class ContentSubmissionDetail {
  final String id;
  final String entityType;
  final String entityName;
  final String? entityId;
  final String status;
  final String? statusLabel;
  final List<ContentSubmissionVersionSummary> versions;
  final String reviewNote;
  final String createdAt;

  const ContentSubmissionDetail({
    required this.id,
    required this.entityType,
    required this.entityName,
    this.entityId,
    required this.status,
    this.statusLabel,
    required this.versions,
    required this.reviewNote,
    required this.createdAt,
  });

  factory ContentSubmissionDetail.fromJson(Map<String, dynamic> json) =>
      ContentSubmissionDetail(
        id: json['id'] as String,
        entityType: json['entityType'] as String,
        entityName: json['entityName'] as String,
        entityId: _readSubmissionEntityId(json),
        status: json['status'] as String,
        statusLabel: _readSubmissionStatusLabel(json),
        versions: (json['versions'] as List<dynamic>? ?? [])
            .map(
              (e) => ContentSubmissionVersionSummary.fromJson(
                e as Map<String, dynamic>,
              ),
            )
            .toList(),
        reviewNote: json['reviewNote'] as String,
        createdAt: json['createdAt'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'entityType': entityType,
        'entityName': entityName,
        if (entityId != null) 'entityId': entityId,
        'status': status,
        if (statusLabel != null) 'statusLabel': statusLabel,
        'versions': versions.map((e) => e.toJson()).toList(),
        'reviewNote': reviewNote,
        'createdAt': createdAt,
      };

  ContentSubmissionDetail copyWith({
    String? id,
    String? entityType,
    String? entityName,
    String? entityId,
    String? status,
    String? statusLabel,
    List<ContentSubmissionVersionSummary>? versions,
    String? reviewNote,
    String? createdAt,
  }) =>
      ContentSubmissionDetail(
        id: id ?? this.id,
        entityType: entityType ?? this.entityType,
        entityName: entityName ?? this.entityName,
        entityId: entityId ?? this.entityId,
        status: status ?? this.status,
        statusLabel: statusLabel ?? this.statusLabel,
        versions: versions ?? this.versions,
        reviewNote: reviewNote ?? this.reviewNote,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ContentSubmissionDetail &&
        other.id == id &&
        other.entityType == entityType &&
        other.status == status;
  }

  @override
  int get hashCode => Object.hash(id, entityType, status);

  @override
  String toString() =>
      'ContentSubmissionDetail(id: $id, entityType: $entityType, entityName: $entityName, entityId: $entityId, status: $status)';
}

String? _readSubmissionEntityId(Map<String, dynamic> json) {
  for (final key in const ['entityId', 'targetId', 'contentId', 'resourceId']) {
    final value = _stringOrNull(json[key]);
    if (value != null) return value;
  }

  for (final key in const ['entity', 'target', 'content', 'resource']) {
    final nested = json[key];
    if (nested is Map<String, dynamic>) {
      final value = _stringOrNull(nested['id']);
      if (value != null) return value;
    }
  }
  return null;
}

String? _readSubmissionStatusLabel(Map<String, dynamic> json) {
  for (final key in const [
    'statusLabel',
    'reviewStatusLabel',
    'moderationLabel',
  ]) {
    final value = _stringOrNull(json[key]);
    if (value != null) return value;
  }

  for (final key in const ['metadata', 'reviewNotes', 'reviewNote']) {
    final nested = json[key];
    if (nested is Map<String, dynamic>) {
      final value = _stringOrNull(nested['statusLabel']);
      if (value != null) return value;

      final reviewDecision = nested['reviewDecision'];
      if (reviewDecision is Map<String, dynamic>) {
        final decisionLabel = _stringOrNull(reviewDecision['statusLabel']);
        if (decisionLabel != null) return decisionLabel;
      }
    }
  }

  return null;
}

String? _stringOrNull(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

class ContentSubmissionVersionSummary {
  final String id;
  final String status;
  final String? statusLabel;
  final String createdAt;

  const ContentSubmissionVersionSummary({
    required this.id,
    required this.status,
    this.statusLabel,
    required this.createdAt,
  });

  factory ContentSubmissionVersionSummary.fromJson(Map<String, dynamic> json) =>
      ContentSubmissionVersionSummary(
        id: json['id'] as String,
        status: json['status'] as String,
        statusLabel: _readSubmissionStatusLabel(json),
        createdAt: json['createdAt'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'status': status,
        if (statusLabel != null) 'statusLabel': statusLabel,
        'createdAt': createdAt,
      };

  ContentSubmissionVersionSummary copyWith({
    String? id,
    String? status,
    String? statusLabel,
    String? createdAt,
  }) =>
      ContentSubmissionVersionSummary(
        id: id ?? this.id,
        status: status ?? this.status,
        statusLabel: statusLabel ?? this.statusLabel,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ContentSubmissionVersionSummary &&
        other.id == id &&
        other.status == status;
  }

  @override
  int get hashCode => Object.hash(id, status);

  @override
  String toString() =>
      'ContentSubmissionVersionSummary(id: $id, status: $status, createdAt: $createdAt)';
}
