import 'user.dart';

class Post {
  final String id;
  final String content;
  final List<String>? images;
  final List<String>? videos;
  final UserSummary user;
  final int likeCount;
  final int commentCount;
  final int repostCount;
  final int saveCount;
  final int shareCount;
  final bool? isLiked;
  final bool? isReposted;
  final bool? isSaved;
  final String? eventId;
  final String? eventName;
  final PostSquad? squad;
  final String createdAt;

  const Post({
    required this.id,
    required this.content,
    this.images,
    this.videos,
    required this.user,
    required this.likeCount,
    required this.commentCount,
    required this.repostCount,
    required this.saveCount,
    required this.shareCount,
    this.isLiked,
    this.isReposted,
    this.isSaved,
    this.eventId,
    this.eventName,
    this.squad,
    required this.createdAt,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    final rawImages = _postStringList(json['images']);
    final rawVideos = [
      ..._postStringList(json['videos']),
      ...rawImages.where(_isPostVideoUrl),
    ];
    final images = rawImages.where((url) => !_isPostVideoUrl(url)).toList();
    final videos = rawVideos.toSet().toList();
    return Post(
      id: json['id'] as String,
      content: json['content'] as String? ?? '',
      images: images.isEmpty ? null : images,
      videos: videos.isEmpty ? null : videos,
      user: UserSummary.fromJson(
        (json['user'] ?? json['author']) as Map<String, dynamic>,
      ),
      likeCount: json['likeCount'] as int? ?? 0,
      commentCount: json['commentCount'] as int? ?? 0,
      repostCount: json['repostCount'] as int? ?? 0,
      saveCount: json['saveCount'] as int? ?? 0,
      shareCount: json['shareCount'] as int? ?? 0,
      isLiked: json['isLiked'] as bool?,
      isReposted: json['isReposted'] as bool?,
      isSaved: json['isSaved'] as bool?,
      eventId: json['eventId'] as String?,
      eventName: json['eventName'] as String?,
      squad: json['squad'] != null
          ? PostSquad.fromJson(json['squad'] as Map<String, dynamic>)
          : null,
      createdAt: json['displayPublishedAt'] as String? ??
          json['publishedAt'] as String? ??
          json['createdAt'] as String? ??
          '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        if (images != null) 'images': images,
        if (videos != null) 'videos': videos,
        'user': user.toJson(),
        'likeCount': likeCount,
        'commentCount': commentCount,
        'repostCount': repostCount,
        'saveCount': saveCount,
        'shareCount': shareCount,
        if (isLiked != null) 'isLiked': isLiked,
        if (isReposted != null) 'isReposted': isReposted,
        if (isSaved != null) 'isSaved': isSaved,
        if (eventId != null) 'eventId': eventId,
        if (eventName != null) 'eventName': eventName,
        if (squad != null) 'squad': squad!.toJson(),
        'createdAt': createdAt,
      };

  Post copyWith({
    String? id,
    String? content,
    List<String>? images,
    List<String>? videos,
    UserSummary? user,
    int? likeCount,
    int? commentCount,
    int? repostCount,
    int? saveCount,
    int? shareCount,
    bool? isLiked,
    bool? isReposted,
    bool? isSaved,
    String? eventId,
    String? eventName,
    PostSquad? squad,
    String? createdAt,
  }) =>
      Post(
        id: id ?? this.id,
        content: content ?? this.content,
        images: images ?? this.images,
        videos: videos ?? this.videos,
        user: user ?? this.user,
        likeCount: likeCount ?? this.likeCount,
        commentCount: commentCount ?? this.commentCount,
        repostCount: repostCount ?? this.repostCount,
        saveCount: saveCount ?? this.saveCount,
        shareCount: shareCount ?? this.shareCount,
        isLiked: isLiked ?? this.isLiked,
        isReposted: isReposted ?? this.isReposted,
        isSaved: isSaved ?? this.isSaved,
        eventId: eventId ?? this.eventId,
        eventName: eventName ?? this.eventName,
        squad: squad ?? this.squad,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Post && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Post(id: $id, content: $content)';
}

class PostSquad {
  final String id;
  final String name;
  final String avatarUrl;

  const PostSquad({
    required this.id,
    required this.name,
    required this.avatarUrl,
  });

  factory PostSquad.fromJson(Map<String, dynamic> json) => PostSquad(
        id: json['id'] as String,
        name: json['name'] as String,
        avatarUrl: json['avatarUrl'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatarUrl': avatarUrl,
      };

  PostSquad copyWith({String? id, String? name, String? avatarUrl}) =>
      PostSquad(
        id: id ?? this.id,
        name: name ?? this.name,
        avatarUrl: avatarUrl ?? this.avatarUrl,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PostSquad && other.id == id && other.name == name;
  }

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'PostSquad(id: $id, name: $name)';
}

class Comment {
  final String id;
  final String postId;
  final String parentCommentId;
  final String rootCommentId;
  final int depth;
  final String userId;
  final String displayName;
  final String avatarUrl;
  final String replyToUserId;
  final String replyToDisplayName;
  final String content;
  final String createdAt;

  const Comment({
    required this.id,
    this.postId = '',
    this.parentCommentId = '',
    this.rootCommentId = '',
    this.depth = 0,
    required this.userId,
    required this.displayName,
    required this.avatarUrl,
    this.replyToUserId = '',
    this.replyToDisplayName = '',
    required this.content,
    required this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>? ??
        json['user'] as Map<String, dynamic>? ??
        const {};
    final username = _commentString(author['username']);
    final displayName = _commentString(json['displayName']).isNotEmpty
        ? _commentString(json['displayName'])
        : (_commentString(author['displayName']).isNotEmpty
            ? _commentString(author['displayName'])
            : username);
    final replyToAuthor = json['replyToAuthor'] as Map<String, dynamic>? ??
        json['replyToUser'] as Map<String, dynamic>? ??
        json['replyTo'] as Map<String, dynamic>? ??
        const {};
    final replyToUsername = _commentString(replyToAuthor['username']);
    final replyToDisplayName =
        _commentString(json['replyToDisplayName']).isNotEmpty
            ? _commentString(json['replyToDisplayName'])
            : (_commentString(replyToAuthor['displayName']).isNotEmpty
                ? _commentString(replyToAuthor['displayName'])
                : replyToUsername);
    return Comment(
      id: _commentString(json['id']),
      postId: _commentString(json['postId']).isNotEmpty
          ? _commentString(json['postId'])
          : _commentString(json['postID']),
      parentCommentId: _commentString(json['parentCommentId']).isNotEmpty
          ? _commentString(json['parentCommentId'])
          : (_commentString(json['parentCommentID']).isNotEmpty
              ? _commentString(json['parentCommentID'])
              : _commentString(json['parentId'])),
      rootCommentId: _commentString(json['rootCommentId']).isNotEmpty
          ? _commentString(json['rootCommentId'])
          : _commentString(json['rootCommentID']),
      depth: _commentInt(json['depth']),
      userId: _commentString(json['userId']).isNotEmpty
          ? _commentString(json['userId'])
          : (_commentString(json['authorID']).isNotEmpty
              ? _commentString(json['authorID'])
              : _commentString(author['id'])),
      displayName: displayName.isNotEmpty ? displayName : username,
      avatarUrl: _commentString(json['avatarUrl']).isNotEmpty
          ? _commentString(json['avatarUrl'])
          : (_commentString(json['avatarURL']).isNotEmpty
              ? _commentString(json['avatarURL'])
              : (_commentString(author['avatarUrl']).isNotEmpty
                  ? _commentString(author['avatarUrl'])
                  : _commentString(author['avatarURL']))),
      replyToUserId: _commentString(json['replyToUserId']).isNotEmpty
          ? _commentString(json['replyToUserId'])
          : (_commentString(json['replyToUserID']).isNotEmpty
              ? _commentString(json['replyToUserID'])
              : _commentString(replyToAuthor['id'])),
      replyToDisplayName: replyToDisplayName,
      content: _commentString(json['content']),
      createdAt: _commentString(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (postId.isNotEmpty) 'postId': postId,
        if (parentCommentId.isNotEmpty) 'parentCommentId': parentCommentId,
        if (rootCommentId.isNotEmpty) 'rootCommentId': rootCommentId,
        'depth': depth,
        'userId': userId,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        if (replyToUserId.isNotEmpty) 'replyToUserId': replyToUserId,
        if (replyToDisplayName.isNotEmpty)
          'replyToDisplayName': replyToDisplayName,
        'content': content,
        'createdAt': createdAt,
      };

  Comment copyWith({
    String? id,
    String? postId,
    String? parentCommentId,
    String? rootCommentId,
    int? depth,
    String? userId,
    String? displayName,
    String? avatarUrl,
    String? replyToUserId,
    String? replyToDisplayName,
    String? content,
    String? createdAt,
  }) =>
      Comment(
        id: id ?? this.id,
        postId: postId ?? this.postId,
        parentCommentId: parentCommentId ?? this.parentCommentId,
        rootCommentId: rootCommentId ?? this.rootCommentId,
        depth: depth ?? this.depth,
        userId: userId ?? this.userId,
        displayName: displayName ?? this.displayName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        replyToUserId: replyToUserId ?? this.replyToUserId,
        replyToDisplayName: replyToDisplayName ?? this.replyToDisplayName,
        content: content ?? this.content,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Comment && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Comment(id: $id, displayName: $displayName)';
}

class FeedPage {
  final List<Post> posts;
  final String? nextCursor;

  const FeedPage({required this.posts, this.nextCursor});

  factory FeedPage.fromJson(Map<String, dynamic> json) => FeedPage(
        posts: (json['posts'] as List<dynamic>)
            .map((e) => Post.fromJson(e as Map<String, dynamic>))
            .toList(),
        nextCursor: json['nextCursor'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'posts': posts.map((e) => e.toJson()).toList(),
        if (nextCursor != null) 'nextCursor': nextCursor,
      };

  FeedPage copyWith({List<Post>? posts, String? nextCursor}) => FeedPage(
        posts: posts ?? this.posts,
        nextCursor: nextCursor ?? this.nextCursor,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FeedPage && other.nextCursor == nextCursor;
  }

  @override
  int get hashCode => nextCursor.hashCode;

  @override
  String toString() =>
      'FeedPage(posts: ${posts.length} items, nextCursor: $nextCursor)';
}

String _commentString(Object? value) => value?.toString() ?? '';

int _commentInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

List<String> _postStringList(Object? value) {
  if (value is! List<dynamic>) return const [];
  return value
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList();
}

bool _isPostVideoUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  final path = (uri?.path ?? value).toLowerCase();
  return path.endsWith('.mp4') ||
      path.endsWith('.mov') ||
      path.endsWith('.m4v') ||
      path.endsWith('.webm') ||
      path.endsWith('.avi') ||
      path.endsWith('.m3u8');
}
