import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:ravehub/di/app_providers.dart';
import 'package:ravehub/router/app_router.dart';

/// The main app scaffold displayed when the user is inside the tab shell.
///
/// Renders the active tab's content with a custom floating bottom navigation
/// bar overlaid on top. The tab bar uses the raver design system's visual
/// language (rounded pill shape, frosted glass background, neon accent
/// colours for the active tab).
///
/// Badge counts for the Inbox tab are sourced from [AppStateNotifier].
class RaverShellScaffold extends ConsumerWidget {
  /// Creates a [RaverShellScaffold].
  const RaverShellScaffold({required this.navigationShell, super.key});

  /// The [StatefulNavigationShell] that manages tab state persistence.
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final totalUnread = appState.totalUnreadCount;

    return Scaffold(
      // Let tab content extend behind the floating tab bar.
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: RaverFloatingTabBar(
        selectedIndex: navigationShell.currentIndex,
        inboxBadgeCount: totalUnread,
        onTap: (index) => _onTabTapped(context, index),
        onSearchTap: () => context.push('/search'),
      ),
    );
  }

  void _onTabTapped(BuildContext context, int index) {
    // GoRouter's StatefulNavigationShell handles tab switching and state
    // preservation. Setting `initialLocation: true` pops the tab's
    // navigation stack back to its root when the user re-taps the already
    // active tab.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}
