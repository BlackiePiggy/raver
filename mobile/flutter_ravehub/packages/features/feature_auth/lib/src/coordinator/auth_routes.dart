import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../presentation/login_screen.dart';
import '../presentation/password_reset_screen.dart';
import '../presentation/register_screen.dart';
import '../presentation/sms_verification_screen.dart';

/// Auth-related routes (login, registration, SMS verification, etc.).
List<RouteBase> buildAuthRoutes() => [
      GoRoute(
        path: '/login',
        builder: (BuildContext context, GoRouterState state) => LoginScreen(
          returnTo: state.uri.queryParameters['returnTo'],
        ),
      ),
      GoRoute(
        path: '/register',
        builder: (BuildContext context, GoRouterState state) => RegisterScreen(
          returnTo: state.uri.queryParameters['returnTo'],
        ),
      ),
      GoRoute(
        path: '/verify-code',
        builder: (BuildContext context, GoRouterState state) {
          final query = state.uri.queryParameters;
          final type = switch (query['type']) {
            'email' => VerificationTargetType.email,
            'sms' => VerificationTargetType.sms,
            _ => null,
          };
          return SmsVerificationScreen(
            destination:
                query['destination'] ?? query['email'] ?? query['phone'] ?? '',
            type: type,
            email: query['email'],
            phone: query['phone'],
            countryCode: query['countryCode'] ?? '+86',
            returnTo: query['returnTo'],
          );
        },
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (BuildContext context, GoRouterState state) =>
            const PasswordResetScreen(),
      ),
    ];
