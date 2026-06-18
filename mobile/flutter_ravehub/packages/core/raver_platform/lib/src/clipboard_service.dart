import 'package:flutter/services.dart';

/// Native clipboard bridge used by feature packages.
class ClipboardService {
  const ClipboardService._();

  static Future<void> copyText(String text) async {
    if (text.isEmpty) {
      throw ArgumentError.value(text, 'text', 'Text to copy cannot be empty.');
    }
    await Clipboard.setData(ClipboardData(text: text));
  }
}
