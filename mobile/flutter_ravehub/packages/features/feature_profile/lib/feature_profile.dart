/// Feature module for the Profile section of RaveHub.
///
/// Provides user profile management including viewing/editing profiles,
/// settings, check-ins, publishes, contributions, quizzes, personality
/// flows, follow lists, saves, virtual assets, and tools.
library feature_profile;

// Coordinator / routing
export 'src/coordinator/profile_routes.dart';

// Service locator
export 'src/_shared/profile_service_locator.dart';

// Data layer
export 'src/profile_me/data/profile_api.dart';
export 'src/profile_me/data/profile_repository.dart';
export 'src/checkins/data/checkin_api.dart';
export 'src/publishes/data/publishes_api.dart';
export 'src/quiz/data/quiz_api.dart';
export 'src/personality/data/personality_api.dart';
export 'src/follow_list/data/follow_api.dart';
export 'src/virtual_assets/data/virtual_asset_api.dart';

// Profile Me
export 'src/profile_me/profile_me_screen.dart';
export 'src/profile_me/presentation/widgets/profile_header.dart';
export 'src/profile_me/presentation/widgets/profile_stats_row.dart';
export 'src/profile_me/presentation/view_models/profile_me_view_model.dart';

// Public Profile
export 'src/public_profile/user_profile_screen.dart';
export 'src/public_profile/view_models/user_profile_view_model.dart';

// Edit Profile
export 'src/edit_profile/edit_profile_screen.dart';
export 'src/edit_profile/view_models/edit_profile_view_model.dart';

// Settings
export 'src/settings/settings_screen.dart';
export 'src/settings/language_setting_screen.dart';
export 'src/settings/appearance_setting_screen.dart';
export 'src/settings/account_security_screen.dart';
export 'src/settings/device_manage_screen.dart';
export 'src/settings/cache_manage_screen.dart';
export 'src/settings/permission_guide_screen.dart';
export 'src/settings/about_screen.dart';
export 'src/settings/view_models/settings_view_model.dart';

// Checkins
export 'src/checkins/my_checkins_screen.dart';
export 'src/checkins/view_models/checkin_view_model.dart';

// Publishes
export 'src/publishes/my_publishes_screen.dart';
export 'src/publishes/content_submission_detail_screen.dart';
export 'src/publishes/view_models/publishes_view_model.dart';

// Contributions
export 'src/contributions/contribution_center_screen.dart';
export 'src/contributions/view_models/contribution_view_model.dart';

// Quiz
export 'src/quiz/quiz_flow_screen.dart';
export 'src/quiz/quiz_result_screen.dart';
export 'src/quiz/view_models/quiz_view_model.dart';

// Personality
export 'src/personality/personality_flow_screen.dart';
export 'src/personality/personality_result_screen.dart';
export 'src/personality/view_models/personality_view_model.dart';
export 'src/personality/widgets/personality_share_card.dart';

// Follow List
export 'src/follow_list/follow_list_screen.dart';
export 'src/follow_list/view_models/follow_list_view_model.dart';

// Saves
export 'src/saves/saves_screen.dart';
export 'src/saves/view_models/saves_view_model.dart';

// Virtual Assets
export 'src/virtual_assets/virtual_assets_screen.dart';
export 'src/virtual_assets/virtual_asset_detail_screen.dart';
export 'src/virtual_assets/view_models/virtual_asset_view_model.dart';

// Tools
export 'src/tools/qr_code_screen.dart';
export 'src/tools/route_tool_screen.dart';
export 'src/tools/widget_manage_screen.dart';
export 'src/tools/cinematic_banner_screen.dart';
