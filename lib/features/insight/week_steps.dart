import '../../core/utils/step_history.dart';

// Calendar weeks (Monday to Sunday) for the insights week selector,
// built from the 31 day step history.

class WeekSteps {
  final DateTime start;
  // Steps per day, Monday first. null means the day hasn't happened yet.
  final List<int?> days;

  const WeekSteps({required this.start, required this.days});

  DateTime get end => DateTime(start.year, start.month, start.day + 6);

  int get total => days.fold(0, (sum, steps) => sum + (steps ?? 0));

  // Averaged over days that have steps, like the old weekly insights.
  int get dailyAverage {
    final active = days.where((steps) => (steps ?? 0) > 0).length;
    return active == 0 ? 0 : total ~/ active;
  }

  // Index of the day with the most steps, or null if every day is empty.
  int? get bestDayIndex {
    int? best;
    for (int i = 0; i < days.length; i++) {
      final steps = days[i] ?? 0;
      if (steps > 0 && (best == null || steps > days[best]!)) best = i;
    }
    return best;
  }

  int goalDays(int goalSteps) => goalSteps <= 0
      ? 0
      : days.where((steps) => (steps ?? 0) >= goalSteps).length;
}

DateTime mondayOf(DateTime day) =>
    DateTime(day.year, day.month, day.day - (day.weekday - 1));

// Every week that overlaps the history window, oldest first, ending with
// the current week.
//
// [weeklySteps] is the app's older Monday-first array. It still holds the
// last 7 days, so it fills gaps for users who updated before the history
// had built up. [todaySteps] is the live count, which can be ahead of
// storage.
List<WeekSteps> buildWeeks({
  required Map<String, int> history,
  required List<int> weeklySteps,
  required int todaySteps,
  required DateTime today,
}) {
  final todayDate = DateTime(today.year, today.month, today.day);
  final oldestDay = DateTime(
    today.year,
    today.month,
    today.day - (stepHistoryDays - 1),
  );

  int? stepsFor(DateTime day) {
    if (day.isAfter(todayDate)) return null;
    // UTC dates so a DST change can't make a day 23 hours long.
    final daysAgo = DateTime.utc(
      today.year,
      today.month,
      today.day,
    ).difference(DateTime.utc(day.year, day.month, day.day)).inDays;
    var steps = history[dateKey(day)];
    if (steps == null && daysAgo < 7 && weeklySteps.length == 7) {
      steps = weeklySteps[day.weekday - 1];
    }
    steps ??= 0;
    if (daysAgo == 0 && todaySteps > steps) steps = todaySteps;
    return steps;
  }

  final weeks = <WeekSteps>[];
  for (
    var start = mondayOf(oldestDay);
    !start.isAfter(todayDate);
    start = DateTime(start.year, start.month, start.day + 7)
  ) {
    weeks.add(
      WeekSteps(
        start: start,
        days: [
          for (int i = 0; i < 7; i++)
            stepsFor(DateTime(start.year, start.month, start.day + i)),
        ],
      ),
    );
  }
  return weeks;
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

// "Oct 6 – 12, 2026", "Sep 29 – Oct 5, 2026" or
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

// "THIS WEEK", "LAST WEEK" or "3 WEEKS AGO".
String weekTitle(int weeksAgo) => switch (weeksAgo) {
  0 => 'THIS WEEK',
  1 => 'LAST WEEK',
  _ => '$weeksAgo WEEKS AGO',
};
