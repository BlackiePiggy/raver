import 'package:dio/dio.dart';
import 'package:feature_circle/feature_circle.dart';
import 'package:feature_discover/feature_discover.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raver_network/raver_network.dart';

const _runLiveSmoke = bool.fromEnvironment('RAVEHUB_RUN_LIVE_SMOKE');

void main() {
  group(
    'public live endpoint smoke',
    skip: _runLiveSmoke
        ? false
        : 'Set --dart-define=RAVEHUB_RUN_LIVE_SMOKE=true to hit live BFF.',
    () {
      late Dio dio;

      setUp(() {
        dio = Dio(
          BaseOptions(
            baseUrl: 'https://api.ravehub.top',
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
            headers: const {'Content-Type': 'application/json'},
          ),
        )..interceptors.addAll([
            LanguageInterceptor(languageProvider: () => 'en'),
            BffEnvelopeInterceptor(),
          ]);
      });

      test('Discover public APIs parse live responses', () async {
        final eventsApi = EventsApiService(dio);
        final djsApi = DjApi(dio);
        final setApi = SetApi(dio);
        final newsApi = NewsApi(dio);
        final genreApi = GenreApi(dio);
        final labelApi = LabelApi(dio);
        final organizerApi = OrganizerApi(dio);
        final rankingApi = RankingApi(dio);

        final events = await _smokeStep(
          'GET /v1/events',
          () => eventsApi.fetchEvents(page: 1, limit: 5),
        );
        expect(events.items, isA<List>());
        if (events.items.isNotEmpty) {
          final event = await _smokeStep(
            'GET /v1/events/:id',
            () => eventsApi.fetchEvent(id: events.items.first.id),
          );
          expect(event.id, isNotEmpty);
        }

        final recommendedEvents = await _smokeStep(
          'GET /v1/events/recommendations',
          () => eventsApi.fetchRecommendedEvents(limit: 5),
        );
        expect(recommendedEvents, isA<List>());

        final djs = await _smokeStep(
          'GET /v1/djs',
          () => djsApi.fetchDJs(page: 1, limit: 5),
        );
        expect(djs.items, isA<List>());
        if (djs.items.isNotEmpty) {
          final dj = await _smokeStep(
            'GET /v1/djs/:id',
            () => djsApi.fetchDJ(djs.items.first.id),
          );
          expect(dj.id, isNotEmpty);
        }

        final spotlightDjs = await _smokeStep(
          'GET /v1/djs/recommendations',
          () => djsApi.fetchSpotlightDJs(limit: 5),
        );
        expect(spotlightDjs, isA<List>());

        final sets = await _smokeStep(
          'GET /v1/dj-sets',
          () => setApi.fetchSets(page: 1, limit: 5),
        );
        expect(sets.items, isA<List>());
        if (sets.items.isNotEmpty) {
          final djSet = await _smokeStep(
            'GET /v1/dj-sets/:id',
            () => setApi.fetchSet(sets.items.first.id),
          );
          expect(djSet.id, isNotEmpty);
        }

        final news = await _smokeStep(
          'GET /v1/news',
          () => newsApi.fetchNewsPage(),
        );
        expect(news.articles, isA<List>());
        if (news.articles.isNotEmpty) {
          final article = await _smokeStep(
            'GET /v1/news/:id',
            () => newsApi.fetchArticle(news.articles.first.id),
          );
          expect(article.id, isNotEmpty);
        }

        final genres = await _smokeStep(
          'GET /v1/learn/genres',
          () => genreApi.fetchSunburstTree(),
        );
        expect(genres, isA<List>());
        if (genres.isNotEmpty) {
          final genre = await _smokeStep(
            'GET /v1/learn/genres/:id',
            () => genreApi.fetchGenreDetail(genres.first.id),
          );
          expect(genre.id, isNotEmpty);
        }

        final labels = await _smokeStep(
          'GET /v1/learn/labels',
          () => labelApi.fetchLabels(),
        );
        expect(labels, isA<List>());
        if (labels.isNotEmpty) {
          final label = await _smokeStep(
            'GET /v1/learn/labels/:id',
            () => labelApi.fetchLabelDetail(labels.first.id),
          );
          expect(label.id, isNotEmpty);
        }

        final festivals = await _smokeStep(
          'GET /v1/learn/festivals',
          () => organizerApi.fetchFestivals(),
        );
        expect(festivals, isA<List>());
        if (festivals.isNotEmpty) {
          final festival = await _smokeStep(
            'GET /v1/learn/festivals/:id',
            () => organizerApi.fetchFestivalDetail(festivals.first.id),
          );
          expect(festival.id, isNotEmpty);
        }

        final rankings = await _smokeStep(
          'GET /v1/learn/rankings',
          () => rankingApi.fetchRankings(),
        );
        expect(rankings, isA<List>());
        if (rankings.isNotEmpty) {
          final ranking = await _smokeStep(
            'GET /v1/learn/rankings/:id',
            () => rankingApi.fetchRankingDetail(rankings.first.id),
          );
          expect(ranking.id, isNotEmpty);
        }
      }, timeout: const Timeout(Duration(minutes: 2)));

      test('Circle public APIs parse live responses', () async {
        final feedApi = FeedApi(dio);
        final circleIdApi = CircleIdApi(dio);
        final ratingApi = RatingApi(dio);

        final feed = await _smokeStep(
          'GET /v1/feed',
          () => feedApi.fetchFeed(limit: 5, mode: 'latest'),
        );
        expect(feed.posts, isA<List>());
        if (feed.posts.isNotEmpty) {
          final post = await _smokeStep(
            'GET /v1/feed/posts/:id',
            () => feedApi.fetchPost(id: feed.posts.first.id),
          );
          expect(post.id, isNotEmpty);
        }

        final circleIds = await _smokeStep(
          'GET /v1/feed mode latest for Circle ID',
          circleIdApi.fetchMyCircleIds,
        );
        expect(circleIds, isA<List>());
        if (circleIds.isNotEmpty) {
          final circleId = await _smokeStep(
            'GET /v1/feed/posts/:id for Circle ID',
            () => circleIdApi.fetchCircleId(id: circleIds.first.id),
          );
          expect(circleId.id, isNotEmpty);
        }

        final eventMatches = await _smokeStep(
          'GET /v1/events for Circle ID picker',
          () => circleIdApi.searchEvents(limit: 5),
        );
        expect(eventMatches, isA<List>());

        final djMatches = await _smokeStep(
          'GET /v1/djs for Circle ID picker',
          () => circleIdApi.searchDjs(limit: 5),
        );
        expect(djMatches, isA<List>());

        final ratings = await _smokeStep(
          'GET /v1/rating-events',
          () => ratingApi.fetchRatings(page: 1, limit: 5),
        );
        expect(ratings.items, isA<List>());
        if (ratings.items.isNotEmpty) {
          final rating = await _smokeStep(
            'GET /v1/rating-events/:id',
            () => ratingApi.fetchRatingEvent(id: ratings.items.first.id),
          );
          expect(rating.id, isNotEmpty);
        }
      }, timeout: const Timeout(Duration(minutes: 2)));
    },
  );
}

Future<T> _smokeStep<T>(String name, Future<T> Function() run) async {
  try {
    return await run();
  } catch (error, stackTrace) {
    Error.throwWithStackTrace(
      TestFailure('Live smoke step failed: $name\n$error'),
      stackTrace,
    );
  }
}
