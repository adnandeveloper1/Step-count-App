// Rolling daily step history: today plus the previous 30 days.
// Shared by the app, the background task and the Firebase sync so all
// three keep and trim the same window.

const int stepHistoryDays = 31;

// How many days past the window each cloud sync deletes, so a user who
// skips a few days still gets their old entries cleaned up.
const int _cloudCleanupDays = 7;

String dateKey(DateTime day) =>
    '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

// Calendar day [days] before [day]. DateTime normalises the overflow, and
// unlike subtracting 24h Durations it can't skip a day across DST.
DateTime _daysBefore(DateTime day, int days) =>
    DateTime(day.year, day.month, day.day - days);

// Oldest day that still belongs in the window.
String _oldestKeptKey(DateTime today) =>
    dateKey(_daysBefore(today, stepHistoryDays - 1));

// Drops every day older than the window. Keys are yyyy-MM-dd, so they
// compare correctly as strings.
Map<String, int> trimHistory(Map<String, int> history, DateTime today) {
  final oldest = _oldestKeptKey(today);
  final todayKey = dateKey(today);
  return {
    for (final entry in history.entries)
      if (entry.key.compareTo(oldest) >= 0 &&
          entry.key.compareTo(todayKey) <= 0)
        entry.key: entry.value,
  };
}

// Saves today's steps and trims anything that fell out of the window.
Map<String, int> recordDay(
  Map<String, int> history,
  DateTime today,
  int steps,
) {
  return trimHistory({...history, dateKey(today): steps}, today);
}

// Combines two histories, keeping the higher count for a day both have.
// Used when restoring from Firebase so a partial local day isn't lost.
Map<String, int> mergeHistories(
  Map<String, int> a,
  Map<String, int> b,
  DateTime today,
) {
  final merged = {...a};
  b.forEach((key, steps) {
    final existing = merged[key];
    if (existing == null || steps > existing) merged[key] = steps;
  });
  return trimHistory(merged, today);
}

// Days just outside the window, for the cloud sync to delete.
List<String> expiredDayKeys(DateTime today) {
  return [
    for (int i = stepHistoryDays; i < stepHistoryDays + _cloudCleanupDays; i++)
      dateKey(_daysBefore(today, i)),
  ];
}

// Every one of [keys] that is older than the window.
List<String> staleKeys(Iterable<String> keys, DateTime today) {
  final oldest = _oldestKeptKey(today);
  return [
    for (final key in keys)
      if (key.compareTo(oldest) < 0) key,
  ];
}

// Days in a row, ending today, where the goal was hit. Can't count past
// the window, so the most it returns is [stepHistoryDays].
int goalStreak(Map<String, int> history, int goalSteps, DateTime today) {
  if (goalSteps <= 0) return 0;
  int streak = 0;
  for (int i = 0; i < stepHistoryDays; i++) {
    final steps = history[dateKey(_daysBefore(today, i))];
    if (steps == null || steps < goalSteps) break;
    streak++;
  }
  return streak;
}
