import 'package:flutter/foundation.dart';
import 'package:raver_models/raver_models.dart';

import '../data/search_repository.dart';

enum SearchLoadPhase { idle, loading, loaded, empty, failed }

class GlobalSearchResultsViewModel extends ChangeNotifier {
  GlobalSearchResultsViewModel({
    required String initialQuery,
    required SearchRepository repository,
  })  : _query = initialQuery,
        _repository = repository {
    for (final tab in GlobalSearchTab.values) {
      _phaseByTab[tab] = SearchLoadPhase.idle;
      _countsByTab[tab] = 0;
    }
  }

  final SearchRepository _repository;

  String _query;
  String get query => _query;

  List<GlobalSearchItem> _allItems = [];
  List<GlobalSearchItem> get allItems => _allItems;

  final Map<GlobalSearchTab, SearchLoadPhase> _phaseByTab = {};
  Map<GlobalSearchTab, SearchLoadPhase> get phaseByTab =>
      Map.unmodifiable(_phaseByTab);

  final Map<GlobalSearchTab, int> _countsByTab = {};
  Map<GlobalSearchTab, int> get countsByTab => Map.unmodifiable(_countsByTab);

  final Set<GlobalSearchTab> _partialFailureTabs = {};

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  void loadInitial() {
    if (_allItems.isNotEmpty) return;
    _load(query: _query, requestedTab: GlobalSearchTab.all, resetTabs: true);
  }

  void submitSearch(String rawQuery) {
    final keyword = rawQuery.trim();
    if (keyword.isEmpty) return;
    _load(query: keyword, requestedTab: GlobalSearchTab.all, resetTabs: true);
  }

  void retryTab(GlobalSearchTab tab) {
    _load(
      query: _query,
      requestedTab: tab,
      resetTabs: tab == GlobalSearchTab.all,
    );
  }

  List<GlobalSearchItem> itemsForTab(GlobalSearchTab tab) {
    final items = tab == GlobalSearchTab.all
        ? _allItems
        : _allItems.where((item) => _tabForItemType(item.type) == tab).toList();
    items.sort(
      (a, b) =>
          (b.relevanceScore ?? 0).compareTo(a.relevanceScore ?? 0),
    );
    return items;
  }

  int countForTab(GlobalSearchTab tab) =>
      _countsByTab[tab] ?? itemsForTab(tab).length;

  List<GlobalSearchItem> get topMatches =>
      itemsForTab(GlobalSearchTab.all).take(5).toList();

  List<GlobalSearchTab> get previewTabs => [
        GlobalSearchTab.events,
        GlobalSearchTab.djs,
        GlobalSearchTab.peopleSquads,
        GlobalSearchTab.posts,
        GlobalSearchTab.news,
        GlobalSearchTab.sets,
        GlobalSearchTab.rankings,
        GlobalSearchTab.ratings,
        GlobalSearchTab.festivals,
        GlobalSearchTab.labels,
        GlobalSearchTab.genreTree,
      ].where((tab) => itemsForTab(tab).isNotEmpty).toList();

  Future<void> _load({
    required String query,
    required GlobalSearchTab requestedTab,
    required bool resetTabs,
  }) async {
    _query = query;
    _errorMessage = null;

    if (resetTabs) {
      for (final tab in GlobalSearchTab.values) {
        _phaseByTab[tab] = SearchLoadPhase.loading;
      }
    } else {
      _phaseByTab[requestedTab] = SearchLoadPhase.loading;
    }
    notifyListeners();

    try {
      final response = await _repository.searchGlobal(
        query: query,
        tab: requestedTab.name,
      );
      _applyResponse(response, requestedTab);
    } catch (e) {
      _errorMessage = e.toString();
      if (resetTabs) {
        for (final tab in GlobalSearchTab.values) {
          _phaseByTab[tab] = SearchLoadPhase.failed;
        }
      } else {
        _phaseByTab[requestedTab] = SearchLoadPhase.failed;
      }
    }
    notifyListeners();
  }

  void _applyResponse(
    GlobalSearchResponse response,
    GlobalSearchTab requestedTab,
  ) {
    _query = response.query;

    if (requestedTab == GlobalSearchTab.all) {
      _allItems = response.items;
    } else {
      final existing = _allItems
          .where((item) => _tabForItemType(item.type) != requestedTab)
          .toList();
      _allItems = [...existing, ...response.items];
    }

    if (response.countsByTab != null) {
      for (final tab in GlobalSearchTab.values) {
        _countsByTab[tab] = response.countsByTab![tab.name] ?? 0;
      }
    }
    _countsByTab[GlobalSearchTab.all] = _allItems.length;

    for (final tab in GlobalSearchTab.values) {
      if (requestedTab == GlobalSearchTab.all || tab == requestedTab) {
        final count = countForTab(tab);
        _phaseByTab[tab] = count > 0 ? SearchLoadPhase.loaded : SearchLoadPhase.empty;
      }
    }
  }

  static GlobalSearchTab _tabForItemType(GlobalSearchItemType type) =>
      switch (type) {
        GlobalSearchItemType.event => GlobalSearchTab.events,
        GlobalSearchItemType.news => GlobalSearchTab.news,
        GlobalSearchItemType.dj => GlobalSearchTab.djs,
        GlobalSearchItemType.set => GlobalSearchTab.sets,
        GlobalSearchItemType.rankingBoard ||
        GlobalSearchItemType.rankingEntry =>
          GlobalSearchTab.rankings,
        GlobalSearchItemType.ratingEvent ||
        GlobalSearchItemType.ratingUnit =>
          GlobalSearchTab.ratings,
        GlobalSearchItemType.post => GlobalSearchTab.posts,
        GlobalSearchItemType.label => GlobalSearchTab.labels,
        GlobalSearchItemType.festival => GlobalSearchTab.festivals,
        GlobalSearchItemType.genre => GlobalSearchTab.genreTree,
        GlobalSearchItemType.user ||
        GlobalSearchItemType.squad =>
          GlobalSearchTab.peopleSquads,
      };
}
