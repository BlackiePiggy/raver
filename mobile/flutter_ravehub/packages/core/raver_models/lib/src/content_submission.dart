class ContentSubmissionSummary {
  final String id;
  final String entityType;
  final String entityName;
  final String status;
  final String createdAt;
  final String updatedAt;

  const ContentSubmissionSummary({
    required this.id,
    required this.entityType,
    required this.entityName,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ContentSubmissionSummary.fromJson(Map<String, dynamic> json) =>
      ContentSubmissionSummary(
        id: json['id'] as String,
        entityType: json['entityType'] as String,
        entityName: json['entityName'] as String,
        status: json['status'] as String,
        createdAt: json['createdAt'] as String,
        updatedAt: json['updatedAt'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'entityType': entityType,
        'entityName': entityName,
        'status': status,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  ContentSubmissionSummary copyWith({
    String? id,
    String? entityType,
    String? entityName,
    String? status,
    String? createdAt,
    String? updatedAt,
  }) =>
      ContentSubmissionSummary(
        id: id ?? this.id,
        entityType: entityType ?? this.entityType,
        entityName: entityName ?? this.entityName,
        status: status ?? this.status,
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
  final String status;
  final List<ContentSubmissionVersionSummary> versions;
  final String reviewNote;
  final String createdAt;

  const ContentSubmissionDetail({
    required this.id,
    required this.entityType,
    required this.entityName,
    required this.status,
    required this.versions,
    required this.reviewNote,
    required this.createdAt,
  });

  factory ContentSubmissionDetail.fromJson(Map<String, dynamic> json) =>
      ContentSubmissionDetail(
        id: json['id'] as String,
        entityType: json['entityType'] as String,
        entityName: json['entityName'] as String,
        status: json['status'] as String,
        versions: (json['versions'] as List<dynamic>? ?? [])
            .map((e) => ContentSubmissionVersionSummary.fromJson(
                e as Map<String, dynamic>))
            .toList(),
        reviewNote: json['reviewNote'] as String,
        createdAt: json['createdAt'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'entityType': entityType,
        'entityName': entityName,
        'status': status,
        'versions': versions.map((e) => e.toJson()).toList(),
        'reviewNote': reviewNote,
        'createdAt': createdAt,
      };

  ContentSubmissionDetail copyWith({
    String? id,
    String? entityType,
    String? entityName,
    String? status,
    List<ContentSubmissionVersionSummary>? versions,
    String? reviewNote,
    String? createdAt,
  }) =>
      ContentSubmissionDetail(
        id: id ?? this.id,
        entityType: entityType ?? this.entityType,
        entityName: entityName ?? this.entityName,
        status: status ?? this.status,
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
      'ContentSubmissionDetail(id: $id, entityType: $entityType, entityName: $entityName, status: $status)';
}

class ContentSubmissionVersionSummary {
  final String id;
  final String status;
  final String createdAt;

  const ContentSubmissionVersionSummary({
    required this.id,
    required this.status,
    required this.createdAt,
  });

  factory ContentSubmissionVersionSummary.fromJson(
    Map<String, dynamic> json,
  ) =>
      ContentSubmissionVersionSummary(
        id: json['id'] as String,
        status: json['status'] as String,
        createdAt: json['createdAt'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'status': status,
        'createdAt': createdAt,
      };

  ContentSubmissionVersionSummary copyWith({
    String? id,
    String? status,
    String? createdAt,
  }) =>
      ContentSubmissionVersionSummary(
        id: id ?? this.id,
        status: status ?? this.status,
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
