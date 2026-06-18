import 'event.dart';

class WebDJ {
  final String id;
  final String name;
  final WebBiText? nameI18n;
  final List<String>? aliases;
  final List<String>? genres;
  final List<WebGenreTagBinding>? genreBindings;
  final String bio;
  final String avatarUrl;
  final String country;
  final String instagramUrl;
  final String soundcloudUrl;
  final String spotifyUrl;
  final List<WebDJHonor>? honors;
  final int followerCount;
  final bool? isFollowing;

  const WebDJ({
    required this.id,
    required this.name,
    this.nameI18n,
    this.aliases,
    this.genres,
    this.genreBindings,
    required this.bio,
    required this.avatarUrl,
    required this.country,
    required this.instagramUrl,
    required this.soundcloudUrl,
    required this.spotifyUrl,
    this.honors,
    required this.followerCount,
    this.isFollowing,
  });

  factory WebDJ.fromJson(Map<String, dynamic> json) => WebDJ(
    id: json['id'] as String,
    name: json['name'] as String,
    nameI18n: json['nameI18n'] != null
        ? WebBiText.fromJson(json['nameI18n'] as Map<String, dynamic>)
        : null,
    aliases: (json['aliases'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    genres: (json['genres'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    genreBindings: (json['genreBindings'] as List<dynamic>?)
        ?.map((e) => WebGenreTagBinding.fromJson(e as Map<String, dynamic>))
        .toList(),
    bio: json['bio'] as String? ?? '',
    avatarUrl:
        json['avatarUrl'] as String? ??
        json['avatarMediumUrl'] as String? ??
        json['avatarSmallUrl'] as String? ??
        '',
    country: json['country'] as String? ?? '',
    instagramUrl: json['instagramUrl'] as String? ?? '',
    soundcloudUrl: json['soundcloudUrl'] as String? ?? '',
    spotifyUrl: json['spotifyUrl'] as String? ?? '',
    honors: (json['honors'] as List<dynamic>?)
        ?.map((e) => WebDJHonor.fromJson(e as Map<String, dynamic>))
        .toList(),
    followerCount: json['followerCount'] as int? ?? 0,
    isFollowing: json['isFollowing'] as bool?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (nameI18n != null) 'nameI18n': nameI18n!.toJson(),
    if (aliases != null) 'aliases': aliases,
    if (genres != null) 'genres': genres,
    if (genreBindings != null)
      'genreBindings': genreBindings!.map((e) => e.toJson()).toList(),
    'bio': bio,
    'avatarUrl': avatarUrl,
    'country': country,
    'instagramUrl': instagramUrl,
    'soundcloudUrl': soundcloudUrl,
    'spotifyUrl': spotifyUrl,
    if (honors != null) 'honors': honors!.map((e) => e.toJson()).toList(),
    'followerCount': followerCount,
    if (isFollowing != null) 'isFollowing': isFollowing,
  };

  WebDJ copyWith({
    String? id,
    String? name,
    WebBiText? nameI18n,
    List<String>? aliases,
    List<String>? genres,
    List<WebGenreTagBinding>? genreBindings,
    String? bio,
    String? avatarUrl,
    String? country,
    String? instagramUrl,
    String? soundcloudUrl,
    String? spotifyUrl,
    List<WebDJHonor>? honors,
    int? followerCount,
    bool? isFollowing,
  }) => WebDJ(
    id: id ?? this.id,
    name: name ?? this.name,
    nameI18n: nameI18n ?? this.nameI18n,
    aliases: aliases ?? this.aliases,
    genres: genres ?? this.genres,
    genreBindings: genreBindings ?? this.genreBindings,
    bio: bio ?? this.bio,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    country: country ?? this.country,
    instagramUrl: instagramUrl ?? this.instagramUrl,
    soundcloudUrl: soundcloudUrl ?? this.soundcloudUrl,
    spotifyUrl: spotifyUrl ?? this.spotifyUrl,
    honors: honors ?? this.honors,
    followerCount: followerCount ?? this.followerCount,
    isFollowing: isFollowing ?? this.isFollowing,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WebDJ && other.id == id && other.name == name;
  }

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'WebDJ(id: $id, name: $name)';
}

class WebDJHonor {
  final String title;
  final int year;
  final int rank;

  const WebDJHonor({
    required this.title,
    required this.year,
    required this.rank,
  });

  factory WebDJHonor.fromJson(Map<String, dynamic> json) => WebDJHonor(
    title: json['title'] as String,
    year: json['year'] as int,
    rank: json['rank'] as int,
  );

  Map<String, dynamic> toJson() => {'title': title, 'year': year, 'rank': rank};

  WebDJHonor copyWith({String? title, int? year, int? rank}) => WebDJHonor(
    title: title ?? this.title,
    year: year ?? this.year,
    rank: rank ?? this.rank,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WebDJHonor &&
        other.title == title &&
        other.year == year &&
        other.rank == rank;
  }

  @override
  int get hashCode => Object.hash(title, year, rank);

  @override
  String toString() => 'WebDJHonor(title: $title, year: $year, rank: $rank)';
}

class WebGenreTagBinding {
  final String genreId;
  final String label;
  final String path;

  const WebGenreTagBinding({
    required this.genreId,
    required this.label,
    required this.path,
  });

  factory WebGenreTagBinding.fromJson(Map<String, dynamic> json) =>
      WebGenreTagBinding(
        genreId: json['genreId'] as String,
        label: json['label'] as String,
        path: json['path'] as String,
      );

  Map<String, dynamic> toJson() => {
    'genreId': genreId,
    'label': label,
    'path': path,
  };

  WebGenreTagBinding copyWith({String? genreId, String? label, String? path}) =>
      WebGenreTagBinding(
        genreId: genreId ?? this.genreId,
        label: label ?? this.label,
        path: path ?? this.path,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WebGenreTagBinding &&
        other.genreId == genreId &&
        other.label == label &&
        other.path == path;
  }

  @override
  int get hashCode => Object.hash(genreId, label, path);

  @override
  String toString() =>
      'WebGenreTagBinding(genreId: $genreId, label: $label, path: $path)';
}

class DJExactMatchItem {
  final String id;
  final String name;
  final String avatarUrl;

  const DJExactMatchItem({
    required this.id,
    required this.name,
    required this.avatarUrl,
  });

  factory DJExactMatchItem.fromJson(Map<String, dynamic> json) =>
      DJExactMatchItem(
        id: json['id'] as String,
        name: json['name'] as String,
        avatarUrl: json['avatarUrl'] as String,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'avatarUrl': avatarUrl,
  };

  DJExactMatchItem copyWith({String? id, String? name, String? avatarUrl}) =>
      DJExactMatchItem(
        id: id ?? this.id,
        name: name ?? this.name,
        avatarUrl: avatarUrl ?? this.avatarUrl,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DJExactMatchItem && other.id == id && other.name == name;
  }

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'DJExactMatchItem(id: $id, name: $name)';
}

class SpotifyDJCandidate {
  final String spotifyId;
  final String name;
  final String imageUrl;
  final List<String> genres;
  final int followers;

  const SpotifyDJCandidate({
    required this.spotifyId,
    required this.name,
    required this.imageUrl,
    required this.genres,
    required this.followers,
  });

  factory SpotifyDJCandidate.fromJson(Map<String, dynamic> json) =>
      SpotifyDJCandidate(
        spotifyId: json['spotifyId'] as String,
        name: json['name'] as String,
        imageUrl: json['imageUrl'] as String,
        genres: (json['genres'] as List<dynamic>)
            .map((e) => e as String)
            .toList(),
        followers: json['followers'] as int,
      );

  Map<String, dynamic> toJson() => {
    'spotifyId': spotifyId,
    'name': name,
    'imageUrl': imageUrl,
    'genres': genres,
    'followers': followers,
  };

  SpotifyDJCandidate copyWith({
    String? spotifyId,
    String? name,
    String? imageUrl,
    List<String>? genres,
    int? followers,
  }) => SpotifyDJCandidate(
    spotifyId: spotifyId ?? this.spotifyId,
    name: name ?? this.name,
    imageUrl: imageUrl ?? this.imageUrl,
    genres: genres ?? this.genres,
    followers: followers ?? this.followers,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SpotifyDJCandidate &&
        other.spotifyId == spotifyId &&
        other.name == name;
  }

  @override
  int get hashCode => Object.hash(spotifyId, name);

  @override
  String toString() => 'SpotifyDJCandidate(spotifyId: $spotifyId, name: $name)';
}

class DiscogsDJCandidate {
  final String discogsId;
  final String name;
  final String imageUrl;

  const DiscogsDJCandidate({
    required this.discogsId,
    required this.name,
    required this.imageUrl,
  });

  factory DiscogsDJCandidate.fromJson(Map<String, dynamic> json) =>
      DiscogsDJCandidate(
        discogsId: json['discogsId'] as String,
        name: json['name'] as String,
        imageUrl: json['imageUrl'] as String,
      );

  Map<String, dynamic> toJson() => {
    'discogsId': discogsId,
    'name': name,
    'imageUrl': imageUrl,
  };

  DiscogsDJCandidate copyWith({
    String? discogsId,
    String? name,
    String? imageUrl,
  }) => DiscogsDJCandidate(
    discogsId: discogsId ?? this.discogsId,
    name: name ?? this.name,
    imageUrl: imageUrl ?? this.imageUrl,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DiscogsDJCandidate &&
        other.discogsId == discogsId &&
        other.name == name;
  }

  @override
  int get hashCode => Object.hash(discogsId, name);

  @override
  String toString() => 'DiscogsDJCandidate(discogsId: $discogsId, name: $name)';
}
