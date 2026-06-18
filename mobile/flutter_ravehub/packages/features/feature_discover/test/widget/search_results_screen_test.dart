import 'package:dio/dio.dart';
import 'package:feature_discover/feature_discover.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_models/raver_models.dart';

Widget _buildApp(Widget child) {
  return MaterialApp(
    theme: RaverThemeData.darkTheme(),
    home: child,
  );
}

void main() {
  group('SearchResultsScreen', () {
    setUp(() {
      DiscoverServiceLocator.configureRecentSearchStore(
        _FakeRecentSearchStore(),
      );
      DiscoverServiceLocator.configureSearchRepository(
        _FakeSearchRepository(),
      );
    });

    testWidgets('shows login gate for unauthenticated users', (tester) async {
      DiscoverServiceLocator.configureCurrentUserIdProvider(() => null);

      await tester.pumpWidget(
        _buildApp(const SearchResultsScreen(initialQuery: 'techno')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Login Required'), findsOneWidget);
      expect(find.text('Log in to use global search.'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.byType(SearchSkeleton), findsNothing);
    });

    testWidgets('shows recent searches before live query starts',
        (tester) async {
      DiscoverServiceLocator.configureCurrentUserIdProvider(() => 'user-1');
      DiscoverServiceLocator.configureRecentSearchStore(
        _FakeRecentSearchStore(['acid', 'techno']),
      );
      final repository = _FakeSearchRepository();
      DiscoverServiceLocator.configureSearchRepository(repository);

      await tester.pumpWidget(
        _buildApp(const SearchResultsScreen(initialQuery: '')),
      );
      await tester.pump();

      expect(find.text('Recent Searches'), findsOneWidget);
      expect(find.text('acid'), findsOneWidget);
      expect(find.text('techno'), findsOneWidget);
      expect(repository.queries, isEmpty);
    });

    testWidgets('debounces typed queries before searching live service',
        (tester) async {
      DiscoverServiceLocator.configureCurrentUserIdProvider(() => 'user-1');
      final repository = _FakeSearchRepository();
      DiscoverServiceLocator.configureSearchRepository(repository);

      await tester.pumpWidget(
        _buildApp(const SearchResultsScreen(initialQuery: '')),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'techno');
      await tester.pump(const Duration(milliseconds: 349));
      expect(repository.queries, isEmpty);

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();

      expect(repository.queries, ['techno']);
    });

    testWidgets('runs recent query immediately when chip is tapped',
        (tester) async {
      DiscoverServiceLocator.configureCurrentUserIdProvider(() => 'user-1');
      final recentStore = _FakeRecentSearchStore(['acid']);
      final repository = _FakeSearchRepository();
      DiscoverServiceLocator.configureRecentSearchStore(recentStore);
      DiscoverServiceLocator.configureSearchRepository(repository);

      await tester.pumpWidget(
        _buildApp(const SearchResultsScreen(initialQuery: '')),
      );
      await tester.pump();

      await tester.tap(find.text('acid'));
      await tester.pump();

      expect(repository.queries, ['acid']);
      expect(recentStore.recordedQueries, ['acid']);
    });
  });
}

class _FakeSearchRepository extends SearchRepository {
  _FakeSearchRepository() : super(SearchApiService(Dio()));

  final List<String> queries = [];

  @override
  Future<GlobalSearchResponse> searchGlobal({
    required String query,
    required String tab,
    int limit = 60,
  }) async {
    queries.add(query);
    return GlobalSearchResponse(
      query: query,
      tab: GlobalSearchTab.all,
      items: [
        GlobalSearchItem(
          id: 'event-$query',
          type: GlobalSearchItemType.event,
          entityId: 'event-$query',
          title: '$query Event',
        ),
      ],
      countsByTab: const {'events': 1},
    );
  }
}

class _FakeRecentSearchStore extends RecentSearchStore {
  _FakeRecentSearchStore([List<String> queries = const []])
      : _queries = [...queries];

  final List<String> recordedQueries = [];
  List<String> _queries;

  @override
  List<String> get queries => List.unmodifiable(_queries);

  @override
  Future<void> initialize() async {
    notifyListeners();
  }

  @override
  Future<void> record(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty) return;
    recordedQueries.add(query);
    _queries = [
      query,
      ..._queries.where((item) => item.toLowerCase() != query.toLowerCase()),
    ];
    notifyListeners();
  }
}
