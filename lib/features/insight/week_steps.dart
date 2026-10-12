import '../../core/utils/step_history.dart';

// Rolling 7 day pages for the insights screen, built from the 31 day
// step history. The newest page is the last 7 days ending today, the one
// before it the 7 days before that, and so on.

class WeekSteps {
  final DateTime start;
  // Steps per day, oldest first, today last on the newest page. null means
  // the day is older than the history window.
  final List<int?> days;

  const WeekSteps({required this.start, required this.days});

  DateTime get end => dayAt(6);

  DateTime dayAt(int index) =>
      DateTime(start.year, start.month, start.day + index);

  int get total => days.fold(0, (sum, steps) => sum + (steps ?? 0));

  // Index of the day with the most steps, or null if every day is empty.
  int? get bestDayIndex {
    int? best;
    for (int i = 0; i < days.length; i++) {
      final steps = days[i] ?? 0;
      if (steps > 0 && (best == null || steps > days[best]!)) best = i;
    }
    return best;
  }
}

// Every 7 day page that overlaps the history window, oldest first, ending
// with the last 7 days.
//
// Steps come only from the dated [history]. The older undated weekly array
// is not used: it is restored from the signed-in account's cloud document
// and can hold an old week's or another account's numbers. [todaySteps] is
// the live count, which can be behind or ahead of storage.
List<WeekSteps> buildWeeks({
  required Map<String, int> history,
  required int todaySteps,
  required DateTime today,
}) {
  final todayDate = DateTime(today.year, today.month, today.day);
  final pageCount = (stepHistoryDays + 6) ~/ 7;

  int? stepsFor(int daysAgo) {
    if (daysAgo >= stepHistoryDays) return null;
    final day = DateTime(today.year, today.month, today.day - daysAgo);
    var steps = history[dateKey(day)] ?? 0;
    if (daysAgo == 0 && todaySteps > steps) steps = todaySteps;
    return steps;
  }

  return [
    for (int page = pageCount - 1; page >= 0; page--)
      WeekSteps(
        start: DateTime(
          todayDate.year,
          todayDate.month,
          todayDate.day - page * 7 - 6,
        ),
        days: [for (int i = 6; i >= 0; i--) stepsFor(page * 7 + i)],
      ),
  ];
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

// "Oct 8 – 14, 2026", "Sep 29 – Oct 5, 2026" or
// "Dec 29, 2025 – Jan 4, 2026".
String weekRangeLabel(WeekSteps week) {
  final s = week.start;
  final e = week.end;
  final startMonth = _months[s.month - 1];
  final endMonth = _months[e.month - 1];
  if (s.year != e.year) {
    return '$startMonth ${s.day}, ${s.year} – $endMonth ${e.day}, ${e.year}';
  }
  if (s.month != e.month) {
    return '$startMonth ${s.day} – $endMonth ${e.day}, ${e.year}';
  }
  return '$startMonth ${s.day} – ${e.day}, ${e.year}';
}

// "LAST 7 DAYS", "PREVIOUS 7 DAYS" or "3 WEEKS AGO".
String weekTitle(int weeksAgo) => switch (weeksAgo) {
  0 => 'LAST 7 DAYS',
  1 => 'PREVIOUS 7 DAYS',
  _ => '$weeksAgo WEEKS AGO',
};
