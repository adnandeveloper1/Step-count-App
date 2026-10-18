import 'package:build_up/core/utils/monthly_best.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final oct18 = DateTime(2026, 10, 18, 9);

  test('month key is yyyy-MM', () {
    expect(monthKey(DateTime(2026, 3, 1)), '2026-03');
  });

  group('mergeMonthlyBest', () {
    test('after a reinstall (empty storage) a higher remote best stays', () {
      // The phone lost its storage, so it only knows today's steps.
      final merged = mergeMonthlyBest(
        localBest: 1942,
        remoteBest: 5475,
        remoteMonth: '2026-10',
        now: oct18,
      );
      expect(merged, 5475);
    });

    test('the reset to 0 of a fresh install does not lower the remote', () {
      expect(
        mergeMonthlyBest(
          localBest: 0,
          remoteBest: 5475,
          remoteMonth: '2026-10',
          now: oct18,
        ),
        5475,
      );
    });

    test('a new local best this month raises the remote', () {
      expect(
        mergeMonthlyBest(
          localBest: 7000,
          remoteBest: 5475,
          remoteMonth: '2026-10',
          now: oct18,
        ),
        7000,
      );
    });

    test('last month\'s remote best is replaced on the 1st', () {
      expect(
        mergeMonthlyBest(
          localBest: 0,
          remoteBest: 9000,
          remoteMonth: '2026-09',
          now: DateTime(2026, 10, 1, 0, 5),
        ),
        0,
      );
      expect(
        mergeMonthlyBest(
          localBest: 300,
          remoteBest: 9000,
          remoteMonth: '2026-09',
          now: DateTime(2026, 10, 1, 8),
        ),
        300,
      );
    });

    test('the same month a year ago is a different month', () {
      expect(
        mergeMonthlyBest(
          localBest: 100,
          remoteBest: 9000,
          remoteMonth: '2025-10',
          now: oct18,
        ),
        100,
      );
    });

    test('no remote best yet takes the local one', () {
      expect(
        mergeMonthlyBest(
          localBest: 1942,
          remoteBest: null,
          remoteMonth: null,
          now: oct18,
        ),
        1942,
      );
    });

    group('documents written before the month was stored', () {
      test('updated this month: the remote best stays', () {
        expect(
          mergeMonthlyBest(
            localBest: 1942,
            remoteBest: 5475,
            remoteMonth: null,
            remoteUpdatedAt: DateTime(2026, 10, 17, 22),
            now: oct18,
          ),
          5475,
        );
      });

      test('last updated in an earlier month: the best is replaced', () {
        expect(
          mergeMonthlyBest(
            localBest: 1942,
            remoteBest: 9000,
            remoteMonth: null,
            remoteUpdatedAt: DateTime(2026, 9, 30, 22),
            now: oct18,
          ),
          1942,
        );
      });

      test('no update time either: the remote best stays', () {
        expect(
          mergeMonthlyBest(
            localBest: 1942,
            remoteBest: 5475,
            remoteMonth: null,
            now: oct18,
          ),
          5475,
        );
      });
    });
  });

  group('localMonthlyBest', () {
    test('a new day best this month is kept', () {
      final r = localMonthlyBest(
        savedMonth: 10,
        savedBest: 5000,
        todaySteps: 6000,
        now: oct18,
      );
      expect((r.best, r.monthChanged), (6000, false));
    });

    test('a lower day keeps the saved best', () {
      final r = localMonthlyBest(
        savedMonth: 10,
        savedBest: 5000,
        todaySteps: 1000,
        now: oct18,
      );
      expect((r.best, r.monthChanged), (5000, false));
    });

    test('resets on the first update of a new month', () {
      final r = localMonthlyBest(
        savedMonth: 9,
        savedBest: 9000,
        todaySteps: 120,
        now: DateTime(2026, 10, 1, 0, 5),
      );
      expect((r.best, r.monthChanged), (120, true));
    });

    test('empty storage starts from today', () {
      final r = localMonthlyBest(
        savedMonth: 0,
        savedBest: 0,
        todaySteps: 1942,
        now: oct18,
      );
      expect((r.best, r.monthChanged), (1942, true));
    });
  });
}
