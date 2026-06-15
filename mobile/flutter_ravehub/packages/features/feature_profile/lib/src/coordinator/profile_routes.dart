import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../profile_me/profile_me_screen.dart';
import '../public_profile/user_profile_screen.dart';
import '../edit_profile/edit_profile_screen.dart';
import '../settings/settings_screen.dart';
import '../settings/language_setting_screen.dart';
import '../settings/appearance_setting_screen.dart';
import '../settings/account_security_screen.dart';
import '../settings/device_manage_screen.dart';
import '../settings/cache_manage_screen.dart';
import '../settings/permission_guide_screen.dart';
import '../settings/about_screen.dart';
import '../checkins/my_checkins_screen.dart';
import '../publishes/my_publishes_screen.dart';
import '../publishes/content_submission_detail_screen.dart';
import '../contributions/contribution_center_screen.dart';
import '../quiz/quiz_flow_screen.dart';
import '../quiz/quiz_result_screen.dart';
import '../personality/personality_flow_screen.dart';
import '../personality/personality_result_screen.dart';
import '../follow_list/follow_list_screen.dart';
import '../saves/saves_screen.dart';
import '../virtual_assets/virtual_assets_screen.dart';
import '../tools/qr_code_screen.dart';
import '../tools/route_tool_screen.dart';
import '../tools/widget_manage_screen.dart';
import '../tools/cinematic_banner_screen.dart';

/// Primary route for the Profile tab (current user's own profile).
List<RouteBase> buildProfileRoutes() => [
      GoRoute(
        path: '/profile',
        builder: (BuildContext context, GoRouterState state) =>
            const ProfileMeScreen(),
      ),
    ];

/// Detail / sub-page routes reachable from the Profile tab and elsewhere.
List<RouteBase> buildProfileDetailRoutes() => [
      // Public profile for any user
      GoRoute(
        path: '/users/:userId',
        builder: (BuildContext context, GoRouterState state) =>
            UserProfileScreen(userId: state.pathParameters['userId']!),
      ),

      // Edit own profile
      GoRoute(
        path: '/profile/edit',
        builder: (BuildContext context, GoRouterState state) =>
            const EditProfileScreen(),
      ),

      // Settings
      GoRoute(
        path: '/profile/settings',
        builder: (BuildContext context, GoRouterState state) =>
            const SettingsScreen(),
      ),

      // Settings sub-screens
      GoRoute(
        path: '/profile/settings/language',
        builder: (BuildContext context, GoRouterState state) =>
            const LanguageSettingScreen(),
      ),
      GoRoute(
        path: '/profile/settings/appearance',
        builder: (BuildContext context, GoRouterState state) =>
            const AppearanceSettingScreen(),
      ),
      GoRoute(
        path: '/profile/settings/account-security',
        builder: (BuildContext context, GoRouterState state) =>
            const AccountSecurityScreen(),
      ),
      GoRoute(
        path: '/profile/settings/devices',
        builder: (BuildContext context, GoRouterState state) =>
            const DeviceManageScreen(),
      ),
      GoRoute(
        path: '/profile/settings/cache',
        builder: (BuildContext context, GoRouterState state) =>
            const CacheManageScreen(),
      ),
      GoRoute(
        path: '/profile/settings/permissions',
        builder: (BuildContext context, GoRouterState state) =>
            const PermissionGuideScreen(),
      ),
      GoRoute(
        path: '/profile/settings/about',
        builder: (BuildContext context, GoRouterState state) =>
            const AboutScreen(),
      ),

      // Check-ins
      GoRoute(
        path: '/profile/checkins',
        builder: (BuildContext context, GoRouterState state) =>
            const MyCheckinsScreen(),
      ),

      // Publishes
      GoRoute(
        path: '/profile/publishes',
        builder: (BuildContext context, GoRouterState state) =>
            const MyPublishesScreen(),
      ),
      GoRoute(
        path: '/profile/publishes/:submissionId',
        builder: (BuildContext context, GoRouterState state) =>
            ContentSubmissionDetailScreen(
          submissionId: state.pathParameters['submissionId']!,
        ),
      ),

      // Contribution center
      GoRoute(
        path: '/profile/contributions',
        builder: (BuildContext context, GoRouterState state) =>
            const ContributionCenterScreen(),
      ),

      // Quiz flow
      GoRoute(
        path: '/profile/quiz',
        builder: (BuildContext context, GoRouterState state) =>
            const QuizFlowScreen(),
      ),

      // Personality flow
      GoRoute(
        path: '/profile/personality',
        builder: (BuildContext context, GoRouterState state) =>
            const PersonalityFlowScreen(),
      ),

      // Follow lists (followers / following)
      GoRoute(
        path: '/profile/follow-list/:listType',
        builder: (BuildContext context, GoRouterState state) =>
            FollowListScreen(
          listType: state.pathParameters['listType']!,
        ),
      ),
      GoRoute(
        path: '/users/:userId/follow-list/:listType',
        builder: (BuildContext context, GoRouterState state) =>
            FollowListScreen(
          userId: state.pathParameters['userId'],
          listType: state.pathParameters['listType']!,
        ),
      ),

      // Saves
      GoRoute(
        path: '/profile/saves',
        builder: (BuildContext context, GoRouterState state) =>
            const SavesScreen(),
      ),

      // Virtual assets
      GoRoute(
        path: '/profile/virtual-assets',
        builder: (BuildContext context, GoRouterState state) =>
            const VirtualAssetsScreen(),
      ),

      // Tools
      GoRoute(
        path: '/profile/tools/qr-code/:userId',
        builder: (BuildContext context, GoRouterState state) =>
            QrCodeScreen(userId: state.pathParameters['userId']!),
      ),
      GoRoute(
        path: '/profile/tools/route',
        builder: (BuildContext context, GoRouterState state) =>
            const RouteToolScreen(),
      ),
      GoRoute(
        path: '/profile/tools/widgets',
        builder: (BuildContext context, GoRouterState state) =>
            const WidgetManageScreen(),
      ),
      GoRoute(
        path: '/profile/tools/cinematic-banner',
        builder: (BuildContext context, GoRouterState state) =>
            const CinematicBannerScreen(),
      ),
    ];
