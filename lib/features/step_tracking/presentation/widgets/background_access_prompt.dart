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
    final body = TextStyle(color: context.textPrimary, fontSize: 14);
    final hint = TextStyle(color: context.textSecondary, fontSize: 12);
    return AlertDialog(
      key: const Key('background_access_dialog'),
      backgroundColor: context.backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: context.textSecondary.withValues(alpha: 0.2)),
      ),
      title: Text(
        'Allow background activity',
        style: TextStyle(
          color: context.textPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Your phone has Build Up's battery use set to Restricted, so "
              "steps and car rides aren't counted while the app is closed.",
              style: body,
            ),
            const SizedBox(height: 12),
            Text('To change it:', style: body),
            const SizedBox(height: 4),
            Text('1. Tap Open settings.', style: body),
            Text(
              '2. Tap App battery usage (on some phones: Battery).',
              style: body,
            ),
            Text(
              '3. Turn on Allow background usage, or choose Optimized or '
              'Unrestricted.',
              style: body,
            ),
            const SizedBox(height: 12),
            Text(
              'You can change it anytime in Settings > Apps > Build Up > '
              'App battery usage.',
              style: hint,
            ),
          ],
        ),
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
