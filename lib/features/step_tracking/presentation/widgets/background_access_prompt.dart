import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../app/theme/theme_extensions.dart';
import '../../../../core/services/local_storage_service.dart';
import '../../../../core/services/native_health_service.dart';

/// Shows, once, how to allow background use when Android has the app's
/// battery use set to Restricted: then steps and car rides are not counted
/// while the app is closed. [openSettings] opens the app's settings page; no
/// special permission is needed for it or for the check.
Future<void> showBackgroundAccessPromptIfNeeded(
  BuildContext context, {
  required NativeHealthService health,
  required LocalStorageService storage,
  Future<bool> Function() openSettings = openAppSettings,
}) async {
  if (storage.getBackgroundAccessPromptShown()) return;
  if (!await health.isBackgroundRestricted()) return;
  if (!context.mounted) return;

  storage.saveBackgroundAccessPromptShown(true);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => _BackgroundAccessDialog(
      onOpenSettings: () {
        Navigator.of(dialogContext).pop();
        openSettings();
      },
    ),
  );
}

class _BackgroundAccessDialog extends StatelessWidget {
  final VoidCallback onOpenSettings;

  const _BackgroundAccessDialog({required this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('background_access_dialog'),
      backgroundColor: context.backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: context.textSecondary.withValues(alpha: 0.2)),
      ),
      title: Text(
        'Allow background use',
        style: TextStyle(
          color: context.textPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Battery use is Restricted, so steps aren't counted while the "
            'app is closed.',
            style: TextStyle(color: context.textPrimary, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            'App battery usage > Allow background usage',
            style: TextStyle(color: context.textSecondary, fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('background_access_not_now'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Not now',
            style: TextStyle(color: context.textSecondary),
          ),
        ),
        TextButton(
          key: const Key('background_access_open_settings'),
          onPressed: onOpenSettings,
          child: Text(
            'Open settings',
            style: TextStyle(
              color: context.primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
