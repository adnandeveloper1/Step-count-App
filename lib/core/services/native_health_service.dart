import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/activity_log.dart';
import '../utils/step_counter_math.dart';

final nativeHealthProvider = Provider<NativeHealthService>((ref) {
  return NativeHealthService();
});

/// The day's steps minute by minute from the Recording API, or null without
/// it. Keyed by the day's midnight.
final recordedStepsProvider = FutureProvider.autoDispose
    .family<RecordedSteps?, DateTime>(
      (ref, day) => ref.read(nativeHealthProvider).getRecordedSteps(day),
    );

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

  /// Subscribes to the Recording API, which counts steps minute by minute
  /// on the device even while the app is closed. False without a recent
  /// enough Google Play Services or the Physical activity permission; the
  /// activity screen then estimates times from the syncs.
  Future<bool> startStepRecording() async {
    try {
      return await platform.invokeMethod<bool>('startStepRecording') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// [day]'s steps minute by minute up to now, or null when the Recording
  /// API is unavailable or not subscribed.
  Future<RecordedSteps?> getRecordedSteps(DateTime day) async {
    final midnight = DateTime(day.year, day.month, day.day);
    final next = DateTime(day.year, day.month, day.day + 1);
    final now = DateTime.now();
    final end = now.isBefore(next) ? now : next;
    if (!end.isAfter(midnight)) return null;
    try {
      final result = await platform
          .invokeMapMethod<String, Object?>('getRecordedSteps', {
            'startMs': midnight.millisecondsSinceEpoch,
            'endMs': end.millisecondsSinceEpoch,
            'bucketMinutes': 1,
          });
      // Anything malformed reads as no recording: the screen estimates.
      if (result case {
        'since': final int since,
        'buckets': final List<Object?> buckets,
      }) {
        return RecordedSteps(
          since: DateTime.fromMillisecondsSinceEpoch(since),
          minutes: [
            for (final bucket in buckets)
              if (bucket case [final int start, final int steps])
                (DateTime.fromMillisecondsSinceEpoch(start), steps),
          ],
        );
      }
      return null;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Whether Android has the app's battery use set to Restricted, which
  /// stops background step syncs and drive detection. False before
  /// Android 9, which has no such setting.
  Future<bool> isBackgroundRestricted() async {
    try {
      return await platform.invokeMethod<bool>('isBackgroundRestricted') ??
          false;
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
