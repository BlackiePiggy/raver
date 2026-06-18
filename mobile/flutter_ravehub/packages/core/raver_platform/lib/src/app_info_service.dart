import 'package:package_info_plus/package_info_plus.dart';

/// Runtime app metadata surfaced by the platform.
class AppVersionInfo {
  const AppVersionInfo({
    required this.appName,
    required this.packageName,
    required this.version,
    required this.buildNumber,
  });

  final String appName;
  final String packageName;
  final String version;
  final String buildNumber;

  String get displayVersion {
    if (buildNumber.isEmpty) return 'v$version';
    return 'v$version ($buildNumber)';
  }
}

/// Reads app metadata from the installed bundle/package.
class AppInfoService {
  const AppInfoService._();

  static Future<AppVersionInfo> getVersionInfo() async {
    final info = await PackageInfo.fromPlatform();
    return AppVersionInfo(
      appName: info.appName,
      packageName: info.packageName,
      version: info.version,
      buildNumber: info.buildNumber,
    );
  }
}
