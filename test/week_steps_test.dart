import 'package:build_up/core/utils/step_history.dart';
import 'package:build_up/features/insight/week_steps.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Wednesday 14 Oct 2026, evening.
  final wednesday = DateTime(2026, 10, 14, 20);
  String day(int month, int d) => dateKey(DateTime(2026, month, d));

  group('buildWeeks', () {
    test('pages are 7 day windows ending today, oldest first', () {
      final weeks = buildWeeks(
        history: const {},
        todaySteps: 0,
        today: wednesday,
      );

      // The newest page is the last 7 days, whatever weekday today is.
      expect(weeks.last.start, DateTime(2026, 10, 8));
      expect(weeks.last.end, DateTime(2026, 10, 14));
      expect(weeks[weeks.length - 2].start, DateTime(2026, 10, 1));
      // 31 days of history need 5 pages of 7.
      expect(weeks, hasLength(5));
      expect(weeks.first.start, DateTime(2026, 9, 10));
    });

    test('reads every day from history, today last', () {
      final weeks = buildWeeks(
        history: {day(10, 8): 4000, day(10, 12): 12000, day(10, 14): 300},
        todaySteps: 500,
        today: wednesday,
      );

      expect(weeks.last.days, [4000, 0, 0, 0, 12000, 0, 500]);
    });

    test('live steps win over a lower stored count for today', () {
      final weeks = buildWeeks(
        history: {day(10, 14): 900},
        todaySteps: 100,
        today: wednesday,
      );

      expect(weeks.last.days.last, 900);
    });

    // The undated weekly array can hold another account's or an old
    // week's numbers, so a day missing from history is 0, never a guess.
    test('a day missing from history is 0', () {
      final weeks = buildWeeks(
        history: {day(10, 13): 3000},
        todaySteps: 0,
        today: wednesday,
      );

      expect(weeks.last.days, [0, 0, 0, 0, 0, 3000, 0]);
    });

    test('days older than the history window have no data', () {
      final weeks = buildWeeks(
        history: {day(9, 14): 5000},
        todaySteps: 0,
        today: wednesday,
      );

      // Window starts 14 Sep; the oldest page starts 10 Sep.
      expect(weeks.first.days, [null, null, null, null, 5000, 0, 0]);
    });
  });

  group('WeekSteps', () {
    final start = DateTime(2026, 10, 5);
    final week = WeekSteps(
      start: start,
      days: const [10000, 0, 6000, 12000, null, null, null],
    );

    test('total and best day', () {
      expect(week.total, 28000);
      expect(week.bestDayIndex, 3);
    });

    test('dayAt gives each day\'s date', () {
      expect(week.dayAt(0), DateTime(2026, 10, 5));
      expect(week.dayAt(6), DateTime(2026, 10, 11));
    });

    test('an empty week has no best day', () {
      final empty = WeekSteps(
        start: start,
        days: const [0, 0, null, null, null, null, null],
      );

      expect(empty.bestDayIndex, isNull);
    });
  });

  group('labels', () {
    WeekSteps from(DateTime start) => WeekSteps(start: start, days: const []);

    test('weekRangeLabel within a month, across months and years', () {
      expect(weekRangeLabel(from(DateTime(2026, 10, 8))), 'Oct 8 – 14, 2026');
      expect(
        weekRangeLabel(from(DateTime(2026, 9, 28))),
        'Sep 28 – Oct 4, 2026',
      );
      expect(
        weekRangeLabel(from(DateTime(2025, 12, 29))),
        'Dec 29, 2025 – Jan 4, 2026',
      );
    });

    test('weekTitle', () {
      expect(weekTitle(0), 'LAST 7 DAYS');
      expect(weekTitle(1), 'PREVIOUS 7 DAYS');
      expect(weekTitle(3), '3 WEEKS AGO');
    });
  });
}
