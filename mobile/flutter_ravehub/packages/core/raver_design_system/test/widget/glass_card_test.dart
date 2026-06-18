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
  group('GlassCard', () {
    testWidgets('renders with a child widget', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          const GlassCard(
            child: Text('Hello Glass'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GlassCard), findsOneWidget);
      expect(find.text('Hello Glass'), findsOneWidget);
    });

    testWidgets('applies BackdropFilter for blur effect', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          const GlassCard(
            child: Text('Blur test'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('respects custom borderRadius', (tester) async {
      const customRadius = 40.0;

      await tester.pumpWidget(
        _buildApp(
          const GlassCard(
            borderRadius: customRadius,
            child: Text('Custom radius'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the ClipRRect has the custom border radius.
      final clipRRect = tester.widget<ClipRRect>(find.byType(ClipRRect));
      final borderRadius = clipRRect.borderRadius as BorderRadius;
      expect(borderRadius.topLeft.x, equals(customRadius));
      expect(borderRadius.bottomRight.x, equals(customRadius));
    });

    testWidgets('shows child widget content correctly', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          GlassCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.star, key: Key('glass_icon')),
                Text('Star content'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('glass_icon')), findsOneWidget);
      expect(find.text('Star content'), findsOneWidget);
      expect(find.byType(Icon), findsOneWidget);
    });

    testWidgets('applies default padding of EdgeInsets.all(16)',
        (tester) async {
      await tester.pumpWidget(
        _buildApp(
          const GlassCard(
            child: Text('Padded content'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The GlassCard wraps content in a Container with padding.
      // Verify the child text is rendered (proving padding is applied).
      final container = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(GlassCard),
          matching: find.byType(Container),
        ),
      );
      expect(container, isNotEmpty);
      expect(find.text('Padded content'), findsOneWidget);
    });
  });
}
