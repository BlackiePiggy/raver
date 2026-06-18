import 'package:dio/dio.dart';

import 'discover_dio.dart';
import '../events/data/events_api_service.dart';
import '../events/data/events_repository.dart';
import '../djs/data/dj_api.dart';
import '../sets/data/set_api.dart';
import '../news/data/news_api.dart';
import '../organizers/data/organizer_api.dart';
import '../labels/data/label_api.dart';
import '../rankings/data/ranking_api.dart';
import '../genres_sunburst/data/genre_api.dart';
import '../search/data/recent_search_store.dart';
import '../search/data/search_api_service.dart';
import '../search/data/search_repository.dart';

typedef CurrentUserIdProvider = String? Function();

class DiscoverServiceLocator {
  DiscoverServiceLocator._();

  static Dio? _dio;
  static CurrentUserIdProvider? _currentUserIdProvider;

  static Dio get dio {
    _dio ??= createDiscoverDio();
    return _dio!;
  }

  static void configureDio(Dio dio) {
    _dio = dio;
  }

  static void configureCurrentUserIdProvider(
    CurrentUserIdProvider provider,
  ) {
    _currentUserIdProvider = provider;
  }

  static String? get currentUserId => _currentUserIdProvider?.call();

  static EventsApiService? _eventsApi;
  static EventsApiService get eventsApi => _eventsApi ??= EventsApiService(dio);

  static EventsRepository? _eventsRepository;
  static EventsRepository get eventsRepository =>
      _eventsRepository ??= EventsRepository(eventsApi);

  static DjApi? _djApi;
  static DjApi get djApi => _djApi ??= DjApi(dio);

  static SetApi? _setApi;
  static SetApi get setApi => _setApi ??= SetApi(dio);

  static NewsApi? _newsApi;
  static NewsApi get newsApi => _newsApi ??= NewsApi(dio);

  static OrganizerApi? _organizerApi;
  static OrganizerApi get organizerApi => _organizerApi ??= OrganizerApi(dio);

  static LabelApi? _labelApi;
  static LabelApi get labelApi => _labelApi ??= LabelApi(dio);

  static RankingApi? _rankingApi;
  static RankingApi get rankingApi => _rankingApi ??= RankingApi(dio);

  static GenreApi? _genreApi;
  static GenreApi get genreApi => _genreApi ??= GenreApi(dio);

  static SearchApiService? _searchApi;
  static SearchApiService get searchApi => _searchApi ??= SearchApiService(dio);

  static SearchRepository? _searchRepository;
  static SearchRepository get searchRepository =>
      _searchRepository ??= SearchRepository(searchApi);

  static void configureSearchRepository(SearchRepository repository) {
    _searchRepository = repository;
  }

  static RecentSearchStore? _recentSearchStore;
  static RecentSearchStore get recentSearchStore =>
      _recentSearchStore ??= RecentSearchStore();

  static void configureRecentSearchStore(RecentSearchStore store) {
    _recentSearchStore = store;
  }
}
