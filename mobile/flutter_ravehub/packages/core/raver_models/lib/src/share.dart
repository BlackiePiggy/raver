enum ShareTargetType {
  event,
  dj,
  set,
  djSet,
  brand,
  label,
  news,
  rankingBoard,
  ratingEvent,
  ratingUnit,
  post,
  circle,
  circleId,
  myCheckins,
  eventRoute;

  static final _snakeCaseMap = <String, ShareTargetType>{
    'event': event,
    'dj': dj,
    'set': set,
    'dj_set': djSet,
    'brand': brand,
    'label': label,
    'news': news,
    'ranking_board': rankingBoard,
    'rating_event': ratingEvent,
    'rating_unit': ratingUnit,
    'post': post,
    'circle': circle,
    'circle_id': circleId,
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
  final String canonicalUrl;
  final String deepLink;
  final String fallbackUrl;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String previewType;
  final String status;

  const ShareLinkPayload({
    required this.code,
    required this.url,
    required this.shortUrl,
    required this.posterUrl,
    required this.qrCodeUrl,
    this.canonicalUrl = '',
    this.deepLink = '',
    this.fallbackUrl = '',
    this.title = '',
    this.subtitle = '',
    this.imageUrl = '',
    this.previewType = '',
    this.status = '',
  });

  factory ShareLinkPayload.fromJson(Map<String, dynamic> json) =>
      ShareLinkPayload(
        code: _string(json['code']),
        url: _string(json['url'] ?? json['shortUrl']),
        shortUrl: _string(json['shortUrl'] ?? json['url']),
        posterUrl: _string(json['posterUrl']),
        qrCodeUrl: _string(json['qrCodeUrl']),
        canonicalUrl: _string(json['canonicalUrl']),
        deepLink: _string(json['deepLink']),
        fallbackUrl: _string(json['fallbackUrl']),
        title: _string(json['title']),
        subtitle: _string(json['subtitle']),
        imageUrl: _string(json['imageUrl']),
        previewType: _string(json['previewType']),
        status: _string(json['status']),
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'url': url,
        'shortUrl': shortUrl,
        'posterUrl': posterUrl,
        'qrCodeUrl': qrCodeUrl,
        'canonicalUrl': canonicalUrl,
        'deepLink': deepLink,
        'fallbackUrl': fallbackUrl,
        'title': title,
        'subtitle': subtitle,
        'imageUrl': imageUrl,
        'previewType': previewType,
        'status': status,
      };

  ShareLinkPayload copyWith({
    String? code,
    String? url,
    String? shortUrl,
    String? posterUrl,
    String? qrCodeUrl,
    String? canonicalUrl,
    String? deepLink,
    String? fallbackUrl,
    String? title,
    String? subtitle,
    String? imageUrl,
    String? previewType,
    String? status,
  }) =>
      ShareLinkPayload(
        code: code ?? this.code,
        url: url ?? this.url,
        shortUrl: shortUrl ?? this.shortUrl,
        posterUrl: posterUrl ?? this.posterUrl,
        qrCodeUrl: qrCodeUrl ?? this.qrCodeUrl,
        canonicalUrl: canonicalUrl ?? this.canonicalUrl,
        deepLink: deepLink ?? this.deepLink,
        fallbackUrl: fallbackUrl ?? this.fallbackUrl,
        title: title ?? this.title,
        subtitle: subtitle ?? this.subtitle,
        imageUrl: imageUrl ?? this.imageUrl,
        previewType: previewType ?? this.previewType,
        status: status ?? this.status,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ShareLinkPayload && other.code == code && other.url == url;
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

  const ShareTarget({required this.type, required this.entityId});

  factory ShareTarget.fromJson(Map<String, dynamic> json) => ShareTarget(
        type: ShareTargetType.fromJson(json['type'] as String),
        entityId: json['entityId'] as String,
      );

  Map<String, dynamic> toJson() => {
        'type': type.toJson(),
        'entityId': entityId,
      };

  ShareTarget copyWith({ShareTargetType? type, String? entityId}) =>
      ShareTarget(type: type ?? this.type, entityId: entityId ?? this.entityId);

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
  String toString() => 'ShareTarget(type: $type, entityId: $entityId)';
}

String _string(Object? value) {
  if (value == null) return '';
  if (value is String) return value;
  return value.toString();
}
