class WebDJSet {
  final String id;
  final String djId;
  final String djName;
  final String djAvatarUrl;
  final String title;
  final String videoUrl;
  final String platform;
  final String videoId;
  final int duration;
  final String recordedAt;
  final String eventId;
  final String eventName;
  final String thumbnailUrl;
  final List<WebDJSetTrack>? tracks;
  final int commentCount;
  final String createdAt;

  const WebDJSet({
    required this.id,
    required this.djId,
    required this.djName,
    required this.djAvatarUrl,
    required this.title,
    required this.videoUrl,
    required this.platform,
    required this.videoId,
    required this.duration,
    required this.recordedAt,
    required this.eventId,
    required this.eventName,
    required this.thumbnailUrl,
    this.tracks,
    required this.commentCount,
    required this.createdAt,
  });

  factory WebDJSet.fromJson(Map<String, dynamic> json) => WebDJSet(
        id: json['id'] as String,
        djId: json['djId'] as String,
        djName: json['djName'] as String,
        djAvatarUrl: json['djAvatarUrl'] as String,
        title: json['title'] as String,
        videoUrl: json['videoUrl'] as String,
        platform: json['platform'] as String,
        videoId: json['videoId'] as String,
        duration: json['duration'] as int,
        recordedAt: json['recordedAt'] as String,
        eventId: json['eventId'] as String,
        eventName: json['eventName'] as String,
        thumbnailUrl: json['thumbnailUrl'] as String,
        tracks: (json['tracks'] as List<dynamic>?)
            ?.map((e) => WebDJSetTrack.fromJson(e as Map<String, dynamic>))
            .toList(),
        commentCount: json['commentCount'] as int,
        createdAt: json['createdAt'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'djId': djId,
        'djName': djName,
        'djAvatarUrl': djAvatarUrl,
        'title': title,
        'videoUrl': videoUrl,
        'platform': platform,
        'videoId': videoId,
        'duration': duration,
        'recordedAt': recordedAt,
        'eventId': eventId,
        'eventName': eventName,
        'thumbnailUrl': thumbnailUrl,
        if (tracks != null)
          'tracks': tracks!.map((e) => e.toJson()).toList(),
        'commentCount': commentCount,
        'createdAt': createdAt,
      };

  WebDJSet copyWith({
    String? id,
    String? djId,
    String? djName,
    String? djAvatarUrl,
    String? title,
    String? videoUrl,
    String? platform,
    String? videoId,
    int? duration,
    String? recordedAt,
    String? eventId,
    String? eventName,
    String? thumbnailUrl,
    List<WebDJSetTrack>? tracks,
    int? commentCount,
    String? createdAt,
  }) =>
      WebDJSet(
        id: id ?? this.id,
        djId: djId ?? this.djId,
        djName: djName ?? this.djName,
        djAvatarUrl: djAvatarUrl ?? this.djAvatarUrl,
        title: title ?? this.title,
        videoUrl: videoUrl ?? this.videoUrl,
        platform: platform ?? this.platform,
        videoId: videoId ?? this.videoId,
        duration: duration ?? this.duration,
        recordedAt: recordedAt ?? this.recordedAt,
        eventId: eventId ?? this.eventId,
        eventName: eventName ?? this.eventName,
        thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
        tracks: tracks ?? this.tracks,
        commentCount: commentCount ?? this.commentCount,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WebDJSet && other.id == id && other.title == title;
  }

  @override
  int get hashCode => Object.hash(id, title);

  @override
  String toString() => 'WebDJSet(id: $id, title: $title)';
}

class WebDJSetTrack {
  final int position;
  final String title;
  final String artist;
  final String label;
  final String startTime;

  const WebDJSetTrack({
    required this.position,
    required this.title,
    required this.artist,
    required this.label,
    required this.startTime,
  });

  factory WebDJSetTrack.fromJson(Map<String, dynamic> json) => WebDJSetTrack(
        position: json['position'] as int,
        title: json['title'] as String,
        artist: json['artist'] as String,
        label: json['label'] as String,
        startTime: json['startTime'] as String,
      );

  Map<String, dynamic> toJson() => {
        'position': position,
        'title': title,
        'artist': artist,
        'label': label,
        'startTime': startTime,
      };

  WebDJSetTrack copyWith({
    int? position,
    String? title,
    String? artist,
    String? label,
    String? startTime,
  }) =>
      WebDJSetTrack(
        position: position ?? this.position,
        title: title ?? this.title,
        artist: artist ?? this.artist,
        label: label ?? this.label,
        startTime: startTime ?? this.startTime,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WebDJSetTrack &&
        other.position == position &&
        other.title == title &&
        other.artist == artist;
  }

  @override
  int get hashCode => Object.hash(position, title, artist);

  @override
  String toString() =>
      'WebDJSetTrack(position: $position, title: $title, artist: $artist)';
}

class WebTracklistSummary {
  final String id;
  final String name;
  final int trackCount;

  const WebTracklistSummary({
    required this.id,
    required this.name,
    required this.trackCount,
  });

  factory WebTracklistSummary.fromJson(Map<String, dynamic> json) =>
      WebTracklistSummary(
        id: json['id'] as String,
        name: json['name'] as String,
        trackCount: json['trackCount'] as int,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'trackCount': trackCount,
      };

  WebTracklistSummary copyWith({String? id, String? name, int? trackCount}) =>
      WebTracklistSummary(
        id: id ?? this.id,
        name: name ?? this.name,
        trackCount: trackCount ?? this.trackCount,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WebTracklistSummary && other.id == id && other.name == name;
  }

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'WebTracklistSummary(id: $id, name: $name)';
}

class WebSetComment {
  final String id;
  final String userId;
  final String displayName;
  final String avatarUrl;
  final String content;
  final String createdAt;

  const WebSetComment({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.avatarUrl,
    required this.content,
    required this.createdAt,
  });

  factory WebSetComment.fromJson(Map<String, dynamic> json) => WebSetComment(
        id: json['id'] as String,
        userId: json['userId'] as String,
        displayName: json['displayName'] as String,
        avatarUrl: json['avatarUrl'] as String,
        content: json['content'] as String,
        createdAt: json['createdAt'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'content': content,
        'createdAt': createdAt,
      };

  WebSetComment copyWith({
    String? id,
    String? userId,
    String? displayName,
    String? avatarUrl,
    String? content,
    String? createdAt,
  }) =>
      WebSetComment(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        displayName: displayName ?? this.displayName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        content: content ?? this.content,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WebSetComment && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'WebSetComment(id: $id, displayName: $displayName)';
}
