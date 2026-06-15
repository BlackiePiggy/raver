import 'package:raver_models/raver_models.dart';
import 'package:test/test.dart';

void main() {
  group('WebEvent', () {
    group('fromJson', () {
      test('parses all required fields', () {
        final json = _minimalEventJson();

        final event = WebEvent.fromJson(json);

        expect(event.id, equals('evt-001'));
        expect(event.name, equals('Ultra Music Festival'));
        expect(event.slug, equals('ultra-music-festival-2026'));
        expect(event.description, equals('The premier electronic music fest'));
        expect(
          event.coverImageUrl,
          equals('https://cdn.example.com/cover.jpg'),
        );
        expect(
          event.lineupImageUrl,
          equals('https://cdn.example.com/lineup.jpg'),
        );
        expect(event.eventType, equals('festival'));
        expect(event.startDate, equals('2026-03-27'));
        expect(event.endDate, equals('2026-03-29'));
        expect(event.favoriteCount, equals(5000));
        expect(event.checkinCount, equals(1200));
      });

      test('handles null optional fields gracefully', () {
        final json = _minimalEventJson();

        final event = WebEvent.fromJson(json);

        expect(event.nameI18n, isNull);
        expect(event.schedule, isNull);
        expect(event.weeks, isNull);
        expect(event.ticketTiers, isNull);
        expect(event.lineupSlots, isNull);
        expect(event.lineupArtists, isNull);
        expect(event.location, isNull);
        expect(event.contributors, isNull);
        expect(event.isFavorited, isNull);
      });

      test('parses nested WebEventSchedule', () {
        final json = _minimalEventJson()
          ..['schedule'] = {
            'mode': 'weekly',
            'timezoneId': 'America/New_York',
            'timezoneName': 'EST',
          };

        final event = WebEvent.fromJson(json);

        expect(event.schedule, isNotNull);
        expect(event.schedule!.mode, equals('weekly'));
        expect(event.schedule!.timezoneId, equals('America/New_York'));
        expect(event.schedule!.timezoneName, equals('EST'));
      });

      test('parses nested WebEventManualLocation', () {
        final json = _minimalEventJson()
          ..['location'] = {
            'name': 'Bayfront Park',
            'address': '301 Biscayne Blvd',
            'city': 'Miami',
            'country': 'US',
            'latitude': 25.7743,
            'longitude': -80.1862,
          };

        final event = WebEvent.fromJson(json);

        expect(event.location, isNotNull);
        expect(event.location!.name, equals('Bayfront Park'));
        expect(event.location!.address, equals('301 Biscayne Blvd'));
        expect(event.location!.city, equals('Miami'));
        expect(event.location!.country, equals('US'));
        expect(event.location!.latitude, closeTo(25.7743, 0.001));
        expect(event.location!.longitude, closeTo(-80.1862, 0.001));
      });

      test('parses location without optional lat/lng', () {
        final json = _minimalEventJson()
          ..['location'] = {
            'name': 'Secret Venue',
            'address': 'TBA',
            'city': 'Berlin',
            'country': 'DE',
          };

        final event = WebEvent.fromJson(json);

        expect(event.location!.latitude, isNull);
        expect(event.location!.longitude, isNull);
      });

      test('parses lineupArtists list', () {
        final json = _minimalEventJson()
          ..['lineupArtists'] = [
            {
              'id': 'artist-001',
              'name': 'Tiesto',
              'djId': 'dj-tiesto',
              'avatarUrl': 'https://cdn.example.com/tiesto.jpg',
              'isB2B': false,
            },
            {
              'id': 'artist-002',
              'name': 'Armin & Ferry',
              'djId': 'dj-armin-ferry',
              'avatarUrl': 'https://cdn.example.com/armin.jpg',
              'isB2B': true,
              'members': [
                {'name': 'Armin van Buuren', 'djId': 'dj-armin'},
                {'name': 'Ferry Corsten', 'djId': 'dj-ferry'},
              ],
            },
          ];

        final event = WebEvent.fromJson(json);

        expect(event.lineupArtists, isNotNull);
        expect(event.lineupArtists!.length, equals(2));

        final artist1 = event.lineupArtists![0];
        expect(artist1.name, equals('Tiesto'));
        expect(artist1.isB2B, isFalse);
        expect(artist1.members, isNull);

        final artist2 = event.lineupArtists![1];
        expect(artist2.isB2B, isTrue);
        expect(artist2.members, isNotNull);
        expect(artist2.members!.length, equals(2));
        expect(artist2.members![0].name, equals('Armin van Buuren'));
        expect(artist2.members![1].djId, equals('dj-ferry'));
      });

      test('parses lineupSlots list', () {
        final json = _minimalEventJson()
          ..['lineupSlots'] = [
            {
              'id': 'slot-001',
              'stageName': 'Main Stage',
              'startTime': '2026-03-27T20:00:00Z',
              'endTime': '2026-03-27T22:00:00Z',
              'artistName': 'Deadmau5',
              'djId': 'dj-deadmau5',
            },
          ];

        final event = WebEvent.fromJson(json);

        expect(event.lineupSlots, isNotNull);
        expect(event.lineupSlots!.length, equals(1));
        expect(event.lineupSlots![0].stageName, equals('Main Stage'));
        expect(event.lineupSlots![0].artistName, equals('Deadmau5'));
      });

      test('parses ticketTiers list', () {
        final json = _minimalEventJson()
          ..['ticketTiers'] = [
            {
              'name': 'General Admission',
              'price': '299.00',
              'currency': 'USD',
              'url': 'https://tickets.example.com/ga',
              'description': 'Standard entry ticket',
            },
            {
              'name': 'VIP',
              'price': '599.00',
              'currency': 'USD',
              'url': 'https://tickets.example.com/vip',
              'description': 'VIP access with backstage pass',
            },
          ];

        final event = WebEvent.fromJson(json);

        expect(event.ticketTiers, isNotNull);
        expect(event.ticketTiers!.length, equals(2));
        expect(event.ticketTiers![0].name, equals('General Admission'));
        expect(event.ticketTiers![0].price, equals('299.00'));
        expect(event.ticketTiers![1].name, equals('VIP'));
      });

      test('parses weeks with nested days', () {
        final json = _minimalEventJson()
          ..['weeks'] = [
            {
              'startDate': '2026-03-27',
              'endDate': '2026-03-29',
              'days': [
                {'id': 'day-1', 'date': '2026-03-27', 'label': 'Day 1'},
                {'id': 'day-2', 'date': '2026-03-28', 'label': 'Day 2'},
                {'id': 'day-3', 'date': '2026-03-29', 'label': 'Day 3'},
              ],
            },
          ];

        final event = WebEvent.fromJson(json);

        expect(event.weeks, isNotNull);
        expect(event.weeks!.length, equals(1));
        expect(event.weeks![0].days.length, equals(3));
        expect(event.weeks![0].days[0].label, equals('Day 1'));
        expect(event.weeks![0].days[2].date, equals('2026-03-29'));
      });

      test('parses nameI18n', () {
        final json = _minimalEventJson()
          ..['nameI18n'] = {
            'en': 'Ultra Music Festival',
            'zh': 'Ultra音乐节',
            'ja': 'ウルトラミュージックフェスティバル',
            'enFull': 'Ultra Music Festival 2026',
          };

        final event = WebEvent.fromJson(json);

        expect(event.nameI18n, isNotNull);
        expect(event.nameI18n!.en, equals('Ultra Music Festival'));
        expect(event.nameI18n!.zh, equals('Ultra音乐节'));
        expect(event.nameI18n!.ja, isNotNull);
        expect(event.nameI18n!.enFull, equals('Ultra Music Festival 2026'));
      });

      test('parses contributors list', () {
        final json = _minimalEventJson()
          ..['contributors'] = [
            {
              'userId': 'contrib-001',
              'displayName': 'DJ Admin',
              'avatarUrl': 'https://cdn.example.com/admin.jpg',
              'contributionCount': 15,
            },
          ];

        final event = WebEvent.fromJson(json);

        expect(event.contributors, isNotNull);
        expect(event.contributors!.length, equals(1));
        expect(event.contributors![0].displayName, equals('DJ Admin'));
        expect(event.contributors![0].contributionCount, equals(15));
      });

      test('parses isFavorited boolean', () {
        final json = _minimalEventJson()..['isFavorited'] = true;

        final event = WebEvent.fromJson(json);

        expect(event.isFavorited, isTrue);
      });
    });

    group('toJson roundtrip', () {
      test('serialization and deserialization preserves data', () {
        const original = WebEvent(
          id: 'evt-rt',
          name: 'Roundtrip Event',
          slug: 'roundtrip-event',
          description: 'A test event for roundtrip',
          coverImageUrl: 'https://cdn.example.com/cover.jpg',
          lineupImageUrl: 'https://cdn.example.com/lineup.jpg',
          eventType: 'club_night',
          startDate: '2026-07-01',
          endDate: '2026-07-01',
          favoriteCount: 42,
          checkinCount: 10,
        );

        final json = original.toJson();
        final restored = WebEvent.fromJson(json);

        expect(restored.id, equals(original.id));
        expect(restored.name, equals(original.name));
        expect(restored.slug, equals(original.slug));
        expect(restored.favoriteCount, equals(original.favoriteCount));
      });
    });
  });

  group('WebEventSchedule', () {
    test('fromJson parses correctly', () {
      final json = <String, dynamic>{
        'mode': 'daily',
        'timezoneId': 'Asia/Shanghai',
        'timezoneName': 'CST',
      };

      final schedule = WebEventSchedule.fromJson(json);

      expect(schedule.mode, equals('daily'));
      expect(schedule.timezoneId, equals('Asia/Shanghai'));
      expect(schedule.timezoneName, equals('CST'));
    });
  });

  group('WebEventManualLocation', () {
    test('fromJson parses all fields', () {
      final json = <String, dynamic>{
        'name': 'Club Space',
        'address': '34 NE 11th St',
        'city': 'Miami',
        'country': 'US',
        'latitude': 25.786,
        'longitude': -80.192,
      };

      final location = WebEventManualLocation.fromJson(json);

      expect(location.name, equals('Club Space'));
      expect(location.latitude, closeTo(25.786, 0.001));
    });
  });

  group('EventFavoriteStatus', () {
    test('fromJson parses isFavorited', () {
      final json = <String, dynamic>{'isFavorited': true};
      final status = EventFavoriteStatus.fromJson(json);
      expect(status.isFavorited, isTrue);
    });

    test('fromJson parses isFavorited as false', () {
      final json = <String, dynamic>{'isFavorited': false};
      final status = EventFavoriteStatus.fromJson(json);
      expect(status.isFavorited, isFalse);
    });
  });
}

/// Helper to produce a minimal valid WebEvent JSON map.
Map<String, dynamic> _minimalEventJson() => <String, dynamic>{
      'id': 'evt-001',
      'name': 'Ultra Music Festival',
      'slug': 'ultra-music-festival-2026',
      'description': 'The premier electronic music fest',
      'coverImageUrl': 'https://cdn.example.com/cover.jpg',
      'lineupImageUrl': 'https://cdn.example.com/lineup.jpg',
      'eventType': 'festival',
      'startDate': '2026-03-27',
      'endDate': '2026-03-29',
      'favoriteCount': 5000,
      'checkinCount': 1200,
    };
