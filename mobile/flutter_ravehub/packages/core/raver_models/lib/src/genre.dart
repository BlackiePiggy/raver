import 'event.dart';

class LearnGenreNode {
  final String id;
  final String name;
  final WebBiText? nameI18n;
  final String parentId;
  final String path;
  final List<LearnGenreNode>? children;
  final String description;
  final String origin;
  final String era;
  final String bpmRange;
  final List<LearnGenreSoundCueTrack>? soundCueTracks;

  const LearnGenreNode({
    required this.id,
    required this.name,
    this.nameI18n,
    required this.parentId,
    required this.path,
    this.children,
    required this.description,
    required this.origin,
    required this.era,
    required this.bpmRange,
    this.soundCueTracks,
  });

  factory LearnGenreNode.fromJson(Map<String, dynamic> json) {
    final id = _genreString(json, ['id', 'genreId', '_id', 'slug']);
    final path = _genreString(json, ['path', 'fullPath'], fallback: id);
    return LearnGenreNode(
      id: id,
      name: _genreString(json, ['name', 'title', 'displayName'], fallback: id),
      nameI18n: json['nameI18n'] is Map<String, dynamic>
          ? WebBiText.fromJson(json['nameI18n'] as Map<String, dynamic>)
          : null,
      parentId: _genreString(json, ['parentId', 'parentID', 'parent_id']),
      path: path,
      children: _genreObjects(json, ['children', 'subGenres', 'subgenres'])
          ?.map(LearnGenreNode.fromJson)
          .toList(),
      description: _genreString(json, ['description', 'desc', 'intro']),
      origin: _genreString(json, ['origin', 'originRegion', 'region']),
      era: _genreString(json, ['era', 'period']),
      bpmRange: _genreString(json, ['bpmRange', 'bpm', 'tempoRange']),
      soundCueTracks:
          _genreObjects(json, ['soundCueTracks', 'soundCues', 'tracks'])
              ?.map(LearnGenreSoundCueTrack.fromJson)
              .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (nameI18n != null) 'nameI18n': nameI18n!.toJson(),
        'parentId': parentId,
        'path': path,
        if (children != null)
          'children': children!.map((e) => e.toJson()).toList(),
        'description': description,
        'origin': origin,
        'era': era,
        'bpmRange': bpmRange,
        if (soundCueTracks != null)
          'soundCueTracks': soundCueTracks!.map((e) => e.toJson()).toList(),
      };

  LearnGenreNode copyWith({
    String? id,
    String? name,
    WebBiText? nameI18n,
    String? parentId,
    String? path,
    List<LearnGenreNode>? children,
    String? description,
    String? origin,
    String? era,
    String? bpmRange,
    List<LearnGenreSoundCueTrack>? soundCueTracks,
  }) =>
      LearnGenreNode(
        id: id ?? this.id,
        name: name ?? this.name,
        nameI18n: nameI18n ?? this.nameI18n,
        parentId: parentId ?? this.parentId,
        path: path ?? this.path,
        children: children ?? this.children,
        description: description ?? this.description,
        origin: origin ?? this.origin,
        era: era ?? this.era,
        bpmRange: bpmRange ?? this.bpmRange,
        soundCueTracks: soundCueTracks ?? this.soundCueTracks,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LearnGenreNode &&
        other.id == id &&
        other.name == name &&
        other.parentId == parentId &&
        other.path == path;
  }

  @override
  int get hashCode => Object.hash(id, name, parentId, path);

  @override
  String toString() => 'LearnGenreNode(id: $id, name: $name, path: $path)';
}

class LearnGenreSoundCueTrack {
  final String title;
  final String artist;
  final String spotifyUrl;
  final String appleMusicUrl;

  const LearnGenreSoundCueTrack({
    required this.title,
    required this.artist,
    required this.spotifyUrl,
    required this.appleMusicUrl,
  });

  factory LearnGenreSoundCueTrack.fromJson(Map<String, dynamic> json) =>
      LearnGenreSoundCueTrack(
        title: _genreString(json, ['title', 'name']),
        artist: _genreString(json, ['artist', 'artistName', 'creator']),
        spotifyUrl: _genreString(json, ['spotifyUrl', 'spotifyURL']),
        appleMusicUrl: _genreString(json, ['appleMusicUrl', 'appleMusicURL']),
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'artist': artist,
        'spotifyUrl': spotifyUrl,
        'appleMusicUrl': appleMusicUrl,
      };

