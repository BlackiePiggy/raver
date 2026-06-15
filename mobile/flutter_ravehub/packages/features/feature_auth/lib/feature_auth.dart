/// Feature module for Authentication in RaveHub.
///
/// Provides login, registration, SMS verification, and related auth flows.
library feature_auth;

// Coordinator / routing
export 'src/coordinator/auth_routes.dart';

// Data layer
export 'src/data/auth_api.dart';
export 'src/data/auth_service_locator.dart';

// Screens
export 'src/presentation/login_screen.dart';
export 'src/presentation/password_reset_screen.dart';
export 'src/presentation/register_screen.dart';
export 'src/presentation/sms_verification_screen.dart';

// View models
export 'src/presentation/view_models/login_view_model.dart';
export 'src/presentation/view_models/password_reset_view_model.dart';
export 'src/presentation/view_models/register_view_model.dart';
