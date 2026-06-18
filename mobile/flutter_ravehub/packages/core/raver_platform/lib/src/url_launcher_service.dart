import 'package:url_launcher/url_launcher.dart';

/// Opens trusted external URLs through the platform/browser.
class UrlLauncherService {
  const UrlLauncherService._();

  static Future<void> openExternalUrl(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw ArgumentError.value(url, 'url', 'External URL is invalid');
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
