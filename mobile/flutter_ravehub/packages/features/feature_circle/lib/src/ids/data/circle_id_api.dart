import 'package:dio/dio.dart';
import 'package:raver_models/raver_models.dart';

class CircleIdLinkedEvent {
  const CircleIdLinkedEvent({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.coverImageUrl,
  });

  final String id;
  final String name;
  final String startDate;
  final String endDate;
  final String coverImageUrl;

  factory CircleIdLinkedEvent.fromWebEvent(WebEvent event) {
    return CircleIdLinkedEvent(
      id: event.id,
      name: event.name,
      startDate: event.startDate,
      endDate: event.endDate,
      coverImageUrl: event.coverImageUrl,
    );
  }
}

class CircleIdLinkedDj {
  const CircleIdLinkedDj({
    required this.id,
    required this.name,
    required this.avatarUrl,
  });

  final String id;
  final String name;
  final String avatarUrl;

  factory CircleIdLinkedDj.fromWebDj(WebDJ dj) {
    return CircleIdLinkedDj(id: dj.id, name: dj.name, avatarUrl: dj.avatarUrl);
  }
}

class CircleIdCreationDraft {
  const CircleIdCreationDraft({
    required this.songName,
    required this.audioUrl,
    required this.videoUrl,
    required this.event,
    required this.djs,
    required this.rightsConfirmed,
  });

  final String songName;
  final String audioUrl;
  final String videoUrl;
  final WebEvent event;
  final List<WebDJ> djs;
  final bool rightsConfirmed;
}

/// Local data model for iOS-compatible Circle ID entries.
class CircleIdCard {
  const CircleIdCard({
    required this.id,
    required this.songName,
    required this.artistNames,
    required this.event,
    required this.djs,
    required this.audioUrl,
    required this.videoUrl,
    required this.contributorId,
    required this.contributorName,
    required this.contributorAvatarUrl,
    required this.likeCount,
    required this.favoriteCount,
    required this.repostCount,
    required this.commentCount,
    required this.isLiked,
    required this.isFavorited,
    required this.isReposted,
    required this.createdAt,
  });

  final String id;
  final String songName;
  final List<String> artistNames;
  final CircleIdLinkedEvent? event;
  final List<CircleIdLinkedDj> djs;
  final String audioUrl;
  final String videoUrl;
  final String contributorId;
  final String contributorName;
  final String contributorAvatarUrl;
  final int likeCount;
  final int favoriteCount;
  final int repostCount;
  final int commentCount;
  final bool isLiked;
  final bool isFavorited;
  final bool isReposted;
  final String createdAt;

  String get nickname => songName;
  String get tagline {
    final parts = [
      if (artistNames.isNotEmpty) artistNames.join(', '),
      if (event != null) event!.name,
      if (contributorName.isNotEmpty) contributorName,
    ];
    return parts.join(' · ');
  }

  String get edmtiType => videoUrl.isNotEmpty
      ? 'VIDEO'
      : audioUrl.isNotEmpty
          ? 'AUDIO'
          : 'ID';
  String get avatarUrl => event?.coverImageUrl ?? contributorAvatarUrl;
  int get gradientIndex => _stableGradientIndexStatic(id);
  int get checkinCount => djs.length;
  int get followerCount => likeCount;
  int get contributionScore => favoriteCount + repostCount;

