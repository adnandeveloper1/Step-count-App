import 'package:build_up/core/utils/step_counter_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('settleChallengeSteps', () {
    test(
      'the app credits steps the background task counted while it was closed',
      () {
        // 8051 credited before closing; the background task then saved 10051.
        final r = settleChallengeSteps(
          todaySteps: 10051,
          previousSavedSteps: 10051,
          credited: 8051,
          pending: 0,
          isNewDay: false,
          canCredit: true,
        );
        expect((r.stepsToCredit, r.credited, r.pending), (2000, 10051, 0));
      },
    );

    test(
      'a background midnight rollover keeps yesterday\'s uncredited steps for the app',
      () {
        // Yesterday ended at 9000 with 8000 credited; the background task starts today.
        final rollover = settleChallengeSteps(
          todaySteps: 0,
          previousSavedSteps: 9000,
          credited: 8000,
          pending: 0,
          isNewDay: true,
          canCredit: false,
        );
        expect(
          (rollover.stepsToCredit, rollover.credited, rollover.pending),
          (0, 0, 1000),
        );

        // Later the app opens with 300 steps today.
        final open = settleChallengeSteps(
          todaySteps: 300,
          previousSavedSteps: 300,
          credited: rollover.credited,
          pending: rollover.pending,
          isNewDay: false,
          canCredit: true,
        );
        expect(
          (open.stepsToCredit, open.credited, open.pending),
          (1300, 300, 0),
        );
      },
    );

    test('the app open over midnight credits yesterday\'s last steps', () {
      final r = settleChallengeSteps(
        todaySteps: 0,
        previousSavedSteps: 9000,
        credited: 8800,
        pending: 0,
        isNewDay: true,
        canCredit: true,
      );
      expect((r.stepsToCredit, r.credited, r.pending), (200, 0, 0));
    });

    test('the background task on the same day leaves credit for the app', () {
      final r = settleChallengeSteps(
        todaySteps: 9500,
        previousSavedSteps: 9000,
        credited: 8000,
        pending: 400,
        isNewDay: false,
        canCredit: false,
      );
      expect((r.stepsToCredit, r.credited, r.pending), (0, 8000, 400));
    });

    test('two background rollovers before the app opens keep both days', () {
      final day2 = settleChallengeSteps(
        todaySteps: 0,
        previousSavedSteps: 9000,
        credited: 8000,
        pending: 0,
        isNewDay: true,
        canCredit: false,
      );
      // Background task counted 5000 on day 2, then day 3 starts.
      final day3 = settleChallengeSteps(
        todaySteps: 0,
        previousSavedSteps: 5000,
        credited: day2.credited,
        pending: day2.pending,
        isNewDay: true,
        canCredit: false,
      );
      expect((day3.stepsToCredit, day3.credited, day3.pending), (0, 0, 6000));
    });

    test('a rollover never makes pending steps negative', () {
      final r = settleChallengeSteps(
        todaySteps: 0,
        previousSavedSteps: 500,
        credited: 800,
        pending: 100,
        isNewDay: true,
        canCredit: false,
      );
      expect(r.pending, 100);
    });

    test('fewer steps than already credited credits nothing', () {
      // e.g. a lower count restored from Firestore after sign-in.
      final r = settleChallengeSteps(
        todaySteps: 500,
        previousSavedSteps: 500,
        credited: 800,
        pending: 0,
        isNewDay: false,
        canCredit: true,
      );
      expect((r.stepsToCredit, r.credited, r.pending), (0, 800, 0));
    });
  });

  group('resolveTodaySteps', () {
    test('counts steps since the baseline', () {
      final r = resolveTodaySteps(
        hardwareSteps: 30000,
        baseline: 27000,
        savedToday: 2500,
        isNewDay: false,
      )!;
      expect(r.todaySteps, 3000);
      expect(r.baseline, 27000);
    });

    test('starts a new day at zero from the current reading', () {
      final r = resolveTodaySteps(
        hardwareSteps: 30000,
        baseline: 27000,
        savedToday: 3000,
        isNewDay: true,
      )!;
      expect(r.todaySteps, 0);
      expect(r.baseline, 30000);
    });

    for (final sentinel in [0, -1, -2]) {
      test('ignores non-reading $sentinel and leaves the baseline alone', () {
        expect(
          resolveTodaySteps(
            hardwareSteps: sentinel,
            baseline: 27205,
            savedToday: 8051,
            isNewDay: false,
          ),
          isNull,
        );
      });
    }

    test('a sensor timeout on a new day does not reset the baseline', () {
      expect(
        resolveTodaySteps(
          hardwareSteps: -2,
          baseline: 27205,
          savedToday: 8051,
          isNewDay: true,
        ),
        isNull,
      );
    });

    test('keeps saved steps and adds new ones after a reboot', () {
      // 8051 steps saved, phone rebooted, 400 steps walked since.
      final r = resolveTodaySteps(
        hardwareSteps: 400,
        baseline: 27205,
        savedToday: 8051,
        isNewDay: false,
      )!;
      expect(r.todaySteps, 8451);
      final next = resolveTodaySteps(
        hardwareSteps: 500,
        baseline: r.baseline,
        savedToday: 8451,
        isNewDay: false,
      )!;
      expect(next.todaySteps, 8551);
    });

    test('a second reboot on the same day keeps the count', () {
      final first = resolveTodaySteps(
        hardwareSteps: 400,
        baseline: 27205,
        savedToday: 8051,
        isNewDay: false,
      )!;
      final second = resolveTodaySteps(
        hardwareSteps: 50,
        baseline: first.baseline,
        savedToday: 8451,
        isNewDay: false,
      )!;
      expect(second.todaySteps, 8501);
    });

    test(
      'a higher saved count without a reboot does not inflate the steps',
      () {
        // restoreDataFromFirebase can save more steps than the sensor delta.
        final r = resolveTodaySteps(
          hardwareSteps: 30000,
          baseline: 27000,
          savedToday: 5000,
          isNewDay: false,
        )!;
        expect(r.todaySteps, 3000);
      },
    );

    test('an unset baseline keeps steps already saved today', () {
      // e.g. steps restored from Firestore before the first sensor read.
      final r = resolveTodaySteps(
        hardwareSteps: 30000,
        baseline: 0,
        savedToday: 1200,
        isNewDay: false,
      )!;
      expect(r.todaySteps, 1200);
      expect(r.baseline, 28800);
    });
  });

  group('shouldNotifyGoal', () {
    test('notifies once the goal is reached', () {
      expect(
        shouldNotifyGoal(
          todaySteps: 10000,
          goal: 10000,
          alreadyNotified: false,
        ),
        isTrue,
      );
    });

    test('does not notify below the goal', () {
      expect(
        shouldNotifyGoal(todaySteps: 9999, goal: 10000, alreadyNotified: false),
        isFalse,
      );
    });

    test('does not notify again after the app or background task did', () {
      expect(
        shouldNotifyGoal(todaySteps: 12000, goal: 10000, alreadyNotified: true),
        isFalse,
      );
    });

    test('does not notify for a zero goal', () {
      expect(
        shouldNotifyGoal(todaySteps: 0, goal: 0, alreadyNotified: false),
        isFalse,
      );
    });
  });
}
