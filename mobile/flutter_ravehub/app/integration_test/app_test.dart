// Integration test entry point for RaveHub.
// Run with: flutter test integration_test/ --device-id <device>
//
// These tests exercise realistic user flows end-to-end on a real device or
// emulator. Mock providers are injected via ProviderScope overrides to avoid
// actual network calls while still verifying the full widget tree, navigation,
// and state management.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'flows/auth_flow_test.dart' as auth;
import 'flows/discover_flow_test.dart' as discover;
import 'flows/post_flow_test.dart' as post;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  auth.main();
  discover.main();
  post.main();
}
