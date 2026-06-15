import 'language_preference.dart';
import 'translations_en.dart';
import 'translations_ja.dart';

/// Inline tri-lingual localization.
///
/// Returns the string matching the user's current effective language.
/// This is the primary API for localizing UI strings that are authored
/// inline rather than stored in the translation maps.
///
/// ```dart
/// Text(lt('发现', 'Discover', '発見'))
/// ```
String lt(String zh, String en, String ja) {
  switch (AppLanguagePreference.instance.effectiveLanguage) {
    case AppLanguage.zh:
      return zh;
    case AppLanguage.en:
      return en;
    case AppLanguage.ja:
      return ja;
    case AppLanguage.system:
      // effectiveLanguage never returns system, but the compiler requires it.
      return en;
  }
}

/// Lookup-based localization using a Chinese key.
///
/// Looks up [zhKey] in the English or Japanese translation map depending
/// on the current effective language. When the language is Chinese the key
/// itself is returned (it *is* the Chinese string). If a key is missing
/// from a translation map the Chinese key is returned as a fallback so
/// the UI never shows an empty string.
///
/// ```dart
/// Text(ll('发现'))  // -> 'Discover' or '発見' depending on language
/// ```
String ll(String zhKey) {
  switch (AppLanguagePreference.instance.effectiveLanguage) {
    case AppLanguage.zh:
      return zhKey;
    case AppLanguage.en:
      return translationsEn[zhKey] ?? zhKey;
    case AppLanguage.ja:
      return translationsJa[zhKey] ?? zhKey;
    case AppLanguage.system:
      return translationsEn[zhKey] ?? zhKey;
  }
}
