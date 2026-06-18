import 'package:flutter/material.dart';
import 'package:raver_platform/raver_platform.dart';

import 'version_check_service.dart';

/// A dialog that prompts the user to update the app.
///
/// Two modes:
/// - **Force update** ([isForced] = `true`): The dialog cannot be dismissed,
///   and only an "Update Now" button is shown. Used when the running version
///   is below [VersionInfo.minimumVersion].
/// - **Soft update** ([isForced] = `false`): The dialog can be dismissed via
///   back gesture or the "Later" button. Used when the running version is
///   below [VersionInfo.latestVersion] but still above the minimum.
class UpdateDialog extends StatelessWidget {
  final VersionInfo versionInfo;
  final bool isForced;

  const UpdateDialog({
    super.key,
    required this.versionInfo,
    required this.isForced,
  });

  /// Convenience method that fetches version info and shows the dialog only
  /// when an update is available.
  ///
  /// Call this from a post-frame callback on the home screen or from
  /// `bootstrap.dart` after the initial session restore completes.
  static Future<void> showIfNeeded(
    BuildContext context,
    VersionCheckService service,
  ) async {
    final info = await service.checkVersion();
    if (info == null || !context.mounted) return;

    final currentVersion = (await AppInfoService.getVersionInfo()).version;

    final isForced = VersionCheckService.isOlderThan(
      currentVersion,
      info.minimumVersion,
    );
    final needsUpdate = isForced ||
        VersionCheckService.isOlderThan(currentVersion, info.latestVersion);

    if (!needsUpdate) return;
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: !isForced,
      builder: (_) => UpdateDialog(versionInfo: info, isForced: isForced),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isForced,
      child: AlertDialog(
        title: Text(isForced ? 'Update Required' : 'Update Available'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version ${versionInfo.latestVersion} is available.'),
            if (versionInfo.releaseNotes != null) ...[
              const SizedBox(height: 8),
              Text(
                versionInfo.releaseNotes!,
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ],
        ),
        actions: [
          if (!isForced)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Later'),
            ),
          FilledButton(
            onPressed: () async {
              final url = versionInfo.updateUrl;
              if (url == null) return;
              try {
                await UrlLauncherService.openExternalUrl(url);
              } catch (_) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Unable to open update link.')),
                );
              }
            },
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  }
}
