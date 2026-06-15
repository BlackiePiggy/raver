class WebCheckin {
  final String id;
  final String userId;
  final String eventId;
  final String eventName;
  final String eventCoverUrl;
  final String djId;
  final String djName;
  final String djAvatarUrl;
  final String type;
  final String note;
  final int rating;
  final String attendedAt;
  final String createdAt;

  const WebCheckin({
    required this.id,
    required this.userId,
    required this.eventId,
    required this.eventName,
    required this.eventCoverUrl,
    required this.djId,
    required this.djName,
    required this.djAvatarUrl,
    required this.type,
    required this.note,
    required this.rating,
    required this.attendedAt,
    required this.createdAt,
  });

  factory WebCheckin.fromJson(Map<String, dynamic> json) => WebCheckin(
        id: json['id'] as String,
        userId: json['userId'] as String,
        eventId: json['eventId'] as String,
        eventName: json['eventName'] as String,
        eventCoverUrl: json['eventCoverUrl'] as String,
        djId: json['djId'] as String,
        djName: json['djName'] as String,
        djAvatarUrl: json['djAvatarUrl'] as String,
        type: json['type'] as String,
        note: json['note'] as String,
        rating: json['rating'] as int,
        attendedAt: json['attendedAt'] as String,
        createdAt: json['createdAt'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'eventId': eventId,
        'eventName': eventName,
        'eventCoverUrl': eventCoverUrl,
        'djId': djId,
        'djName': djName,
        'djAvatarUrl': djAvatarUrl,
        'type': type,
        'note': note,
        'rating': rating,
        'attendedAt': attendedAt,
        'createdAt': createdAt,
      };

  WebCheckin copyWith({
    String? id,
    String? userId,
    String? eventId,
    String? eventName,
    String? eventCoverUrl,
    String? djId,
    String? djName,
    String? djAvatarUrl,
    String? type,
    String? note,
    int? rating,
    String? attendedAt,
    String? createdAt,
  }) =>
      WebCheckin(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        eventId: eventId ?? this.eventId,
        eventName: eventName ?? this.eventName,
        eventCoverUrl: eventCoverUrl ?? this.eventCoverUrl,
        djId: djId ?? this.djId,
        djName: djName ?? this.djName,
        djAvatarUrl: djAvatarUrl ?? this.djAvatarUrl,
        type: type ?? this.type,
        note: note ?? this.note,
        rating: rating ?? this.rating,
        attendedAt: attendedAt ?? this.attendedAt,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WebCheckin &&
        other.id == id &&
        other.userId == userId &&
        other.eventId == eventId &&
        other.eventName == eventName &&
        other.eventCoverUrl == eventCoverUrl &&
        other.djId == djId &&
        other.djName == djName &&
        other.djAvatarUrl == djAvatarUrl &&
        other.type == type &&
        other.note == note &&
        other.rating == rating &&
        other.attendedAt == attendedAt &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(id, userId, eventId, eventName,
      eventCoverUrl, djId, djName, djAvatarUrl, type, note, rating, attendedAt, createdAt);

  @override
  String toString() =>
      'WebCheckin(id: $id, userId: $userId, eventId: $eventId, eventName: $eventName)';
}

class MyCheckinsOverviewResponse {
  final MyCheckinsOverviewStats stats;
  final List<MyCheckinsOverviewTimelineSection> timeline;
  final MyCheckinsOverviewGallerySummary gallerySummary;

  const MyCheckinsOverviewResponse({
    required this.stats,
    required this.timeline,
    required this.gallerySummary,
  });

  factory MyCheckinsOverviewResponse.fromJson(Map<String, dynamic> json) =>
      MyCheckinsOverviewResponse(
        stats: MyCheckinsOverviewStats.fromJson(
            json['stats'] as Map<String, dynamic>),
        timeline: (json['timeline'] as List<dynamic>? ?? [])
            .map((e) =>
                MyCheckinsOverviewTimelineSection.fromJson(e as Map<String, dynamic>))
            .toList(),
        gallerySummary: MyCheckinsOverviewGallerySummary.fromJson(
            json['gallerySummary'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'stats': stats.toJson(),
        'timeline': timeline.map((e) => e.toJson()).toList(),
        'gallerySummary': gallerySummary.toJson(),
      };

  MyCheckinsOverviewResponse copyWith({
    MyCheckinsOverviewStats? stats,
    List<MyCheckinsOverviewTimelineSection>? timeline,
    MyCheckinsOverviewGallerySummary? gallerySummary,
  }) =>
      MyCheckinsOverviewResponse(
        stats: stats ?? this.stats,
        timeline: timeline ?? this.timeline,
        gallerySummary: gallerySummary ?? this.gallerySummary,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MyCheckinsOverviewResponse &&
        other.stats == stats &&
        other.gallerySummary == gallerySummary;
  }

  @override
  int get hashCode => Object.hash(stats, gallerySummary);

  @override
  String toString() => 'MyCheckinsOverviewResponse(stats: $stats)';
}

class MyCheckinsOverviewStats {
  final int totalCheckins;
  final int uniqueEvents;
  final int uniqueDJs;
  final int totalDays;

  const MyCheckinsOverviewStats({
    required this.totalCheckins,
    required this.uniqueEvents,
    required this.uniqueDJs,
    required this.totalDays,
  });

  factory MyCheckinsOverviewStats.fromJson(Map<String, dynamic> json) =>
      MyCheckinsOverviewStats(
        totalCheckins: json['totalCheckins'] as int,
        uniqueEvents: json['uniqueEvents'] as int,
        uniqueDJs: json['uniqueDJs'] as int,
        totalDays: json['totalDays'] as int,
      );

  Map<String, dynamic> toJson() => {
        'totalCheckins': totalCheckins,
        'uniqueEvents': uniqueEvents,
        'uniqueDJs': uniqueDJs,
        'totalDays': totalDays,
      };

  MyCheckinsOverviewStats copyWith({
    int? totalCheckins,
    int? uniqueEvents,
    int? uniqueDJs,
    int? totalDays,
  }) =>
      MyCheckinsOverviewStats(
        totalCheckins: totalCheckins ?? this.totalCheckins,
        uniqueEvents: uniqueEvents ?? this.uniqueEvents,
        uniqueDJs: uniqueDJs ?? this.uniqueDJs,
        totalDays: totalDays ?? this.totalDays,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MyCheckinsOverviewStats &&
        other.totalCheckins == totalCheckins &&
        other.uniqueEvents == uniqueEvents &&
        other.uniqueDJs == uniqueDJs &&
        other.totalDays == totalDays;
  }

  @override
  int get hashCode =>
      Object.hash(totalCheckins, uniqueEvents, uniqueDJs, totalDays);

  @override
  String toString() =>
      'MyCheckinsOverviewStats(totalCheckins: $totalCheckins, uniqueEvents: $uniqueEvents, uniqueDJs: $uniqueDJs, totalDays: $totalDays)';
}

class MyCheckinsOverviewGallerySummary {
  final int eventCount;
  final int artistCount;

  const MyCheckinsOverviewGallerySummary({
    required this.eventCount,
    required this.artistCount,
  });

  factory MyCheckinsOverviewGallerySummary.fromJson(
    Map<String, dynamic> json,
  ) =>
      MyCheckinsOverviewGallerySummary(
        eventCount: json['eventCount'] as int,
        artistCount: json['artistCount'] as int,
      );

  Map<String, dynamic> toJson() => {
        'eventCount': eventCount,
        'artistCount': artistCount,
      };

  MyCheckinsOverviewGallerySummary copyWith({
    int? eventCount,
    int? artistCount,
  }) =>
      MyCheckinsOverviewGallerySummary(
        eventCount: eventCount ?? this.eventCount,
        artistCount: artistCount ?? this.artistCount,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MyCheckinsOverviewGallerySummary &&
        other.eventCount == eventCount &&
        other.artistCount == artistCount;
  }

  @override
  int get hashCode => Object.hash(eventCount, artistCount);

  @override
  String toString() =>
      'MyCheckinsOverviewGallerySummary(eventCount: $eventCount, artistCount: $artistCount)';
}

class MyCheckinsOverviewTimelineSection {
  final int year;
  final List<MyCheckinsOverviewTimelineItem> items;

  const MyCheckinsOverviewTimelineSection({
    required this.year,
    required this.items,
  });

  factory MyCheckinsOverviewTimelineSection.fromJson(
    Map<String, dynamic> json,
  ) =>
      MyCheckinsOverviewTimelineSection(
        year: json['year'] as int,
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) =>
                MyCheckinsOverviewTimelineItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'year': year,
        'items': items.map((e) => e.toJson()).toList(),
      };

  MyCheckinsOverviewTimelineSection copyWith({
    int? year,
    List<MyCheckinsOverviewTimelineItem>? items,
  }) =>
      MyCheckinsOverviewTimelineSection(
        year: year ?? this.year,
        items: items ?? this.items,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MyCheckinsOverviewTimelineSection && other.year == year;
  }

  @override
  int get hashCode => year.hashCode;

  @override
  String toString() =>
      'MyCheckinsOverviewTimelineSection(year: $year, items: ${items.length} items)';
}

class MyCheckinsOverviewTimelineItem {
  final String eventId;
  final String eventName;
  final String coverImageUrl;
  final String date;
  final int djCount;

  const MyCheckinsOverviewTimelineItem({
    required this.eventId,
    required this.eventName,
    required this.coverImageUrl,
    required this.date,
    required this.djCount,
  });

  factory MyCheckinsOverviewTimelineItem.fromJson(
    Map<String, dynamic> json,
  ) =>
      MyCheckinsOverviewTimelineItem(
        eventId: json['eventId'] as String,
        eventName: json['eventName'] as String,
        coverImageUrl: json['coverImageUrl'] as String,
        date: json['date'] as String,
        djCount: json['djCount'] as int,
      );

  Map<String, dynamic> toJson() => {
        'eventId': eventId,
        'eventName': eventName,
        'coverImageUrl': coverImageUrl,
        'date': date,
        'djCount': djCount,
      };

  MyCheckinsOverviewTimelineItem copyWith({
    String? eventId,
    String? eventName,
    String? coverImageUrl,
    String? date,
    int? djCount,
  }) =>
      MyCheckinsOverviewTimelineItem(
        eventId: eventId ?? this.eventId,
        eventName: eventName ?? this.eventName,
        coverImageUrl: coverImageUrl ?? this.coverImageUrl,
        date: date ?? this.date,
        djCount: djCount ?? this.djCount,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MyCheckinsOverviewTimelineItem &&
        other.eventId == eventId &&
        other.eventName == eventName &&
        other.coverImageUrl == coverImageUrl &&
        other.date == date &&
        other.djCount == djCount;
  }

  @override
  int get hashCode =>
      Object.hash(eventId, eventName, coverImageUrl, date, djCount);

  @override
  String toString() =>
      'MyCheckinsOverviewTimelineItem(eventId: $eventId, eventName: $eventName, date: $date)';
}
