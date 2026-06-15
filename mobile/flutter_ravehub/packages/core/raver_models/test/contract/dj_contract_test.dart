// BFF Contract Tests for WebDJ and related models.
//
// These tests verify that our Freezed model deserializers match the actual
// response shapes returned by the RaveHub BFF (api.ravehub.top). JSON
// fixtures below represent realistic API responses for DJ endpoints.
//
// Run with: dart test packages/core/raver_models/test/contract/dj_contract_test.dart

import 'package:raver_models/raver_models.dart';
import 'package:test/test.dart';

void main() {
  group('WebDJ BFF Contract', () {
    test('full DJ response deserializes correctly', () {
      final json = <String, dynamic>{
        'id': 'dj_charlotte_001',
        'name': 'Charlotte de Witte',
        'nameI18n': {
          'en': 'Charlotte de Witte',
          'zh': '夏洛特·德维特',
          'ja': 'シャルロット・デ・ヴィッテ',
        },
        'aliases': ['Raving George'],
        'genres': ['techno', 'acid techno', 'hard techno'],
        'genreBindings': [
          {
            'genreId': 'genre-techno',
            'label': 'Techno',
            'path': '/genres/techno',
          },
          {
            'genreId': 'genre-acid',
            'label': 'Acid Techno',
            'path': '/genres/techno/acid',
          },
        ],
        'bio': 'Belgian techno DJ and producer. Founder of KNTXT label.',
        'avatarUrl': 'https://cdn.ravehub.top/djs/cdw/avatar.jpg',
        'country': 'BE',
        'instagramUrl': 'https://instagram.com/charlottedewittemusic',
        'soundcloudUrl': 'https://soundcloud.com/charlottedewittemusic',
        'spotifyUrl':
            'https://open.spotify.com/artist/1lJhME1ZpIN1FKjEyMPAMK',
        'honors': [
          {'title': 'DJ Mag Top 100', 'year': 2023, 'rank': 2},
          {'title': 'DJ Mag Top 100', 'year': 2024, 'rank': 1},
        ],
        'followerCount': 45200,
        'isFollowing': true,
      };

      final dj = WebDJ.fromJson(json);

      // Core fields
      expect(dj.id, 'dj_charlotte_001');
      expect(dj.name, 'Charlotte de Witte');
      expect(dj.bio, contains('Belgian techno'));
      expect(dj.avatarUrl, contains('cdw/avatar.jpg'));
      expect(dj.country, 'BE');
      expect(dj.followerCount, 45200);
      expect(dj.isFollowing, isTrue);

      // Social links
      expect(dj.instagramUrl, contains('instagram.com'));
      expect(dj.soundcloudUrl, contains('soundcloud.com'));
      expect(dj.spotifyUrl, contains('spotify.com'));

      // I18n
      expect(dj.nameI18n, isNotNull);
      expect(dj.nameI18n!.en, 'Charlotte de Witte');
      expect(dj.nameI18n!.zh, contains('夏洛特'));

      // Aliases
      expect(dj.aliases, isNotNull);
      expect(dj.aliases!.length, 1);
      expect(dj.aliases![0], 'Raving George');

      // Genres
      expect(dj.genres, isNotNull);
      expect(dj.genres!.length, 3);
      expect(dj.genres!, contains('techno'));
      expect(dj.genres!, contains('hard techno'));

      // Genre bindings
      expect(dj.genreBindings, isNotNull);
      expect(dj.genreBindings!.length, 2);
      expect(dj.genreBindings![0].genreId, 'genre-techno');
      expect(dj.genreBindings![0].label, 'Techno');
      expect(dj.genreBindings![1].path, '/genres/techno/acid');

      // Honors
      expect(dj.honors, isNotNull);
      expect(dj.honors!.length, 2);
      expect(dj.honors![0].title, 'DJ Mag Top 100');
      expect(dj.honors![0].year, 2023);
      expect(dj.honors![0].rank, 2);
      expect(dj.honors![1].rank, 1);
    });

    test('DJ with null optional fields deserializes without error', () {
      final json = <String, dynamic>{
        'id': 'dj_minimal',
        'name': 'Unknown DJ',
        'bio': '',
        'avatarUrl': '',
        'country': 'XX',
        'instagramUrl': '',
        'soundcloudUrl': '',
        'spotifyUrl': '',
        'followerCount': 0,
        // All optional fields omitted: nameI18n, aliases, genres,
        // genreBindings, honors, isFollowing
      };

      final dj = WebDJ.fromJson(json);

      expect(dj.id, 'dj_minimal');
      expect(dj.name, 'Unknown DJ');
      expect(dj.nameI18n, isNull);
      expect(dj.aliases, isNull);
      expect(dj.genres, isNull);
      expect(dj.genreBindings, isNull);
      expect(dj.honors, isNull);
      expect(dj.isFollowing, isNull);
      expect(dj.followerCount, 0);
    });

    test('DJ list response deserializes correctly', () {
      final djsJson = [
        {
          'id': 'dj_list_1',
          'name': 'Adam Beyer',
          'bio': 'Swedish techno pioneer, founder of Drumcode Records.',
          'avatarUrl': 'https://cdn.ravehub.top/djs/adam-beyer.jpg',
          'country': 'SE',
          'instagramUrl': 'https://instagram.com/realadambeyer',
          'soundcloudUrl': 'https://soundcloud.com/adambeyer',
          'spotifyUrl': 'https://open.spotify.com/artist/xyz',
          'genres': ['techno'],
          'followerCount': 38000,
          'isFollowing': false,
        },
        {
          'id': 'dj_list_2',
          'name': 'Amelie Lens',
          'bio': 'Belgian DJ and producer, resident of Exhale.',
          'avatarUrl': 'https://cdn.ravehub.top/djs/amelie-lens.jpg',
          'country': 'BE',
          'instagramUrl': 'https://instagram.com/amelielens',
          'soundcloudUrl': 'https://soundcloud.com/amelielens',
          'spotifyUrl': 'https://open.spotify.com/artist/abc',
          'genres': ['techno', 'acid techno'],
          'honors': [
            {'title': 'DJ Mag Top 100', 'year': 2024, 'rank': 8},
          ],
          'followerCount': 29500,
          'isFollowing': true,
        },
      ];

      final djs = djsJson.map((j) => WebDJ.fromJson(j)).toList();

      expect(djs.length, 2);
      expect(djs[0].name, 'Adam Beyer');
      expect(djs[0].country, 'SE');
      expect(djs[0].isFollowing, isFalse);
      expect(djs[1].name, 'Amelie Lens');
      expect(djs[1].honors, isNotNull);
      expect(djs[1].honors!.first.rank, 8);
      expect(djs[1].isFollowing, isTrue);
    });
  });
}
