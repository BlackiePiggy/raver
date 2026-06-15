/// Tri-lingual inline localization for RaveHub (zh / en / ja).
///
/// ## Quick start
///
/// ```dart
/// import 'package:raver_i18n/raver_i18n.dart';
///
/// // Set the language (usually once at app startup):
/// AppLanguagePreference.instance.language = AppLanguage.system;
///
/// // Inline localization — provide all three translations at the call site:
/// Text(lt('发现', 'Discover', '発見'))
///
/// // Lookup localization — use a Chinese key, translations are in the maps:
/// Text(ll('发现'))
/// ```
library raver_i18n;

export 'src/l.dart' show lt, ll;
export 'src/language_preference.dart' show AppLanguage, AppLanguagePreference;
export 'src/translations_en.dart' show translationsEn;
export 'src/translations_ja.dart' show translationsJa;
export 'src/translations_zh.dart' show translationsZh;
