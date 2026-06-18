class AppNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final String targetType;
  final String targetId;
  final String imageUrl;
  final bool isRead;
  final String createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.targetType,
    required this.targetId,
    required this.imageUrl,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        type: json['type'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        targetType: json['targetType'] as String,
        targetId: json['targetId'] as String,
        imageUrl: json['imageUrl'] as String,
        isRead: json['isRead'] as bool,
        createdAt: json['createdAt'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'body': body,
        'targetType': targetType,
        'targetId': targetId,
        'imageUrl': imageUrl,
        'isRead': isRead,
        'createdAt': createdAt,
      };

  AppNotification copyWith({
    String? id,
    String? type,
    String? title,
    String? body,
    String? targetType,
    String? targetId,
    String? imageUrl,
    bool? isRead,
    String? createdAt,
  }) =>
      AppNotification(
        id: id ?? this.id,
        type: type ?? this.type,
        title: title ?? this.title,
        body: body ?? this.body,
        targetType: targetType ?? this.targetType,
        targetId: targetId ?? this.targetId,
        imageUrl: imageUrl ?? this.imageUrl,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppNotification && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'AppNotification(id: $id, title: $title)';
}

class NotificationInbox {
  final List<AppNotification> notifications;
  final String? nextCursor;

  const NotificationInbox({
    required this.notifications,
    this.nextCursor,
  });

  factory NotificationInbox.fromJson(Map<String, dynamic> json) =>
      NotificationInbox(
        notifications: (json['notifications'] as List<dynamic>)
            .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
            .toList(),
        nextCursor: json['nextCursor'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'notifications': notifications.map((e) => e.toJson()).toList(),
        if (nextCursor != null) 'nextCursor': nextCursor,
      };

  NotificationInbox copyWith({
    List<AppNotification>? notifications,
    String? nextCursor,
  }) =>
      NotificationInbox(
        notifications: notifications ?? this.notifications,
        nextCursor: nextCursor ?? this.nextCursor,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationInbox && other.nextCursor == nextCursor;
  }

  @override
  int get hashCode => nextCursor.hashCode;

  @override
  String toString() =>
      'NotificationInbox(notifications: ${notifications.length} items, nextCursor: $nextCursor)';
}

class NotificationUnreadCount {
  final int community;
  final int followedEvents;
  final int followedDJs;
  final int followedBrands;

  const NotificationUnreadCount({
    required this.community,
    required this.followedEvents,
    required this.followedDJs,
    required this.followedBrands,
  });

  factory NotificationUnreadCount.fromJson(Map<String, dynamic> json) =>
      NotificationUnreadCount(
        community: _intFromJson(
          json,
          const [
            'community',
            'communityUnread',
            'communityUnreadCount',
            'community_unread',
            'community_unread_count',
            'circle',
            'circleUnread',
            'circle_unread',
          ],
        ),
        followedEvents: _intFromJson(
          json,
          const [
            'followedEvents',
            'followedEventsUnread',
            'followedEventsUnreadCount',
            'followed_events',
            'followed_events_unread',
            'followed_events_unread_count',
            'events',
          ],
        ),
        followedDJs: _intFromJson(
          json,
          const [
            'followedDJs',
            'followedDjs',
            'followedDJsUnread',
            'followedDjsUnread',
            'followedDJsUnreadCount',
            'followedDjsUnreadCount',
            'followed_djs',
            'followed_djs_unread',
            'followed_djs_unread_count',
            'djs',
          ],
        ),
        followedBrands: _intFromJson(
          json,
          const [
            'followedBrands',
            'followedBrandsUnread',
            'followedBrandsUnreadCount',
            'followed_brands',
            'followed_brands_unread',
            'followed_brands_unread_count',
            'brands',
          ],
        ),
      );

  Map<String, dynamic> toJson() => {
        'community': community,
        'followedEvents': followedEvents,
        'followedDJs': followedDJs,
        'followedBrands': followedBrands,
      };

  NotificationUnreadCount copyWith({
    int? community,
    int? followedEvents,
    int? followedDJs,
    int? followedBrands,
  }) =>
      NotificationUnreadCount(
        community: community ?? this.community,
        followedEvents: followedEvents ?? this.followedEvents,
        followedDJs: followedDJs ?? this.followedDJs,
        followedBrands: followedBrands ?? this.followedBrands,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationUnreadCount &&
        other.community == community &&
        other.followedEvents == followedEvents &&
        other.followedDJs == followedDJs &&
        other.followedBrands == followedBrands;
  }

  @override
  int get hashCode =>
      Object.hash(community, followedEvents, followedDJs, followedBrands);

  @override
  String toString() =>
      'NotificationUnreadCount(community: $community, followedEvents: $followedEvents, followedDJs: $followedDJs, followedBrands: $followedBrands)';
}

int _intFromJson(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
  }
  return 0;
}

class FollowedEventNotificationItem {
  final String id;
  final String type;
  final String eventId;
  final String eventName;
  final String newsId;
  final String newsTitle;
  final String newsSummary;
  final String newsCoverImageUrl;
  final bool isRead;
  final String occurredAt;

  const FollowedEventNotificationItem({
    required this.id,
    required this.type,
    required this.eventId,
    required this.eventName,
    required this.newsId,
    required this.newsTitle,
    required this.newsSummary,
    required this.newsCoverImageUrl,
    required this.isRead,
    required this.occurredAt,
  });

  String get coverImageUrl => newsCoverImageUrl;
  String get changeType => type;
  String get summary => newsSummary;
  String get createdAt => occurredAt;

  factory FollowedEventNotificationItem.fromJson(
    Map<String, dynamic> json,
  ) =>
      FollowedEventNotificationItem(
        id: _readString(json, 'id'),
        type: _readString(json, 'type',
            fallback: _readString(json, 'changeType')),
        eventId: _readString(json, 'eventId'),
        eventName: _readString(json, 'eventName'),
        newsId: _readString(
          json,
          'newsId',
          fallback: _readString(json, 'eventId'),
        ),
        newsTitle: _readString(
          json,
          'newsTitle',
          fallback: _readString(json, 'eventName'),
        ),
        newsSummary: _readString(
          json,
          'newsSummary',
          fallback: _readString(json, 'summary'),
        ),
        newsCoverImageUrl: _readString(
          json,
          'newsCoverImageURL',
          fallback: _readString(
            json,
            'newsCoverImageUrl',
            fallback: _readString(json, 'coverImageUrl'),
          ),
        ),
        isRead: _readBool(json, 'isRead'),
        occurredAt: _readString(
          json,
          'occurredAt',
          fallback: _readString(json, 'createdAt'),
        ),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'eventId': eventId,
        'eventName': eventName,
        'newsId': newsId,
        'newsTitle': newsTitle,
        'newsSummary': newsSummary,
        'newsCoverImageURL': newsCoverImageUrl,
        'isRead': isRead,
        'occurredAt': occurredAt,
      };

  FollowedEventNotificationItem copyWith({
    String? id,
    String? type,
    String? eventId,
    String? eventName,
    String? newsId,
    String? newsTitle,
    String? newsSummary,
    String? newsCoverImageUrl,
    bool? isRead,
    String? occurredAt,
  }) =>
      FollowedEventNotificationItem(
        id: id ?? this.id,
        type: type ?? this.type,
        eventId: eventId ?? this.eventId,
        eventName: eventName ?? this.eventName,
        newsId: newsId ?? this.newsId,
        newsTitle: newsTitle ?? this.newsTitle,
        newsSummary: newsSummary ?? this.newsSummary,
        newsCoverImageUrl: newsCoverImageUrl ?? this.newsCoverImageUrl,
        isRead: isRead ?? this.isRead,
        occurredAt: occurredAt ?? this.occurredAt,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FollowedEventNotificationItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'FollowedEventNotificationItem(id: $id, eventName: $eventName)';
}

class FollowedDJNotificationItem {
  final String id;
  final String type;
  final String djId;
  final String djName;
  final String avatarUrl;
  final String newsId;
  final String newsTitle;
  final String newsSummary;
  final String newsCoverImageUrl;
  final bool isRead;
  final String occurredAt;

  const FollowedDJNotificationItem({
    required this.id,
    required this.type,
    required this.djId,
    required this.djName,
    required this.avatarUrl,
    required this.newsId,
    required this.newsTitle,
    required this.newsSummary,
    required this.newsCoverImageUrl,
    required this.isRead,
    required this.occurredAt,
  });

  String get changeType => type;
  String get summary => newsSummary;
  String get createdAt => occurredAt;

  factory FollowedDJNotificationItem.fromJson(Map<String, dynamic> json) =>
      FollowedDJNotificationItem(
        id: _readString(json, 'id'),
        type: _readString(json, 'type',
            fallback: _readString(json, 'changeType')),
        djId: _readString(json, 'djId'),
        djName: _readString(json, 'djName'),
        avatarUrl: _readString(
          json,
          'avatarUrl',
          fallback: _readString(json, 'djAvatarUrl'),
        ),
        newsId: _readString(json, 'newsId'),
        newsTitle: _readString(
          json,
          'newsTitle',
          fallback: _readString(json, 'djName'),
        ),
        newsSummary: _readString(
          json,
          'newsSummary',
          fallback: _readString(json, 'summary'),
        ),
        newsCoverImageUrl: _readString(
          json,
          'newsCoverImageURL',
          fallback: _readString(
            json,
            'newsCoverImageUrl',
            fallback: _readString(json, 'coverImageUrl'),
          ),
        ),
        isRead: _readBool(json, 'isRead'),
        occurredAt: _readString(
          json,
          'occurredAt',
          fallback: _readString(json, 'createdAt'),
        ),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'djId': djId,
        'djName': djName,
        'avatarUrl': avatarUrl,
        'newsId': newsId,
        'newsTitle': newsTitle,
        'newsSummary': newsSummary,
        'newsCoverImageURL': newsCoverImageUrl,
        'isRead': isRead,
        'occurredAt': occurredAt,
      };

  FollowedDJNotificationItem copyWith({
    String? id,
    String? type,
    String? djId,
    String? djName,
    String? avatarUrl,
    String? newsId,
    String? newsTitle,
    String? newsSummary,
    String? newsCoverImageUrl,
    bool? isRead,
    String? occurredAt,
  }) =>
      FollowedDJNotificationItem(
        id: id ?? this.id,
        type: type ?? this.type,
        djId: djId ?? this.djId,
        djName: djName ?? this.djName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        newsId: newsId ?? this.newsId,
        newsTitle: newsTitle ?? this.newsTitle,
        newsSummary: newsSummary ?? this.newsSummary,
        newsCoverImageUrl: newsCoverImageUrl ?? this.newsCoverImageUrl,
        isRead: isRead ?? this.isRead,
        occurredAt: occurredAt ?? this.occurredAt,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FollowedDJNotificationItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'FollowedDJNotificationItem(id: $id, djName: $djName)';
}

class FollowedBrandNotificationItem {
  final String id;
  final String type;
  final String brandId;
  final String brandName;
  final String imageUrl;
  final String newsId;
  final String newsTitle;
  final String newsSummary;
  final String newsCoverImageUrl;
  final bool isRead;
  final String occurredAt;

  const FollowedBrandNotificationItem({
    required this.id,
    required this.type,
    required this.brandId,
    required this.brandName,
    required this.imageUrl,
    required this.newsId,
    required this.newsTitle,
    required this.newsSummary,
    required this.newsCoverImageUrl,
    required this.isRead,
    required this.occurredAt,
  });

  String get changeType => type;
  String get summary => newsSummary;
  String get createdAt => occurredAt;

  factory FollowedBrandNotificationItem.fromJson(
    Map<String, dynamic> json,
  ) =>
      FollowedBrandNotificationItem(
        id: _readString(json, 'id'),
        type: _readString(json, 'type',
            fallback: _readString(json, 'changeType')),
        brandId: _readString(json, 'brandId'),
        brandName: _readString(json, 'brandName'),
        imageUrl: _readString(
          json,
          'imageUrl',
          fallback: _readString(json, 'brandImageUrl'),
        ),
        newsId: _readString(json, 'newsId'),
        newsTitle: _readString(
          json,
          'newsTitle',
          fallback: _readString(json, 'brandName'),
        ),
        newsSummary: _readString(
          json,
          'newsSummary',
          fallback: _readString(json, 'summary'),
        ),
        newsCoverImageUrl: _readString(
          json,
          'newsCoverImageURL',
          fallback: _readString(
            json,
            'newsCoverImageUrl',
            fallback: _readString(json, 'coverImageUrl'),
          ),
        ),
        isRead: _readBool(json, 'isRead'),
        occurredAt: _readString(
          json,
          'occurredAt',
          fallback: _readString(json, 'createdAt'),
        ),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'brandId': brandId,
        'brandName': brandName,
        'imageUrl': imageUrl,
        'newsId': newsId,
        'newsTitle': newsTitle,
        'newsSummary': newsSummary,
        'newsCoverImageURL': newsCoverImageUrl,
        'isRead': isRead,
        'occurredAt': occurredAt,
      };

  FollowedBrandNotificationItem copyWith({
    String? id,
    String? type,
    String? brandId,
    String? brandName,
    String? imageUrl,
    String? newsId,
    String? newsTitle,
    String? newsSummary,
    String? newsCoverImageUrl,
    bool? isRead,
    String? occurredAt,
  }) =>
      FollowedBrandNotificationItem(
        id: id ?? this.id,
        type: type ?? this.type,
        brandId: brandId ?? this.brandId,
        brandName: brandName ?? this.brandName,
        imageUrl: imageUrl ?? this.imageUrl,
        newsId: newsId ?? this.newsId,
        newsTitle: newsTitle ?? this.newsTitle,
        newsSummary: newsSummary ?? this.newsSummary,
        newsCoverImageUrl: newsCoverImageUrl ?? this.newsCoverImageUrl,
        isRead: isRead ?? this.isRead,
        occurredAt: occurredAt ?? this.occurredAt,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FollowedBrandNotificationItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'FollowedBrandNotificationItem(id: $id, brandName: $brandName)';
}

class ContentReviewNotificationItem {
  final String id;
  final String submissionId;
  final String entityType;
  final String entityName;
  final String status;
  final String reviewNote;
  final String createdAt;

  const ContentReviewNotificationItem({
    required this.id,
    required this.submissionId,
    required this.entityType,
    required this.entityName,
    required this.status,
    required this.reviewNote,
    required this.createdAt,
  });

  factory ContentReviewNotificationItem.fromJson(
    Map<String, dynamic> json,
  ) =>
      ContentReviewNotificationItem(
        id: json['id'] as String,
        submissionId: json['submissionId'] as String,
        entityType: json['entityType'] as String,
        entityName: json['entityName'] as String,
        status: json['status'] as String,
        reviewNote: json['reviewNote'] as String,
        createdAt: json['createdAt'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'submissionId': submissionId,
        'entityType': entityType,
        'entityName': entityName,
        'status': status,
        'reviewNote': reviewNote,
        'createdAt': createdAt,
      };

  ContentReviewNotificationItem copyWith({
    String? id,
    String? submissionId,
    String? entityType,
    String? entityName,
    String? status,
    String? reviewNote,
    String? createdAt,
  }) =>
      ContentReviewNotificationItem(
        id: id ?? this.id,
        submissionId: submissionId ?? this.submissionId,
        entityType: entityType ?? this.entityType,
        entityName: entityName ?? this.entityName,
        status: status ?? this.status,
        reviewNote: reviewNote ?? this.reviewNote,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ContentReviewNotificationItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'ContentReviewNotificationItem(id: $id, entityName: $entityName)';
}

String _readString(
  Map<String, dynamic> json,
  String key, {
  String fallback = '',
}) {
  final value = json[key];
  if (value == null) return fallback;
  if (value is String) return value;
  return value.toString();
}

bool _readBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) return value.trim().toLowerCase() == 'true';
  return false;
}
