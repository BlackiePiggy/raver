import 'package:flutter/foundation.dart';

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

  String _category = 'news';
  String get category => _category;

  String? _coverImageUrl;
  String? get coverImageUrl => _coverImageUrl;

  List<String> _tags = [];
  List<String> get tags => List.unmodifiable(_tags);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _isSaved = false;
  bool get isSaved => _isSaved;

  bool get isEditing => _articleId != null;

  bool get canSave => _title.trim().isNotEmpty && _content.trim().isNotEmpty;

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
      _category = article.category;
      _coverImageUrl = article.coverImageUrl;
      _tags = article.tags?.toList() ?? [];
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
    String? category,
    List<String>? tags,
  }) {
    if (title != null) _title = title;
    if (content != null) _content = content;
    if (category != null) _category = category;
    if (tags != null) _tags = tags;
    _errorMessage = null;
    _isSaved = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Cover image upload
  // ---------------------------------------------------------------------------

  /// Uploads a cover image from a local file path and sets the URL on success.
  Future<void> uploadCover(String localPath) async {
    _isLoading = true;
    _errorMessage = null;
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
        'body': _content.trim(),
        'category': _category,
        if (_coverImageUrl != null) 'coverImageUrl': _coverImageUrl,
        if (_tags.isNotEmpty) 'tags': _tags,
      };

      if (_articleId != null) {
        await _api.updateArticle(_articleId!, payload);
      } else {
        final created = await _api.createArticle(payload);
        _articleId = created.id;
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
}
