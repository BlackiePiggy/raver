import 'package:raver_models/raver_models.dart';

import 'circle_id_api.dart';

class CircleIdRepository {
  CircleIdRepository(this._api);

  final CircleIdApi _api;

  Future<List<CircleIdCard>> fetchMyCircleIds() {
    return _api.fetchMyCircleIds();
  }

  Future<List<WebEvent>> searchEvents({String? search}) {
    return _api.searchEvents(search: search);
  }

  Future<List<WebDJ>> searchDjs({String? search}) {
    return _api.searchDjs(search: search);
  }

  Future<CircleIdCard> createCircleId(CircleIdCreationDraft draft) {
    return _api.createCircleId(draft);
  }

  Future<CircleIdCard> fetchCircleId({required String id}) {
    return _api.fetchCircleId(id: id);
  }

  Future<CircleIdCard> updateCircleId({
    required String id,
    String? nickname,
    String? tagline,
    int? gradientIndex,
  }) {
    return _api.updateCircleId(
      id: id,
      nickname: nickname,
      tagline: tagline,
      gradientIndex: gradientIndex,
    );
  }
}
