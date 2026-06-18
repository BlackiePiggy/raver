import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:feature_discover/feature_discover.dart';
import 'package:ravehub/di/app_providers.dart';

/// The main app scaffold displayed when the user is inside the tab shell.
///
/// Renders the active tab's content with a custom floating bottom navigation
/// bar overlaid on top. The tab bar uses the raver design system's visual
/// language (rounded pill shape, frosted glass background, neon accent
/// colours for the active tab).
///
/// Badge counts for the Inbox tab are sourced from [AppStateNotifier].
class RaverShellScaffold extends ConsumerStatefulWidget {
  /// Creates a [RaverShellScaffold].
  const RaverShellScaffold({required this.navigationShell, super.key});

  /// The [StatefulNavigationShell] that manages tab state persistence.
  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<RaverShellScaffold> createState() => _RaverShellScaffoldState();
}

class _RaverShellScaffoldState extends ConsumerState<RaverShellScaffold> {
  late final RaverTabReselectionController _tabReselectionController;

  @override
  void initState() {
    super.initState();
    _tabReselectionController = RaverTabReselectionController();
  }

  @override
  void dispose() {
    _tabReselectionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final totalUnread = appState.totalUnreadCount;

    return Scaffold(
      // Let tab content extend behind the floating tab bar.
      extendBody: true,
      body: RaverTabReselectionScope(
        controller: _tabReselectionController,
        child: widget.navigationShell,
      ),
      bottomNavigationBar: RaverFloatingTabBar(
        selectedIndex: widget.navigationShell.currentIndex,
        inboxBadgeCount: totalUnread,
        onTap: (index) => _onTabTapped(context, index),
        onSearchTap: () => _openGlobalSearch(context),
      ),
    );
  }

  void _openGlobalSearch(BuildContext context) {
    showGeneralDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      barrierDismissible: true,
      barrierLabel: 'Global Search',
      pageBuilder: (_, __, ___) => SearchOverlayScreen(
        onDismiss: () => Navigator.of(context).pop(),
      ),
      transitionDuration: const Duration(milliseconds: 200),
      transitionBuilder: (_, animation, __, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
            ),
            child: child,
          ),
        );
      },
    );
  }

  void _onTabTapped(BuildContext context, int index) {
    final isReselection = index == widget.navigationShell.currentIndex;
    // GoRouter's StatefulNavigationShell handles tab switching and state
    // preservation. Setting `initialLocation: true` pops the tab's
    // navigation stack back to its root when the user re-taps the already
    // active tab.
    widget.navigationShell.goBranch(
      index,
      initialLocation: isReselection,
    );
    if (isReselection) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _tabReselectionController.notifyReselected(index);
      });
    }
  }
}
