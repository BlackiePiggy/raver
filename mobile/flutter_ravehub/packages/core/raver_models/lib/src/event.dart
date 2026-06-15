import 'package:flutter/foundation.dart' show listEquals;

class WebEvent {
  final String id;
  final String name;
  final WebBiText? nameI18n;
  final String slug;
  final String description;
  final String coverImageUrl;
  final String lineupImageUrl;
  final String eventType;
  final String startDate;
  final String endDate;
  final WebEventSchedule? schedule;
  final List<WebEventWeek>? weeks;
  final List<WebEventTicketTier>? ticketTiers;
  final List<WebEventLineupSlot>? lineupSlots;
  final List<WebEventLineupArtist>? lineupArtists;
  final WebEventManualLocation? location;
  final List<WebContributorProfile>? contributors;
  final int favoriteCount;
  final int checkinCount;
  final bool? isFavorited;

  const WebEvent({
    required this.id,
    required this.name,
    this.nameI18n,
    required this.slug,
    required this.description,
    required this.coverImageUrl,
    required this.lineupImageUrl,
    required this.eventType,
    required this.startDate,
    required this.endDate,
    this.schedule,
    this.weeks,
    this.ticketTiers,
    this.lineupSlots,
    this.lineupArtists,
    this.location,
    this.contributors,
    required this.favoriteCount,
    required this.checkinCount,
    this.isFavorited,
  });

  factory WebEvent.fromJson(Map<String, dynamic> json) => WebEvent(
        id: json['id'] as String,
        name: json['name'] as String,
        nameI18n: json['nameI18n'] != null
            ? WebBiText.fromJson(json['nameI18n'] as Map<String, dynamic>)
            : null,
        slug: json['slug'] as String,
        description: json['description'] as String,
        coverImageUrl: json['coverImageUrl'] as String,
        lineupImageUrl: json['lineupImageUrl'] as String,
        eventType: json['eventType'] as String,
        startDate: json['startDate'] as String,
        endDate: json['endDate'] as String,
        schedule: json['schedule'] != null
            ? WebEventSchedule.fromJson(
                json['schedule'] as Map<String, dynamic>)
            : null,
        weeks: (json['weeks'] as List<dynamic>?)
            ?.map((e) => WebEventWeek.fromJson(e as Map<String, dynamic>))
            .toList(),
        ticketTiers: (json['ticketTiers'] as List<dynamic>?)
            ?.map((e) =>
                WebEventTicketTier.fromJson(e as Map<String, dynamic>))
            .toList(),
        lineupSlots: (json['lineupSlots'] as List<dynamic>?)
            ?.map((e) =>
                WebEventLineupSlot.fromJson(e as Map<String, dynamic>))
            .toList(),
        lineupArtists: (json['lineupArtists'] as List<dynamic>?)
            ?.map((e) =>
                WebEventLineupArtist.fromJson(e as Map<String, dynamic>))
            .toList(),
        location: json['location'] != null
            ? WebEventManualLocation.fromJson(
                json['location'] as Map<String, dynamic>)
            : null,
        contributors: (json['contributors'] as List<dynamic>?)
            ?.map((e) =>
                WebContributorProfile.fromJson(e as Map<String, dynamic>))
            .toList(),
        favoriteCount: json['favoriteCount'] as int,
        checkinCount: json['checkinCount'] as int,
        isFavorited: json['isFavorited'] as bool?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (nameI18n != null) 'nameI18n': nameI18n!.toJson(),
        'slug': slug,
        'description': description,
        'coverImageUrl': coverImageUrl,
        'lineupImageUrl': lineupImageUrl,
        'eventType': eventType,
        'startDate': startDate,
        'endDate': endDate,
        if (schedule != null) 'schedule': schedule!.toJson(),
        if (weeks != null) 'weeks': weeks!.map((e) => e.toJson()).toList(),
        if (ticketTiers != null)
          'ticketTiers': ticketTiers!.map((e) => e.toJson()).toList(),
        if (lineupSlots != null)
          'lineupSlots': lineupSlots!.map((e) => e.toJson()).toList(),
        if (lineupArtists != null)
          'lineupArtists': lineupArtists!.map((e) => e.toJson()).toList(),
        if (location != null) 'location': location!.toJson(),
        if (contributors != null)
          'contributors': contributors!.map((e) => e.toJson()).toList(),
        'favoriteCount': favoriteCount,
        'checkinCount': checkinCount,
        if (isFavorited != null) 'isFavorited': isFavorited,
      };

