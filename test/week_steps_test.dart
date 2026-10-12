import 'package:build_up/core/utils/step_history.dart';
import 'package:build_up/features/insight/week_steps.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Sunday 18 Oct 2026, evening. Its week starts Monday 12 Oct.
  final sunday = DateTime(2026, 10, 18, 20);
  String day(int month, int d) => dateKey(DateTime(2026, month, d));

  test('mondayOf finds the Monday of the week', () {
    expect(mondayOf(DateTime(2026, 10, 18)), DateTime(2026, 10, 12));
    expect(mondayOf(DateTime(2026, 10, 12)), DateTime(2026, 10, 12));
    expect(mondayOf(DateTime(2026, 1, 1)), DateTime(2025, 12, 29));
  });

  group('buildWeeks', () {
    test('covers every week in the 31 day window, oldest first', () {
      final weeks = buildWeeks(
        history: const {},
        weeklySteps: const [0, 0, 0, 0, 0, 0, 0],
        todaySteps: 0,
        today: sunday,
      );

      // Window starts Fri 18 Sep, which is in the week of Mon 14 Sep.
      expect(weeks.first.start, DateTime(2026, 9, 14));
      expect(weeks.last.start, DateTime(2026, 10, 12));
      expect(weeks, hasLength(5));
    });

    test('reads steps from history and marks future days as null', () {
      final wednesday = DateTime(2026, 10, 14, 9);
      final weeks = buildWeeks(
        history: {day(10, 12): 4000, day(10, 13): 12000},
        weeklySteps: const [],
        todaySteps: 500,
        today: wednesday,
      );

      expect(weeks.last.days, [4000, 12000, 500, null, null, null, null]);
    });

    test('live steps win over a lower stored count for today', () {
      final weeks = buildWeeks(
        history: {day(10, 18): 100},
        weeklySteps: const [],
        todaySteps: 900,
        today: sunday,
      );

      expect(weeks.last.days.last, 900);
    });

    test('falls back to the weekly array only for missing recent days', () {
      final weeks = buildWeeks(
        history: {day(10, 13): 3000},
        weeklySteps: const [1111, 2222, 3333, 4444, 5555, 6666, 7777],
        todaySteps: 0,
        today: sunday,
      );

      // Tuesday comes from history, the rest from the weekly array.
      expect(weeks.last.days, [1111, 3000, 3333, 4444, 5555, 6666, 7777]);
      // Older weeks never use the weekly array.
      expect(weeks[weeks.length - 2].days, everyElement(0));
    });
  });

  group('WeekSteps', () {
    final monday = DateTime(2026, 10, 5);
    final week = WeekSteps(
      start: monday,
      days: const [10000, 0, 6000, 12000, null, null, null],
    );

    test('total, average over active days and best day', () {
      expect(week.total, 28000);
      expect(week.dailyAverage, 9333);
      expect(week.bestDayIndex, 3);
    });

    test('goalDays counts days at or above the goal', () {
      expect(week.goalDays(10000), 2);
      expect(week.goalDays(0), 0);
    });

    test('an empty week has no average and no best day', () {
      final empty = WeekSteps(
        start: monday,
        days: const [0, 0, null, null, null, null, null],
      );

      expect(empty.dailyAverage, 0);
      expect(empty.bestDayIndex, isNull);
    });
  });

  group('labels', () {
    WeekSteps from(DateTime start) => WeekSteps(start: start, days: const []);

    test('weekRangeLabel within a month, across months and years', () {
      expect(weekRangeLabel(from(DateTime(2026, 10, 5))), 'Oct 5 – 11, 2026');
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
      expect(weekTitle(0), 'THIS WEEK');
      expect(weekTitle(1), 'LAST WEEK');
      expect(weekTitle(3), '3 WEEKS AGO');
    });
  });
}
