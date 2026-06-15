import 'package:flutter/foundation.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_models/raver_models.dart';

import '../data/virtual_asset_api.dart';

class VirtualAssetViewModel extends ChangeNotifier {
  VirtualAssetViewModel({required VirtualAssetApi api}) : _api = api;

  final VirtualAssetApi _api;

  // Tab: 0 = mine, 1 = shop
  int _selectedTab = 0;
  int get selectedTab => _selectedTab;

  // All definitions (shop)
  LoadPhase<List<VirtualAssetDefinition>> _allPhase =
      const LoadPhase.loading();
  LoadPhase<List<VirtualAssetDefinition>> get allPhase => _allPhase;
  List<VirtualAssetDefinition> _allAssets = [];
  List<VirtualAssetDefinition> get allAssets => _allAssets;

  // My assets
  LoadPhase<List<UserVirtualAsset>> _myPhase = const LoadPhase.loading();
  LoadPhase<List<UserVirtualAsset>> get myPhase => _myPhase;
  List<UserVirtualAsset> _myAssets = [];
  List<UserVirtualAsset> get myAssets => _myAssets;

  // Equip state
  bool _isEquipping = false;
  bool get isEquipping => _isEquipping;

  Future<void> load() async {
    _myPhase = const LoadPhase.loading();
    _allPhase = const LoadPhase.loading();
    notifyListeners();

    try {
      _myAssets = await _api.fetchMine();
      _myPhase = _myAssets.isEmpty
          ? const LoadPhase.empty()
          : LoadPhase.success(_myAssets);
    } catch (e) {
      _myPhase = LoadPhase.failure(e);
    }

    try {
      _allAssets = await _api.fetchAll();
      _allPhase = _allAssets.isEmpty
          ? const LoadPhase.empty()
          : LoadPhase.success(_allAssets);
    } catch (e) {
      _allPhase = LoadPhase.failure(e);
    }
    notifyListeners();
  }

  void setSelectedTab(int index) {
    if (_selectedTab == index) return;
    _selectedTab = index;
    notifyListeners();
  }

  Future<void> toggleEquip(String definitionId, bool equip) async {
    if (_isEquipping) return;
    _isEquipping = true;
    notifyListeners();

    try {
      await _api.equip(definitionId: definitionId, equip: equip);
      // Reload my assets to reflect changes
      _myAssets = await _api.fetchMine();
      _myPhase = _myAssets.isEmpty
          ? const LoadPhase.empty()
          : LoadPhase.success(_myAssets);
    } catch (_) {}
    _isEquipping = false;
    notifyListeners();
  }
}
