class WebDJSet {
  final String id;
  final String djId;
  final String djName;
  final String djAvatarUrl;
  final String title;
  final String slug;
  final String description;
  final String videoUrl;
  final String videoAuthorName;
  final String platform;
  final String videoId;
  final int duration;
  final String recordedAt;
  final String venue;
  final String eventId;
  final String eventName;
  final String thumbnailUrl;
  final List<WebDJSetTrack>? tracks;
  final int viewCount;
  final int likeCount;
  final int commentCount;
  final int trackCount;
  final bool isVerified;
  final String createdAt;
  final String updatedAt;
  final String uploadedById;

  /// Compatibility alias for audio-only sets; falls back to [videoUrl].
  String get audioUrl => videoUrl;

  const WebDJSet({
    required this.id,
    required this.djId,
    required this.djName,
    required this.djAvatarUrl,
    required this.title,
    this.slug = '',
    this.description = '',
    required this.videoUrl,
    this.videoAuthorName = '',
    required this.platform,
    required this.videoId,
    required this.duration,
    required this.recordedAt,
    this.venue = '',
    required this.eventId,
    required this.eventName,
    required this.thumbnailUrl,
    this.tracks,
    this.viewCount = 0,
    this.likeCount = 0,
    required this.commentCount,
    this.trackCount = 0,
    this.isVerified = false,
    required this.createdAt,
    this.updatedAt = '',
    this.uploadedById = '',
  });

