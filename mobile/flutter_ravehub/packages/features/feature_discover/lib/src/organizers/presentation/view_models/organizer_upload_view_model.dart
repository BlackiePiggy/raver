import 'package:flutter/foundation.dart';

import '../../data/organizer_api.dart';

/// Steps in the organizer/festival upload wizard.
enum OrganizerUploadStep {
  basicInfo,
  media,
  details,
  submit,
}

/// ViewModel for the multi-step organizer/festival upload flow.
///
/// Manages the wizard state, form fields, cover image upload, and final
/// submission.
class OrganizerUploadViewModel extends ChangeNotifier {
  OrganizerUploadViewModel({required OrganizerApi api}) : _api = api;

  final OrganizerApi _api;

  // ---------------------------------------------------------------------------
  // Wizard state
  // ---------------------------------------------------------------------------

  OrganizerUploadStep _currentStep = OrganizerUploadStep.basicInfo;
  OrganizerUploadStep get currentStep => _currentStep;

  int get currentStepIndex => _currentStep.index;
  int get totalSteps => OrganizerUploadStep.values.length;

  bool get isFirstStep => _currentStep == OrganizerUploadStep.basicInfo;
  bool get isLastStep => _currentStep == OrganizerUploadStep.submit;

  // ---------------------------------------------------------------------------
  // Form fields
  // ---------------------------------------------------------------------------

  String _name = '';
  String get name => _name;

  String _description = '';
  String get description => _description;

  String _country = '';
  String get country => _country;

  String _city = '';
  String get city => _city;

  String _website = '';
  String get website => _website;

  String? _coverImageUrl;
  String? get coverImageUrl => _coverImageUrl;

  int? _foundingYear;
  int? get foundingYear => _foundingYear;

  List<String> _genres = [];
  List<String> get genres => List.unmodifiable(_genres);

  List<String> _aliases = [];
  List<String> get aliases => List.unmodifiable(_aliases);

  // ---------------------------------------------------------------------------
  // Status
  // ---------------------------------------------------------------------------

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _isSaved = false;
  bool get isSaved => _isSaved;

  /// Whether the basic info step has enough data to proceed.
  bool get canProceedFromBasicInfo => _name.trim().isNotEmpty;

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  /// Advances to the next wizard step.
  void nextStep() {
    final steps = OrganizerUploadStep.values;
    final nextIndex = _currentStep.index + 1;
    if (nextIndex < steps.length) {
      _currentStep = steps[nextIndex];
      notifyListeners();
    }
  }

  /// Returns to the previous wizard step.
  void prevStep() {
    final steps = OrganizerUploadStep.values;
    final prevIndex = _currentStep.index - 1;
    if (prevIndex >= 0) {
      _currentStep = steps[prevIndex];
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Field setters
  // ---------------------------------------------------------------------------

  void setName(String value) {
    _name = value;
    notifyListeners();
  }

  void setDescription(String value) {
    _description = value;
    notifyListeners();
  }

  void setCountry(String value) {
    _country = value;
    notifyListeners();
  }

  void setCity(String value) {
    _city = value;
    notifyListeners();
  }

  void setWebsite(String value) {
    _website = value;
    notifyListeners();
  }

  void setFoundingYear(int? value) {
    _foundingYear = value;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Genres
  // ---------------------------------------------------------------------------

  void addGenre(String genre) {
    if (genre.trim().isNotEmpty && !_genres.contains(genre.trim())) {
      _genres = [..._genres, genre.trim()];
      notifyListeners();
    }
  }

  void removeGenre(int index) {
    if (index >= 0 && index < _genres.length) {
      _genres = List.from(_genres)..removeAt(index);
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Aliases
  // ---------------------------------------------------------------------------

  void addAlias(String alias) {
    if (alias.trim().isNotEmpty && !_aliases.contains(alias.trim())) {
      _aliases = [..._aliases, alias.trim()];
      notifyListeners();
    }
  }

  void removeAlias(int index) {
    if (index >= 0 && index < _aliases.length) {
      _aliases = List.from(_aliases)..removeAt(index);
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Cover image upload
  // ---------------------------------------------------------------------------

  /// Uploads a cover image from a local file path.
  Future<void> uploadCover(String localPath) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final url = await _api.uploadFestivalCover(localPath);
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
  // Submit
  // ---------------------------------------------------------------------------

  /// Submits the festival data to the server.
  ///
  /// Returns `true` on success.
  Future<bool> submit() async {
    if (_name.trim().isEmpty) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final payload = <String, dynamic>{
        'name': _name.trim(),
        if (_description.trim().isNotEmpty) 'description': _description.trim(),
        if (_country.trim().isNotEmpty) 'country': _country.trim(),
        if (_city.trim().isNotEmpty) 'city': _city.trim(),
        if (_website.trim().isNotEmpty) 'website': _website.trim(),
        if (_coverImageUrl != null) 'coverImageUrl': _coverImageUrl,
        if (_foundingYear != null) 'foundingYear': _foundingYear,
        if (_genres.isNotEmpty) 'genres': _genres,
        if (_aliases.isNotEmpty) 'aliases': _aliases,
      };

      await _api.createFestival(payload);

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
