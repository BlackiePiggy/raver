import 'event.dart';

class LearnFestival {
  final String id;
  final String name;
  final WebBiText? nameI18n;
  final List<String>? aliases;
  final String country;
  final String city;
  final String introduction;
  final List<String>? genres;
  final List<LearnFestivalLink>? links;
  final List<String>? imageUrls;
  final int followerCount;
  final bool? isFollowing;

  const LearnFestival({
    required this.id,
    required this.name,
    this.nameI18n,
    this.aliases,
    required this.country,
    required this.city,
    required this.introduction,
    this.genres,
    this.links,
    this.imageUrls,
    required this.followerCount,
    this.isFollowing,
  });

  factory LearnFestival.fromJson(Map<String, dynamic> json) => LearnFestival(
        id: json['id'] as String,
        name: json['name'] as String,
        nameI18n: json['nameI18n'] != null
            ? WebBiText.fromJson(json['nameI18n'] as Map<String, dynamic>)
            : null,
        aliases: (json['aliases'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList(),
        country: json['country'] as String,
        city: json['city'] as String,
        introduction: json['introduction'] as String,
        genres: (json['genres'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList(),
        links: json['links'] != null
            ? (json['links'] as List<dynamic>)
                .map((e) =>
                    LearnFestivalLink.fromJson(e as Map<String, dynamic>))
                .toList()
            : null,
        imageUrls: (json['imageUrls'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList(),
        followerCount: json['followerCount'] as int,
        isFollowing: json['isFollowing'] as bool?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (nameI18n != null) 'nameI18n': nameI18n!.toJson(),
        if (aliases != null) 'aliases': aliases,
        'country': country,
        'city': city,
        'introduction': introduction,
        if (genres != null) 'genres': genres,
        if (links != null) 'links': links!.map((e) => e.toJson()).toList(),
        if (imageUrls != null) 'imageUrls': imageUrls,
        'followerCount': followerCount,
        if (isFollowing != null) 'isFollowing': isFollowing,
      };

  LearnFestival copyWith({
    String? id,
    String? name,
    WebBiText? nameI18n,
    List<String>? aliases,
    String? country,
    String? city,
    String? introduction,
    List<String>? genres,
    List<LearnFestivalLink>? links,
    List<String>? imageUrls,
    int? followerCount,
    bool? isFollowing,
  }) =>
      LearnFestival(
        id: id ?? this.id,
        name: name ?? this.name,
        nameI18n: nameI18n ?? this.nameI18n,
        aliases: aliases ?? this.aliases,
        country: country ?? this.country,
        city: city ?? this.city,
        introduction: introduction ?? this.introduction,
        genres: genres ?? this.genres,
        links: links ?? this.links,
        imageUrls: imageUrls ?? this.imageUrls,
        followerCount: followerCount ?? this.followerCount,
        isFollowing: isFollowing ?? this.isFollowing,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LearnFestival &&
        other.id == id &&
        other.name == name;
  }

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() =>
      'LearnFestival(id: $id, name: $name, country: $country, city: $city)';
}

class LearnFestivalLink {
  final String type;
  final String url;
  final String label;

  const LearnFestivalLink({
    required this.type,
    required this.url,
    required this.label,
  });

  factory LearnFestivalLink.fromJson(Map<String, dynamic> json) =>
      LearnFestivalLink(
        type: json['type'] as String,
        url: json['url'] as String,
        label: json['label'] as String,
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'url': url,
        'label': label,
      };

  LearnFestivalLink copyWith({
    String? type,
    String? url,
    String? label,
  }) =>
      LearnFestivalLink(
        type: type ?? this.type,
        url: url ?? this.url,
        label: label ?? this.label,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LearnFestivalLink &&
        other.type == type &&
        other.url == url;
  }

  @override
  int get hashCode => Object.hash(type, url);

  @override
  String toString() =>
      'LearnFestivalLink(type: $type, url: $url, label: $label)';
}

class LearnLabel {
  final String id;
  final String name;
  final String slug;
  final String introduction;
  final List<String>? genres;
  final List<LearnLabelFounder>? founders;
  final String imageUrl;
  final String websiteUrl;

  const LearnLabel({
    required this.id,
    required this.name,
    required this.slug,
    required this.introduction,
    this.genres,
    this.founders,
    required this.imageUrl,
    required this.websiteUrl,
  });

  factory LearnLabel.fromJson(Map<String, dynamic> json) => LearnLabel(
        id: json['id'] as String,
        name: json['name'] as String,
        slug: json['slug'] as String,
        introduction: json['introduction'] as String,
        genres: (json['genres'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList(),
        founders: json['founders'] != null
            ? (json['founders'] as List<dynamic>)
                .map((e) =>
                    LearnLabelFounder.fromJson(e as Map<String, dynamic>))
                .toList()
            : null,
        imageUrl: json['imageUrl'] as String,
        websiteUrl: json['websiteUrl'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'introduction': introduction,
        if (genres != null) 'genres': genres,
        if (founders != null)
          'founders': founders!.map((e) => e.toJson()).toList(),
        'imageUrl': imageUrl,
        'websiteUrl': websiteUrl,
      };

  LearnLabel copyWith({
    String? id,
    String? name,
    String? slug,
    String? introduction,
    List<String>? genres,
    List<LearnLabelFounder>? founders,
    String? imageUrl,
    String? websiteUrl,
  }) =>
      LearnLabel(
        id: id ?? this.id,
        name: name ?? this.name,
        slug: slug ?? this.slug,
        introduction: introduction ?? this.introduction,
        genres: genres ?? this.genres,
        founders: founders ?? this.founders,
        imageUrl: imageUrl ?? this.imageUrl,
        websiteUrl: websiteUrl ?? this.websiteUrl,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LearnLabel &&
        other.id == id &&
        other.name == name;
  }

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() =>
      'LearnLabel(id: $id, name: $name, slug: $slug)';
}

class LearnLabelFounder {
  final String name;
  final String djId;

  const LearnLabelFounder({
    required this.name,
    required this.djId,
  });

  factory LearnLabelFounder.fromJson(Map<String, dynamic> json) =>
      LearnLabelFounder(
        name: json['name'] as String,
        djId: json['djId'] as String,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'djId': djId,
      };

  LearnLabelFounder copyWith({
    String? name,
    String? djId,
  }) =>
      LearnLabelFounder(
        name: name ?? this.name,
        djId: djId ?? this.djId,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LearnLabelFounder &&
        other.name == name &&
        other.djId == djId;
  }

  @override
  int get hashCode => Object.hash(name, djId);

  @override
  String toString() => 'LearnLabelFounder(name: $name, djId: $djId)';
}

class RankingBoard {
  final String id;
  final String title;
  final List<int> years;

  const RankingBoard({
    required this.id,
    required this.title,
    required this.years,
  });

  factory RankingBoard.fromJson(Map<String, dynamic> json) => RankingBoard(
        id: json['id'] as String,
        title: json['title'] as String,
        years: (json['years'] as List<dynamic>)
            .map((e) => e as int)
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'years': years,
      };

  RankingBoard copyWith({
    String? id,
    String? title,
    List<int>? years,
  }) =>
      RankingBoard(
        id: id ?? this.id,
        title: title ?? this.title,
        years: years ?? this.years,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RankingBoard &&
        other.id == id &&
        other.title == title;
  }

  @override
  int get hashCode => Object.hash(id, title);

  @override
  String toString() => 'RankingBoard(id: $id, title: $title, years: $years)';
}

class RankingBoardDetail {
  final String id;
  final String title;
  final int year;
  final List<RankingEntry> entries;

  const RankingBoardDetail({
    required this.id,
    required this.title,
    required this.year,
    required this.entries,
  });

  factory RankingBoardDetail.fromJson(Map<String, dynamic> json) =>
      RankingBoardDetail(
        id: json['id'] as String,
        title: json['title'] as String,
        year: json['year'] as int,
        entries: (json['entries'] as List<dynamic>? ?? [])
            .map((e) => RankingEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'year': year,
        'entries': entries.map((e) => e.toJson()).toList(),
      };

  RankingBoardDetail copyWith({
    String? id,
    String? title,
    int? year,
    List<RankingEntry>? entries,
  }) =>
      RankingBoardDetail(
        id: id ?? this.id,
        title: title ?? this.title,
        year: year ?? this.year,
        entries: entries ?? this.entries,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RankingBoardDetail &&
        other.id == id &&
        other.year == year;
  }

  @override
  int get hashCode => Object.hash(id, year);

  @override
  String toString() =>
      'RankingBoardDetail(id: $id, title: $title, year: $year)';
}

class RankingEntry {
  final int rank;
  final String name;
  final int? delta;
  final String? djId;
  final String? djAvatarUrl;
  final String? festivalId;

  const RankingEntry({
    required this.rank,
    required this.name,
    this.delta,
    this.djId,
    this.djAvatarUrl,
    this.festivalId,
  });

  factory RankingEntry.fromJson(Map<String, dynamic> json) => RankingEntry(
        rank: json['rank'] as int,
        name: json['name'] as String,
        delta: json['delta'] as int?,
        djId: json['djId'] as String?,
        djAvatarUrl: json['djAvatarUrl'] as String?,
        festivalId: json['festivalId'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'rank': rank,
        'name': name,
        if (delta != null) 'delta': delta,
        if (djId != null) 'djId': djId,
        if (djAvatarUrl != null) 'djAvatarUrl': djAvatarUrl,
        if (festivalId != null) 'festivalId': festivalId,
      };

  RankingEntry copyWith({
    int? rank,
    String? name,
    int? delta,
    String? djId,
    String? djAvatarUrl,
    String? festivalId,
  }) =>
      RankingEntry(
        rank: rank ?? this.rank,
        name: name ?? this.name,
        delta: delta ?? this.delta,
        djId: djId ?? this.djId,
        djAvatarUrl: djAvatarUrl ?? this.djAvatarUrl,
        festivalId: festivalId ?? this.festivalId,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RankingEntry &&
        other.rank == rank &&
        other.name == name;
  }

  @override
  int get hashCode => Object.hash(rank, name);

  @override
  String toString() =>
      'RankingEntry(rank: $rank, name: $name, djId: $djId)';
}
