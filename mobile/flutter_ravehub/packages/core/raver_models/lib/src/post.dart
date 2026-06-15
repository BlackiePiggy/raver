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

  factory Post.fromJson(Map<String, dynamic> json) => Post(
        id: json['id'] as String,
        content: json['content'] as String,
        images: (json['images'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList(),
        videos: (json['videos'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList(),
        user: UserSummary.fromJson(json['user'] as Map<String, dynamic>),
        likeCount: json['likeCount'] as int,
        commentCount: json['commentCount'] as int,
        repostCount: json['repostCount'] as int,
        saveCount: json['saveCount'] as int,
        shareCount: json['shareCount'] as int,
        isLiked: json['isLiked'] as bool?,
        isReposted: json['isReposted'] as bool?,
        isSaved: json['isSaved'] as bool?,
        eventId: json['eventId'] as String?,
        eventName: json['eventName'] as String?,
        squad: json['squad'] != null
            ? PostSquad.fromJson(json['squad'] as Map<String, dynamic>)
            : null,
        createdAt: json['createdAt'] as String,
      );

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
  final String userId;
  final String displayName;
  final String avatarUrl;
  final String content;
  final String createdAt;

  const Comment({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.avatarUrl,
    required this.content,
    required this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
        id: json['id'] as String,
        userId: json['userId'] as String,
        displayName: json['displayName'] as String,
        avatarUrl: json['avatarUrl'] as String,
        content: json['content'] as String,
        createdAt: json['createdAt'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'content': content,
        'createdAt': createdAt,
      };

  Comment copyWith({
    String? id,
    String? userId,
    String? displayName,
    String? avatarUrl,
    String? content,
    String? createdAt,
  }) =>
      Comment(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        displayName: displayName ?? this.displayName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
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

  const FeedPage({
    required this.posts,
    this.nextCursor,
  });

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
