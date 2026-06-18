import 'package:raver_models/raver_models.dart';

import 'event_discussion_models.dart';
import 'events_api_service.dart';

class EventsRepository {
  EventsRepository(this._api);

  final EventsApiService _api;

  Future<BFFListPage<WebEvent>> fetchEvents({
    required int page,
    int limit = 20,
    String? search,
    String? eventType,
    String? status,
  }) {
    return _api.fetchEvents(
      page: page,
      limit: limit,
      search: search,
      eventType: eventType,
      status: status,
    );
  }

  Future<List<WebEvent>> fetchRecommendedEvents({
    int limit = 10,
    List<String>? statuses,
  }) {
    return _api.fetchRecommendedEvents(limit: limit, statuses: statuses);
  }

  Future<WebEvent> fetchEvent({required String id}) {
    return _api.fetchEvent(id: id);
  }

  Future<WebEvent> fetchEventSummary({required String id}) {
    return _api.fetchEventSummary(id: id);
  }

  Future<List<WebEventLineupArtist>> fetchEventLineup({
    required String eventId,
  }) {
    return _api.fetchEventLineup(eventId: eventId);
  }

  Future<List<WebEventLineupSlot>> fetchEventTimetable({
    required String eventId,
  }) {
    return _api.fetchEventTimetable(eventId: eventId);
  }

  Future<FeedPage> fetchEventPosts({
    required String eventId,
    int limit = 20,
    String mode = 'latest',
    String? cursor,
  }) {
    return _api.fetchEventPosts(
      eventId: eventId,
      limit: limit,
      mode: mode,
      cursor: cursor,
    );
  }

  Future<List<WebDJSet>> fetchEventSets({
    required String eventId,
    String eventName = '',
    int limit = 200,
  }) {
    return _api.fetchEventSets(
      eventId: eventId,
      eventName: eventName,
      limit: limit,
    );
  }

  Future<List<WebRatingEvent>> fetchEventRatingEvents({
    required String eventId,
    int page = 1,
    int limit = 20,
  }) {
    return _api.fetchEventRatingEvents(
      eventId: eventId,
      page: page,
      limit: limit,
    );
  }

  Future<NewsPage> fetchEventNews({
    required String eventId,
    int limit = 20,
    String? cursor,
  }) {
    return _api.fetchEventNews(
      eventId: eventId,
      limit: limit,
      cursor: cursor,
    );
  }

  Future<EventFavoriteStatus> fetchFavoriteStatus({required String eventId}) {
    return _api.fetchFavoriteStatus(eventId: eventId);
  }

  Future<bool> toggleFavorite({
    required String eventId,
    required bool currentlyFavorited,
  }) async {
    if (currentlyFavorited) {
      await _api.unfavoriteEvent(eventId: eventId);
      return false;
    } else {
      await _api.favoriteEvent(eventId: eventId);
      return true;
    }
  }

  Future<ShareLinkPayload> resolveShareLink({
    required WebEvent event,
    String channel = 'system_share',
  }) {
    return _api.resolveShareLink(event: event, channel: channel);
  }

  // ---------------------------------------------------------------------------
  // Discussion
  // ---------------------------------------------------------------------------

  Future<EventDiscussionPage> fetchDiscussion({
    required String eventId,
    String? cursor,
  }) {
    return _api.fetchDiscussion(eventId: eventId, cursor: cursor);
  }

  Future<EventDiscussionComment> postComment({
    required String eventId,
    required String content,
  }) {
    return _api.postComment(eventId: eventId, content: content);
  }

  // ---------------------------------------------------------------------------
  // Check-in
  // ---------------------------------------------------------------------------

  Future<EventCheckinResult> checkin({required String eventId}) {
    return _api.checkin(eventId: eventId);
  }

  Future<EventCheckinList> fetchCheckins({
    required String eventId,
    int limit = 10,
  }) {
    return _api.fetchCheckins(eventId: eventId, limit: limit);
  }

  Future<BFFListPage<WebCheckin>> fetchEventRelatedCheckins({
    required String eventId,
    int page = 1,
    int limit = 20,
  }) {
    return _api.fetchEventRelatedCheckins(
      eventId: eventId,
      page: page,
      limit: limit,
    );
  }

  Future<void> reportEvent({
    required String eventId,
    required String reason,
    String? detail,
  }) {
    return _api.reportEvent(
      eventId: eventId,
      reason: reason,
      detail: detail,
    );
  }
}