  WebEvent copyWith({
    String? id,
    String? name,
    WebBiText? nameI18n,
    String? slug,
    String? description,
    String? coverImageUrl,
    String? lineupImageUrl,
    String? eventType,
    String? startDate,
    String? endDate,
    WebEventSchedule? schedule,
    List<WebEventWeek>? weeks,
    List<WebEventTicketTier>? ticketTiers,
    List<WebEventLineupSlot>? lineupSlots,
    List<WebEventLineupArtist>? lineupArtists,
    WebEventManualLocation? location,
    List<WebContributorProfile>? contributors,
    int? favoriteCount,
    int? checkinCount,
    bool? isFavorited,
  }) =>
      WebEvent(
        id: id ?? this.id,
        name: name ?? this.name,
        nameI18n: nameI18n ?? this.nameI18n,
        slug: slug ?? this.slug,
        description: description ?? this.description,
        coverImageUrl: coverImageUrl ?? this.coverImageUrl,
        lineupImageUrl: lineupImageUrl ?? this.lineupImageUrl,
        eventType: eventType ?? this.eventType,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        schedule: schedule ?? this.schedule,
        weeks: weeks ?? this.weeks,
        ticketTiers: ticketTiers ?? this.ticketTiers,
        lineupSlots: lineupSlots ?? this.lineupSlots,
        lineupArtists: lineupArtists ?? this.lineupArtists,
        location: location ?? this.location,
        contributors: contributors ?? this.contributors,
        favoriteCount: favoriteCount ?? this.favoriteCount,
        checkinCount: checkinCount ?? this.checkinCount,
        isFavorited: isFavorited ?? this.isFavorited,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WebEvent &&
        other.id == id &&
        other.name == name &&
        other.nameI18n == nameI18n &&
        other.slug == slug &&
        other.description == description &&
        other.coverImageUrl == coverImageUrl &&
        other.lineupImageUrl == lineupImageUrl &&
        other.eventType == eventType &&
        other.startDate == startDate &&
        other.endDate == endDate &&
        other.schedule == schedule &&
        listEquals(other.weeks, weeks) &&
        listEquals(other.ticketTiers, ticketTiers) &&
        listEquals(other.lineupSlots, lineupSlots) &&
        listEquals(other.lineupArtists, lineupArtists) &&
        other.location == location &&
        listEquals(other.contributors, contributors) &&
        other.favoriteCount == favoriteCount &&
        other.checkinCount == checkinCount &&
        other.isFavorited == isFavorited;
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        nameI18n,
        slug,
        description,
        coverImageUrl,
        lineupImageUrl,
        eventType,
        startDate,
        endDate,
        schedule,
        weeks,
        ticketTiers,
        lineupSlots,
        lineupArtists,
        location,
        contributors,
        favoriteCount,
        checkinCount,
        isFavorited,
      );

  @override
  String toString() =>
      'WebEvent(id: $id, name: $name, slug: $slug, eventType: $eventType, startDate: $startDate, endDate: $endDate, favoriteCount: $favoriteCount, checkinCount: $checkinCount)';
}

class WebEventSchedule {
  final String mode;
  final String timezoneId;
  final String timezoneName;

  const WebEventSchedule({
    required this.mode,
    required this.timezoneId,
    required this.timezoneName,
  });

  factory WebEventSchedule.fromJson(Map<String, dynamic> json) =>
      WebEventSchedule(
        mode: json['mode'] as String,
        timezoneId: json['timezoneId'] as String,
        timezoneName: json['timezoneName'] as String,
      );

  Map<String, dynamic> toJson() => {
        'mode': mode,
        'timezoneId': timezoneId,
        'timezoneName': timezoneName,
      };

  WebEventSchedule copyWith({
    String? mode,
    String? timezoneId,
    String? timezoneName,
  }) =>
      WebEventSchedule(
        mode: mode ?? this.mode,
        timezoneId: timezoneId ?? this.timezoneId,
        timezoneName: timezoneName ?? this.timezoneName,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WebEventSchedule &&
        other.mode == mode &&
        other.timezoneId == timezoneId &&
        other.timezoneName == timezoneName;
  }

