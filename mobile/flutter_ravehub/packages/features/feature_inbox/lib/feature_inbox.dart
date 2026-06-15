/// Feature module for the Inbox tab of RaveHub.
///
/// Provides notifications and alerts organized into five sections:
/// followed events, followed DJs, followed brands, content reviews,
/// and general alerts.
library feature_inbox;

// Coordinator / routing
export 'src/coordinator/inbox_routes.dart';

// Data layer
export 'src/data/notification_api.dart';
export 'src/data/notification_repository.dart';
export 'src/data/inbox_service_locator.dart';

// View models
export 'src/presentation/view_models/inbox_view_model.dart';

// Screens
export 'src/presentation/inbox_home_screen.dart';
export 'src/presentation/alert_category_screen.dart';
export 'src/presentation/followed_events_inbox_screen.dart';
export 'src/presentation/followed_djs_inbox_screen.dart';
export 'src/presentation/followed_brands_inbox_screen.dart';
export 'src/presentation/content_reviews_inbox_screen.dart';
export 'src/presentation/entity_change_detail_screen.dart';
export 'src/presentation/notification_settings_screen.dart';
