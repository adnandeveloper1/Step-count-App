// Best single day this month (`monthlyHighScore`), the Step Race month
// ranking. The phone keeps its own copy, but storage can be lost (a
// reinstall), so the Firestore value is only ever raised within a month and
// is replaced only once the month it belongs to has ended.

/// Month a best belongs to, stored next to it as `monthlyHighScoreMonth`.
String monthKey(DateTime day) =>
    '${day.year}-${day.month.toString().padLeft(2, '0')}';

/// The phone's best after today's update. [monthChanged] is true when the
/// saved best belongs to another month (or none was saved) and was dropped.
({int best, bool monthChanged}) localMonthlyBest({
  required int savedMonth,
  required int savedBest,
  required int todaySteps,
  required DateTime now,
}) {
  final monthChanged = savedMonth != now.month;
  final base = monthChanged ? 0 : savedBest;
  return (
    best: todaySteps > base ? todaySteps : base,
    monthChanged: monthChanged,
  );
}

/// The value to write to Firestore: the higher of [localBest] and the
/// remote best while that one is from this month, else [localBest].
///
/// Documents written before [remoteMonth] was stored fall back to the last
/// update time; without either the remote best is kept, since dropping a
/// real best is worse than keeping an old one until the month ends.
int mergeMonthlyBest({
  required int localBest,
  required int? remoteBest,
  required String? remoteMonth,
  DateTime? remoteUpdatedAt,
  required DateTime now,
}) {
  if (remoteBest == null) return localBest;
  final month =
      remoteMonth ??
      (remoteUpdatedAt == null ? null : monthKey(remoteUpdatedAt));
  final sameMonth = month == null || month == monthKey(now);
  if (!sameMonth) return localBest;
  return remoteBest > localBest ? remoteBest : localBest;
}
