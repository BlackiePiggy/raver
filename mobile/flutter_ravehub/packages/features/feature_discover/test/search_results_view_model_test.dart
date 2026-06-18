import 'dart:async';

import 'package:dio/dio.dart';
import 'package:feature_discover/src/search/data/search_api_service.dart';
import 'package:feature_discover/src/search/data/search_repository.dart';
import 'package:feature_discover/src/search/presentation/search_results_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raver_models/raver_models.dart';

void main() {
  group('GlobalSearchResultsViewModel', () {
    test('normalizes snake_case and camelCase live count keys', () async {
      final viewModel = GlobalSearchResultsViewModel(
        initialQuery: 'techno',
        repository: _FakeSearchRepository(
          GlobalSearchResponse(
            query: 'techno',
            tab: GlobalSearchTab.all,
            items: const [
              GlobalSearchItem(
                id: 'user-1',
                type: GlobalSearchItemType.user,
                entityId: 'user-1',
                title: 'User',
              ),
              GlobalSearchItem(
                id: 'genre-1',
                type: GlobalSearchItemType.genre,
                entityId: 'genre-1',
                title: 'Genre',
              ),
            ],
            countsByTab: const {
              'people_squads': 7,
              'genre_tree': 3,
              'events': 2,
            },
          ),
        ),
      );
      addTearDown(viewModel.dispose);

      viewModel.loadInitial();
      await _pumpEventQueue();

      expect(viewModel.countForTab(GlobalSearchTab.peopleSquads), 7);
      expect(viewModel.countForTab(GlobalSearchTab.genreTree), 3);
      expect(viewModel.countForTab(GlobalSearchTab.events), 2);
      expect(
        viewModel.phaseByTab[GlobalSearchTab.peopleSquads],
        SearchLoadPhase.loaded,
      );
      expect(
        viewModel.phaseByTab[GlobalSearchTab.genreTree],
        SearchLoadPhase.loaded,
      );
    });

    test('keeps newer live search result when older request completes later',
        () async {
      final first = Completer<GlobalSearchResponse>();
      final second = Completer<GlobalSearchResponse>();
      final repository = _SequencedSearchRepository([
        first.future,
        second.future,
      ]);
      final viewModel = GlobalSearchResultsViewModel(
        initialQuery: 'old',
        repository: repository,
      );
      addTearDown(viewModel.dispose);

      viewModel.loadInitial();
      await _pumpEventQueue();
      viewModel.submitSearch('new');
      await _pumpEventQueue();

      second.complete(
        const GlobalSearchResponse(
          query: 'new',
          tab: GlobalSearchTab.all,
          items: [
            GlobalSearchItem(
              id: 'event-1',
              type: GlobalSearchItemType.event,
              entityId: 'event-1',
              title: 'New Event',
              relevanceScore: 10,
            ),
          ],
        ),
      );
      await _pumpEventQueue();

      first.complete(
        const GlobalSearchResponse(
          query: 'old',
          tab: GlobalSearchTab.all,
          items: [
            GlobalSearchItem(
              id: 'dj-1',
              type: GlobalSearchItemType.dj,
              entityId: 'dj-1',
              title: 'Old DJ',
              relevanceScore: 99,
            ),
          ],
        ),
      );
      await _pumpEventQueue();

      expect(repository.queries, ['old', 'new']);
      expect(viewModel.query, 'new');
      expect(viewModel.allItems.single.title, 'New Event');
      expect(viewModel.countForTab(GlobalSearchTab.events), 1);
      expect(viewModel.countForTab(GlobalSearchTab.djs), 0);
    });
  });
}

Future<void> _pumpEventQueue() async {
  await Future<void>.delayed(Duration.zero);
}

class _FakeSearchRepository extends SearchRepository {
  _FakeSearchRepository(this._response) : super(SearchApiService(Dio()));

  final GlobalSearchResponse _response;

  @override
  Future<GlobalSearchResponse> searchGlobal({
    required String query,
    required String tab,
    int limit = 60,
  }) async =>
      _response;
}

class _SequencedSearchRepository extends SearchRepository {
  _SequencedSearchRepository(this._responses) : super(SearchApiService(Dio()));

  final List<Future<GlobalSearchResponse>> _responses;
  final List<String> queries = [];

  @override
  Future<GlobalSearchResponse> searchGlobal({
    required String query,
    required String tab,
    int limit = 60,
  }) {
    queries.add(query);
    return _responses.removeAt(0);
  }
}
