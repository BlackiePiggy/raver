import 'package:flutter/foundation.dart';
import 'package:raver_models/raver_models.dart';
import 'package:raver_design_system/raver_design_system.dart';

import '../../data/squad_repository.dart';

class SquadViewModel extends ChangeNotifier {
  SquadViewModel({required SquadRepository repository})
      : _repository = repository;

  final SquadRepository _repository;

  // My squads
  LoadPhase<List<SquadProfile>> _mySquadsPhase = const LoadPhase.loading();
  LoadPhase<List<SquadProfile>> get mySquadsPhase => _mySquadsPhase;

  final List<SquadProfile> _mySquads = [];
  List<SquadProfile> get mySquads => List.unmodifiable(_mySquads);

  // Recommended squads
  LoadPhase<List<SquadProfile>> _recommendedPhase = const LoadPhase.loading();
  LoadPhase<List<SquadProfile>> get recommendedPhase => _recommendedPhase;

  final List<SquadProfile> _recommendedSquads = [];
  List<SquadProfile> get recommendedSquads =>
      List.unmodifiable(_recommendedSquads);

  bool _isJoining = false;

  Future<void> load() async {
    _mySquadsPhase = const LoadPhase.loading();
    _recommendedPhase = const LoadPhase.loading();
    notifyListeners();

    await Future.wait([_loadMySquads(), _loadRecommended()]);
  }

  Future<void> _loadMySquads() async {
    try {
      final page = await _repository.fetchMySquads(page: 1);
      _mySquads
        ..clear()
        ..addAll(page.items);
      _mySquadsPhase = _mySquads.isEmpty
          ? const LoadPhase.empty()
          : LoadPhase.success(_mySquads);
    } catch (e) {
      _mySquadsPhase = LoadPhase.fromError(e);
    }
    notifyListeners();
  }

  Future<void> _loadRecommended() async {
    try {
      _recommendedSquads
        ..clear()
        ..addAll(await _repository.fetchRecommendedSquads());
      _recommendedPhase = _recommendedSquads.isEmpty
          ? const LoadPhase.empty()
          : LoadPhase.success(_recommendedSquads);
    } catch (e) {
      _recommendedPhase = LoadPhase.fromError(e);
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    await Future.wait([_loadMySquads(), _loadRecommended()]);
  }

  Future<void> joinSquad(String squadId) async {
    if (_isJoining) return;
    _isJoining = true;
    try {
      await _repository.joinSquad(squadId: squadId);
      // Move from recommended to my squads
      final idx = _recommendedSquads.indexWhere((s) => s.id == squadId);
      if (idx != -1) {
        final squad = _recommendedSquads.removeAt(idx);
        _mySquads.add(squad);
        _mySquadsPhase = LoadPhase.success(_mySquads);
        _recommendedPhase = _recommendedSquads.isEmpty
            ? const LoadPhase.empty()
            : LoadPhase.success(_recommendedSquads);
      }
    } catch (_) {
      // Silently fail.
    }
    _isJoining = false;
    notifyListeners();
  }

  Future<SquadProfile?> createSquad({
    required String name,
    required String description,
    String? avatarLocalPath,
  }) async {
    try {
      var squad = await _repository.createSquad(
        name: name,
        description: description,
      );
      if (avatarLocalPath != null && avatarLocalPath.isNotEmpty) {
        try {
          final avatarUrl = await _repository.uploadSquadAvatar(
            squadId: squad.id,
            localPath: avatarLocalPath,
          );
          squad = squad.copyWith(avatarUrl: avatarUrl);
        } catch (_) {
          // The squad was created successfully; keep it visible even if the
          // optional avatar upload fails.
        }
      }
      _mySquads.insert(0, squad);
      _mySquadsPhase = LoadPhase.success(_mySquads);
      notifyListeners();
      return squad;
    } catch (_) {
      return null;
    }
  }
}

class SquadProfileViewModel extends ChangeNotifier {
  SquadProfileViewModel({
    required this.squadId,
    required SquadRepository repository,
  }) : _repository = repository;

  final String squadId;
  final SquadRepository _repository;

  LoadPhase<SquadProfile> _phase = const LoadPhase.loading();
  LoadPhase<SquadProfile> get phase => _phase;

  SquadProfile? _squad;
  SquadProfile? get squad => _squad;

  final List<SquadMemberProfile> _members = [];
  List<SquadMemberProfile> get members => List.unmodifiable(_members);

  final List<SquadOfflineActivity> _activities = [];
  List<SquadOfflineActivity> get activities => List.unmodifiable(_activities);

  bool get isOwner => _squad?.myRole == 'owner';

  Future<void> load() async {
    _phase = const LoadPhase.loading();
    notifyListeners();

    try {
      _squad = await _repository.fetchSquad(id: squadId);
      _phase = LoadPhase.success(_squad!);
      _loadMembers();
      _loadActivities();
    } catch (e) {
      _phase = LoadPhase.fromError(e);
    }
    notifyListeners();
  }

  Future<void> _loadMembers() async {
    try {
      _members
        ..clear()
        ..addAll(await _repository.fetchMembers(squadId: squadId));
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _loadActivities() async {
    try {
      _activities
        ..clear()
        ..addAll(await _repository.fetchOfflineActivities(squadId: squadId));
    } catch (_) {}
    notifyListeners();
  }

  Future<void> leaveSquad() async {
    await _repository.leaveSquad(squadId: squadId);
  }

  Future<void> kickMember(String userId) async {
    await _repository.kickMember(squadId: squadId, userId: userId);
    _members.removeWhere((m) => m.userId == userId);
    notifyListeners();
  }

  Future<void> updateSquad({
    String? name,
    String? description,
    String? coverImageUrl,
  }) async {
    _squad = await _repository.updateSquad(
      id: squadId,
      name: name,
      description: description,
      coverImageUrl: coverImageUrl,
    );
    _phase = LoadPhase.success(_squad!);
    notifyListeners();
  }

  Future<void> deleteSquad() async {
    await _repository.deleteSquad(id: squadId);
  }

  Future<void> inviteMember(String userId) async {
    await _repository.inviteMember(squadId: squadId, userId: userId);
  }
}
