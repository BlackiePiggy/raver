import 'package:dio/dio.dart';
import 'package:raver_core/raver_core.dart';

import '../profile_me/data/profile_api.dart';
import '../profile_me/data/profile_repository.dart';
import '../checkins/data/checkin_api.dart';
import '../publishes/data/publishes_api.dart';
import '../quiz/data/quiz_api.dart';
import '../personality/data/personality_api.dart';
import '../follow_list/data/follow_api.dart';
import '../virtual_assets/data/virtual_asset_api.dart';

class ProfileServiceLocator {
  ProfileServiceLocator._();

  static Dio? _dio;

  static Dio get dio {
    _dio ??= Dio(
      BaseOptions(
        baseUrl: AppConfig.bffBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    return _dio!;
  }

  static void configureDio(Dio dio) {
    _dio = dio;
  }

  // Profile
  static ProfileApi? _profileApi;
  static ProfileApi get profileApi => _profileApi ??= ProfileApi(dio);

  static ProfileRepository? _profileRepository;
  static ProfileRepository get profileRepository =>
      _profileRepository ??= ProfileRepository(profileApi);

  // Checkins
  static CheckinApi? _checkinApi;
  static CheckinApi get checkinApi => _checkinApi ??= CheckinApi(dio);

  // Publishes
  static PublishesApi? _publishesApi;
  static PublishesApi get publishesApi =>
      _publishesApi ??= PublishesApi(dio);

  // Quiz
  static QuizApi? _quizApi;
  static QuizApi get quizApi => _quizApi ??= QuizApi(dio);

  // Personality
  static PersonalityApi? _personalityApi;
  static PersonalityApi get personalityApi =>
      _personalityApi ??= PersonalityApi(dio);

  // Follow
  static FollowApi? _followApi;
  static FollowApi get followApi => _followApi ??= FollowApi(dio);

  // Virtual Assets
  static VirtualAssetApi? _virtualAssetApi;
  static VirtualAssetApi get virtualAssetApi =>
      _virtualAssetApi ??= VirtualAssetApi(dio);
}
