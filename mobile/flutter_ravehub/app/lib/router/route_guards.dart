import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ravehub/di/app_providers.dart';

/// Routes that require an authenticated session to access.
///
/// Any path starting with one of these prefixes will trigger a redirect to
/// `/login` when the user is unauthenticated.
const _protectedPrefixes = <String>[
  '/inbox',
  '/profile',
  '/settings',
  '/search',
  '/circle/compose',
  '/circle/squads',
];

/// Routes that are only meaningful for unauthenticated users.
///
/// Authenticated users navigating to these paths will be redirected to the
/// default logged-in landing page.
const _authOnlyPaths = <String>[
  '/login',
  '/register',
  '/forgot-password',
];

/// GoRouter redirect guard that enforces authentication requirements.
///
/// ## Behaviour
///
///  * **Unauthenticated + protected route** -> redirect to `/login`.
///  * **Authenticated + auth-only route** (e.g. `/login`) -> redirect to
///    `/discover`.
///  * Otherwise -> `null` (no redirect, proceed normally).
///
/// This function is intended to be passed as the `redirect` parameter of
/// [GoRouter].
String? authRedirectGuard(BuildContext context, GoRouterState state) {
  final container = ProviderScope.containerOf(context);
  final appState = container.read(appStateProvider);
  final isLoggedIn = appState.isLoggedIn;
  final location = state.matchedLocation;

  developer.log(
    'Route guard: location=$location, isLoggedIn=$isLoggedIn',
    name: 'Router',
  );

  // Unauthenticated users trying to access protected content.
  final isProtected =
      _protectedPrefixes.any((prefix) => location.startsWith(prefix));
  if (!isLoggedIn && isProtected) {
    // Preserve the intended destination so we can return after login.
    final returnTo = Uri.encodeComponent(state.uri.toString());
    return '/login?returnTo=$returnTo';
  }

  // Authenticated users who land on a login/register screen.
  final isAuthOnly = _authOnlyPaths.contains(location);
  if (isLoggedIn && isAuthOnly) {
    // Check if there is a stored return-to destination.
    final returnTo = state.uri.queryParameters['returnTo'];
    if (returnTo != null && returnTo.isNotEmpty) {
      return Uri.decodeComponent(returnTo);
    }
    return '/discover';
  }

  // No redirect needed.
  return null;
}