  factory WebDJSet.fromJson(Map<String, dynamic> json) {
    final tracks = (json['tracks'] as List<dynamic>?)
        ?.map((e) => WebDJSetTrack.fromJson(e as Map<String, dynamic>))
        .toList();
    return WebDJSet(
      id: json['id'] as String,
      djId: json['djId'] as String? ?? '',
      djName: json['djName'] as String? ??
          (json['dj'] as Map<String, dynamic>?)?['name'] as String? ??
          '',
      djAvatarUrl: json['djAvatarUrl'] as String? ??
          (json['dj'] as Map<String, dynamic>?)?['avatarSmallUrl'] as String? ??
          (json['dj'] as Map<String, dynamic>?)?['avatarUrl'] as String? ??
          '',
      title: json['title'] as String,
      slug: json['slug'] as String? ?? '',
      description: json['description'] as String? ?? '',
      videoUrl: json['videoUrl'] as String? ?? '',
      videoAuthorName: json['videoAuthorName'] as String? ?? '',
      platform: json['platform'] as String? ?? '',
      videoId: json['videoId'] as String? ?? '',
      duration: _intFromJson(json['duration']) ?? 0,
      recordedAt: _stringFromJson(json['recordedAt']),
      venue: json['venue'] as String? ?? '',
      eventId: json['eventId'] as String? ?? '',
      eventName: json['eventName'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      tracks: tracks,
      viewCount: _intFromJson(json['viewCount']) ?? 0,
      likeCount: _intFromJson(json['likeCount']) ?? 0,
      commentCount: _intFromJson(json['commentCount']) ?? 0,
      trackCount: _intFromJson(json['trackCount']) ?? tracks?.length ?? 0,
      isVerified: json['isVerified'] as bool? ?? false,
      createdAt: _stringFromJson(json['createdAt']),
      updatedAt: _stringFromJson(json['updatedAt']),
      uploadedById: json['uploadedById'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'djId': djId,
        'djName': djName,
        'djAvatarUrl': djAvatarUrl,
        'title': title,
        'slug': slug,
        'description': description,
        'videoUrl': videoUrl,
        'videoAuthorName': videoAuthorName,
        'platform': platform,
        'videoId': videoId,
        'duration': duration,
        'recordedAt': recordedAt,
        'venue': venue,
        'eventId': eventId,
        'eventName': eventName,
        'thumbnailUrl': thumbnailUrl,
        if (tracks != null) 'tracks': tracks!.map((e) => e.toJson()).toList(),
        'viewCount': viewCount,
        'likeCount': likeCount,
        'commentCount': commentCount,
        'trackCount': trackCount,
        'isVerified': isVerified,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'uploadedById': uploadedById,
      };

  WebDJSet copyWith({
    String? id,
    String? djId,
    String? djName,
    String? djAvatarUrl,
    String? title,
    String? slug,
    String? description,
    String? videoUrl,
    String? videoAuthorName,
    String? platform,
    String? videoId,
    int? duration,
    String? recordedAt,
    String? venue,
    String? eventId,
    String? eventName,
    String? thumbnailUrl,
    List<WebDJSetTrack>? tracks,
    int? viewCount,
    int? likeCount,
    int? commentCount,
    int? trackCount,
    bool? isVerified,
    String? createdAt,
    String? updatedAt,
    String? uploadedById,
  }) =>
      WebDJSet(
        id: id ?? this.id,
        djId: djId ?? this.djId,
        djName: djName ?? this.djName,
        djAvatarUrl: djAvatarUrl ?? this.djAvatarUrl,
        title: title ?? this.title,
        slug: slug ?? this.slug,
        description: description ?? this.description,
        videoUrl: videoUrl ?? this.videoUrl,
        videoAuthorName: videoAuthorName ?? this.videoAuthorName,
        platform: platform ?? this.platform,
        videoId: videoId ?? this.videoId,
        duration: duration ?? this.duration,
        recordedAt: recordedAt ?? this.recordedAt,
        venue: venue ?? this.venue,
        eventId: eventId ?? this.eventId,
        eventName: eventName ?? this.eventName,
        thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
        tracks: tracks ?? this.tracks,
        viewCount: viewCount ?? this.viewCount,
        likeCount: likeCount ?? this.likeCount,
        commentCount: commentCount ?? this.commentCount,
        trackCount: trackCount ?? this.trackCount,
        isVerified: isVerified ?? this.isVerified,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        uploadedById: uploadedById ?? this.uploadedById,
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
  final String id;
  final int position;
  final String title;
  final String artist;
  final String label;
  final String startTime;
  final int? endTime;
  final String status;
  final String spotifyUrl;
  final String neteaseUrl;

  const WebDJSetTrack({
    this.id = '',
    required this.position,
    required this.title,
    required this.artist,
    required this.label,
    required this.startTime,
    this.endTime,
    this.status = '',
    this.spotifyUrl = '',
    this.neteaseUrl = '',
  });

  factory WebDJSetTrack.fromJson(Map<String, dynamic> json) => WebDJSetTrack(
        id: json['id'] as String? ?? '',
        position: json['position'] as int? ?? 0,
        title: json['title'] as String? ?? '',
        artist: json['artist'] as String? ?? '',
        label: json['label'] as String? ?? '',
        startTime: _stringFromJson(json['startTime']),
        endTime: _intFromJson(json['endTime']),
        status: json['status'] as String? ?? '',
        spotifyUrl: json['spotifyUrl'] as String? ?? '',
        neteaseUrl: json['neteaseUrl'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        if (id.isNotEmpty) 'id': id,
        'position': position,
        'title': title,
        'artist': artist,
        'label': label,
        'startTime': startTime,
        if (endTime != null) 'endTime': endTime,
        if (status.isNotEmpty) 'status': status,
        if (spotifyUrl.isNotEmpty) 'spotifyUrl': spotifyUrl,
        if (neteaseUrl.isNotEmpty) 'neteaseUrl': neteaseUrl,
      };

  WebDJSetTrack copyWith({
    String? id,
    int? position,
    String? title,
    String? artist,
    String? label,
    String? startTime,
    int? endTime,
    String? status,
    String? spotifyUrl,
    String? neteaseUrl,
  }) =>
      WebDJSetTrack(
        id: id ?? this.id,
        position: position ?? this.position,
        title: title ?? this.title,
        artist: artist ?? this.artist,
        label: label ?? this.label,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        status: status ?? this.status,
        spotifyUrl: spotifyUrl ?? this.spotifyUrl,
        neteaseUrl: neteaseUrl ?? this.neteaseUrl,
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

String _stringFromJson(Object? value) {
  if (value == null) return '';
  if (value is String) return value;
  return value.toString();
}

int? _intFromJson(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
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
        userId: json['userId'] as String? ??
            (json['user'] as Map<String, dynamic>?)?['id'] as String? ??
            '',
        displayName: json['displayName'] as String? ??
            (json['user'] as Map<String, dynamic>?)?['displayName']
                as String? ??
            (json['user'] as Map<String, dynamic>?)?['username'] as String? ??
            '',
        avatarUrl: json['avatarUrl'] as String? ??
            (json['user'] as Map<String, dynamic>?)?['avatarUrl'] as String? ??
            '',
        content: json['content'] as String? ?? '',
        createdAt: json['createdAt'] as String? ?? '',
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
