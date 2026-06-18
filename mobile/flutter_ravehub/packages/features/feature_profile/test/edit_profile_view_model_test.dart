import 'package:dio/dio.dart';
import 'package:feature_profile/src/edit_profile/view_models/edit_profile_view_model.dart';
import 'package:feature_profile/src/profile_me/data/profile_api.dart';
import 'package:feature_profile/src/profile_me/data/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';

ProfileRepository _repository({
  required List<RequestOptions> requests,
  void Function(RequestOptions options)? onPatchProfile,
  bool displayNameAvailable = true,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.ravehub.top'))
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          if (options.path == '/v1/users/check-display-name') {
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {'available': displayNameAvailable},
              ),
            );
            return;
          }
          if (options.path == '/v1/profile/me') {
            onPatchProfile?.call(options);
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: const {
                  'id': 'user-1',
                  'username': 'bass_runner',
                  'displayName': 'Bass Rider',
                  'bio': 'Trimmed bio',
                  'followerCount': 1,
                  'followingCount': 2,
                  'friendCount': 3,
                  'postCount': 4,
                  'ageBand': '25-34',
                },
              ),
            );
            return;
          }
          handler.reject(DioException(requestOptions: options));
        },
      ),
    );
  return ProfileRepository(ProfileApi(dio));
}

void main() {
  group('EditProfileViewModel', () {
    test('blocks invalid display names before sending profile update',
        () async {
      final requests = <RequestOptions>[];
      final viewModel = EditProfileViewModel(
        repository: _repository(requests: requests),
      );

      viewModel.setDisplayName('A');
      await viewModel.save();

      expect(viewModel.saveSuccess, isFalse);
      expect(viewModel.error, isNotNull);
      expect(requests, isEmpty);
    });

    test('blocks taken display names before sending profile update', () async {
      final requests = <RequestOptions>[];
      final viewModel = EditProfileViewModel(
        repository: _repository(
          requests: requests,
          displayNameAvailable: false,
        ),
      );

      viewModel.setDisplayName('Taken Name');
      await viewModel.checkDisplayName();
      await viewModel.save();

      expect(viewModel.saveSuccess, isFalse);
      expect(viewModel.displayNameError, isNotNull);
      expect(
        requests.map((request) => request.path),
        ['/v1/users/check-display-name'],
      );
    });

    test('trims and sends iOS-parity profile save payload', () async {
      final requests = <RequestOptions>[];
      late Map<String, dynamic> patchBody;
      final viewModel = EditProfileViewModel(
        repository: _repository(
          requests: requests,
          onPatchProfile: (options) {
            patchBody = Map<String, dynamic>.from(
              options.data as Map<String, dynamic>,
            );
          },
        ),
      );

      viewModel
        ..setDisplayName('  Bass Rider  ')
        ..setBio('  Trimmed bio  ')
        ..setCity('  Shanghai  ')
        ..setGender('private')
        ..setBirthday('2000-01-02')
        ..setAvatarUrl('https://cdn.example.com/avatar.jpg')
        ..setBackgroundUrl('https://cdn.example.com/bg.jpg');

      await viewModel.save();

      expect(viewModel.saveSuccess, isTrue);
      expect(patchBody, {
        'displayName': 'Bass Rider',
        'bio': 'Trimmed bio',
        'gender': 'private',
        'birthday': '2000-01-02',
        'location': 'Shanghai',
        'avatarUrl': 'https://cdn.example.com/avatar.jpg',
        'backgroundURL': 'https://cdn.example.com/bg.jpg',
      });
      expect(requests.single.path, '/v1/profile/me');
    });
  });
}
