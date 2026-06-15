import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';

class PushRouter {
  static void handleMessage(RemoteMessage message, GoRouter router) {
    final data = message.data;
    final type = data['type'] as String?;
    final id = data['id'] as String?;

    if (type == null || id == null) return;

    switch (type) {
      case 'event':
        router.push('/events/$id');
      case 'dj':
        router.push('/djs/$id');
      case 'post':
        router.push('/posts/$id');
      case 'squad':
        router.push('/squads/$id');
      case 'news':
        router.push('/news/$id');
      default:
        router.push('/inbox');
    }
  }
}
