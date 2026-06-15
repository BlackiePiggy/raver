import 'package:raver_models/raver_models.dart';

import 'search_api_service.dart';

class SearchRepository {
  SearchRepository(this._api);

  final SearchApiService _api;

  Future<GlobalSearchResponse> searchGlobal({
    required String query,
    required String tab,
    int limit = 60,
  }) {
    return _api.searchGlobal(query: query, tab: tab, limit: limit);
  }
}
