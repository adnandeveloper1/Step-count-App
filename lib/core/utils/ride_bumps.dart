/// Takes vehicle bumps the step counter counted just before or after a ride
/// out of today's steps.
///
/// Activity Recognition often notices a ride minutes late, or ends it early,
/// and the counter takes the bumps of those minutes for steps. Play
/// Services' step recording leaves them out. So the stretch from the last
/// check to a ride's start, and from its end to the next check, is compared
/// with the recording once it has saved it: when the recording saw under
/// half of the counter's steps as walking, the rest were bumps and go to
/// the ride, like the steps counted during it.
library;

import 'activity_log.dart';
import 'step_counter_math.dart';

/// A stretch beside a ride, between two step counter readings, still to be
/// compared with the recording.
class BumpCheck {
  /// `in:<ride id>` for the stretch before the ride, `out:<ride id>` after.
  final String key;
  final int rideId;
  final DateTime from;
  final DateTime to;

  /// What the counter counted between [from] and [to].
  final int steps;

  const BumpCheck({
    required this.key,
    required this.rideId,
    required this.from,
    required this.to,
    required this.steps,
  });

  Map<String, Object> toJson() => {
    'k': key,
    'r': rideId,
    'f': from.millisecondsSinceEpoch,
    't': to.millisecondsSinceEpoch,
    'n': steps,
  };

  factory BumpCheck.fromJson(Map<Object?, Object?> json) => BumpCheck(
    key: json['k']! as String,
    rideId: json['r']! as int,
    from: DateTime.fromMillisecondsSinceEpoch(json['f']! as int),
    to: DateTime.fromMillisecondsSinceEpoch(json['t']! as int),
    steps: json['n']! as int,
  );
}

/// Differences smaller than this are left alone: the counter and the
/// recording never agree exactly.
const minBumpSteps = 20;

/// The stretches beside [drives] not checked yet ([queued] holds the keys
/// already made). [lastSyncAt] and [lastReading] are the last check and the
/// counter then; [hardwareSteps] is the counter at [now].
///
/// A stretch is only made when the counter readings at both ends are known
/// and from since the phone last restarted, both ends fall on [now]'s day,
/// and no other ride falls in it (its steps are taken out already).
List<BumpCheck> newBumpChecks({
  required List<Drive> drives,
  required Set<String> queued,
  required DateTime? lastSyncAt,
  required int? lastReading,
  required int hardwareSteps,
  required DateTime now,
}) {
  final today = dayKey(now);
  bool overlapsOther(Drive drive, DateTime from, DateTime to) => drives.any(
    (other) =>
        other.id != drive.id &&
        (other.enteredAt?.isBefore(to) ?? false) &&
        (other.exitedAt ?? now).isAfter(from),
  );
  BumpCheck? check(
    String key,
    Drive drive,
    DateTime? from,
    DateTime? to,
    int? fromSteps,
    int? toSteps,
  ) {
    if (queued.contains(key) || from == null || to == null) return null;
    if (fromSteps == null || toSteps == null) return null;
    if (fromSteps == Drive.unknown || toSteps == Drive.unknown) return null;
    if (dayKey(from) != today || dayKey(to) != today || to.isBefore(from)) {
      return null;
    }
    final steps = toSteps - fromSteps;
    if (steps <= 0 || overlapsOther(drive, from, to)) return null;
    return BumpCheck(
      key: key,
      rideId: drive.id,
      from: from,
      to: to,
      steps: steps,
    );
  }

  return [
    for (final drive in drives)
      // A reading above the counter now is from before a restart.
      if (drive.enterSteps <= hardwareSteps &&
          (drive.exitSteps ?? 0) <= hardwareSteps) ...[
        if (!drive.enteredBeforeBoot)
          ?check(
            'in:${drive.id}',
            drive,
            lastSyncAt,
            drive.enteredAt,
            lastReading,
            drive.enterSteps,
          ),
        if (!drive.isOpen && !drive.exitedBeforeBoot)
          ?check(
            'out:${drive.id}',
            drive,
            // Already a check after the exit: its steps were counted then.
            (lastSyncAt?.isAfter(drive.exitedAt ?? now) ?? false)
                ? null
                : drive.exitedAt,
            now,
            drive.exitSteps,
            hardwareSteps,
          ),
      ],
  ];
}

/// The bumps to take out for [check]: its steps the recording did not see
/// as walking, when it saw under half of them. 0 when there are none, or
/// recording had not begun by then; null while the recording may not have
/// saved the stretch yet.
int? bumpsIn(BumpCheck check, RecordedSteps recorded) {
  if (check.from.isBefore(recorded.since)) return 0;
  final until = recorded.until;
  if (until != null && check.to.isAfter(until.subtract(recordingDelay))) {
    return null;
  }
  final from = DateTime(
    check.from.year,
    check.from.month,
    check.from.day,
    check.from.hour,
    check.from.minute,
  );
  final walked = recorded.minutes
      .where((m) => !m.$1.isBefore(from) && m.$1.isBefore(check.to))
      .fold(0, (sum, m) => sum + m.$2);
  final bumps = check.steps - walked;
  return walked * 2 >= check.steps || bumps < minBumpSteps ? 0 : bumps;
}

/// [result] with [bumps] more steps taken out of today, as a finished
/// ride's steps are.
StepCounterResult withoutBumps(StepCounterResult result, int bumps) {
  if (bumps <= 0) return result;
  final taken = bumps < result.todaySteps ? bumps : result.todaySteps;
  return StepCounterResult(
    todaySteps: result.todaySteps - taken,
    baseline: result.baseline + taken,
    drivingSteps: result.drivingSteps + taken,
    appliedDriveIds: result.appliedDriveIds,
    rides: result.rides,
    earlierDaySteps: result.earlierDaySteps,
  );
}
