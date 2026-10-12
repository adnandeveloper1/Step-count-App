import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/step_counter_math.dart';

final nativeHealthProvider = Provider<NativeHealthService>((ref) {
  return NativeHealthService();
});

class NativeHealthService {
  static const platform = MethodChannel('com.buildup.app/health_services');

  Future<int> getHardwareSteps() async {
    try {
      final int steps = await platform.invokeMethod('getHardwareSteps');
      return steps;
    } on PlatformException {
      return 0;
    } on MissingPluginException {
      return 0;
    }
  }

  /// Asks Activity Recognition to report vehicle enter / exit transitions,
  /// even while the app is closed. False without Google Play Services or the
  /// Physical activity permission; steps then count as before.
  Future<bool> startDriveDetection() async {
    try {
      return await platform.invokeMethod<bool>('startDriveDetection') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Asks Activity Recognition whether the user is still in a vehicle (see
  /// needsDriveCheck). The answer confirms or ends the open drive natively
  /// and shows up in a later [getDrives].
  Future<void> checkStillDriving() async {
    try {
      await platform.invokeMethod('checkStillDriving');
    } on PlatformException {
      // No answer: the drive times out instead (see openDriveTimeout).
    } on MissingPluginException {
      // No plugin: there are no drives.
    }
  }

  /// Drives recorded natively and not yet applied to today's steps.
  Future<List<Drive>> getDrives() async {
    try {
      final drives = await platform.invokeListMethod<Map>('getDrives') ?? [];
      return drives.map(Drive.fromMap).toList();
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  /// Deletes finished drives once their steps are saved in the baseline.
  Future<void> removeDrives(List<int> ids) async {
    if (ids.isEmpty) return;
    try {
      await platform.invokeMethod('removeDrives', ids);
    } on PlatformException {
      // Kept drives are skipped by id and deleted on a later sync.
    } on MissingPluginException {
      // No plugin: there are no drives to remove.
    }
  }
}
