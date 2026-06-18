enum GlobalSearchTab {
  all,
  events,
  djs,
  peopleSquads,
  posts,
  news,
  sets,
  rankings,
  ratings,
  festivals,
  labels,
  genreTree;

  static final _snakeCaseMap = <String, GlobalSearchTab>{
    'all': all,
    'events': events,
    'djs': djs,
    'people_squads': peopleSquads,
    'peopleSquads': peopleSquads,
    'posts': posts,
    'news': news,
    'sets': sets,
    'rankings': rankings,
    'ratings': ratings,
    'festivals': festivals,
    'labels': labels,
    'genre_tree': genreTree,
    'genreTree': genreTree,
  };

  static final _toSnakeCase = <GlobalSearchTab, String>{
    for (final entry in _snakeCaseMap.entries) entry.value: entry.key,
  };

  static GlobalSearchTab fromJson(String v) =>
      _snakeCaseMap[v] ?? GlobalSearchTab.all;

  String toJson() => _toSnakeCase[this] ?? name;
}

enum GlobalSearchItemType {
  event,
  news,
  dj,
  set,
  rankingBoard,
  rankingEntry,
  ratingEvent,
  ratingUnit,
  post,
  label,
  festival,
  genre,
  user,
  squad;

  static final _snakeCaseMap = <String, GlobalSearchItemType>{
    'event': event,
    'news': news,
    'dj': dj,
    'set': set,
    'ranking_board': rankingBoard,
    'ranking_entry': rankingEntry,
    'rating_event': ratingEvent,
    'rating_unit': ratingUnit,
    'post': post,
    'label': label,
    'festival': festival,
    'genre': genre,
    'user': user,
    'squad': squad,
  };

  static final _toSnakeCase = <GlobalSearchItemType, String>{
    for (final entry in _snakeCaseMap.entries) entry.value: entry.key,
  };

  static GlobalSearchItemType fromJson(String v) =>
      _snakeCaseMap[v] ?? GlobalSearchItemType.event;

  String toJson() => _toSnakeCase[this] ?? name;
}

class GlobalSearchItem {
  final String id;
  final GlobalSearchItemType type;
  final String entityId;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final String? deeplink;
  final double? relevanceScore;

  const GlobalSearchItem({
    required this.id,
    required this.type,
    required this.entityId,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.deeplink,
    this.relevanceScore,
  });

  factory GlobalSearchItem.fromJson(Map<String, dynamic> json) =>
      GlobalSearchItem(
        id: _string(json['id']),
        type: GlobalSearchItemType.fromJson(_string(json['type'])),
        entityId: _string(json['entityId'] ?? json['entity_id']),
        title: _string(json['title'] ?? json['name']),
        subtitle: _nullableString(json['subtitle'] ?? json['sub_title']),
        imageUrl: _nullableString(
          json['imageUrl'] ?? json['image_url'] ?? json['coverImageUrl'],
        ),
        deeplink: _nullableString(json['deeplink'] ?? json['deepLink']),
        relevanceScore:
            _double(json['relevanceScore'] ?? json['relevance_score']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.toJson(),
        'entityId': entityId,
        'title': title,
        if (subtitle != null) 'subtitle': subtitle,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (deeplink != null) 'deeplink': deeplink,
        if (relevanceScore != null) 'relevanceScore': relevanceScore,
      };

  GlobalSearchItem copyWith({
    String? id,
    GlobalSearchItemType? type,
    String? entityId,
    String? title,
    String? subtitle,
    String? imageUrl,
    String? deeplink,
    double? relevanceScore,
  }) =>
      GlobalSearchItem(
        id: id ?? this.id,
        type: type ?? this.type,
        entityId: entityId ?? this.entityId,
        title: title ?? this.title,
        subtitle: subtitle ?? this.subtitle,
        imageUrl: imageUrl ?? this.imageUrl,
        deeplink: deeplink ?? this.deeplink,
        relevanceScore: relevanceScore ?? this.relevanceScore,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GlobalSearchItem &&
        other.id == id &&
        other.type == type &&
        other.entityId == entityId;
  }

  @override
  int get hashCode => Object.hash(id, type, entityId);

  @override
  String toString() =>
      'GlobalSearchItem(id: $id, type: $type, entityId: $entityId, title: $title)';
}

class GlobalSearchResponse {
  final String query;
  final GlobalSearchTab tab;
  final List<GlobalSearchItem> items;
  final Map<String, int>? countsByTab;

  const GlobalSearchResponse({
    required this.query,
    required this.tab,
    required this.items,
    this.countsByTab,
  });

  factory GlobalSearchResponse.fromJson(Map<String, dynamic> json) =>
      GlobalSearchResponse(
        query: _string(json['query']),
        tab: GlobalSearchTab.fromJson(_string(json['tab'])),
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => GlobalSearchItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        countsByTab: _countsByTabFromJson(
          json['countsByTab'] ?? json['counts_by_tab'],
        ),
      );

  Map<String, dynamic> toJson() => {
        'query': query,
        'tab': tab.toJson(),
        'items': items.map((e) => e.toJson()).toList(),
        if (countsByTab != null) 'countsByTab': countsByTab,
      };

  GlobalSearchResponse copyWith({
    String? query,
    GlobalSearchTab? tab,
    List<GlobalSearchItem>? items,
    Map<String, int>? countsByTab,
  }) =>
      GlobalSearchResponse(
        query: query ?? this.query,
        tab: tab ?? this.tab,
        items: items ?? this.items,
        countsByTab: countsByTab ?? this.countsByTab,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GlobalSearchResponse &&
        other.query == query &&
        other.tab == tab;
  }

  @override
  int get hashCode => Object.hash(query, tab);

  @override
  String toString() =>
      'GlobalSearchResponse(query: $query, tab: $tab, items: ${items.length} items)';
}

String _string(Object? value) => value?.toString() ?? '';

String? _nullableString(Object? value) {
  final string = value?.toString().trim();
  return string == null || string.isEmpty ? null : string;
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double? _double(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

Map<String, int>? _countsByTabFromJson(Object? value) {
  if (value is! Map) return null;
  return {
    for (final entry in value.entries) entry.key.toString(): _int(entry.value),
  };
}
