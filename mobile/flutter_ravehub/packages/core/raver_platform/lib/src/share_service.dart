import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// Lightweight wrapper around [share_plus] for sharing text, URLs, and images.
class ShareService {
  const ShareService._();

  /// Shares a plain [text] string via the platform share sheet.
  static Future<void> shareText(String text) async {
    await Share.share(text);
  }

  /// Shares a [url] with an optional [subject] line (used by email clients).
  static Future<void> shareUrl(String url, {String? subject}) async {
    await Share.share(url, subject: subject);
  }

  /// Shares an image located at [imagePath] with optional accompanying [text].
  static Future<void> shareImage(String imagePath, {String? text}) async {
    await Share.shareXFiles([XFile(imagePath)], text: text);
  }

  /// Shares in-memory bytes as a file through the platform share sheet.
  static Future<void> shareBytes(
    Uint8List bytes, {
    required String fileName,
    String? mimeType,
    String? text,
  }) async {
    await Share.shareXFiles(
      [
        XFile.fromData(
          bytes,
          name: fileName,
          mimeType: mimeType,
        ),
      ],
      text: text,
    );
  }

  /// Backwards-compatible generic share alias.
  static Future<void> share({required String text}) => shareText(text);
}
