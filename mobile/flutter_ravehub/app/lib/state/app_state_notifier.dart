import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:raver_auth/raver_auth.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

/// Controls the app's visual appearance mode.
enum AppAppearance {
  /// Follow the OS dark/light mode setting.
  system,

  /// Force light mode.
  light,

  /// Force dark mode.
  dark,
}

// ---------------------------------------------------------------------------
// Persistence keys
// ---------------------------------------------------------------------------

abstract final class _PrefKeys {
  static const language = 'raver_preferred_language';
  static const appearance = 'raver_appearance';
}

// ---------------------------------------------------------------------------
// AppStateNotifier
// ---------------------------------------------------------------------------

/// Central application state, ported from the iOS `AppState.swift`.
///
/// Manages:
///  * **Session** -- current authentication session (token + user summary).
///  * **Language** -- user-chosen language preference persisted to disk.
///  * **Appearance** -- light / dark / system theme preference.
///  * **Badge counts** -- unread counters for the tab bar and inbox badges.
///  * **Enforcement status** -- account-level restrictions from the backend.
///
/// This is a [ChangeNotifier] intended to be provided via a Riverpod
/// [ChangeNotifierProvider] so that all consumer widgets rebuild on mutation.
class AppStateNotifier extends ChangeNotifier {
  /// Creates an [AppStateNotifier].
  ///
  /// Requires a [SessionTokenStore] for reading / clearing persisted tokens.
  AppStateNotifier({required SessionTokenStore tokenStore})
      : _tokenStore = tokenStore;

  final SessionTokenStore _tokenStore;

  // ---- Session ------------------------------------------------------------

  Session? _session;

  /// Whether the user has an active session.
  bool get isLoggedIn => _session != null;

  /// The current session, or `null` when unauthenticated.
  Session? get session => _session;

  // ---- Language -----------------------------------------------------------

  AppLanguage _preferredLanguage = AppLanguage.system;

  /// The user's preferred display language.
  AppLanguage get preferredLanguage => _preferredLanguage;

  // ---- Appearance ---------------------------------------------------------

  AppAppearance _appearance = AppAppearance.system;

  /// The user's preferred appearance mode.
  AppAppearance get appearance => _appearance;

  // ---- Badge counts -------------------------------------------------------

  /// Unread count for the community / Circle tab.
  int communityUnreadCount = 0;

  /// Unread count for followed events.
  int followedEventsUnreadCount = 0;

  /// Unread count for followed DJs.
  int followedDJsUnreadCount = 0;

  /// Unread count for followed brands / labels.
  int followedBrandsUnreadCount = 0;

  /// Sum of all unread badge counts (used by the Inbox tab badge).
  int get totalUnreadCount =>
      communityUnreadCount +
      followedEventsUnreadCount +
      followedDJsUnreadCount +
      followedBrandsUnreadCount;

  // ---- Enforcement --------------------------------------------------------

  /// Non-null when the backend has flagged this account with a restriction.
  AccountEnforcementStatus? enforcementStatus;

  // =========================================================================
  // Session management
  // =========================================================================

  /// Attempts to restore a previously persisted session.
  ///
  /// If valid tokens are found in [SessionTokenStore] the app transitions to
  /// a logged-in state with a stub [Session] (the full user profile is fetched
  /// lazily on the first authenticated screen).
  ///
  /// Returns `true` if a session was restored successfully.
  Future<bool> restoreSession() async {
    try {
      final hasTokens = await _tokenStore.hasTokens();
      if (!hasTokens) return false;

      final accessToken = await _tokenStore.readAccessToken();
      final refreshToken = await _tokenStore.readRefreshToken();
      if (accessToken == null || refreshToken == null) return false;

      final expiresAt = await _tokenStore.readAccessTokenExpiresAt();
      final expiresIn = expiresAt != null
          ? expiresAt.difference(DateTime.now()).inSeconds
          : 3600;

      // Create a lightweight placeholder session. The full user profile will
      // be fetched by the home screen once the app is interactive.
      _session = Session(
        token: accessToken,
        refreshToken: refreshToken,
        accessTokenExpiresIn: expiresIn > 0 ? expiresIn : 3600,
        user: const UserSummary(
          id: '',
          username: '',
          displayName: '',
        ),
      );
      notifyListeners();
      developer.log('Session restored from secure storage.', name: 'AppState');
      return true;
    } catch (e) {
      developer.log(
        'Failed to restore session: $e',
        name: 'AppState',
        level: 900,
      );
      return false;
    }
  }

  /// Sets a new session after a successful login or token refresh.
  void setSession(Session session) {
    _session = session;
    notifyListeners();
  }

  /// Clears the current session and wipes stored tokens.
  ///
  /// Also resets badge counts and enforcement status.
  Future<void> clearSession() async {
    _session = null;
    communityUnreadCount = 0;
    followedEventsUnreadCount = 0;
    followedDJsUnreadCount = 0;
    followedBrandsUnreadCount = 0;
    enforcementStatus = null;
    notifyListeners();
    await _tokenStore.clearTokens();
    developer.log('Session cleared.', name: 'AppState');
  }

  // =========================================================================
  // Language
  // =========================================================================

  /// Updates the user's preferred language and persists it.
  ///
  /// Also synchronises the global [AppLanguagePreference] singleton so that
  /// all calls to [lt] / [ll] immediately reflect the new language.
  Future<void> setPreferredLanguage(AppLanguage lang) async {
    if (_preferredLanguage == lang) return;
    _preferredLanguage = lang;
    AppLanguagePreference.instance.language = lang;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_PrefKeys.language, lang.name);
  }

  /// Loads the persisted language preference from disk.
  Future<void> restoreLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_PrefKeys.language);
    if (stored != null) {
      _preferredLanguage = AppLanguage.fromCode(stored);
    }
    AppLanguagePreference.instance.language = _preferredLanguage;
  }

  // =========================================================================
  // Appearance
  // =========================================================================

  /// Updates the visual appearance mode and persists it.
  Future<void> setAppearance(AppAppearance appearance) async {
    if (_appearance == appearance) return;
    _appearance = appearance;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_PrefKeys.appearance, appearance.name);
  }

  /// Loads the persisted appearance preference from disk.
  Future<void> restoreAppearancePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_PrefKeys.appearance);
    if (stored != null) {
      _appearance = AppAppearance.values.firstWhere(
        (e) => e.name == stored,
        orElse: () => AppAppearance.system,
      );
    }
  }

  // =========================================================================
  // Badge counts
  // =========================================================================

  /// Selectively updates one or more unread badge counts.
  void updateUnreadCounts({
    int? community,
    int? events,
    int? djs,
    int? brands,
  }) {
    var changed = false;

    if (community != null && communityUnreadCount != community) {
      communityUnreadCount = community;
      changed = true;
    }
    if (events != null && followedEventsUnreadCount != events) {
      followedEventsUnreadCount = events;
      changed = true;
    }
    if (djs != null && followedDJsUnreadCount != djs) {
      followedDJsUnreadCount = djs;
      changed = true;
    }
    if (brands != null && followedBrandsUnreadCount != brands) {
      followedBrandsUnreadCount = brands;
      changed = true;
    }

    if (changed) notifyListeners();
  }
}