  factory CircleIdCard.fromJson(Map<String, dynamic> json) {
    final djs = _list(json['djs'] ?? json['djSnapshots']).map((item) {
      final object = item is Map<String, dynamic> ? item : <String, dynamic>{};
      return CircleIdLinkedDj(
        id: _stringStatic(object['id']),
        name: _stringStatic(object['name']),
        avatarUrl: _stringStatic(object['avatarUrl'] ?? object['avatarURL']),
      );
    }).toList();
    final eventObject = json['event'] is Map<String, dynamic>
        ? json['event'] as Map<String, dynamic>
        : null;
    return CircleIdCard(
      id: _stringStatic(json['id']),
      songName: _stringStatic(json['songName'] ?? json['nickname']),
      artistNames: _list(
        json['artistNames'],
      ).map(_stringStatic).where((value) => value.isNotEmpty).toList(),
      event: eventObject == null
          ? null
          : CircleIdLinkedEvent(
              id: _stringStatic(eventObject['id']),
              name: _stringStatic(eventObject['name']),
              startDate: _stringStatic(eventObject['startDate']),
              endDate: _stringStatic(eventObject['endDate']),
              coverImageUrl: _stringStatic(eventObject['coverImageUrl']),
            ),
      djs: djs,
      audioUrl: _stringStatic(json['audioUrl']),
      videoUrl: _stringStatic(json['videoUrl']),
      contributorId: _stringStatic(json['contributorId']),
      contributorName: _stringStatic(json['contributorName']),
      contributorAvatarUrl: _stringStatic(json['contributorAvatarUrl']),
      likeCount: _intStatic(json['likeCount'] ?? json['followerCount']),
      favoriteCount: _intStatic(json['favoriteCount']),
      repostCount: _intStatic(json['repostCount']),
      commentCount: _intStatic(json['commentCount']),
      isLiked: json['isLiked'] as bool? ?? false,
      isFavorited:
          json['isFavorited'] as bool? ?? json['isSaved'] as bool? ?? false,
      isReposted: json['isReposted'] as bool? ?? false,
      createdAt: _stringStatic(json['createdAt']),
    );
  }

  CircleIdCard copyWith({
    int? likeCount,
    int? favoriteCount,
    int? repostCount,
    int? commentCount,
    bool? isLiked,
    bool? isFavorited,
    bool? isReposted,
  }) {
    return CircleIdCard(
      id: id,
      songName: songName,
      artistNames: artistNames,
      event: event,
      djs: djs,
      audioUrl: audioUrl,
      videoUrl: videoUrl,
      contributorId: contributorId,
      contributorName: contributorName,
      contributorAvatarUrl: contributorAvatarUrl,
      likeCount: likeCount ?? this.likeCount,
      favoriteCount: favoriteCount ?? this.favoriteCount,
      repostCount: repostCount ?? this.repostCount,
      commentCount: commentCount ?? this.commentCount,
      isLiked: isLiked ?? this.isLiked,
      isFavorited: isFavorited ?? this.isFavorited,
      isReposted: isReposted ?? this.isReposted,
      createdAt: createdAt,
    );
  }

  CircleIdCard withPostInteraction(Post post) {
    return copyWith(
      likeCount: post.likeCount,
      favoriteCount: post.saveCount,
      repostCount: post.repostCount,
      commentCount: post.commentCount,
      isLiked: post.isLiked ?? isLiked,
      isFavorited: post.isSaved ?? isFavorited,
      isReposted: post.isReposted ?? isReposted,
    );
  }
}

class CircleIdApi {
  CircleIdApi(this._dio);

  final Dio _dio;

  Future<List<CircleIdCard>> fetchMyCircleIds() async {
    final response = await _dio.get<dynamic>(
      '/v1/feed',
      queryParameters: {'limit': 100, 'mode': 'latest'},
    );
    final items = LiveApiPayload.items(
      response.data,
      itemKeys: const ['posts', 'items', 'list', 'data'],
    );
    return items
        .whereType<Map<String, dynamic>>()
        .map(_cardFromApprovedPost)
        .whereType<CircleIdCard>()
        .toList();
  }

