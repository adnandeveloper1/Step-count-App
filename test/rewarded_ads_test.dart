import 'package:build_up/core/ads/rewarded_ad_limits.dart';
import 'package:build_up/core/utils/step_counter_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('fillToGoal', () {
    test('adds the missing steps by lowering the baseline', () {
      // Sensor reads 53200 with baseline 50000: 3200 steps of a 10000 goal.
      final fill = fillToGoal(
        todaySteps: 3200,
        goal: 10000,
        baseline: 50000,
        lastCoinStep: 3200,
        challengeCredited: 3200,
      )!;
      expect(fill.addedSteps, 6800);
      expect(fill.todaySteps, 10000);
      // The next sync reads 53200 - 43200 = 10000, the filled count.
      expect(fill.baseline, 43200);
    });

    test('the added steps earn no walking coins and no challenge progress', () {
      final fill = fillToGoal(
        todaySteps: 3250,
        goal: 10000,
        baseline: 50000,
        lastCoinStep: 3200,
        challengeCredited: 3250,
      )!;
      // The 50 real steps since the last coin still count towards the next.
      expect(fill.lastCoinStep, 3200 + 6750);
      expect(fill.challengeCredited, 3250 + 6750);
    });

    test('the filled count survives the next sync, including a reboot', () {
      final fill = fillToGoal(
        todaySteps: 3000,
        goal: 11000,
        baseline: 3000,
        lastCoinStep: 3000,
        challengeCredited: 3000,
      )!;
      // A positive baseline can go negative; the reboot check must still
      // see no reboot at the same reading.
      final same = resolveTodaySteps(
        hardwareSteps: 6000,
        baseline: fill.baseline,
        savedToday: fill.todaySteps,
        isNewDay: false,
      )!;
      expect(same.todaySteps, 11000);

      // After a real reboot the counter restarts and today's steps are kept.
      final rebooted = resolveTodaySteps(
        hardwareSteps: 40,
        baseline: fill.baseline,
        savedToday: fill.todaySteps,
        isNewDay: false,
      )!;
      expect(rebooted.todaySteps, 11040);
    });

    test('an unset baseline stays unset so the next sync anchors to it', () {
      final fill = fillToGoal(
        todaySteps: 0,
        goal: 8000,
        baseline: 0,
        lastCoinStep: 0,
        challengeCredited: 0,
      )!;
      expect(fill.baseline, 0);
      final next = resolveTodaySteps(
        hardwareSteps: 120000,
        baseline: fill.baseline,
        savedToday: fill.todaySteps,
        isNewDay: false,
      )!;
      expect(next.todaySteps, 8000);
    });

    test('does nothing once the goal is reached or when there is no goal', () {
      expect(
        fillToGoal(
          todaySteps: 10000,
          goal: 10000,
          baseline: 1,
          lastCoinStep: 0,
          challengeCredited: 0,
        ),
        isNull,
      );
      expect(
        fillToGoal(
          todaySteps: 0,
          goal: 0,
          baseline: 1,
          lastCoinStep: 0,
          challengeCredited: 0,
        ),
        isNull,
      );
    });
  });

  group('rewarded ad limits', () {
    final today = DateTime(2026, 10, 14, 9);

    test('the coin ad can be watched 3 times a day, the goal ad once', () {
      expect(RewardedAdKind.coins.dailyLimit, 3);
      expect(RewardedAdKind.goal.dailyLimit, 1);
      expect(coinAdReward, 50);
    });

    test('counts only views stored for today', () {
      expect(
        adsLeftToday(
          RewardedAdKind.coins,
          storedDate: '2026-10-14',
          watched: 2,
          today: today,
        ),
        1,
      );
      // Yesterday's views don't count against today.
      expect(
        adsLeftToday(
          RewardedAdKind.coins,
          storedDate: '2026-10-13',
          watched: 3,
          today: today,
        ),
        3,
      );
      expect(
        adsLeftToday(
          RewardedAdKind.goal,
          storedDate: '2026-10-14',
          watched: 1,
          today: today,
        ),
        0,
      );
    });

    test('never goes below zero', () {
      expect(
        adsLeftToday(
          RewardedAdKind.goal,
          storedDate: '2026-10-14',
          watched: 5,
          today: today,
        ),
        0,
      );
    });
  });
}
