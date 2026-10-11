/// Result of turning a raw hardware step counter reading into today's steps.
class StepCounterResult {
  final int todaySteps;
  final int baseline;

  const StepCounterResult({required this.todaySteps, required this.baseline});
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
StepCounterResult? resolveTodaySteps({
  required int hardwareSteps,
  required int baseline,
  required int savedToday,
  required bool isNewDay,
}) {
  if (hardwareSteps <= 0) return null;

  if (isNewDay) {
    return StepCounterResult(todaySteps: 0, baseline: hardwareSteps);
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

  return StepCounterResult(
    todaySteps: hardwareSteps - baseline,
    baseline: baseline,
  );
}
