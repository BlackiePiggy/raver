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

  factory LearnGenreNode.fromJson(Map<String, dynamic> json) => LearnGenreNode(
        id: json['id'] as String,
        name: json['name'] as String,
        nameI18n: json['nameI18n'] != null
            ? WebBiText.fromJson(json['nameI18n'] as Map<String, dynamic>)
            : null,
        parentId: json['parentId'] as String,
        path: json['path'] as String,
        children: json['children'] != null
            ? (json['children'] as List<dynamic>)
                .map((e) =>
                    LearnGenreNode.fromJson(e as Map<String, dynamic>))
                .toList()
            : null,
        description: json['description'] as String,
        origin: json['origin'] as String,
        era: json['era'] as String,
        bpmRange: json['bpmRange'] as String,
        soundCueTracks: json['soundCueTracks'] != null
            ? (json['soundCueTracks'] as List<dynamic>)
                .map((e) => LearnGenreSoundCueTrack.fromJson(
                    e as Map<String, dynamic>))
                .toList()
            : null,
      );

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
  String toString() =>
      'LearnGenreNode(id: $id, name: $name, path: $path)';
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
        title: json['title'] as String,
        artist: json['artist'] as String,
        spotifyUrl: json['spotifyUrl'] as String,
        appleMusicUrl: json['appleMusicUrl'] as String,
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

  factory LearnGenreTreeSummaryNode.fromJson(Map<String, dynamic> json) =>
      LearnGenreTreeSummaryNode(
        id: json['id'] as String,
        name: json['name'] as String,
        path: json['path'] as String,
        childCount: json['childCount'] as int,
      );

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

  factory GenreSunburstNode.fromJson(Map<String, dynamic> json) =>
      GenreSunburstNode(
        id: json['id'] as String,
        name: json['name'] as String,
        path: json['path'] as String,
        themeColor: json['themeColor'] as String?,
        children: json['children'] != null
            ? (json['children'] as List<dynamic>)
                .map((e) =>
                    GenreSunburstNode.fromJson(e as Map<String, dynamic>))
                .toList()
            : null,
      );

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
  String toString() =>
      'GenreSunburstNode(id: $id, name: $name, path: $path)';
}
