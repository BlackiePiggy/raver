/// Lightweight models for the event discussion / check-in APIs.
///
/// These are local to feature_discover and intentionally plain Dart classes
/// to avoid a build_runner dependency for a small surface area.

class EventDiscussionComment {
  EventDiscussionComment({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.avatarUrl,
    required this.content,
    required this.createdAt,
  });

  factory EventDiscussionComment.fromJson(Map<String, dynamic> json) {
    return EventDiscussionComment(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }

  final String id;
  final String userId;
  final String displayName;
  final String avatarUrl;
  final String content;
  final String createdAt;
}

class EventDiscussionPage {
  EventDiscussionPage({
    required this.comments,
    this.nextCursor,
  });

  factory EventDiscussionPage.fromJson(Map<String, dynamic> json) {
    final items = json['items'] as List<dynamic>? ?? [];
    return EventDiscussionPage(
      comments: items
          .map((e) =>
              EventDiscussionComment.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextCursor: json['nextCursor'] as String?,
    );
  }

  final List<EventDiscussionComment> comments;
  final String? nextCursor;
}

class EventCheckinResult {
  EventCheckinResult({
    required this.success,
    required this.checkinId,
    required this.checkedInAt,
  });

  factory EventCheckinResult.fromJson(Map<String, dynamic> json) {
    return EventCheckinResult(
      success: json['success'] as bool? ?? true,
      checkinId: json['checkinId'] as String? ?? '',
      checkedInAt: json['checkedInAt'] as String? ?? '',
    );
  }

  final bool success;
  final String checkinId;
  final String checkedInAt;
}

class EventCheckinUser {
  EventCheckinUser({
    required this.userId,
    required this.displayName,
    required this.avatarUrl,
    required this.checkedInAt,
  });

  factory EventCheckinUser.fromJson(Map<String, dynamic> json) {
    return EventCheckinUser(
      userId: json['userId'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String? ?? '',
      checkedInAt: json['checkedInAt'] as String? ?? '',
    );
  }

  final String userId;
  final String displayName;
  final String avatarUrl;
  final String checkedInAt;
}

class EventCheckinList {
  EventCheckinList({
    required this.users,
    required this.totalCount,
    required this.myCheckinAt,
  });

  factory EventCheckinList.fromJson(Map<String, dynamic> json) {
    final items = json['items'] as List<dynamic>? ?? [];
    return EventCheckinList(
      users: items
          .map((e) => EventCheckinUser.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalCount: json['totalCount'] as int? ?? 0,
      myCheckinAt: json['myCheckinAt'] as String?,
    );
  }

  final List<EventCheckinUser> users;
  final int totalCount;
  final String? myCheckinAt;
}
