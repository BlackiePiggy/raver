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
        id: _string(json['id']),
        name: _string(json['name']),
        description: _string(json['description']),
        imageUrl: _string(json['imageUrl'] ?? json['coverImageUrl']),
        eventId: _string(json['eventId'] ?? json['sourceEventId']),
        eventName: _string(json['eventName'] ?? json['name']),
        units: json['units'] != null
            ? (json['units'] as List<dynamic>)
                .map((e) => WebRatingUnit.fromJson(e as Map<String, dynamic>))
                .toList()
            : null,
        creatorId: _string(
          json['creatorId'] ??
              (json['createdBy'] is Map<String, dynamic>
                  ? (json['createdBy'] as Map<String, dynamic>)['id']
                  : null),
        ),
        createdAt: _string(json['createdAt']),
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
  final String description;
  final String imageUrl;
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
    this.description = '',
    this.imageUrl = '',
    required this.djId,
    required this.djName,
    required this.djAvatarUrl,
    this.rating,
    required this.ratingCount,
    required this.commentCount,
    required this.createdAt,
  });

  factory WebRatingUnit.fromJson(Map<String, dynamic> json) => WebRatingUnit(
        id: _string(json['id']),
        name: _string(json['name']),
        description: _string(json['description']),
        imageUrl: _string(json['imageUrl'] ?? json['coverImageUrl']),
        djId: _string(
          json['djId'] ??
              _firstLinkedDjValue(json, 'id') ??
              (json['djIds'] is List<dynamic> &&
                      (json['djIds'] as List<dynamic>).isNotEmpty
                  ? (json['djIds'] as List<dynamic>).first
                  : null),
        ),
        djName: _string(_firstLinkedDjValue(json, 'name') ?? json['name']),
        djAvatarUrl: _string(
          json['djAvatarUrl'] ??
              _firstLinkedDjValue(json, 'avatarUrl') ??
              json['imageUrl'],
        ),
        rating: (json['rating'] as num?)?.toDouble(),
        ratingCount: _int(json['ratingCount']),
        commentCount: _int(
          json['commentCount'] ??
              (json['comments'] is List<dynamic>
                  ? (json['comments'] as List<dynamic>).length
                  : null),
        ),
        createdAt: _string(json['createdAt']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'imageUrl': imageUrl,
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
    String? description,
    String? imageUrl,
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
        description: description ?? this.description,
        imageUrl: imageUrl ?? this.imageUrl,
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
        id: _string(json['id']),
        userId: _string(
          json['userId'] ??
              (json['user'] is Map<String, dynamic>
                  ? (json['user'] as Map<String, dynamic>)['id']
                  : null),
        ),
        displayName: _string(
          json['displayName'] ??
              (json['user'] is Map<String, dynamic>
                  ? ((json['user'] as Map<String, dynamic>)['displayName'] ??
                      (json['user'] as Map<String, dynamic>)['username'])
                  : null),
        ),
        avatarUrl: _string(
          json['avatarUrl'] ??
              (json['user'] is Map<String, dynamic>
                  ? (json['user'] as Map<String, dynamic>)['avatarUrl']
                  : null),
        ),
        score: (json['score'] as num?)?.toDouble() ?? 0,
        content: _string(json['content']),
        createdAt: _string(json['createdAt']),
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

Object? _firstLinkedDjValue(Map<String, dynamic> json, String key) {
  final linked = json['linkedDJs'];
  if (linked is List<dynamic> && linked.isNotEmpty) {
    final first = linked.first;
    if (first is Map<String, dynamic>) return first[key];
  }
  return null;
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
