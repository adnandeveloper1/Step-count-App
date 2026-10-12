/// Result of turning a raw hardware step counter reading into today's steps.
class StepCounterResult {
  final int todaySteps;
  final int baseline;

  /// Steps removed by the finished drives in [appliedDriveIds].
  final int drivingSteps;

  /// Finished drives folded into [baseline]; delete them once it is saved.
  final List<int> appliedDriveIds;

  const StepCounterResult({
    required this.todaySteps,
    required this.baseline,
    this.drivingSteps = 0,
    this.appliedDriveIds = const [],
  });
}

/// A vehicle ride recorded natively from Activity Recognition transitions,
/// as hardware step counter readings at the enter and the exit.
class Drive {
  /// Marks a reading the sensor did not return in time.
  static const unknown = -1;

  final int id;
  final int enterSteps;

  /// Null while the user is still in the vehicle.
  final int? exitSteps;

  /// When the user got in and out; null if unknown (the drive then never
  /// times out).
  final DateTime? enteredAt;
  final DateTime? exitedAt;

  /// The last time Activity Recognition said the user was still in a
  /// vehicle (see [needsDriveCheck]); null if never asked.
  final DateTime? confirmedAt;

  /// Whether a reading was taken before the phone last restarted, when the
  /// counter was counting from an earlier zero.
  final bool enteredBeforeBoot;
  final bool exitedBeforeBoot;

  const Drive({
    required this.id,
    required this.enterSteps,
    this.exitSteps,
    this.enteredAt,
    this.exitedAt,
    this.confirmedAt,
    this.enteredBeforeBoot = false,
    this.exitedBeforeBoot = false,
  });

  /// Reads a drive sent over the step sensor platform channel.
  factory Drive.fromMap(Map<Object?, Object?> map) {
    DateTime? time(String key) => switch (map[key]) {
      final int ms => DateTime.fromMillisecondsSinceEpoch(ms),
      _ => null,
    };
    return Drive(
      id: map['id'] as int,
      enterSteps: map['enterSteps'] as int,
      exitSteps: map['exitSteps'] as int?,
      enteredAt: time('enterMs'),
      exitedAt: time('exitMs'),
      confirmedAt: time('confirmedMs'),
      enteredBeforeBoot: map['enterBeforeBoot'] as bool? ?? false,
      exitedBeforeBoot: map['exitBeforeBoot'] as bool? ?? false,
    );
  }

  bool get isOpen => exitSteps == null;

  /// The last sign the user was in the vehicle: the enter, or a later
  /// confirmation.
  DateTime? get lastSeenDriving => confirmedAt ?? enteredAt;
}

/// Result of settling which steps still need to go to active challenges.
class ChallengeCredit {
  /// Steps to add to active challenges now.
  final int stepsToCredit;

  /// How many of today's steps have been credited, to store.
  final int credited;

  /// Steps from an earlier day not yet credited, to store.
  final int pending;

  const ChallengeCredit({
    required this.stepsToCredit,
    required this.credited,
    required this.pending,
  });
}

/// Works out which steps go to challenges.
///
/// [credited] is how many of today's steps were already credited and
/// [pending] how many steps from an earlier day still wait to be credited.
/// Only the app can credit challenges ([canCredit]); the background task
/// passes false so steps it counts wait for the app.
ChallengeCredit settleChallengeSteps({
  required int todaySteps,
  required int previousSavedSteps,
  required int credited,
  required int pending,
  required bool isNewDay,
  required bool canCredit,
}) {
  if (isNewDay) {
    // Yesterday's steps that were never credited carry over.
    final leftover = previousSavedSteps - credited;
    if (leftover > 0) pending += leftover;
    credited = 0;
  }
  if (!canCredit) {
    return ChallengeCredit(
      stepsToCredit: 0,
      credited: credited,
      pending: pending,
    );
  }
  final newSteps = todaySteps - credited;
  return ChallengeCredit(
    stepsToCredit: pending + (newSteps > 0 ? newSteps : 0),
    credited: newSteps > 0 ? todaySteps : credited,
    pending: 0,
  );
}

