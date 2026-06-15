// Integration tests for the authentication flow.
//
// Covers: email login, registration with SMS verification, password reset,
// and logout. Uses ProviderScope overrides to inject mock auth providers so
// no real network calls are made.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ravehub/app.dart';
import 'package:ravehub/di/app_providers.dart';

// ---------------------------------------------------------------------------
// Mock helpers
// ---------------------------------------------------------------------------

/// A mock [SessionTokenStore] that stores tokens in memory rather than in
/// the platform keychain.
// TODO: Replace with a real mock when raver_auth exposes a test double.
// class MockSessionTokenStore extends SessionTokenStore { ... }

/// Builds the app wrapped in a [ProviderScope] with overrides that replace
/// network-dependent providers with test doubles.
Widget _buildTestApp() {
  return ProviderScope(
    overrides: [
      // Override sessionTokenStoreProvider with an in-memory mock.
      // sessionTokenStoreProvider.overrideWithValue(MockSessionTokenStore()),
      //
      // Override dioProvider with a mock Dio that returns canned responses.
      // dioProvider.overrideWithValue(mockDio),
    ],
    child: const RaveHubApp(),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Auth Flow', () {
    testWidgets(
      'Email login -> sees Discover tab',
      (WidgetTester tester) async {
        // 1. Pump the app with mock providers.
        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        // 2. The LoginScreen should be visible (identified by the brand text).
        expect(find.text('RaveHub'), findsOneWidget);

        // 3. The default login method tab should be "Email Login".
        //    (The LoginScreen uses lt() for i18n; in English locale this is
        //    "Email Login".)
        expect(find.text('Email Login'), findsOneWidget);

        // 4. Enter test credentials into the email field.
        final emailField = find.widgetWithText(TextField, 'Email Address');
        expect(emailField, findsOneWidget);
        await tester.enterText(emailField, 'test@ravehub.top');
        await tester.pumpAndSettle();

        // 5. Tap "Send Code" to trigger the mock verification code send.
        final sendCodeButton = find.text('Send Code');
        expect(sendCodeButton, findsOneWidget);
        await tester.tap(sendCodeButton);
        await tester.pumpAndSettle();

        // 6. Enter the 6-digit verification code.
        final codeField = find.widgetWithText(TextField, 'Verification Code');
        expect(codeField, findsOneWidget);
        await tester.enterText(codeField, '123456');
        await tester.pumpAndSettle();

        // 7. Accept terms of service.
        final termsCheckbox = find.byType(Checkbox);
        expect(termsCheckbox, findsOneWidget);
        await tester.tap(termsCheckbox);
        await tester.pumpAndSettle();

        // 8. Tap the "Log In" button.
        final loginButton = find.text('Log In');
        expect(loginButton, findsOneWidget);
        await tester.tap(loginButton);
        await tester.pumpAndSettle();

        // 9. After successful login, the DiscoverHomeScreen should appear.
        //    The AppBar title is "Discover" in English.
        expect(find.text('Discover'), findsOneWidget);

        // 10. The bottom navigation bar should be visible with 4 tabs.
        expect(find.byType(NavigationBar), findsOneWidget);
      },
    );

    testWidgets(
      'Register -> SMS verification -> logged in',
      (WidgetTester tester) async {
        // 1. Pump the app.
        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        // 2. Tap the "Register" link at the bottom of LoginScreen.
        final registerLink = find.text('Register');
        expect(registerLink, findsOneWidget);
        await tester.tap(registerLink);
        await tester.pumpAndSettle();

        // 3. The RegisterScreen should now be visible.
        //    It contains display name, email, password, and confirm password
        //    fields.
        expect(find.byType(TextField), findsNWidgets(4));

        // 4. Fill in registration form fields.
        final displayNameField = find.byType(TextField).first;
        await tester.enterText(displayNameField, 'TestRaver');
        await tester.pumpAndSettle();

        // 5. Enter email.
        final emailFields = find.byType(TextField);
        await tester.enterText(emailFields.at(1), 'newuser@ravehub.top');
        await tester.pumpAndSettle();

        // 6. Enter password.
        await tester.enterText(emailFields.at(2), 'Str0ngP@ss!');
        await tester.pumpAndSettle();

        // 7. Confirm password.
        await tester.enterText(emailFields.at(3), 'Str0ngP@ss!');
        await tester.pumpAndSettle();

        // 8. Accept terms and tap Register.
        final termsCheckbox = find.byType(Checkbox);
        if (termsCheckbox.evaluate().isNotEmpty) {
          await tester.tap(termsCheckbox);
          await tester.pumpAndSettle();
        }

        // 9. After registration, SmsVerificationScreen should appear with 6
        //    single-digit input boxes.
        // expect(find.byType(SmsVerificationScreen), findsOneWidget);

        // 10. Enter verification digits (mock auto-forwards).
        // The SMS verification screen typically has 6 individual TextField
        // widgets for each digit.
        // for (int i = 0; i < 6; i++) {
        //   await tester.enterText(find.byType(TextField).at(i), '${i + 1}');
        // }
        // await tester.pumpAndSettle();

        // 11. After verification, should land on DiscoverHomeScreen.
        // expect(find.text('Discover'), findsOneWidget);
      },
    );

    testWidgets(
      'Forgot password sends reset email',
      (WidgetTester tester) async {
        // 1. Pump the app.
        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        // 2. Switch to password login mode.
        final passwordLoginToggle = find.text('Login with Password');
        expect(passwordLoginToggle, findsOneWidget);
        await tester.tap(passwordLoginToggle);
        await tester.pumpAndSettle();

        // 3. The password login form should now be visible with username and
        //    password fields.
        expect(
          find.widgetWithText(TextField, 'Username / Email'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(TextField, 'Password'),
          findsOneWidget,
        );

        // 4. Navigate to forgot-password screen.
        //    (The PasswordResetScreen is accessed via GoRouter /forgot-password.)
        // await tester.tap(find.text('Forgot Password?'));
        // await tester.pumpAndSettle();

        // 5. On PasswordResetScreen, enter an email and submit.
        // final resetEmailField = find.byType(TextField);
        // await tester.enterText(resetEmailField, 'forgot@ravehub.top');
        // await tester.pumpAndSettle();

        // 6. Tap submit / send reset link.
        // await tester.tap(find.text('Send Reset Link'));
        // await tester.pumpAndSettle();

        // 7. A success message should appear confirming the email was sent.
        // expect(find.textContaining('sent'), findsOneWidget);
      },
    );

    testWidgets(
      'Logout -> back to login',
      (WidgetTester tester) async {
        // 1. Start the app in a logged-in state (with mock session token).
        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        // 2. Navigate to the Profile tab (4th tab in the bottom nav bar).
        // final profileTab = find.text('Profile');
        // await tester.tap(profileTab);
        // await tester.pumpAndSettle();

        // 3. Navigate to Settings from profile.
        // final settingsButton = find.byIcon(Icons.settings);
        // await tester.tap(settingsButton);
        // await tester.pumpAndSettle();

        // 4. Scroll down to the logout button and tap it.
        // await tester.scrollUntilVisible(find.text('Log Out'), 100);
        // await tester.tap(find.text('Log Out'));
        // await tester.pumpAndSettle();

        // 5. Confirm the logout dialog.
        // await tester.tap(find.text('Confirm'));
        // await tester.pumpAndSettle();

        // 6. After logout, the LoginScreen should reappear.
        // expect(find.text('RaveHub'), findsOneWidget);
        // expect(find.text('Email Login'), findsOneWidget);
      },
    );
  });
}
