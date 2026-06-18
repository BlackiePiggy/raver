// BFF Contract Tests for AppNotification and NotificationUnreadCount.
//
// These tests verify that our Freezed model deserializers match the actual
// response shapes returned by the RaveHub BFF notification center endpoints
// (api.ravehub.top/v1/notification-center/*).
//
// Run with: dart test packages/core/raver_models/test/contract/notification_contract_test.dart

import 'package:raver_models/raver_models.dart';
import 'package:test/test.dart';

void main() {
  group('AppNotification BFF Contract', () {
    test('full notification response deserializes correctly', () {
      final json = <String, dynamic>{
        'id': 'notif_001',
        'type': 'social',
        'title': 'New follower',
        'body': 'DJ_Koda started following you.',
        'targetType': 'user',
        'targetId': 'user_koda_123',
        'imageUrl': 'https://cdn.ravehub.top/users/koda/avatar.jpg',
        'isRead': false,
        'createdAt': '2026-06-14T09:30:00.000Z',
      };

      final notification = AppNotification.fromJson(json);

      expect(notification.id, 'notif_001');
      expect(notification.type, 'social');
      expect(notification.title, 'New follower');
      expect(notification.body, contains('DJ_Koda'));
      expect(notification.targetType, 'user');
      expect(notification.targetId, 'user_koda_123');
      expect(notification.imageUrl, contains('koda/avatar.jpg'));
      expect(notification.isRead, isFalse);
      expect(notification.createdAt, '2026-06-14T09:30:00.000Z');
    });

    test('notification with read=true deserializes correctly', () {
      final json = <String, dynamic>{
        'id': 'notif_002',
        'type': 'event_update',
        'title': 'Event Update',
        'body': 'Awakenings Festival added 3 new artists to the lineup.',
        'targetType': 'event',
        'targetId': 'evt_awakenings_2026',
        'imageUrl': 'https://cdn.ravehub.top/events/awakenings/cover.jpg',
        'isRead': true,
        'createdAt': '2026-06-13T18:00:00.000Z',
      };

      final notification = AppNotification.fromJson(json);

      expect(notification.id, 'notif_002');
      expect(notification.type, 'event_update');
      expect(notification.isRead, isTrue);
      expect(notification.targetType, 'event');
    });

    test('notification inbox (paginated list) deserializes correctly', () {
      final json = <String, dynamic>{
        'notifications': [
          {
            'id': 'notif_inbox_1',
            'type': 'like',
            'title': 'Post liked',
            'body': 'RaverGirl liked your post.',
            'targetType': 'post',
            'targetId': 'post_xyz',
            'imageUrl': 'https://cdn.ravehub.top/users/rg/avatar.jpg',
            'isRead': false,
            'createdAt': '2026-06-14T10:00:00.000Z',
          },
          {
            'id': 'notif_inbox_2',
            'type': 'comment',
            'title': 'New comment',
            'body': 'TechnoFan replied to your post.',
            'targetType': 'post',
            'targetId': 'post_abc',
            'imageUrl': 'https://cdn.ravehub.top/users/tf/avatar.jpg',
            'isRead': true,
            'createdAt': '2026-06-14T08:30:00.000Z',
          },
        ],
        'nextCursor': 'cursor_page2_abc',
      };

      final inbox = NotificationInbox.fromJson(json);

      expect(inbox.notifications.length, 2);
      expect(inbox.notifications[0].id, 'notif_inbox_1');
      expect(inbox.notifications[0].type, 'like');
      expect(inbox.notifications[0].isRead, isFalse);
      expect(inbox.notifications[1].id, 'notif_inbox_2');
      expect(inbox.notifications[1].isRead, isTrue);
      expect(inbox.nextCursor, 'cursor_page2_abc');
    });
  });

  group('NotificationUnreadCount BFF Contract', () {
    test('full unread count response deserializes correctly', () {
      final json = <String, dynamic>{
        'community': 5,
        'followedEvents': 3,
        'followedDJs': 1,
        'followedBrands': 0,
      };

      final unread = NotificationUnreadCount.fromJson(json);

      expect(unread.community, 5);
      expect(unread.followedEvents, 3);
      expect(unread.followedDJs, 1);
      expect(unread.followedBrands, 0);
    });

    test('unread count with all zeros deserializes correctly', () {
      final json = <String, dynamic>{
        'community': 0,
        'followedEvents': 0,
        'followedDJs': 0,
        'followedBrands': 0,
      };

      final unread = NotificationUnreadCount.fromJson(json);

      expect(unread.community, 0);
      expect(unread.followedEvents, 0);
      expect(unread.followedDJs, 0);
      expect(unread.followedBrands, 0);
    });

    test('large unread counts deserialize correctly', () {
      final json = <String, dynamic>{
        'community': 999,
        'followedEvents': 150,
        'followedDJs': 42,
        'followedBrands': 7,
      };

      final unread = NotificationUnreadCount.fromJson(json);

      expect(unread.community, 999);
      expect(unread.followedEvents, 150);
      expect(unread.followedDJs, 42);
      expect(unread.followedBrands, 7);
    });

    test('snake case and numeric string aliases deserialize correctly', () {
      final json = <String, dynamic>{
        'community_unread_count': '4',
        'followed_events_unread_count': '6',
        'followed_djs_unread_count': 8.0,
        'followed_brands_unread_count': '10',
      };

      final unread = NotificationUnreadCount.fromJson(json);

      expect(unread.community, 4);
      expect(unread.followedEvents, 6);
      expect(unread.followedDJs, 8);
      expect(unread.followedBrands, 10);
    });
  });

  group('Followed entity inbox projections', () {
    test('followed event live projection deserializes correctly', () {
      final item = FollowedEventNotificationItem.fromJson({
        'id': 'inbox-event-1',
        'type': 'news',
        'eventId': 'event-1',
        'eventName': 'RaveHub Night',
        'newsId': 'news-1',
        'newsTitle': 'Lineup phase two announced',
        'newsSummary': 'Three artists were added.',
        'newsCoverImageURL': 'https://cdn.example.com/news.jpg',
        'isRead': false,
        'occurredAt': '2026-06-16T10:00:00Z',
      });

      expect(item.type, 'news');
      expect(item.eventId, 'event-1');
      expect(item.newsId, 'news-1');
      expect(item.summary, 'Three artists were added.');
      expect(item.coverImageUrl, contains('news.jpg'));
      expect(item.isRead, isFalse);
      expect(item.createdAt, '2026-06-16T10:00:00Z');
    });

    test('followed DJ live projection deserializes correctly', () {
      final item = FollowedDJNotificationItem.fromJson({
        'id': 'inbox-dj-1',
        'type': 'event',
        'djId': 'dj-1',
        'djName': 'DJ Koda',
        'newsId': 'event-2',
        'newsTitle': 'DJ Koda joins RaveHub Night',
        'newsSummary': 'A new performance was announced.',
        'newsCoverImageUrl': 'https://cdn.example.com/event.jpg',
        'isRead': true,
        'occurredAt': '2026-06-16T11:00:00Z',
      });

      expect(item.type, 'event');
      expect(item.djId, 'dj-1');
      expect(item.newsId, 'event-2');
      expect(item.newsCoverImageUrl, contains('event.jpg'));
      expect(item.isRead, isTrue);
    });

    test('followed brand keeps legacy aliases working', () {
      final item = FollowedBrandNotificationItem.fromJson({
        'id': 'legacy-brand-1',
        'brandId': 'brand-1',
        'brandName': 'RaveHub Records',
        'imageUrl': 'https://cdn.example.com/brand.jpg',
        'changeType': 'news',
        'summary': 'New release announced.',
        'createdAt': '2026-06-16T12:00:00Z',
      });

      expect(item.type, 'news');
      expect(item.newsId, isEmpty);
      expect(item.summary, 'New release announced.');
      expect(item.imageUrl, contains('brand.jpg'));
      expect(item.isRead, isFalse);
      expect(item.occurredAt, '2026-06-16T12:00:00Z');
    });
  });
}