  @override
  int get hashCode => Object.hash(mode, timezoneId, timezoneName);

  @override
  String toString() =>
      'WebEventSchedule(mode: $mode, timezoneId: $timezoneId, timezoneName: $timezoneName)';
}

class WebEventWeek {
  final String startDate;
  final String endDate;
  final List<WebEventDay> days;

  const WebEventWeek({
    required this.startDate,
    required this.endDate,
    required this.days,
  });

  factory WebEventWeek.fromJson(Map<String, dynamic> json) => WebEventWeek(
        startDate: json['startDate'] as String,
        endDate: json['endDate'] as String,
        days: (json['days'] as List<dynamic>)
            .map((e) => WebEventDay.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'startDate': startDate,
        'endDate': endDate,
        'days': days.map((e) => e.toJson()).toList(),
      };

  WebEventWeek copyWith({
    String? startDate,
    String? endDate,
    List<WebEventDay>? days,
  }) =>
      WebEventWeek(
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        days: days ?? this.days,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WebEventWeek &&
        other.startDate == startDate &&
        other.endDate == endDate &&
        listEquals(other.days, days);
  }

  @override
  int get hashCode => Object.hash(startDate, endDate, days);

  @override
  String toString() =>
      'WebEventWeek(startDate: $startDate, endDate: $endDate, days: $days)';
}

class WebEventDay {
  final String id;
  final String date;
  final String label;

  const WebEventDay({
    required this.id,
    required this.date,
    required this.label,
  });

  factory WebEventDay.fromJson(Map<String, dynamic> json) => WebEventDay(
        id: json['id'] as String,
        date: json['date'] as String,
        label: json['label'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'label': label,
      };

  WebEventDay copyWith({
    String? id,
    String? date,
    String? label,
  }) =>
      WebEventDay(
        id: id ?? this.id,
        date: date ?? this.date,
        label: label ?? this.label,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WebEventDay &&
        other.id == id &&
        other.date == date &&
        other.label == label;
  }

  @override
  int get hashCode => Object.hash(id, date, label);

  @override
  String toString() => 'WebEventDay(id: $id, date: $date, label: $label)';
}

class WebEventTicketTier {
  final String name;
  final String price;
  final String currency;
  final String url;
  final String description;

  const WebEventTicketTier({
    required this.name,
    required this.price,
    required this.currency,
    required this.url,
    required this.description,
  });

  factory WebEventTicketTier.fromJson(Map<String, dynamic> json) =>
      WebEventTicketTier(
        name: json['name'] as String,
        price: json['price'] as String,
        currency: json['currency'] as String,
        url: json['url'] as String,
        description: json['description'] as String,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'price': price,
        'currency': currency,
        'url': url,
        'description': description,
      };

  WebEventTicketTier copyWith({
    String? name,
    String? price,
    String? currency,
    String? url,
    String? description,
  }) =>
      WebEventTicketTier(
        name: name ?? this.name,
        price: price ?? this.price,
        currency: currency ?? this.currency,
        url: url ?? this.url,
        description: description ?? this.description,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WebEventTicketTier &&
        other.name == name &&
        other.price == price &&
        other.currency == currency &&
        other.url == url &&
        other.description == description;
  }

  @override
  int get hashCode => Object.hash(name, price, currency, url, description);

  @override
  String toString() =>
      'WebEventTicketTier(name: $name, price: $price, currency: $currency, url: $url, description: $description)';
}

class WebEventLineupSlot {
  final String id;
  final String stageName;
  final String startTime;
  final String endTime;
  final String artistName;
  final String djId;

  const WebEventLineupSlot({
    required this.id,
    required this.stageName,
    required this.startTime,
    required this.endTime,
    required this.artistName,
    required this.djId,
  });

