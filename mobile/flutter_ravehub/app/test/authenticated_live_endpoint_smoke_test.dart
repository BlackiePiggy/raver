import 'package:dio/dio.dart';
import 'package:feature_circle/feature_circle.dart';
import 'package:feature_discover/feature_discover.dart';
import 'package:feature_inbox/feature_inbox.dart';
import 'package:feature_profile/feature_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raver_network/raver_network.dart';

const _accessToken = String.fromEnvironment('RAVEHUB_TEST_ACCESS_TOKEN');
const _baseUrl = String.fromEnvironment(
  'RAVEHUB_TEST_BASE_URL',
  defaultValue: 'https://api.ravehub.top',
);

void main() {
  group(
    'authenticated live endpoint smoke',
    skip: _accessToken.isNotEmpty
        ? false
        : 'Set --dart-define=RAVEHUB_TEST_ACCESS_TOKEN=<token> to hit '
            'protected live BFF endpoints.',
    () {
      late Dio dio;

      setUp(() {
        dio = Dio(
          BaseOptions(
            baseUrl: _baseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
            headers: const {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_accessToken',
            },
          ),
        )..interceptors.addAll([
            LanguageInterceptor(languageProvider: () => 'en'),
            BffEnvelopeInterceptor(),
          ]);
      });

      test('Profile APIs parse protected live responses', () async {
        final api = ProfileApi(dio);

        final me = await _authSmokeStep(
          'GET /v1/users/me',
          api.fetchMe,
        );
        expect(me.id, isNotEmpty);

        final posts = await _authSmokeStep(
          'GET /v1/users/me/posts',
          () => api.fetchMyPosts(page: 1, limit: 5),
        );
        expect(posts.items, isA<List>());

        final saves = await _authSmokeStep(
          'GET /v1/users/me/saves',
          () => api.fetchMySaves(page: 1, limit: 5),
        );
        expect(saves.items, isA<List>());

        final contributions = await _authSmokeStep(
          'GET /v1/users/me/contributions',
          api.fetchContributions,
        );
        expect(contributions, isA<Map<String, dynamic>>());

        final devices = await _authSmokeStep(
          'GET /v1/users/me/devices',
          api.fetchDevices,
        );
        expect(devices, isA<List>());
      }, timeout: const Timeout(Duration(minutes: 2)));

      test('Checkin APIs parse protected live responses', () async {
        final api = CheckinApi(dio);

        final checkins = await _authSmokeStep(
          'GET /v1/checkins',
          () => api.fetchCheckins(page: 1, limit: 5),
        );
        expect(checkins.items, isA<List>());

        final overview = await _authSmokeStep(
          'GET /v2/me/checkins/overview',
          api.fetchOverview,
        );
        expect(overview.stats.totalCheckins, greaterThanOrEqualTo(0));
      }, timeout: const Timeout(Duration(minutes: 2)));

      test('Profile auxiliary APIs parse protected live responses', () async {
        final profileApi = ProfileApi(dio);
        final publishesApi = PublishesApi(dio);
        final followApi = FollowApi(dio);
        final virtualAssetApi = VirtualAssetApi(dio);

        final me = await _authSmokeStep(
          'GET /v1/users/me for auxiliary profile APIs',
          profileApi.fetchMe,
        );
        expect(me.id, isNotEmpty);

        final submissions = await _authSmokeStep(
          'GET /api/content-submissions/mine',
          () => publishesApi.fetchSubmissions(page: 1, limit: 5),
        );
        expect(submissions.items, isA<List>());
        if (submissions.items.isNotEmpty) {
          final submission = await _authSmokeStep(
            'GET /api/content-submissions/mine/:id',
            () => publishesApi.fetchSubmissionDetail(
              id: submissions.items.first.id,
            ),
          );
          expect(submission.id, isNotEmpty);
        }

        final following = await _authSmokeStep(
          'GET /v1/users/:id/following',
          () => followApi.fetchFollowing(userId: me.id, page: 1, limit: 5),
        );
        expect(following.items, isA<List>());

        final followers = await _authSmokeStep(
          'GET /v1/users/:id/followers',
          () => followApi.fetchFollowers(userId: me.id, page: 1, limit: 5),
        );
        expect(followers.items, isA<List>());

        final friends = await _authSmokeStep(
          'GET /v1/users/:id/friends',
          () => followApi.fetchFriends(userId: me.id, page: 1, limit: 5),
        );
        expect(friends.items, isA<List>());

        final assetCatalog = await _authSmokeStep(
          'GET /v1/virtual-assets',
          virtualAssetApi.fetchAll,
        );
        expect(assetCatalog, isA<List>());

        final myAssets = await _authSmokeStep(
          'GET /v1/virtual-assets/mine',
          virtualAssetApi.fetchMine,
        );
        expect(myAssets, isA<List>());
      }, timeout: const Timeout(Duration(minutes: 2)));

      test('Quiz and Personality APIs can start protected live sessions',
          () async {
        final quizApi = QuizApi(dio);
        final personalityApi = PersonalityApi(dio);

        final quizQuestions = await _authSmokeStep(
          'POST /v1/quiz/sessions',
          quizApi.fetchQuestions,
        );
        expect(quizQuestions, isA<List>());

        final personalityQuestions = await _authSmokeStep(
          'POST /v1/personality/sessions',
          personalityApi.fetchQuestions,
        );
        expect(personalityQuestions, isA<List>());
      }, timeout: const Timeout(Duration(minutes: 2)));

      test('Squad APIs parse protected live responses', () async {
        final api = SquadApi(dio);

        final mySquads = await _authSmokeStep(
          'GET /v1/squads/mine',
          () => api.fetchMySquads(page: 1, limit: 5),
        );
        expect(mySquads.items, isA<List>());

        final recommended = await _authSmokeStep(
          'GET /v1/squads/recommended',
          api.fetchRecommendedSquads,
        );
        expect(recommended, isA<List>());

        if (mySquads.items.isNotEmpty) {
          final squad = await _authSmokeStep(
            'GET /v1/squads/:id/profile',
            () => api.fetchSquad(id: mySquads.items.first.id),
          );
          expect(squad.id, isNotEmpty);
        }
      }, timeout: const Timeout(Duration(minutes: 2)));

      test('Global Search API parses protected live responses', () async {
        final api = SearchApiService(dio);

        final result = await _authSmokeStep(
          'GET /v1/search',
          () => api.searchGlobal(
            query: 'rave',
            tab: 'all',
            limit: 5,
            locale: 'en',
          ),
        );
        expect(result.items, isA<List>());
      }, timeout: const Timeout(Duration(minutes: 2)));

      test('Inbox APIs parse protected live responses', () async {
        final api = NotificationApiService(dio);

        final inbox = await _authSmokeStep(
          'GET /v1/notification-center/inbox',
          () => api.fetchInbox(page: 1, limit: 5),
        );
        expect(inbox.items, isA<List>());

        final followedEvents = await _authSmokeStep(
          'GET /v1/notification-center/followed-events/items',
          () => api.fetchFollowedEvents(page: 1, limit: 5),
        );
        expect(followedEvents.items, isA<List>());

        final followedDjs = await _authSmokeStep(
          'GET /v1/notification-center/followed-djs/items',
          () => api.fetchFollowedDJs(page: 1, limit: 5),
        );
        expect(followedDjs.items, isA<List>());

        final followedBrands = await _authSmokeStep(
          'GET /v1/notification-center/followed-brands/items',
          () => api.fetchFollowedBrands(page: 1, limit: 5),
        );
        expect(followedBrands.items, isA<List>());

        final contentReviews = await _authSmokeStep(
          'GET /v1/notification-center/content-reviews/items',
          () => api.fetchContentReviews(page: 1, limit: 5),
        );
        expect(contentReviews.items, isA<List>());

        final unreadCount = await _authSmokeStep(
          'GET /v1/notification-center/unread-count',
          api.fetchUnreadCount,
        );
        final totalUnread = unreadCount.community +
            unreadCount.followedEvents +
            unreadCount.followedDJs +
            unreadCount.followedBrands;
        expect(totalUnread, greaterThanOrEqualTo(0));
      }, timeout: const Timeout(Duration(minutes: 2)));
    },
  );
}

Future<T> _authSmokeStep<T>(String name, Future<T> Function() run) async {
  try {
    return await run();
  } catch (error, stackTrace) {
    Error.throwWithStackTrace(
      TestFailure(
        'Authenticated live smoke step failed: $name\n'
        '${_redactToken(error.toString())}',
      ),
      stackTrace,
    );
  }
}

String _redactToken(String message) {
  if (_accessToken.isEmpty) return message;
  return message.replaceAll(_accessToken, '<redacted>');
}
