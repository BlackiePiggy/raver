import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ravehub/bootstrap.dart';

/// Keeps live app-shell state fresh across foreground/background transitions.
class AppLifecycleSyncController with WidgetsBindingObserver {
  /// Creates an app lifecycle sync controller.
  AppLifecycleSyncController({required ProviderContainer container})
      : _container = container;

  final ProviderContainer _container;
  bool _isSyncing = false;
  Future<void>? _lastSync;

  /// Last resume-triggered sync, exposed for focused tests.
  @visibleForTesting
  Future<void>? get lastSync => _lastSync;

  /// Registers this controller with the Flutter binding.
  void attach() {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Unregisters this controller from the Flutter binding.
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _lastSync = _syncAfterResume();
  }

  Future<void> _syncAfterResume() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      await AppBootstrap.syncUnreadCountsIfNeeded(_container);
    } finally {
      _isSyncing = false;
    }
  }
}
