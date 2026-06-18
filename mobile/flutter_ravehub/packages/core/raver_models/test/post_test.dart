import 'package:raver_models/raver_models.dart';
import 'package:test/test.dart';

void main() {
  group('Post', () {
    test('splits live mixed media urls into images and videos', () {
      final post = Post.fromJson({
        'id': 'post-1',
        'content': 'media set',
        'images': [
          'https://cdn.ravehub.top/feed/photo.jpg',
          'https://cdn.ravehub.top/feed/clip.mp4?token=abc',
          'https://cdn.ravehub.top/feed/live.m3u8',
        ],
        'author': {
          'id': 'user-1',
          'username': 'media_raver',
          'displayName': 'Media Raver',
        },
        'createdAt': '2026-06-17T12:00:00Z',
      });

      expect(post.images, ['https://cdn.ravehub.top/feed/photo.jpg']);
      expect(post.videos, [
        'https://cdn.ravehub.top/feed/clip.mp4?token=abc',
        'https://cdn.ravehub.top/feed/live.m3u8',
      ]);
    });
  });

  group('Comment', () {
    test('parses live thread and reply target fields', () {
      final comment = Comment.fromJson({
        'id': 'reply-1',
        'postID': 'post-1',
        'parentCommentID': 'root-1',
        'rootCommentID': 'root-1',
        'depth': '2',
        'author': {
          'id': 'user-2',
          'username': 'raver_two',
          'displayName': 'Raver Two',
          'avatarURL': 'https://img.example.com/u2.jpg',
        },
        'replyToAuthor': {
          'id': 'user-1',
          'username': 'raver_one',
          'displayName': 'Raver One',
        },
        'content': 'Totally agree',
        'createdAt': '2026-06-17T12:00:00Z',
      });

      expect(comment.postId, 'post-1');
      expect(comment.parentCommentId, 'root-1');
      expect(comment.rootCommentId, 'root-1');
      expect(comment.depth, 2);
      expect(comment.userId, 'user-2');
      expect(comment.displayName, 'Raver Two');
      expect(comment.avatarUrl, 'https://img.example.com/u2.jpg');
      expect(comment.replyToUserId, 'user-1');
      expect(comment.replyToDisplayName, 'Raver One');
    });

    test('parses alternate parent and reply field aliases', () {
      final comment = Comment.fromJson({
        'id': 'reply-2',
        'postId': 'post-2',
        'parentId': 'root-2',
        'rootCommentId': 'root-2',
        'user': {
          'id': 'user-3',
          'username': 'raver_three',
          'displayName': 'Raver Three',
        },
        'replyToUserID': 'user-4',
        'replyToDisplayName': 'Raver Four',
        'content': 'Reply alias',
      });

      expect(comment.postId, 'post-2');
      expect(comment.parentCommentId, 'root-2');
      expect(comment.rootCommentId, 'root-2');
      expect(comment.replyToUserId, 'user-4');
      expect(comment.replyToDisplayName, 'Raver Four');
    });
  });
}