/// Converts the cumulative-since-boot [hardwareSteps] into today's steps.
///
/// [baseline] is the stored hardware reading that corresponds to zero steps
/// today, [savedToday] the last saved count for today, and [isNewDay] whether
/// the stored date is not today.
///
/// Returns null when [hardwareSteps] is not a real reading (0, -1 for no
/// sensor, -2 for a sensor timeout); callers must then leave storage alone.
/// The baseline can go negative after a reboot, because the counter restarts
/// from zero while today's saved steps must be kept.
///
/// Steps counted during [drives] are removed: a finished drive's steps are
/// added to the baseline, and an open drive's steps are left out of
/// [StepCounterResult.todaySteps] until its exit arrives, or until
/// [openDriveTimeout] has passed since [now] without one. Drives listed in
/// [appliedDriveIds] are already in the baseline and are skipped.
StepCounterResult? resolveTodaySteps({
  required int hardwareSteps,
  required int baseline,
  required int savedToday,
  required bool isNewDay,
  List<Drive> drives = const [],
  List<int> appliedDriveIds = const [],
  DateTime? now,
}) {
  if (hardwareSteps <= 0) return null;
  drives = [
    for (final drive in drives)
      if (!appliedDriveIds.contains(drive.id)) drive,
  ];

  now ??= DateTime.now();

  if (isNewDay) {
    return _removeDrives(hardwareSteps, hardwareSteps, drives, now);
  }

  // Unset baseline: anchor so the steps already saved today are kept.
  if (baseline == 0) baseline = hardwareSteps - savedToday;

  // The counter only goes backwards after a reboot: keep today's saved steps
  // and add everything counted since the reboot. A positive baseline is a raw
  // counter value, so a reboot shows as a reading below it; a negative one
  // means we already rebooted today, so only a drop in the total can show it.
  final rebooted = baseline > 0
      ? hardwareSteps < baseline
      : hardwareSteps - baseline < savedToday;
  if (rebooted) baseline = -savedToday;

  return _removeDrives(hardwareSteps, baseline, drives, now);
}

/// How long a drive may go without a sign the user is still in the vehicle.
/// Activity Recognition can miss the exit, and checks may get no answer;
/// after this the drive's steps count again instead of staying hidden.
const openDriveTimeout = Duration(hours: 4);

/// How often to ask Activity Recognition whether the user is still in the
/// vehicle during a drive.
const driveCheckInterval = Duration(minutes: 30);

/// Whether to ask now if the user is still in a vehicle: an open drive has
/// had no sign of driving for [driveCheckInterval]. The answer either
/// confirms the drive or ends it.
bool needsDriveCheck(List<Drive> drives, DateTime now) => drives.any((drive) {
  final seen = drive.lastSeenDriving;
  return drive.isOpen &&
      seen != null &&
      now.difference(seen) > driveCheckInterval;
});

StepCounterResult _removeDrives(
  int hardwareSteps,
  int baseline,
  List<Drive> drives,
  DateTime now,
) {
  // A positive baseline is the reading at today's zero, so a drive's steps
  // before it belong to an earlier day. A negative one is not a reading.
  final dayStart = baseline > 0 ? baseline : null;
  var remaining = hardwareSteps - baseline;
  var driving = 0;
  final applied = <int>[];

  // Steps between [from] and [to], or 0 when a reading is unknown or from
  // before a reboot (above the current counter).
  int stepsBetween(int from, int to) {
    if (from == Drive.unknown || to == Drive.unknown) return 0;
    if (from > hardwareSteps || to > hardwareSteps) return 0;
    if (dayStart != null && from < dayStart) from = dayStart;
    final steps = to - from;
    if (steps <= 0) return 0;
    return steps > remaining ? remaining : steps;
  }

  for (final drive in drives) {
    // The counter restarts from zero at boot, so a drive that began before
    // the restart started, as far as today's count goes, at zero.
    final enter = drive.enteredBeforeBoot ? 0 : drive.enterSteps;
    final seen = drive.lastSeenDriving;
    final timedOut =
        seen != null &&
        (drive.exitedAt ?? now).difference(seen) > openDriveTimeout;
    if (timedOut) {
      // The exit never came in time: its steps count again (an exit that
      // comes later must not take them back), and it can be deleted.
      applied.add(drive.id);
    } else if (drive.isOpen) {
      // Left out of today until the exit arrives; the baseline stays put.
      remaining -= stepsBetween(enter, hardwareSteps);
    } else if (drive.exitedBeforeBoot) {
      // Ended before the restart: today's count lost those steps already.
      applied.add(drive.id);
    } else {
      final steps = stepsBetween(enter, drive.exitSteps!);
      driving += steps;
      remaining -= steps;
      applied.add(drive.id);
    }
  }

  return StepCounterResult(
    todaySteps: remaining < 0 ? 0 : remaining,
    baseline: baseline + driving,
    drivingSteps: driving,
    appliedDriveIds: applied,
  );
}

/// How many applied drive ids are remembered; far more than drives can pile
/// up natively between two syncs.
const appliedDrivesKept = 50;

/// The ids to store after a sync: [stored] plus the drives just [applied],
/// keeping the most recent [appliedDrivesKept].
List<int> rememberAppliedDrives(List<int> stored, List<int> applied) {
  final ids = [...stored, ...applied];
  return ids.length > appliedDrivesKept
      ? ids.sublist(ids.length - appliedDrivesKept)
      : ids;
}
