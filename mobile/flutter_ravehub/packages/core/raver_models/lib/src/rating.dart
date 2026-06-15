class WebRatingEvent {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final String eventId;
  final String eventName;
  final List<WebRatingUnit>? units;
  final String creatorId;
  final String createdAt;

  const WebRatingEvent({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.eventId,
    required this.eventName,
    this.units,
    required this.creatorId,
    required this.createdAt,
  });

  factory WebRatingEvent.fromJson(Map<String, dynamic> json) => WebRatingEvent(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        imageUrl: json['imageUrl'] as String,
        eventId: json['eventId'] as String,
        eventName: json['eventName'] as String,
        units: json['units'] != null
            ? (json['units'] as List<dynamic>)
                .map((e) => WebRatingUnit.fromJson(e as Map<String, dynamic>))
                .toList()
            : null,
        creatorId: json['creatorId'] as String,
        createdAt: json['createdAt'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'imageUrl': imageUrl,
        'eventId': eventId,
        'eventName': eventName,
        if (units != null) 'units': units!.map((e) => e.toJson()).toList(),
        'creatorId': creatorId,
        'createdAt': createdAt,
      };

  WebRatingEvent copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    String? eventId,
    String? eventName,
    List<WebRatingUnit>? units,
    String? creatorId,
    String? createdAt,
  }) =>
      WebRatingEvent(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        imageUrl: imageUrl ?? this.imageUrl,
        eventId: eventId ?? this.eventId,
        eventName: eventName ?? this.eventName,
        units: units ?? this.units,
        creatorId: creatorId ?? this.creatorId,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WebRatingEvent &&
        other.id == id &&
        other.name == name &&
        other.eventId == eventId &&
        other.eventName == eventName;
  }

  @override
  int get hashCode => Object.hash(id, name, eventId, eventName);

  @override
  String toString() =>
      'WebRatingEvent(id: $id, name: $name, eventId: $eventId, eventName: $eventName)';
}

class WebRatingUnit {
  final String id;
  final String name;
  final String djId;
  final String djName;
  final String djAvatarUrl;
  final double? rating;
  final int ratingCount;
  final int commentCount;
  final String createdAt;

  const WebRatingUnit({
    required this.id,
    required this.name,
    required this.djId,
    required this.djName,
    required this.djAvatarUrl,
    this.rating,
    required this.ratingCount,
    required this.commentCount,
    required this.createdAt,
  });

  factory WebRatingUnit.fromJson(Map<String, dynamic> json) => WebRatingUnit(
        id: json['id'] as String,
        name: json['name'] as String,
        djId: json['djId'] as String,
        djName: json['djName'] as String,
        djAvatarUrl: json['djAvatarUrl'] as String,
        rating: (json['rating'] as num?)?.toDouble(),
        ratingCount: json['ratingCount'] as int,
        commentCount: json['commentCount'] as int,
        createdAt: json['createdAt'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'djId': djId,
        'djName': djName,
        'djAvatarUrl': djAvatarUrl,
        if (rating != null) 'rating': rating,
        'ratingCount': ratingCount,
        'commentCount': commentCount,
        'createdAt': createdAt,
      };

  WebRatingUnit copyWith({
    String? id,
    String? name,
    String? djId,
    String? djName,
    String? djAvatarUrl,
    double? rating,
    int? ratingCount,
    int? commentCount,
    String? createdAt,
  }) =>
      WebRatingUnit(
        id: id ?? this.id,
        name: name ?? this.name,
        djId: djId ?? this.djId,
        djName: djName ?? this.djName,
        djAvatarUrl: djAvatarUrl ?? this.djAvatarUrl,
        rating: rating ?? this.rating,
        ratingCount: ratingCount ?? this.ratingCount,
        commentCount: commentCount ?? this.commentCount,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WebRatingUnit &&
        other.id == id &&
        other.name == name &&
        other.djId == djId;
  }

  @override
  int get hashCode => Object.hash(id, name, djId);

  @override
  String toString() =>
      'WebRatingUnit(id: $id, name: $name, djId: $djId, djName: $djName)';
}

class WebRatingComment {
  final String id;
  final String userId;
  final String displayName;
  final String avatarUrl;
  final double score;
  final String content;
  final String createdAt;

  const WebRatingComment({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.avatarUrl,
    required this.score,
    required this.content,
    required this.createdAt,
  });

  factory WebRatingComment.fromJson(Map<String, dynamic> json) =>
      WebRatingComment(
        id: json['id'] as String,
        userId: json['userId'] as String,
        displayName: json['displayName'] as String,
        avatarUrl: json['avatarUrl'] as String,
        score: (json['score'] as num).toDouble(),
        content: json['content'] as String,
        createdAt: json['createdAt'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'score': score,
        'content': content,
        'createdAt': createdAt,
      };

  WebRatingComment copyWith({
    String? id,
    String? userId,
    String? displayName,
    String? avatarUrl,
    double? score,
    String? content,
    String? createdAt,
  }) =>
      WebRatingComment(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        displayName: displayName ?? this.displayName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        score: score ?? this.score,
        content: content ?? this.content,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WebRatingComment &&
        other.id == id &&
        other.userId == userId;
  }

  @override
  int get hashCode => Object.hash(id, userId);

  @override
  String toString() =>
      'WebRatingComment(id: $id, userId: $userId, displayName: $displayName, score: $score)';
}
