/// Feature module for the Discover tab of RaveHub.
///
/// Provides browsing and discovery of events, DJs, sets, news,
/// labels, festivals, rankings, genres, and personalized recommendations.
library feature_discover;

// Coordinator / routing
export 'src/coordinator/discover_routes.dart';
export 'src/coordinator/discover_home_screen.dart';

// Recommend
export 'src/recommend/presentation/recommend_detail_sheet.dart';
export 'src/recommend/presentation/recommend_screen.dart';
export 'src/recommend/presentation/recommend_view_model.dart';

// Events
export 'src/events/data/events_api_service.dart';
export 'src/events/data/events_repository.dart';
export 'src/events/presentation/events_list_screen.dart';
export 'src/events/presentation/event_detail_screen.dart';
export 'src/events/presentation/event_editor_screen.dart';
export 'src/events/presentation/event_upload_flow_screen.dart';
export 'src/events/presentation/event_lineup_import_screen.dart';
export 'src/events/presentation/event_route_planner_screen.dart';
export 'src/events/presentation/event_schedule_canvas.dart';
export 'src/events/presentation/view_models/events_list_view_model.dart';
export 'src/events/presentation/view_models/event_detail_view_model.dart';
export 'src/events/presentation/view_models/event_editor_view_model.dart';
export 'src/events/presentation/view_models/event_upload_view_model.dart';
export 'src/events/presentation/widgets/event_card.dart';

// News
export 'src/news/data/news_api.dart';
export 'src/news/data/news_providers.dart';
export 'src/news/presentation/news_list_screen.dart';
export 'src/news/presentation/news_detail_screen.dart';
export 'src/news/presentation/news_editor_screen.dart';
export 'src/news/presentation/view_models/news_editor_view_model.dart';

// DJs
export 'src/djs/data/dj_api.dart';
export 'src/djs/data/dj_providers.dart';
export 'src/djs/presentation/djs_list_screen.dart';
export 'src/djs/presentation/dj_detail_screen.dart';
export 'src/djs/presentation/dj_import_screen.dart';
export 'src/djs/presentation/dj_editor_screen.dart';
export 'src/djs/presentation/dj_upload_flow_screen.dart';
export 'src/djs/presentation/view_models/dj_editor_view_model.dart';

// Sets
export 'src/sets/data/set_api.dart';
export 'src/sets/data/set_providers.dart';
export 'src/sets/presentation/sets_list_screen.dart';
export 'src/sets/presentation/set_detail_screen.dart';
export 'src/sets/presentation/set_editor_screen.dart';
export 'src/sets/presentation/tracklist_editor_screen.dart';
export 'src/sets/presentation/view_models/set_editor_view_model.dart';

// Genres
export 'src/genres_sunburst/data/genre_api.dart';
export 'src/genres_sunburst/presentation/genres_root_screen.dart';
export 'src/genres_sunburst/presentation/genre_detail_screen.dart';
export 'src/genres_sunburst/presentation/genre_sunburst_painter.dart';
export 'src/genres_sunburst/presentation/genre_sunburst_view_model.dart';
export 'src/genres_sunburst/presentation/genre_theme_palette.dart';

// Organizers
export 'src/organizers/data/organizer_api.dart';
export 'src/organizers/presentation/organizers_root_screen.dart';
export 'src/organizers/presentation/organizer_card.dart';
export 'src/organizers/presentation/organizer_list_filter_sheet.dart';
export 'src/organizers/presentation/organizer_view_model.dart';
export 'src/organizers/presentation/festival_detail_screen.dart';
export 'src/organizers/presentation/organizer_upload_flow_screen.dart';
export 'src/organizers/presentation/view_models/organizer_upload_view_model.dart';

// Labels
export 'src/labels/data/label_api.dart';
export 'src/labels/presentation/labels_root_screen.dart';
export 'src/labels/presentation/label_detail_screen.dart';
export 'src/labels/presentation/label_list_filter_sheet.dart';
export 'src/labels/presentation/label_view_model.dart';

// Rankings
export 'src/rankings/data/ranking_api.dart';
export 'src/rankings/presentation/rankings_root_screen.dart';
export 'src/rankings/presentation/ranking_board_detail_screen.dart';
export 'src/rankings/presentation/ranking_entry_detail_screen.dart';
export 'src/rankings/presentation/ranking_view_model.dart';

// Search
export 'src/search/data/search_api_service.dart';
export 'src/search/data/search_repository.dart';
export 'src/search/data/recent_search_store.dart';
export 'src/search/presentation/search_overlay_screen.dart';
export 'src/search/presentation/search_results_screen.dart';
export 'src/search/presentation/search_results_view_model.dart';
export 'src/search/presentation/widgets/search_result_card.dart';

// Shared / DI
export 'src/_shared/discover_service_locator.dart';
