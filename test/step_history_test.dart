import 'package:build_up/core/utils/step_history.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 10, 12, 18, 30);
  String daysAgo(int n) => dateKey(DateTime(2026, 10, 12 - n));

  test('dateKey pads month and day', () {
    expect(dateKey(DateTime(2026, 3, 7)), '2026-03-07');
  });

  group('recordDay', () {
    test('adds today and keeps today plus the previous 30 days', () {
      final history = {for (int i = 1; i <= 40; i++) daysAgo(i): 1000 + i};

      final result = recordDay(history, today, 5000);

      expect(result.length, stepHistoryDays);
      expect(result['2026-10-12'], 5000);
      expect(result.containsKey(daysAgo(30)), isTrue);
      expect(result.containsKey(daysAgo(31)), isFalse);
    });

    test('overwrites an earlier count for the same day', () {
      final result = recordDay({'2026-10-12': 100}, today, 250);

      expect(result, {'2026-10-12': 250});
    });

    test('drops days after today', () {
      final result = recordDay({'2026-10-13': 900}, today, 10);

      expect(result.containsKey('2026-10-13'), isFalse);
    });

    test('crosses month and year boundaries', () {
      final jan3 = DateTime(2027, 1, 3);
      final result = recordDay({'2026-12-04': 1, '2026-12-03': 2}, jan3, 3);

      expect(result.keys, containsAll(['2026-12-04', '2027-01-03']));
      expect(result.containsKey('2026-12-03'), isFalse);
    });
  });

  test('mergeHistories keeps the higher count per day and trims', () {
    final local = {daysAgo(0): 4000, daysAgo(1): 9000};
    final cloud = {daysAgo(0): 3500, daysAgo(2): 7000, daysAgo(45): 1};

    expect(mergeHistories(local, cloud, today), {
      daysAgo(0): 4000,
      daysAgo(1): 9000,
      daysAgo(2): 7000,
    });
  });

  test('expiredDayKeys lists the week just outside the window', () {
    final keys = expiredDayKeys(today);

    expect(keys.first, daysAgo(31));
    expect(keys.last, daysAgo(37));
    expect(keys, hasLength(7));
  });

  test('staleKeys finds only days older than the window', () {
    expect(
      staleKeys([daysAgo(0), daysAgo(30), daysAgo(31), daysAgo(90)], today),
      [daysAgo(31), daysAgo(90)],
    );
  });

  group('goalStreak', () {
    test('counts back from today while the goal was met', () {
      final history = {
        daysAgo(0): 10000,
        daysAgo(1): 12000,
        daysAgo(2): 9999,
        daysAgo(3): 15000,
      };

      expect(goalStreak(history, 10000, today), 2);
    });

    test('a missing day breaks the streak', () {
      expect(
        goalStreak({daysAgo(0): 10000, daysAgo(2): 10000}, 10000, today),
        1,
      );
    });

    test('is zero when today is under the goal', () {
      expect(goalStreak({daysAgo(0): 10, daysAgo(1): 99999}, 10000, today), 0);
    });

    test('runs across months and stops at the 31 day window', () {
      final history = {for (int i = 0; i < 60; i++) daysAgo(i): 20000};

      expect(goalStreak(history, 10000, today), stepHistoryDays);
    });

    test('is zero for a goal of zero', () {
      expect(goalStreak({daysAgo(0): 500}, 0, today), 0);
    });
  });
}
