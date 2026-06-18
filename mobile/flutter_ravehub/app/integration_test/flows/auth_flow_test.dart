import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group(
    'Authenticated live flows',
    skip: 'Requires real-account credentials and protected live-service QA.',
    () {
      testWidgets(
        'profile, checkins, quiz, personality, and squads',
        (tester) async {},
      );
    },
  );
}
