import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_models/raver_models.dart';

Widget _buildApp(Widget child) {
  return MaterialApp(
    theme: RaverThemeData.darkTheme(),
    home: Scaffold(body: child),
  );
}

void main() {
  group('LoadPhaseBuilder — Feed (Circle)', () {
    testWidgets('shows loading state with CircularProgressIndicator',
        (tester) async {
      await tester.pumpWidget(
        _buildApp(
          LoadPhaseBuilder<List<Post>>(
            phase: const LoadPhase.loading(),
            onSuccess: (_) => const SizedBox.shrink(),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows post list on success', (tester) async {
      const alice = UserSummary(
        id: 'u1',
        username: 'alice',
        displayName: 'Alice',
      );
      const bob = UserSummary(
        id: 'u2',
        username: 'bob',
        displayName: 'Bob',
      );
      const posts = [
        Post(
          id: 'p1',
          content: 'Hello World',
          user: alice,
          likeCount: 0,
          commentCount: 0,
          repostCount: 0,
          saveCount: 0,
          shareCount: 0,
          createdAt: '2026-06-14T00:00:00Z',
        ),
        Post(
          id: 'p2',
          content: 'Flutter rocks',
          user: bob,
          likeCount: 5,
          commentCount: 2,
          repostCount: 0,
          saveCount: 0,
          shareCount: 0,
          isLiked: true,
          createdAt: '2026-06-14T00:00:00Z',
        ),
      ];

      await tester.pumpWidget(
        _buildApp(
          LoadPhaseBuilder<List<Post>>(
            phase: LoadPhase.success(posts),
            onSuccess: (ps) => ListView(
              children: ps
                  .map((p) => ListTile(key: Key(p.id), title: Text(p.content)))
                  .toList(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hello World'), findsOneWidget);
      expect(find.text('Flutter rocks'), findsOneWidget);
    });

    testWidgets('shows empty state when feed is empty', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          LoadPhaseBuilder<List<Post>>(
            phase: const LoadPhase.empty(),
            onSuccess: (_) => const SizedBox.shrink(),
            onEmpty: () => const EmptyStateView(
              icon: Icons.dynamic_feed_outlined,
              title: 'No Posts',
              subtitle: 'Follow someone to see their posts',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EmptyStateView), findsOneWidget);
      expect(find.text('No Posts'), findsOneWidget);
    });

    testWidgets('shows error state on failure', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          LoadPhaseBuilder<List<Post>>(
            phase: const LoadPhase.failure('Connection timeout'),
            onSuccess: (_) => const SizedBox.shrink(),
            onFailure: (msg) => ErrorStateView(
              title: 'Feed Unavailable',
              error: msg,
              retryLabel: 'Try Again',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ErrorStateView), findsOneWidget);
      expect(find.text('Connection timeout'), findsOneWidget);
    });

    testWidgets('GlassCard renders correctly in dark theme', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          const GlassCard(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Circle post preview'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GlassCard), findsOneWidget);
      expect(find.text('Circle post preview'), findsOneWidget);
    });
  });
}
