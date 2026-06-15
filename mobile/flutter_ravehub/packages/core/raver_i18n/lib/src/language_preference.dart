import 'dart:ui' as ui;

/// Supported application languages.
///
/// [system] defers to the device locale at runtime; the other values
/// represent explicit user overrides.
enum AppLanguage {
  /// Follow the device / OS language setting.
  system,

  /// Simplified Chinese.
  zh,

  /// English.
  en,

  /// Japanese.
  ja;

  /// Attempts to match a language code string (e.g. `'zh'`, `'en'`, `'ja'`)
  /// to an [AppLanguage] value. Returns [system] if no match is found.
  static AppLanguage fromCode(String code) {
    switch (code.toLowerCase()) {
      case 'zh':
        return AppLanguage.zh;
      case 'en':
        return AppLanguage.en;
      case 'ja':
        return AppLanguage.ja;
      default:
        return AppLanguage.system;
    }
  }
}

/// Manages the user's language preference and resolves the effective language
/// at runtime.
///
/// This is a lightweight singleton so that [lt] and [ll] can access the
/// current language without requiring a `BuildContext`.
///
/// ```dart
/// // At app startup:
/// AppLanguagePreference.instance.language = AppLanguage.system;
///
/// // After the user picks a language in settings:
/// AppLanguagePreference.instance.language = AppLanguage.ja;
/// ```
class AppLanguagePreference {
  AppLanguagePreference._();

  /// The shared global instance.
  static final AppLanguagePreference instance = AppLanguagePreference._();

  /// The user's chosen language preference.
  ///
  /// Defaults to [AppLanguage.system], which defers to the device locale.
  AppLanguage language = AppLanguage.system;

  /// Resolves [AppLanguage.system] to a concrete language by inspecting the
  /// device locale. Falls back to [AppLanguage.en] when the device language
  /// is not one of the three supported languages.
  AppLanguage get effectiveLanguage {
    if (language != AppLanguage.system) {
      return language;
    }
    return _resolveSystemLanguage();
  }

  /// Override point for tests: when non-null, [_resolveSystemLanguage] returns
  /// this value instead of reading [ui.PlatformDispatcher].
  AppLanguage? systemLanguageOverride;

  AppLanguage _resolveSystemLanguage() {
    if (systemLanguageOverride != null) {
      return systemLanguageOverride!;
    }

    final locale = ui.PlatformDispatcher.instance.locale;
    final code = locale.languageCode.toLowerCase();

    if (code == 'zh') return AppLanguage.zh;
    if (code == 'ja') return AppLanguage.ja;

    // Default to English for all other system locales.
    return AppLanguage.en;
  }
}
