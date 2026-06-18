import 'package:flutter/foundation.dart';
import 'package:raver_models/raver_models.dart';

import '../../data/news_api.dart';

/// ViewModel for the news article editor screen.
///
/// Manages form state for creating and editing news articles, including
/// cover image upload and article persistence.
class NewsEditorViewModel extends ChangeNotifier {
  NewsEditorViewModel({required NewsApi api}) : _api = api;

  final NewsApi _api;

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  String? _articleId;
  String? get articleId => _articleId;

  String _title = '';
  String get title => _title;

  String _content = '';
  String get content => _content;

  String _summary = '';
  String get summary => _summary;

  String _source = '';
  String get source => _source;

  String _link = '';
  String get link => _link;

  String _category = 'festival';
  String get category => _category;

  String? _coverImageUrl;
  String? get coverImageUrl => _coverImageUrl;

  List<WebDJ> _boundDjs = [];
  List<WebDJ> get boundDjs => List.unmodifiable(_boundDjs);

  List<WebEvent> _boundEvents = [];
  List<WebEvent> get boundEvents => List.unmodifiable(_boundEvents);

  List<String> _boundDjIds = [];
  List<String> get boundDjIds => List.unmodifiable(_boundDjIds);

  List<String> _boundEventIds = [];
  List<String> get boundEventIds => List.unmodifiable(_boundEventIds);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _isSaved = false;
  bool get isSaved => _isSaved;

  bool _submittedForReview = false;
  bool get submittedForReview => _submittedForReview;

  String _submissionMessage = '';
  String get submissionMessage => _submissionMessage;

  String? _submissionId;
  String? get submissionId => _submissionId;

  bool get isEditing => _articleId != null;

  bool get canSave =>
      !_isLoading && _title.trim().isNotEmpty && _source.trim().isNotEmpty;

  // ---------------------------------------------------------------------------
  // Load existing article for editing
  // ---------------------------------------------------------------------------

  /// Loads an existing article for editing.
  Future<void> loadArticle(String id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final article = await _api.fetchArticle(id);
      _articleId = article.id;
      _title = article.title;
      _content = article.body;
      _summary = article.summary;
      _source = article.source;
      _link = article.link ?? '';
      _category = _normalizeCategory(article.category);
      _coverImageUrl = article.coverImageUrl;
      _boundDjIds = article.boundDjIds;
      _boundEventIds = article.boundEventIds;
      _boundDjs = await _api.fetchBoundDJs(_boundDjIds);
      _boundEvents = await _api.fetchBoundEvents(_boundEventIds);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Field updates
  // ---------------------------------------------------------------------------

  /// Updates a specific field of the editor state.
  void updateField({
    String? title,
    String? content,
    String? summary,
    String? source,
    String? link,
    String? category,
  }) {
    if (title != null) _title = title;
    if (content != null) _content = content;
    if (summary != null) _summary = summary;
    if (source != null) _source = source;
    if (link != null) _link = link;
    if (category != null) _category = _normalizeCategory(category);
    _errorMessage = null;
    _isSaved = false;
    _submittedForReview = false;
    _submissionMessage = '';
    _submissionId = null;
    notifyListeners();
  }

  Future<List<WebDJ>> searchDJs(String query) => _api.searchDJs(query);

  Future<List<WebEvent>> searchEvents(String query) => _api.searchEvents(query);

  void addBoundDj(WebDJ dj) {
    if (_boundDjIds.contains(dj.id)) return;
    _boundDjIds = [..._boundDjIds, dj.id];
    _boundDjs = [..._boundDjs, dj];
    _markDirty();
  }

  void removeBoundDj(String id) {
    _boundDjIds = _boundDjIds.where((item) => item != id).toList();
    _boundDjs = _boundDjs.where((item) => item.id != id).toList();
    _markDirty();
  }

  void addBoundEvent(WebEvent event) {
    if (_boundEventIds.contains(event.id)) return;
    _boundEventIds = [..._boundEventIds, event.id];
    _boundEvents = [..._boundEvents, event];
    _markDirty();
  }

  void removeBoundEvent(String id) {
    _boundEventIds = _boundEventIds.where((item) => item != id).toList();
    _boundEvents = _boundEvents.where((item) => item.id != id).toList();
    _markDirty();
  }

  void _markDirty() {
    _errorMessage = null;
    _isSaved = false;
    _submittedForReview = false;
    _submissionMessage = '';
    _submissionId = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Cover image upload
  // ---------------------------------------------------------------------------

  /// Uploads a cover image from a local file path and sets the URL on success.
  Future<void> uploadCover(String localPath) async {
    _isLoading = true;
    _errorMessage = null;
    _submittedForReview = false;
    _submissionMessage = '';
    _submissionId = null;
    notifyListeners();

    try {
      final url = await _api.uploadCoverImage(localPath);
      _coverImageUrl = url;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Save (create or update)
  // ---------------------------------------------------------------------------

  /// Saves the article. Creates a new article or updates an existing one.
  ///
  /// Returns `true` on success.
  Future<bool> save() async {
    if (!canSave) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final payload = <String, dynamic>{
        'title': _title.trim(),
        'source': _source.trim(),
        'summary': _summary.trim(),
        'body': _content.trim(),
        'category': _category,
        if (_link.trim().isNotEmpty) 'link': _link.trim(),
        if (_coverImageUrl != null && _coverImageUrl!.isNotEmpty)
          'coverImageUrl': _coverImageUrl,
        if (_boundDjIds.isNotEmpty) 'boundDjIds': _boundDjIds,
        if (_boundEventIds.isNotEmpty) 'boundEventIds': _boundEventIds,
      };

      if (_articleId != null) {
        final result = await _api.updateArticle(_articleId!, payload);
        _applySaveResult(result);
      } else {
        final result = await _api.createArticle(payload);
        _applySaveResult(result);
      }

      _isLoading = false;
      _isSaved = true;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  void _applySaveResult(NewsArticleSaveResult result) {
    final article = result.article;
    if (article != null) {
      _articleId = article.id;
      return;
    }

    final submission = result.submission;
    if (submission != null) {
      _submittedForReview = true;
      _submissionId = submission.id;
      _submissionMessage =
          result.message.trim().isNotEmpty ? result.message.trim() : '已提交审核';
    }
  }

  String _normalizeCategory(String value) {
    const allowed = {
      'festival',
      'scene',
      'gear',
      'industry',
      'community',
    };
    return allowed.contains(value) ? value : 'festival';
  }
}
