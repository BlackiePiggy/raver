import 'package:dio/dio.dart';
import 'package:raver_core/raver_core.dart';

import '../feed/data/feed_api.dart';
import '../feed/data/feed_repository.dart';
import '../squads/data/squad_api.dart';
import '../squads/data/squad_repository.dart';
import '../ids/data/circle_id_api.dart';
import '../ids/data/circle_id_repository.dart';
import '../ratings/data/rating_api.dart';
import '../ratings/data/rating_repository.dart';

class CircleServiceLocator {
  CircleServiceLocator._();

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

  // Feed
  static FeedApi? _feedApi;
  static FeedApi get feedApi => _feedApi ??= FeedApi(dio);

  static FeedRepository? _feedRepository;
  static FeedRepository get feedRepository =>
      _feedRepository ??= FeedRepository(feedApi);

  // Squads
  static SquadApi? _squadApi;
  static SquadApi get squadApi => _squadApi ??= SquadApi(dio);

  static SquadRepository? _squadRepository;
  static SquadRepository get squadRepository =>
      _squadRepository ??= SquadRepository(squadApi);

  // Circle IDs
  static CircleIdApi? _circleIdApi;
  static CircleIdApi get circleIdApi => _circleIdApi ??= CircleIdApi(dio);

  static CircleIdRepository? _circleIdRepository;
  static CircleIdRepository get circleIdRepository =>
      _circleIdRepository ??= CircleIdRepository(circleIdApi);

  // Ratings
  static RatingApi? _ratingApi;
  static RatingApi get ratingApi => _ratingApi ??= RatingApi(dio);

  static RatingRepository? _ratingRepository;
  static RatingRepository get ratingRepository =>
      _ratingRepository ??= RatingRepository(ratingApi);
}
