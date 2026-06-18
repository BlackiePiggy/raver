// Integration test entry point for RaveHub.
// Run with: flutter test integration_test/ --device-id <device>
//
// These tests exercise realistic public flows end-to-end on a real device or
// emulator against the live BFF service surface.

import 'package:integration_test/integration_test.dart';

import 'flows/clean_launch_flow_test.dart' as clean_launch;
import 'flows/public_live_flow_test.dart' as public_live;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  clean_launch.main();
  public_live.main();
}
