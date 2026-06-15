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
        community: json['community'] as int,
        followedEvents: json['followedEvents'] as int,
        followedDJs: json['followedDJs'] as int,
        followedBrands: json['followedBrands'] as int,
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

class FollowedEventNotificationItem {
  final String id;
  final String eventId;
  final String eventName;
  final String coverImageUrl;
  final String changeType;
  final String summary;
  final String createdAt;

  const FollowedEventNotificationItem({
    required this.id,
    required this.eventId,
    required this.eventName,
    required this.coverImageUrl,
    required this.changeType,
    required this.summary,
    required this.createdAt,
  });

  factory FollowedEventNotificationItem.fromJson(
    Map<String, dynamic> json,
  ) =>
      FollowedEventNotificationItem(
        id: json['id'] as String,
        eventId: json['eventId'] as String,
        eventName: json['eventName'] as String,
        coverImageUrl: json['coverImageUrl'] as String,
        changeType: json['changeType'] as String,
        summary: json['summary'] as String,
        createdAt: json['createdAt'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'eventId': eventId,
        'eventName': eventName,
        'coverImageUrl': coverImageUrl,
        'changeType': changeType,
        'summary': summary,
        'createdAt': createdAt,
      };

  FollowedEventNotificationItem copyWith({
    String? id,
    String? eventId,
    String? eventName,
    String? coverImageUrl,
    String? changeType,
    String? summary,
    String? createdAt,
  }) =>
      FollowedEventNotificationItem(
        id: id ?? this.id,
        eventId: eventId ?? this.eventId,
        eventName: eventName ?? this.eventName,
        coverImageUrl: coverImageUrl ?? this.coverImageUrl,
        changeType: changeType ?? this.changeType,
        summary: summary ?? this.summary,
        createdAt: createdAt ?? this.createdAt,
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
  final String djId;
  final String djName;
  final String avatarUrl;
  final String changeType;
  final String summary;
  final String createdAt;

  const FollowedDJNotificationItem({
    required this.id,
    required this.djId,
    required this.djName,
    required this.avatarUrl,
    required this.changeType,
    required this.summary,
    required this.createdAt,
  });

  factory FollowedDJNotificationItem.fromJson(Map<String, dynamic> json) =>
      FollowedDJNotificationItem(
        id: json['id'] as String,
        djId: json['djId'] as String,
        djName: json['djName'] as String,
        avatarUrl: json['avatarUrl'] as String,
        changeType: json['changeType'] as String,
        summary: json['summary'] as String,
        createdAt: json['createdAt'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'djId': djId,
        'djName': djName,
        'avatarUrl': avatarUrl,
        'changeType': changeType,
        'summary': summary,
        'createdAt': createdAt,
      };

  FollowedDJNotificationItem copyWith({
    String? id,
    String? djId,
    String? djName,
    String? avatarUrl,
    String? changeType,
    String? summary,
    String? createdAt,
  }) =>
      FollowedDJNotificationItem(
        id: id ?? this.id,
        djId: djId ?? this.djId,
        djName: djName ?? this.djName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        changeType: changeType ?? this.changeType,
        summary: summary ?? this.summary,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FollowedDJNotificationItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'FollowedDJNotificationItem(id: $id, djName: $djName)';
}

class FollowedBrandNotificationItem {
  final String id;
  final String brandId;
  final String brandName;
  final String imageUrl;
  final String changeType;
  final String summary;
  final String createdAt;

  const FollowedBrandNotificationItem({
    required this.id,
    required this.brandId,
    required this.brandName,
    required this.imageUrl,
    required this.changeType,
    required this.summary,
    required this.createdAt,
  });

  factory FollowedBrandNotificationItem.fromJson(
    Map<String, dynamic> json,
  ) =>
      FollowedBrandNotificationItem(
        id: json['id'] as String,
        brandId: json['brandId'] as String,
        brandName: json['brandName'] as String,
        imageUrl: json['imageUrl'] as String,
        changeType: json['changeType'] as String,
        summary: json['summary'] as String,
        createdAt: json['createdAt'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'brandId': brandId,
        'brandName': brandName,
        'imageUrl': imageUrl,
        'changeType': changeType,
        'summary': summary,
        'createdAt': createdAt,
      };

  FollowedBrandNotificationItem copyWith({
    String? id,
    String? brandId,
    String? brandName,
    String? imageUrl,
    String? changeType,
    String? summary,
    String? createdAt,
  }) =>
      FollowedBrandNotificationItem(
        id: id ?? this.id,
        brandId: brandId ?? this.brandId,
        brandName: brandName ?? this.brandName,
        imageUrl: imageUrl ?? this.imageUrl,
        changeType: changeType ?? this.changeType,
        summary: summary ?? this.summary,
        createdAt: createdAt ?? this.createdAt,
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
