import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ravehub/app.dart';
import 'package:ravehub/di/app_providers.dart';

void main() {
  testWidgets('RaveHub app builds', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const SizedBox.shrink(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          routerProvider.overrideWithValue(router),
        ],
        child: const RaveHubApp(),
      ),
    );

    expect(find.byType(RaveHubApp), findsOneWidget);
  });
}