  factory WebEventLineupSlot.fromJson(Map<String, dynamic> json) =>
      WebEventLineupSlot(
        id: json['id'] as String,
        stageName: json['stageName'] as String,
        startTime: json['startTime'] as String,
        endTime: json['endTime'] as String,
        artistName: json['artistName'] as String,
        djId: json['djId'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'stageName': stageName,
        'startTime': startTime,
        'endTime': endTime,
        'artistName': artistName,
        'djId': djId,
      };

  WebEventLineupSlot copyWith({
    String? id,
    String? stageName,
    String? startTime,
    String? endTime,
    String? artistName,
    String? djId,
  }) =>
      WebEventLineupSlot(
        id: id ?? this.id,
        stageName: stageName ?? this.stageName,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        artistName: artistName ?? this.artistName,
        djId: djId ?? this.djId,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WebEventLineupSlot &&
        other.id == id &&
        other.stageName == stageName &&
        other.startTime == startTime &&
        other.endTime == endTime &&
        other.artistName == artistName &&
        other.djId == djId;
  }

  @override
  int get hashCode =>
      Object.hash(id, stageName, startTime, endTime, artistName, djId);

  @override
  String toString() =>
      'WebEventLineupSlot(id: $id, stageName: $stageName, startTime: $startTime, endTime: $endTime, artistName: $artistName, djId: $djId)';
}

class WebEventLineupArtist {
  final String id;
  final String name;
  final String djId;
  final String avatarUrl;
  final bool isB2B;
  final List<WebEventLineupArtistMember>? members;

  const WebEventLineupArtist({
    required this.id,
    required this.name,
    required this.djId,
    required this.avatarUrl,
    required this.isB2B,
    this.members,
  });