  Future<List<WebEvent>> searchEvents({String? search, int limit = 50}) async {
    final response = await _dio.get<dynamic>(
      '/v1/events',
      queryParameters: {
        'page': 1,
        'limit': limit,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    return LiveApiPayload.items(
      response.data,
    ).whereType<Map<String, dynamic>>().map(WebEvent.fromJson).toList();
  }

  Future<List<WebDJ>> searchDjs({String? search, int limit = 50}) async {
    final response = await _dio.get<dynamic>(
      '/v1/djs',
      queryParameters: {
        'page': 1,
        'limit': limit,
        'sortBy': 'random',
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    return LiveApiPayload.items(
      response.data,
    ).whereType<Map<String, dynamic>>().map(WebDJ.fromJson).toList();
  }

  Future<CircleIdCard> createCircleId(CircleIdCreationDraft draft) async {
    final djs = draft.djs.map(CircleIdLinkedDj.fromWebDj).toList();
    final event = CircleIdLinkedEvent.fromWebEvent(draft.event);
    final audioUrl = draft.audioUrl.trim();
    final videoUrl = draft.videoUrl.trim();
    final content = _circleIdContent(
      songName: draft.songName,
      artistNames: djs.map((dj) => dj.name).toList(),
      eventName: event.name,
      audioUrl: audioUrl,
      videoUrl: videoUrl,
    );
    final response = await _dio.post<dynamic>(
      '/api/content-submissions',
      data: {
        'entityType': 'id',
        'payload': {
          'title': draft.songName,
          'songName': draft.songName,
          'audioUrl': audioUrl.isEmpty ? null : audioUrl,
          'videoUrl': videoUrl.isEmpty ? null : videoUrl,
          'images': [
            if (videoUrl.isNotEmpty) videoUrl,
            if (event.coverImageUrl.isNotEmpty) event.coverImageUrl,
          ],
          'eventId': event.id,
          'eventName': event.name,
          'boundEventIDs': [event.id],
          'djIds': djs.map((dj) => dj.id).toList(),
          'boundDjIDs': djs.map((dj) => dj.id).toList(),
          'djNames': djs.map((dj) => dj.name).toList(),
          'rightsConfirmed': draft.rightsConfirmed,
          'content': content,
        },
      },
    );
    final data = LiveApiPayload.object(response.data);
    final submission = data['submission'] is Map<String, dynamic>
        ? data['submission'] as Map<String, dynamic>
        : data;
    return CircleIdCard(
      id: _string(submission['id'], fallback: DateTime.now().toIso8601String()),
      songName: draft.songName,
      artistNames: djs.map((dj) => dj.name).toList(),
      event: event,
      djs: djs,
      audioUrl: audioUrl,
      videoUrl: videoUrl,
      contributorId: '',
      contributorName: '',
      contributorAvatarUrl: '',
      likeCount: 0,
      favoriteCount: 0,
      repostCount: 0,
      commentCount: 0,
      isLiked: false,
      isFavorited: false,
      isReposted: false,
      createdAt: _string(submission['createdAt']),
    );
  }

  Future<CircleIdCard> fetchCircleId({required String id}) async {
    final response = await _dio.get<dynamic>('/v1/feed/posts/$id');
    final card = _cardFromApprovedPost(LiveApiPayload.object(response.data));
    if (card == null) {
      throw StateError('Circle ID post is missing #RAVER_ID metadata.');
    }
    return card;
  }

  Future<CircleIdCard> updateCircleId({
    required String id,
    String? nickname,
    String? tagline,
    int? gradientIndex,
  }) async {
    throw UnsupportedError(
      'Circle ID entries are reviewed content submissions and cannot be edited '
      'through the legacy identity-card endpoint.',
    );
  }

  CircleIdCard? _cardFromApprovedPost(Map<String, dynamic> post) {
    final content = _string(post['content'] ?? post['text']);
    if (!content
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .contains('#RAVER_ID')) {
      return null;
    }

    final fields = _fieldsFromContent(content);
    final songName = _firstNonBlank([
      fields['标题'],
      fields['Title'],
      fields['title'],
      post['title'],
    ]);
    if (songName == null) return null;

    final artistNames = _commaSeparatedValues(
      _firstNonBlank([fields['艺人'], fields['Artist'], fields['artist']]),
    );
    final eventName = _firstNonBlank([
      fields['活动'],
      fields['Event'],
      fields['event'],
      post['eventName'],
    ]);
    final audioUrl = _firstNonBlank([
      fields['音频'],
      fields['Audio'],
      fields['audioUrl'],
    ]);
    final videoUrl = _firstNonBlank([
      fields['视频'],
      fields['Video'],
      fields['videoUrl'],
    ]);
    final author = post['author'] is Map<String, dynamic>
        ? post['author'] as Map<String, dynamic>
        : post['user'] is Map<String, dynamic>
            ? post['user'] as Map<String, dynamic>
            : const <String, dynamic>{};
    final djs = _djsFromPost(post, artistNames);
    final event = eventName == null
        ? null
        : CircleIdLinkedEvent(
            id: _firstNonBlank([
                  post['eventId'],
                  post['eventID'],
                  post['boundEventId'],
                ]) ??
                '',
            name: eventName,
            startDate: _string(post['eventStartDate']),
            endDate: _string(post['eventEndDate']),
            coverImageUrl: _string(post['eventCoverImageUrl']),
          );
    final images = post['images'] is List<dynamic>
        ? post['images'] as List<dynamic>
        : const <dynamic>[];
    final contributor = _firstNonBlank([
      author['displayName'],
      author['username'],
    ]);

    return CircleIdCard(
      id: _string(post['id']),
      songName: songName,
      artistNames: artistNames,
      event: event?.coverImageUrl.isNotEmpty == true
          ? event
          : event == null
              ? null
              : CircleIdLinkedEvent(
                  id: event.id,
                  name: event.name,
                  startDate: event.startDate,
                  endDate: event.endDate,
                  coverImageUrl:
                      _string(images.isNotEmpty ? images.first : null),
                ),
      djs: djs,
      audioUrl: audioUrl ?? '',
      videoUrl: videoUrl ?? '',
      contributorId: _string(author['id']),
      contributorName: contributor ?? '',
      contributorAvatarUrl: _string(author['avatarUrl'] ?? author['avatarURL']),
      likeCount: _int(post['likeCount']),
      favoriteCount: _int(post['saveCount']),
      repostCount: _int(post['repostCount']),
      commentCount: _int(post['commentCount']),
      isLiked: post['isLiked'] as bool? ?? false,
      isFavorited: post['isSaved'] as bool? ?? false,
      isReposted: post['isReposted'] as bool? ?? false,
      createdAt: _string(
        post['displayPublishedAt'] ?? post['publishedAt'] ?? post['createdAt'],
      ),
    );
  }

  String _circleIdContent({
    required String songName,
    required List<String> artistNames,
    required String eventName,
    required String audioUrl,
    required String videoUrl,
  }) {
    return [
      '#RAVER_ID',
      '标题: $songName',
      if (artistNames.isNotEmpty) '艺人: ${artistNames.join(', ')}',
      if (eventName.isNotEmpty) '活动: $eventName',
      if (audioUrl.isNotEmpty) '音频: $audioUrl',
      if (videoUrl.isNotEmpty) '视频: $videoUrl',
    ].join('\n');
  }

  List<CircleIdLinkedDj> _djsFromPost(
    Map<String, dynamic> post,
    List<String> fallbackNames,
  ) {
    final rawDjs = _list(post['djs'] ?? post['djSnapshots']);
    final parsed = rawDjs
        .whereType<Map<String, dynamic>>()
        .map((dj) {
          return CircleIdLinkedDj(
            id: _string(dj['id']),
            name: _string(dj['name']),
            avatarUrl: _string(dj['avatarUrl'] ?? dj['avatarURL']),
          );
        })
        .where((dj) => dj.name.isNotEmpty)
        .toList();
    if (parsed.isNotEmpty) return parsed;

    final ids = _list(
      post['djIds'] ?? post['boundDjIDs'],
    ).map(_string).toList();
    return fallbackNames.asMap().entries.map((entry) {
      return CircleIdLinkedDj(
        id: entry.key < ids.length ? ids[entry.key] : '',
        name: entry.value,
        avatarUrl: '',
      );
    }).toList();
  }

  Map<String, String> _fieldsFromContent(String content) {
    final result = <String, String>{};
    for (final rawLine in content.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      final separator = line.indexOf(RegExp('[:：]'));
      if (separator <= 0) continue;
      final key = line.substring(0, separator).trim();
      final value = line.substring(separator + 1).trim();
      if (key.isNotEmpty && value.isNotEmpty) {
        result[key] = value;
      }
    }
    return result;
  }

  List<String> _commaSeparatedValues(String? value) {
    if (value == null) return const [];
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  String? _firstNonBlank(List<Object?> values) {
    for (final value in values) {
      final text = _string(value).trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  String _string(Object? value, {String fallback = ''}) {
    if (value == null) return fallback;
    if (value is String) return value;
    return value.toString();
  }

  int _int(Object? value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}

List<dynamic> _list(Object? value) {
  return value is List<dynamic> ? value : const [];
}

String _stringStatic(Object? value, {String fallback = ''}) {
  if (value == null) return fallback;
  if (value is String) return value;
  return value.toString();
}

int _intStatic(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

int _stableGradientIndexStatic(Object? value) {
  final text = _stringStatic(value);
  if (text.isEmpty) return 0;
  return text.codeUnits.fold<int>(0, (sum, unit) => sum + unit) % 6;
}
