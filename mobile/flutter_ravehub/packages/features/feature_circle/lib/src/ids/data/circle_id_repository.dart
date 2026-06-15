import 'circle_id_api.dart';

class CircleIdRepository {
  CircleIdRepository(this._api);

  final CircleIdApi _api;

  Future<List<CircleIdCard>> fetchMyCircleIds() {
    return _api.fetchMyCircleIds();
  }

  Future<CircleIdCard> createCircleId({
    required String nickname,
    required String tagline,
    required int gradientIndex,
  }) {
    return _api.createCircleId(
      nickname: nickname,
      tagline: tagline,
      gradientIndex: gradientIndex,
    );
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
