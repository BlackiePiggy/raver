/// Feature module for the Circle tab of RaveHub.
///
/// Provides the social layer: feeds, squads, raver IDs, and ratings.
library feature_circle;

// Coordinator / routing
export 'src/coordinator/circle_routes.dart';
export 'src/coordinator/circle_home_screen.dart';

// Feed - data
export 'src/feed/data/feed_api.dart';
export 'src/feed/data/feed_repository.dart';

// Feed - presentation
export 'src/feed/presentation/feed_screen.dart';
export 'src/feed/presentation/post_detail_screen.dart';
export 'src/feed/presentation/compose_post_screen.dart';
export 'src/feed/presentation/view_models/feed_view_model.dart';
export 'src/feed/presentation/view_models/post_detail_view_model.dart';
export 'src/feed/presentation/view_models/compose_post_view_model.dart';

// Squads - data
export 'src/squads/data/squad_api.dart';
export 'src/squads/data/squad_repository.dart';

// Squads - presentation
export 'src/squads/presentation/squad_hall_screen.dart';
export 'src/squads/presentation/squad_profile_screen.dart';
export 'src/squads/presentation/squad_manage_screen.dart';
export 'src/squads/presentation/squad_offline_activity_screen.dart';
export 'src/squads/presentation/squad_offline_activity_history_screen.dart';
export 'src/squads/presentation/view_models/squad_view_model.dart';
export 'src/squads/presentation/widgets/squad_create_sheet.dart';
export 'src/squads/presentation/widgets/squad_member_list.dart';

// IDs - data
export 'src/ids/data/circle_id_api.dart';
export 'src/ids/data/circle_id_repository.dart';

// IDs - presentation
export 'src/ids/presentation/circle_id_hub_screen.dart';
export 'src/ids/presentation/circle_id_detail_screen.dart';
export 'src/ids/presentation/view_models/circle_id_view_model.dart';
export 'src/ids/presentation/widgets/circle_id_composer_sheet.dart';

// Ratings - data
export 'src/ratings/data/rating_api.dart';
export 'src/ratings/data/rating_repository.dart';

// Ratings - presentation
export 'src/ratings/presentation/rating_hub_screen.dart';
export 'src/ratings/presentation/rating_event_detail_screen.dart';
export 'src/ratings/presentation/rating_unit_detail_screen.dart';
export 'src/ratings/presentation/view_models/rating_view_model.dart';
export 'src/ratings/presentation/widgets/create_rating_event_sheet.dart';
export 'src/ratings/presentation/widgets/create_rating_unit_sheet.dart';

// Shared
export 'src/_shared/circle_service_locator.dart';
