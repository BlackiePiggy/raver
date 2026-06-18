import 'package:flutter/foundation.dart';
import 'package:raver_models/raver_models.dart';
import 'package:raver_design_system/raver_design_system.dart';

import '../../data/rating_repository.dart';

class RatingViewModel extends ChangeNotifier {
  RatingViewModel({required RatingRepository repository})
      : _repository = repository;

  final RatingRepository _repository;

  LoadPhase<List<WebRatingEvent>> _phase = const LoadPhase.loading();
  LoadPhase<List<WebRatingEvent>> get phase => _phase;

  final List<WebRatingEvent> _events = [];
  List<WebRatingEvent> get events => List.unmodifiable(_events);

  int _currentPage = 1;
  int _totalPages = 1;
  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;
  bool get canLoadMore => _currentPage < _totalPages;

  String? _statusFilter;
  String? get statusFilter => _statusFilter;

  Future<void> load() async {
    _phase = const LoadPhase.loading();
    notifyListeners();

    try {
      final page = await _repository.fetchRatings(
        page: 1,
        status: _statusFilter,
      );
      _events
        ..clear()
        ..addAll(page.items);
      _currentPage = 1;
      _totalPages = page.pagination?.totalPages ?? 1;
      _phase = _events.isEmpty
          ? const LoadPhase.empty()
          : LoadPhase.success(_events);
    } catch (e) {
      _phase = LoadPhase.fromError(e);
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    try {
      final page = await _repository.fetchRatings(
        page: 1,
        status: _statusFilter,
      );
      _events
        ..clear()
        ..addAll(page.items);
      _currentPage = 1;
      _totalPages = page.pagination?.totalPages ?? 1;
      _phase = _events.isEmpty
          ? const LoadPhase.empty()
          : LoadPhase.success(_events);
    } catch (e) {
      if (_events.isEmpty) {
        _phase = LoadPhase.fromError(e);
      }
    }
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !canLoadMore) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextPage = _currentPage + 1;
      final page = await _repository.fetchRatings(
        page: nextPage,
        status: _statusFilter,
      );
      _events.addAll(page.items);
      _currentPage = nextPage;
      _totalPages = page.pagination?.totalPages ?? _totalPages;
      _phase = LoadPhase.success(_events);
    } catch (_) {
      // Silently fail on pagination.
    }
    _isLoadingMore = false;
    notifyListeners();
  }

  void setStatusFilter(String? status) {
    if (_statusFilter == status) return;
    _statusFilter = status;
    load();
  }
}

class RatingDetailViewModel extends ChangeNotifier {
  RatingDetailViewModel({
    required this.ratingId,
    required RatingRepository repository,
  }) : _repository = repository;

  final String ratingId;
  final RatingRepository _repository;

  LoadPhase<WebRatingEvent> _phase = const LoadPhase.loading();
  LoadPhase<WebRatingEvent> get phase => _phase;

  WebRatingEvent? _event;
  WebRatingEvent? get event => _event;

  final List<WebRatingUnit> _units = [];
  List<WebRatingUnit> get units => List.unmodifiable(_units);

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  Future<void> load() async {
    _phase = const LoadPhase.loading();
    notifyListeners();

    try {
      _event = await _repository.fetchRatingEvent(id: ratingId);
      _phase = LoadPhase.success(_event!);
      _loadUnits();
    } catch (e) {
      _phase = LoadPhase.fromError(e);
    }
    notifyListeners();
  }

  Future<void> _loadUnits() async {
    try {
      _units
        ..clear()
        ..addAll(await _repository.fetchRatingUnits(ratingId: ratingId));
      _sortUnits();
    } catch (_) {}
    notifyListeners();
  }

  Future<void> createUnit({
    required String name,
    required String djId,
    String description = '',
    String? imageUrl,
  }) async {
    try {
      final unit = await _repository.createRatingUnit(
        ratingId: ratingId,
        name: name,
        djId: djId,
        description: description,
        imageUrl: imageUrl,
      );
      _units.add(unit);
      _sortUnits();
      notifyListeners();
    } catch (_) {
      // Silently fail.
    }
  }

