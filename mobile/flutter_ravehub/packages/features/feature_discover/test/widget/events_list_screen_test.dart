import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raver_design_system/raver_design_system.dart';

/// Helper that wraps a widget with MaterialApp + RaverTheme.
Widget _buildApp(Widget child) {
  return MaterialApp(
    theme: RaverThemeData.darkTheme(),
    home: Scaffold(body: child),
  );
}

void main() {
  group('LoadPhaseBuilder (used by EventsListScreen)', () {
    testWidgets('shows loading indicator when phase is loading',
        (tester) async {
      await tester.pumpWidget(
        _buildApp(
          LoadPhaseBuilder<List<String>>(
            phase: const LoadPhase.loading(),
            onSuccess: (_) => const SizedBox.shrink(),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows success content when phase is success',
        (tester) async {
      const data = ['Event 1', 'Event 2', 'Event 3'];

      await tester.pumpWidget(
        _buildApp(
          LoadPhaseBuilder<List<String>>(
            phase: const LoadPhase.success(data),
            onSuccess: (events) => ListView(
              children: events
                  .map((e) => ListTile(
                        key: Key(e),
                        title: Text(e),
                      ))
                  .toList(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Event 1'), findsOneWidget);
      expect(find.text('Event 2'), findsOneWidget);
      expect(find.text('Event 3'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('shows empty state when phase is empty', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          LoadPhaseBuilder<List<String>>(
            phase: const LoadPhase.empty(),
            onSuccess: (_) => const SizedBox.shrink(),
            onEmpty: () => const EmptyStateView(
              icon: Icons.event_busy,
              title: 'No Events',
              subtitle: 'Try different filters',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EmptyStateView), findsOneWidget);
      expect(find.text('No Events'), findsOneWidget);
      expect(find.text('Try different filters'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('shows error state when phase is failure', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          LoadPhaseBuilder<List<String>>(
            phase: const LoadPhase.failure('Network error'),
            onSuccess: (_) => const SizedBox.shrink(),
            onFailure: (error) => ErrorStateView(
              title: 'Failed to Load',
              error: error,
              retryLabel: 'Retry',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ErrorStateView), findsOneWidget);
      expect(find.text('Failed to Load'), findsOneWidget);
      expect(find.text('Network error'), findsOneWidget);
    });

    testWidgets('shows custom loading skeleton when provided',
        (tester) async {
      await tester.pumpWidget(
        _buildApp(
          LoadPhaseBuilder<List<String>>(
            phase: const LoadPhase.loading(),
            onSuccess: (_) => const SizedBox.shrink(),
            onLoading: () => const Center(
              child: Text('Loading skeleton placeholder'),
            ),
          ),
        ),
      );

      expect(find.text('Loading skeleton placeholder'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
