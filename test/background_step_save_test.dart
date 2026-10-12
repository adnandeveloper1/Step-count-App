import 'dart:io';

import 'package:build_up/core/services/background_step_save.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// The background task's save with the app closed, against a real Hive box,
/// to check when it shows the goal reached notification.
void main() {
  const boxName = 'buildUpData';
  final today = DateTime(2026, 10, 12, 10);
  const todayStr = '2026-10-12';

  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('background_step_save_');
    Hive.init(dir.path);
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  Future<Box> openBox() => Hive.openBox(boxName);

  /// Stores today's state as the app or an earlier run left it.
  Future<void> seed({
    String lastDate = todayStr,
    required int steps,
    required int baseline,
    int goal = 60,
    bool goalNotified = false,
  }) async {
    final box = await openBox();
    await box.putAll({
      'lastDate': lastDate,
      'currentSteps': steps,
      'hardwareBaseline': baseline,
      'stepGoal': goal,
      'goalNotified': goalNotified,
    });
  }

  /// One background run; it closes the box when done, like on the phone.
  Future<BackgroundSyncResult?> run(int hardwareSteps, {DateTime? now}) async {
    await openBox();
    return saveStepsInBackground(hardwareSteps, now: now ?? today);
  }

  Future<bool> goalNotified() async =>
      (await openBox()).get('goalNotified') as bool;

  test(
    'notifies when steps counted while the app is closed reach the goal',
    () async {
      // 41 steps saved; the sensor has since counted 34 more.
      await seed(steps: 41, baseline: 1000);

      final result = await run(1075);

      expect(result!.todaySteps, 75);
      expect(result.notifyGoal, isTrue);
      // Marked, so neither the app nor a later run shows it again.
      expect(await goalNotified(), isTrue);
    },
  );

  test('notifies only once a day across background runs', () async {
    await seed(steps: 41, baseline: 1000);

    expect((await run(1075))!.notifyGoal, isTrue);
    expect((await run(1100))!.notifyGoal, isFalse);
    expect((await run(1200))!.notifyGoal, isFalse);
  });

  test('does not notify again after the app already did', () async {
    await seed(steps: 70, baseline: 1000, goalNotified: true);

    final result = await run(1080);

    expect(result!.notifyGoal, isFalse);
    expect(await goalNotified(), isTrue);
  });

  test('does not notify below the goal', () async {
    await seed(steps: 41, baseline: 1000);

    final result = await run(1050);

    expect(result!.todaySteps, 50);
    expect(result.notifyGoal, isFalse);
    expect(await goalNotified(), isFalse);
  });

  test(
    'a new day resets it, and reaching the goal that day notifies again',
    () async {
      // Yesterday's goal was shown.
      await seed(
        lastDate: '2026-10-11',
        steps: 9000,
        baseline: 1000,
        goalNotified: true,
      );

      // First run of the new day: starts from zero and clears the flag.
      final rollover = await run(10000);
      expect(rollover!.todaySteps, 0);
      expect(rollover.notifyGoal, isFalse);
      expect(await goalNotified(), isFalse);

      // 70 steps later the same day.
      final reached = await run(10070);
      expect(reached!.todaySteps, 70);
      expect(reached.notifyGoal, isTrue);
    },
  );

  test('an unusable sensor reading changes nothing', () async {
    await seed(steps: 41, baseline: 1000);

    expect(await run(0), isNull);
    expect(await goalNotified(), isFalse);
  });
}
