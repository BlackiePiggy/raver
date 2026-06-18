import 'package:feature_discover/src/djs/presentation/dj_detail_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raver_models/raver_models.dart';

void main() {
  group('djGenreRoute', () {
    test('uses live genre binding id when the label matches', () {
      final dj = _dj(
        genres: const ['Techno'],
        genreBindings: const [
          WebGenreTagBinding(
            genreId: 'genre-techno',
            label: 'Techno',
            path: 'Electronic/Techno',
          ),
        ],
      );

      expect(djGenreRoute(dj, 'Techno'), '/genres/genre-techno');
    });

    test('falls back to global search when the live binding is missing', () {
      final dj = _dj(genres: const ['Hard Groove']);

      expect(djGenreRoute(dj, 'Hard Groove'), '/search?q=Hard+Groove');
    });
  });
}

WebDJ _dj({
  List<String>? genres,
  List<WebGenreTagBinding>? genreBindings,
}) {
  return WebDJ(
    id: 'dj-1',
    name: 'DJ One',
    genres: genres,
    genreBindings: genreBindings,
    bio: '',
    avatarUrl: '',
    country: '',
    instagramUrl: '',
    soundcloudUrl: '',
    spotifyUrl: '',
    followerCount: 0,
  );
}