  LearnGenreSoundCueTrack copyWith({
    String? title,
    String? artist,
    String? spotifyUrl,
    String? appleMusicUrl,
  }) =>
      LearnGenreSoundCueTrack(
        title: title ?? this.title,
        artist: artist ?? this.artist,
        spotifyUrl: spotifyUrl ?? this.spotifyUrl,
        appleMusicUrl: appleMusicUrl ?? this.appleMusicUrl,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LearnGenreSoundCueTrack &&
        other.title == title &&
        other.artist == artist;
  }

  @override
  int get hashCode => Object.hash(title, artist);

  @override
  String toString() =>
      'LearnGenreSoundCueTrack(title: $title, artist: $artist)';
}

class LearnGenreTreeSummaryNode {
  final String id;
  final String name;
  final String path;
  final int childCount;

  const LearnGenreTreeSummaryNode({
    required this.id,
    required this.name,
    required this.path,
    required this.childCount,
  });

  factory LearnGenreTreeSummaryNode.fromJson(Map<String, dynamic> json) {
    final id = _genreString(json, ['id', 'genreId', '_id', 'slug']);
    return LearnGenreTreeSummaryNode(
      id: id,
      name: _genreString(json, ['name', 'title', 'displayName'], fallback: id),
      path: _genreString(json, ['path', 'fullPath'], fallback: id),
      childCount: _genreInt(json, ['childCount', 'childrenCount']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'path': path,
        'childCount': childCount,
      };

  LearnGenreTreeSummaryNode copyWith({
    String? id,
    String? name,
    String? path,
    int? childCount,
  }) =>
      LearnGenreTreeSummaryNode(
        id: id ?? this.id,
        name: name ?? this.name,
        path: path ?? this.path,
        childCount: childCount ?? this.childCount,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LearnGenreTreeSummaryNode &&
        other.id == id &&
        other.name == name &&
        other.path == path;
  }

  @override
  int get hashCode => Object.hash(id, name, path);

  @override
  String toString() =>
      'LearnGenreTreeSummaryNode(id: $id, name: $name, path: $path, childCount: $childCount)';
}

class GenreSunburstNode {
  final String id;
  final String name;
  final String path;
  final String? themeColor;
  final List<GenreSunburstNode>? children;

  const GenreSunburstNode({
    required this.id,
    required this.name,
    required this.path,
    this.themeColor,
    this.children,
  });

  factory GenreSunburstNode.fromJson(Map<String, dynamic> json) {
    final id = _genreString(json, ['id', 'genreId', '_id', 'slug']);
    return GenreSunburstNode(
      id: id,
      name: _genreString(json, ['name', 'title', 'displayName'], fallback: id),
      path: _genreString(json, ['path', 'fullPath'], fallback: id),
      themeColor:
          _genreOptionalString(json, ['themeColor', 'color', 'hexColor']),
      children: _genreObjects(json, ['children', 'subGenres', 'subgenres'])
          ?.map(GenreSunburstNode.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'path': path,
        if (themeColor != null) 'themeColor': themeColor,
        if (children != null)
          'children': children!.map((e) => e.toJson()).toList(),
      };

  GenreSunburstNode copyWith({
    String? id,
    String? name,
    String? path,
    String? themeColor,
    List<GenreSunburstNode>? children,
  }) =>
      GenreSunburstNode(
        id: id ?? this.id,
        name: name ?? this.name,
        path: path ?? this.path,
        themeColor: themeColor ?? this.themeColor,
        children: children ?? this.children,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GenreSunburstNode &&
        other.id == id &&
        other.name == name &&
        other.path == path;
  }

  @override
  int get hashCode => Object.hash(id, name, path);

  @override
  String toString() => 'GenreSunburstNode(id: $id, name: $name, path: $path)';
}

String _genreString(
  Map<String, dynamic> json,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;
    if (value is String) return value;
    return value.toString();
  }
  return fallback;
}

String? _genreOptionalString(Map<String, dynamic> json, List<String> keys) {
  final value = _genreString(json, keys);
  return value.isEmpty ? null : value;
}

int _genreInt(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
  }
  return 0;
}

List<Map<String, dynamic>>? _genreObjects(
  Map<String, dynamic> json,
  List<String> keys,
) {
  for (final key in keys) {
    final value = json[key];
    if (value is List<dynamic>) {
      return value.whereType<Map<String, dynamic>>().toList();
    }
  }
  return null;
}
