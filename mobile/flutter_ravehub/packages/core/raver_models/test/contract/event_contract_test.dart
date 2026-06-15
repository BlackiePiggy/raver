// BFF Contract Tests for WebEvent.
//
// These tests verify that our Freezed model deserializers match the actual
// response shapes returned by the RaveHub BFF (api.ravehub.top). JSON
// fixtures below represent realistic API responses. If the BFF changes its
// response schema, these tests should fail, alerting us to update the models.
//
// Run with: dart test packages/core/raver_models/test/contract/event_contract_test.dart

import 'package:raver_models/raver_models.dart';
import 'package:test/test.dart';

void main() {
  group('WebEvent BFF Contract', () {
    test('full event response deserializes correctly', () {
      final json = <String, dynamic>{
        'id': 'evt_abc123',
        'name': 'Awakenings Festival 2026',
        'nameI18n': {
          'en': 'Awakenings Festival 2026',
          'zh': 'Awakenings 音乐节 2026',
          'ja': 'アウェイクニングス フェスティバル 2026',
          'enFull': 'Awakenings Festival Amsterdam 2026',
        },
        'slug': 'awakenings-festival-2026',
        'description':
            'The legendary Awakenings Festival returns to the Gashouder '
                'in Amsterdam for another epic weekend of techno.',
        'coverImageUrl': 'https://cdn.ravehub.top/events/abc123/cover.jpg',
        'lineupImageUrl': 'https://cdn.ravehub.top/events/abc123/lineup.jpg',
        'eventType': 'festival',
        'startDate': '2026-06-20T14:00:00.000Z',
        'endDate': '2026-06-21T23:59:00.000Z',
        'schedule': {
          'mode': 'daily',
          'timezoneId': 'Europe/Amsterdam',
          'timezoneName': 'CET',
        },
        'weeks': [
          {
            'startDate': '2026-06-20',
            'endDate': '2026-06-21',
            'days': [
              {'id': 'day-1', 'date': '2026-06-20', 'label': 'Saturday'},
              {'id': 'day-2', 'date': '2026-06-21', 'label': 'Sunday'},
            ],
          },
        ],
        'ticketTiers': [
          {
            'name': 'Weekend Pass',
            'price': '169.00',
            'currency': 'EUR',
            'url': 'https://tickets.awakenings.com/weekend',
            'description': 'Full weekend access',
          },
          {
            'name': 'VIP Weekend',
            'price': '299.00',
            'currency': 'EUR',
            'url': 'https://tickets.awakenings.com/vip',
            'description': 'VIP lounge access included',
          },
        ],
        'lineupArtists': [
          {
            'id': 'artist-001',
            'name': 'Adam Beyer',
            'djId': 'dj-adam-beyer',
            'avatarUrl': 'https://cdn.ravehub.top/djs/adam-beyer.jpg',
            'isB2B': false,
          },
          {
            'id': 'artist-002',
            'name': 'Charlotte de Witte B2B Amelie Lens',
            'djId': 'dj-cdw-al',
            'avatarUrl': 'https://cdn.ravehub.top/djs/cdw.jpg',
            'isB2B': true,
            'members': [
              {'name': 'Charlotte de Witte', 'djId': 'dj-cdw'},
              {'name': 'Amelie Lens', 'djId': 'dj-amelie'},
            ],
          },
        ],
        'lineupSlots': [
          {
            'id': 'slot-001',
            'stageName': 'Area V',
            'startTime': '2026-06-20T22:00:00Z',
            'endTime': '2026-06-21T00:00:00Z',
            'artistName': 'Adam Beyer',
            'djId': 'dj-adam-beyer',
          },
        ],
        'location': {
          'name': 'Gashouder Amsterdam',
          'address': 'Klönneplein 1',
          'city': 'Amsterdam',
          'country': 'NL',
          'latitude': 52.3906,
          'longitude': 4.9026,
        },
        'contributors': [
          {
            'userId': 'user-contrib-1',
            'displayName': 'RaverAdmin',
            'avatarUrl': 'https://cdn.ravehub.top/users/admin.jpg',
            'contributionCount': 42,
          },
        ],
        'favoriteCount': 1250,
        'checkinCount': 834,
        'isFavorited': false,
      };

      final event = WebEvent.fromJson(json);

      // Core fields
      expect(event.id, 'evt_abc123');
      expect(event.name, 'Awakenings Festival 2026');
      expect(event.slug, 'awakenings-festival-2026');
      expect(event.eventType, 'festival');
      expect(event.startDate, '2026-06-20T14:00:00.000Z');
      expect(event.endDate, '2026-06-21T23:59:00.000Z');
      expect(event.coverImageUrl, contains('abc123/cover.jpg'));
      expect(event.lineupImageUrl, contains('abc123/lineup.jpg'));
      expect(event.description, contains('legendary Awakenings'));
      expect(event.favoriteCount, 1250);
      expect(event.checkinCount, 834);
      expect(event.isFavorited, isFalse);

      // I18n
      expect(event.nameI18n, isNotNull);
      expect(event.nameI18n!.en, 'Awakenings Festival 2026');
      expect(event.nameI18n!.zh, contains('音乐节'));
      expect(event.nameI18n!.enFull, contains('Amsterdam'));

      // Schedule
      expect(event.schedule, isNotNull);
      expect(event.schedule!.mode, 'daily');
      expect(event.schedule!.timezoneId, 'Europe/Amsterdam');
      expect(event.schedule!.timezoneName, 'CET');

      // Weeks / Days
      expect(event.weeks, isNotNull);
      expect(event.weeks!.length, 1);
      expect(event.weeks![0].days.length, 2);
      expect(event.weeks![0].days[0].label, 'Saturday');

      // Ticket tiers
      expect(event.ticketTiers, isNotNull);
      expect(event.ticketTiers!.length, 2);
      expect(event.ticketTiers![0].name, 'Weekend Pass');
      expect(event.ticketTiers![0].currency, 'EUR');
      expect(event.ticketTiers![1].price, '299.00');

      // Lineup artists
      expect(event.lineupArtists, isNotNull);
      expect(event.lineupArtists!.length, 2);
      expect(event.lineupArtists![0].name, 'Adam Beyer');
      expect(event.lineupArtists![0].isB2B, isFalse);
      expect(event.lineupArtists![1].isB2B, isTrue);
      expect(event.lineupArtists![1].members, isNotNull);
      expect(event.lineupArtists![1].members!.length, 2);
      expect(event.lineupArtists![1].members![0].name, 'Charlotte de Witte');

      // Lineup slots
      expect(event.lineupSlots, isNotNull);
      expect(event.lineupSlots!.length, 1);
      expect(event.lineupSlots![0].stageName, 'Area V');

      // Location
      expect(event.location, isNotNull);
      expect(event.location!.name, 'Gashouder Amsterdam');
      expect(event.location!.city, 'Amsterdam');
      expect(event.location!.country, 'NL');
      expect(event.location!.latitude, closeTo(52.3906, 0.001));
      expect(event.location!.longitude, closeTo(4.9026, 0.001));

      // Contributors
      expect(event.contributors, isNotNull);
      expect(event.contributors!.length, 1);
      expect(event.contributors![0].displayName, 'RaverAdmin');
      expect(event.contributors![0].contributionCount, 42);
    });

    test('event with null optional fields deserializes without error', () {
      final json = <String, dynamic>{
        'id': 'evt_minimal',
        'name': 'Small Club Night',
        'slug': 'small-club-night',
        'description': 'A cozy underground techno night.',
        'coverImageUrl': 'https://cdn.ravehub.top/events/minimal/cover.jpg',
        'lineupImageUrl': '',
        'eventType': 'club_party',
        'startDate': '2026-07-10T22:00:00.000Z',
        'endDate': '2026-07-11T06:00:00.000Z',
        'favoriteCount': 23,
        'checkinCount': 0,
        // All optional fields intentionally omitted.
      };

      final event = WebEvent.fromJson(json);

      expect(event.id, 'evt_minimal');
      expect(event.name, 'Small Club Night');
      expect(event.nameI18n, isNull);
      expect(event.schedule, isNull);
      expect(event.weeks, isNull);
      expect(event.ticketTiers, isNull);
      expect(event.lineupSlots, isNull);
      expect(event.lineupArtists, isNull);
      expect(event.location, isNull);
      expect(event.contributors, isNull);
      expect(event.isFavorited, isNull);
      expect(event.favoriteCount, 23);
      expect(event.checkinCount, 0);
    });

    test('event list page deserializes correctly (BFFListPage pattern)', () {
      // The BFF returns paginated event lists. While we test the individual
      // event deserialization above, this test verifies that a list of events
      // can be deserialized in bulk (simulating what the repository does).
      final eventsJson = [
        {
          'id': 'evt_page_1',
          'name': 'Time Warp 2026',
          'slug': 'time-warp-2026',
          'description': 'Mannheim techno marathon.',
          'coverImageUrl': 'https://cdn.ravehub.top/events/tw/cover.jpg',
          'lineupImageUrl': 'https://cdn.ravehub.top/events/tw/lineup.jpg',
          'eventType': 'festival',
          'startDate': '2026-04-04T18:00:00.000Z',
          'endDate': '2026-04-05T10:00:00.000Z',
          'favoriteCount': 3400,
          'checkinCount': 1800,
          'isFavorited': true,
        },
        {
          'id': 'evt_page_2',
          'name': 'Berghain Klubnacht',
          'slug': 'berghain-klubnacht-june',
          'description': 'Regular Klubnacht session.',
          'coverImageUrl': 'https://cdn.ravehub.top/events/bg/cover.jpg',
          'lineupImageUrl': '',
          'eventType': 'club_party',
          'startDate': '2026-06-14T23:59:00.000Z',
          'endDate': '2026-06-16T12:00:00.000Z',
          'favoriteCount': 876,
          'checkinCount': 412,
          'isFavorited': false,
          'location': {
            'name': 'Berghain',
            'address': 'Am Wriezener Bhf',
            'city': 'Berlin',
            'country': 'DE',
            'latitude': 52.5112,
            'longitude': 13.4426,
          },
        },
      ];

      final events =
          eventsJson.map((j) => WebEvent.fromJson(j)).toList();

      expect(events.length, 2);
      expect(events[0].name, 'Time Warp 2026');
      expect(events[0].isFavorited, isTrue);
      expect(events[1].name, 'Berghain Klubnacht');
      expect(events[1].location, isNotNull);
      expect(events[1].location!.name, 'Berghain');
    });
  });

  group('EventFavoriteStatus BFF Contract', () {
    test('deserializes correctly', () {
      final json = <String, dynamic>{'isFavorited': true};
      final status = EventFavoriteStatus.fromJson(json);
      expect(status.isFavorited, isTrue);
    });
  });
}
