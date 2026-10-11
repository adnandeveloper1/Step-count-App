import 'package:build_up/core/utils/step_counter_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
