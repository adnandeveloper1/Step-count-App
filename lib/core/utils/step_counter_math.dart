/// Result of turning a raw hardware step counter reading into today's steps.
class StepCounterResult {
  final int todaySteps;
  final int baseline;

  const StepCounterResult({required this.todaySteps, required this.baseline});
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