  factory WebEventLineupArtist.fromJson(Map<String, dynamic> json) =>
      WebEventLineupArtist(
        id: json['id'] as String,
        name: json['name'] as String,
        djId: json['djId'] as String,
        avatarUrl: json['avatarUrl'] as String,
        isB2B: json['isB2B'] as bool,
        members: (json['members'] as List<dynamic>?)
            ?.map((e) => WebEventLineupArtistMember.fromJson(
                e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'djId': djId,
        'avatarUrl': avatarUrl,
        'isB2B': isB2B,
        if (members != null)
          'members': members!.map((e) => e.toJson()).toList(),
      };

  WebEventLineupArtist copyWith({
    String? id,
    String? name,
    String? djId,
    String? avatarUrl,
    bool? isB2B,
    List<WebEventLineupArtistMember>? members,
  }) =>
      WebEventLineupArtist(
        id: id ?? this.id,
        name: name ?? this.name,
        djId: djId ?? this.djId,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        isB2B: isB2B ?? this.isB2B,
        members: members ?? this.members,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WebEventLineupArtist &&
        other.id == id &&
        other.name == name &&
        other.djId == djId &&
        other.avatarUrl == avatarUrl &&
        other.isB2B == isB2B &&
        listEquals(other.members, members);
  }

  @override
  int get hashCode => Object.hash(id, name, djId, avatarUrl, isB2B, members);

  @override
  String toString() =>
      'WebEventLineupArtist(id: $id, name: $name, djId: $djId, avatarUrl: $avatarUrl, isB2B: $isB2B, members: $members)';
}

class WebEventLineupArtistMember {
  final String name;
  final String djId;

  const WebEventLineupArtistMember({
    required this.name,
    required this.djId,
  });

  factory WebEventLineupArtistMember.fromJson(Map<String, dynamic> json) =>
      WebEventLineupArtistMember(
        name: json['name'] as String,
        djId: json['djId'] as String,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'djId': djId,
      };

  WebEventLineupArtistMember copyWith({
    String? name,
    String? djId,
  }) =>
      WebEventLineupArtistMember(
        name: name ?? this.name,
        djId: djId ?? this.djId,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WebEventLineupArtistMember &&
        other.name == name &&
        other.djId == djId;
  }

  @override
  int get hashCode => Object.hash(name, djId);

  @override
  String toString() =>
      'WebEventLineupArtistMember(name: $name, djId: $djId)';
}

class WebEventManualLocation {
  final String name;
  final String address;
  final String city;
  final String country;
  final double? latitude;
  final double? longitude;

  const WebEventManualLocation({
    required this.name,
    required this.address,
    required this.city,
    required this.country,
    this.latitude,
    this.longitude,
  });

  factory WebEventManualLocation.fromJson(Map<String, dynamic> json) =>
      WebEventManualLocation(
        name: json['name'] as String,
        address: json['address'] as String,
        city: json['city'] as String,
        country: json['country'] as String,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'address': address,
        'city': city,
        'country': country,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      };

  WebEventManualLocation copyWith({
    String? name,
    String? address,
    String? city,
    String? country,
    double? latitude,
    double? longitude,
  }) =>
      WebEventManualLocation(
        name: name ?? this.name,
        address: address ?? this.address,
        city: city ?? this.city,
        country: country ?? this.country,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WebEventManualLocation &&
        other.name == name &&
        other.address == address &&
        other.city == city &&
        other.country == country &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode =>
      Object.hash(name, address, city, country, latitude, longitude);

  @override
  String toString() =>
      'WebEventManualLocation(name: $name, address: $address, city: $city, country: $country, latitude: $latitude, longitude: $longitude)';
}

class WebBiText {
  final String? en;
  final String? zh;
  final String? ja;
  final String? enFull;

  const WebBiText({
    this.en,
    this.zh,
    this.ja,
    this.enFull,
  });

  factory WebBiText.fromJson(Map<String, dynamic> json) => WebBiText(
        en: json['en'] as String?,
        zh: json['zh'] as String?,
        ja: json['ja'] as String?,
        enFull: json['enFull'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (en != null) 'en': en,
        if (zh != null) 'zh': zh,
        if (ja != null) 'ja': ja,
        if (enFull != null) 'enFull': enFull,
      };

  WebBiText copyWith({
    String? en,
    String? zh,
    String? ja,
    String? enFull,
  }) =>
      WebBiText(
        en: en ?? this.en,
        zh: zh ?? this.zh,
        ja: ja ?? this.ja,
        enFull: enFull ?? this.enFull,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WebBiText &&
        other.en == en &&
        other.zh == zh &&
        other.ja == ja &&
        other.enFull == enFull;
  }

  @override
  int get hashCode => Object.hash(en, zh, ja, enFull);

  @override
  String toString() =>
      'WebBiText(en: $en, zh: $zh, ja: $ja, enFull: $enFull)';
}

class WebContributorProfile {
  final String userId;
  final String displayName;
  final String avatarUrl;
  final int contributionCount;

  const WebContributorProfile({
    required this.userId,
    required this.displayName,
    required this.avatarUrl,
    required this.contributionCount,
  });

  factory WebContributorProfile.fromJson(Map<String, dynamic> json) =>
      WebContributorProfile(
        userId: json['userId'] as String,
        displayName: json['displayName'] as String,
        avatarUrl: json['avatarUrl'] as String,
        contributionCount: json['contributionCount'] as int,
      );

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'contributionCount': contributionCount,
      };

  WebContributorProfile copyWith({
    String? userId,
    String? displayName,
    String? avatarUrl,
    int? contributionCount,
  }) =>
      WebContributorProfile(
        userId: userId ?? this.userId,
        displayName: displayName ?? this.displayName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        contributionCount: contributionCount ?? this.contributionCount,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WebContributorProfile &&
        other.userId == userId &&
        other.displayName == displayName &&
        other.avatarUrl == avatarUrl &&
        other.contributionCount == contributionCount;
  }

  @override
  int get hashCode =>
      Object.hash(userId, displayName, avatarUrl, contributionCount);

  @override
  String toString() =>
      'WebContributorProfile(userId: $userId, displayName: $displayName, avatarUrl: $avatarUrl, contributionCount: $contributionCount)';
}

class EventFavoriteStatus {
  final bool isFavorited;

  const EventFavoriteStatus({
    required this.isFavorited,
  });

  factory EventFavoriteStatus.fromJson(Map<String, dynamic> json) =>
      EventFavoriteStatus(
        isFavorited: json['isFavorited'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'isFavorited': isFavorited,
      };

  EventFavoriteStatus copyWith({
    bool? isFavorited,
  }) =>
      EventFavoriteStatus(
        isFavorited: isFavorited ?? this.isFavorited,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EventFavoriteStatus && other.isFavorited == isFavorited;
  }

  @override
  int get hashCode => isFavorited.hashCode;

  @override
  String toString() => 'EventFavoriteStatus(isFavorited: $isFavorited)';
}