  Future<bool> updateEvent({
    required String name,
    required String description,
    String? imageUrl,
  }) async {
    if (_isSaving) return false;
    _isSaving = true;
    notifyListeners();

    try {
      final updated = await _repository.updateRatingEvent(
        id: ratingId,
        name: name.trim(),
        description: description.trim(),
        imageUrl: imageUrl?.trim(),
      );
      _event = updated;
      _phase = LoadPhase.success(updated);
      if (updated.units != null) {
        _units
          ..clear()
          ..addAll(updated.units!);
        _sortUnits();
      }
      _isSaving = false;
      notifyListeners();
      return true;
    } catch (_) {
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateUnit({
    required String unitId,
    required String name,
    required String description,
    required String djId,
    String? imageUrl,
  }) async {
    if (_isSaving) return false;
    _isSaving = true;
    notifyListeners();

    try {
      final updated = await _repository.updateRatingUnit(
        unitId: unitId,
        name: name.trim(),
        description: description.trim(),
        djId: djId.trim(),
        imageUrl: imageUrl?.trim(),
      );
      final index = _units.indexWhere((unit) => unit.id == unitId);
      if (index == -1) {
        _units.add(updated);
      } else {
        _units[index] = updated;
      }
      _sortUnits();
      _isSaving = false;
      notifyListeners();
      return true;
    } catch (_) {
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  void _sortUnits() {
    _units.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
  }
}

class RatingUnitDetailViewModel extends ChangeNotifier {
  RatingUnitDetailViewModel({
    required this.ratingId,
    required this.unitId,
    required RatingRepository repository,
  }) : _repository = repository;

  final String ratingId;
  final String unitId;
  final RatingRepository _repository;

  WebRatingUnit? _unit;
  WebRatingUnit? get unit => _unit;

  final List<WebRatingComment> _comments = [];
  List<WebRatingComment> get comments => List.unmodifiable(_comments);

  int _commentPage = 1;
  int _commentTotalPages = 1;
  bool _isLoadingComments = false;
  bool get isLoadingComments => _isLoadingComments;
  bool get canLoadMoreComments => _commentPage < _commentTotalPages;

  double _userScore = 5.0;
  double get userScore => _userScore;

  bool _isVoting = false;
  bool get isVoting => _isVoting;

  bool _isSendingComment = false;
  bool get isSendingComment => _isSendingComment;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  void setUserScore(double score) {
    _userScore = score;
    notifyListeners();
  }

  Future<void> load() async {
    try {
      _unit = await _repository.fetchRatingUnit(unitId: unitId);
      _loadComments();
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _loadComments() async {
    _isLoadingComments = true;
    try {
      final page = await _repository.fetchUnitComments(
        ratingId: ratingId,
        unitId: unitId,
        page: 1,
      );
      _comments
        ..clear()
        ..addAll(page.items);
      _commentPage = 1;
      _commentTotalPages = page.pagination?.totalPages ?? 1;
    } catch (_) {}
    _isLoadingComments = false;
    notifyListeners();
  }

  Future<void> loadMoreComments() async {
    if (_isLoadingComments || !canLoadMoreComments) return;
    _isLoadingComments = true;
    notifyListeners();

    try {
      final nextPage = _commentPage + 1;
      final page = await _repository.fetchUnitComments(
        ratingId: ratingId,
        unitId: unitId,
        page: nextPage,
      );
      _comments.addAll(page.items);
      _commentPage = nextPage;
      _commentTotalPages = page.pagination?.totalPages ?? _commentTotalPages;
    } catch (_) {}
    _isLoadingComments = false;
    notifyListeners();
  }

  Future<bool> vote() async {
    if (_isVoting) return false;
    _isVoting = true;
    notifyListeners();

    try {
      await _repository.voteRatingUnit(
        ratingId: ratingId,
        unitId: unitId,
        score: _userScore,
      );
      _isVoting = false;
      notifyListeners();
      return true;
    } catch (_) {
      _isVoting = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendComment(String content) async {
    if (_isSendingComment || content.trim().isEmpty) return false;
    _isSendingComment = true;
    notifyListeners();

    try {
      final comment = await _repository.postUnitComment(
        ratingId: ratingId,
        unitId: unitId,
        content: content.trim(),
        score: _userScore,
      );
      _comments.insert(0, comment);
      _isSendingComment = false;
      notifyListeners();
      return true;
    } catch (_) {
      _isSendingComment = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateUnit({
    required String name,
    required String description,
    required String djId,
    String? imageUrl,
  }) async {
    if (_isSaving) return false;
    _isSaving = true;
    notifyListeners();

    try {
      _unit = await _repository.updateRatingUnit(
        unitId: unitId,
        name: name.trim(),
        description: description.trim(),
        djId: djId.trim(),
        imageUrl: imageUrl?.trim(),
      );
      _isSaving = false;
      notifyListeners();
      return true;
    } catch (_) {
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }
}
