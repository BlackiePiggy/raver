import 'package:flutter/widgets.dart';

/// Broadcasts bottom-tab reselection events to screens inside the tab shell.
class RaverTabReselectionController extends ChangeNotifier {
  int _serial = 0;
  int? _tabIndex;

  /// Monotonic event id. Increases every time a tab is reselected.
  int get serial => _serial;

  /// The tab index from the most recent reselection event.
  int? get tabIndex => _tabIndex;

  /// Emits a reselection event for [tabIndex].
  void notifyReselected(int tabIndex) {
    _tabIndex = tabIndex;
    _serial++;
    notifyListeners();
  }
}

/// Provides a [RaverTabReselectionController] to tab root pages.
class RaverTabReselectionScope
    extends InheritedNotifier<RaverTabReselectionController> {
  const RaverTabReselectionScope({
    required RaverTabReselectionController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  /// Returns the nearest reselection controller, if one exists.
  static RaverTabReselectionController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<RaverTabReselectionScope>()
        ?.notifier;
  }
}

/// Calls [onReselected] when [tabIndex] is reselected in the shell.
class RaverTabReselectionListener extends StatefulWidget {
  const RaverTabReselectionListener({
    required this.tabIndex,
    required this.onReselected,
    required this.child,
    super.key,
  });

  final int tabIndex;
  final VoidCallback onReselected;
  final Widget child;

  @override
  State<RaverTabReselectionListener> createState() =>
      _RaverTabReselectionListenerState();
}

class _RaverTabReselectionListenerState
    extends State<RaverTabReselectionListener> {
  RaverTabReselectionController? _controller;
  int _seenSerial = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextController = RaverTabReselectionScope.maybeOf(context);
    if (identical(nextController, _controller)) return;

    _controller?.removeListener(_handleReselection);
    _controller = nextController;
    _seenSerial = _controller?.serial ?? 0;
    _controller?.addListener(_handleReselection);
  }

  @override
  void didUpdateWidget(covariant RaverTabReselectionListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabIndex != widget.tabIndex) {
      _seenSerial = _controller?.serial ?? 0;
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_handleReselection);
    super.dispose();
  }

  void _handleReselection() {
    final controller = _controller;
    if (controller == null || controller.serial == _seenSerial) return;

    _seenSerial = controller.serial;
    if (controller.tabIndex == widget.tabIndex) {
      widget.onReselected();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
