import 'package:share_plus/share_plus.dart';

/// Lightweight wrapper around [share_plus] for sharing text, URLs, and images.
class ShareService {
  const ShareService._();

  /// Shares a plain [text] string via the platform share sheet.
  static Future<void> shareText(String text) async {
    await SharePlus.instance.share(ShareParams(text: text));
  }

  /// Shares a [url] with an optional [subject] line (used by email clients).
  static Future<void> shareUrl(String url, {String? subject}) async {
    await SharePlus.instance.share(
      ShareParams(
        uri: Uri.parse(url),
        subject: subject,
      ),
    );
  }

  /// Shares an image located at [imagePath] with optional accompanying [text].
  static Future<void> shareImage(String imagePath, {String? text}) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(imagePath)],
        text: text,
      ),
    );
  }
}
