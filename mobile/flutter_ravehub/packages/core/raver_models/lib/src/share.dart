enum ShareTargetType {
  event,
  dj,
  djSet,
  brand,
  label,
  news,
  rankingBoard,
  ratingEvent,
  ratingUnit,
  post,
  circle,
  myCheckins,
  eventRoute;

  static final _snakeCaseMap = <String, ShareTargetType>{
    'event': event,
    'dj': dj,
    'dj_set': djSet,
    'brand': brand,
    'label': label,
    'news': news,
    'ranking_board': rankingBoard,
    'rating_event': ratingEvent,
    'rating_unit': ratingUnit,
    'post': post,
    'circle': circle,
    'my_checkins': myCheckins,
    'event_route': eventRoute,
  };

  static final _toSnakeCase = <ShareTargetType, String>{
    for (final entry in _snakeCaseMap.entries) entry.value: entry.key,
  };

  static ShareTargetType fromJson(String v) =>
      _snakeCaseMap[v] ?? ShareTargetType.event;

  String toJson() => _toSnakeCase[this] ?? name;
}

class ShareLinkPayload {
  final String code;
  final String url;
  final String shortUrl;
  final String posterUrl;
  final String qrCodeUrl;

  const ShareLinkPayload({
    required this.code,
    required this.url,
    required this.shortUrl,
    required this.posterUrl,
    required this.qrCodeUrl,
  });

  factory ShareLinkPayload.fromJson(Map<String, dynamic> json) =>
      ShareLinkPayload(
        code: json['code'] as String,
        url: json['url'] as String,
        shortUrl: json['shortUrl'] as String,
        posterUrl: json['posterUrl'] as String,
        qrCodeUrl: json['qrCodeUrl'] as String,
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'url': url,
        'shortUrl': shortUrl,
        'posterUrl': posterUrl,
        'qrCodeUrl': qrCodeUrl,
      };

  ShareLinkPayload copyWith({
    String? code,
    String? url,
    String? shortUrl,
    String? posterUrl,
    String? qrCodeUrl,
  }) =>
      ShareLinkPayload(
        code: code ?? this.code,
        url: url ?? this.url,
        shortUrl: shortUrl ?? this.shortUrl,
        posterUrl: posterUrl ?? this.posterUrl,
        qrCodeUrl: qrCodeUrl ?? this.qrCodeUrl,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ShareLinkPayload &&
        other.code == code &&
        other.url == url;
  }

  @override
  int get hashCode => Object.hash(code, url);

  @override
  String toString() =>
      'ShareLinkPayload(code: $code, url: $url, shortUrl: $shortUrl)';
}

class ShareTarget {
  final ShareTargetType type;
  final String entityId;

  const ShareTarget({
    required this.type,
    required this.entityId,
  });

  factory ShareTarget.fromJson(Map<String, dynamic> json) => ShareTarget(
        type: ShareTargetType.fromJson(json['type'] as String),
        entityId: json['entityId'] as String,
      );

  Map<String, dynamic> toJson() => {
        'type': type.toJson(),
        'entityId': entityId,
      };

  ShareTarget copyWith({
    ShareTargetType? type,
    String? entityId,
  }) =>
      ShareTarget(
        type: type ?? this.type,
        entityId: entityId ?? this.entityId,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ShareTarget &&
        other.type == type &&
        other.entityId == entityId;
  }

  @override
  int get hashCode => Object.hash(type, entityId);

  @override
  String toString() =>
      'ShareTarget(type: $type, entityId: $entityId)';
}
