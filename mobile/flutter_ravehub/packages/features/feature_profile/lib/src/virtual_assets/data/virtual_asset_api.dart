import 'package:dio/dio.dart';
import 'package:raver_models/raver_models.dart';

class VirtualAssetApi {
  VirtualAssetApi(this._dio);

  final Dio _dio;

  /// Fetch all virtual assets (shop).
  Future<List<VirtualAssetDefinition>> fetchAll() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/virtual-assets',
    );
    final items = response.data!['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => VirtualAssetDefinition.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetch my owned virtual assets.
  Future<List<UserVirtualAsset>> fetchMine() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/virtual-assets/mine',
    );
    final items = response.data!['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => UserVirtualAsset.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Equip or unequip a virtual asset.
  Future<void> equip({
    required String definitionId,
    required bool equip,
  }) async {
    await _dio.put<void>(
      '/v1/virtual-assets/equip',
      data: {'definitionId': definitionId, 'equip': equip},
    );
  }
}
