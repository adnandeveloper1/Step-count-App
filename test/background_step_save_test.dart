import 'dart:io';

import 'package:build_up/core/services/background_step_save.dart';
import 'package:build_up/core/utils/activity_log.dart';
import 'package:build_up/core/utils/step_counter_math.dart';
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

  test('removes steps counted during a drive and stores the drive', () async {
    await seed(steps: 100, baseline: 1000, goal: 10000);
    await openBox();

    final result = await saveStepsInBackground(
      1500,
      drives: [const Drive(id: 7, enterSteps: 1200, exitSteps: 1450)],
      now: today,
    );

    // 500 counted, 250 of them in a vehicle.
    expect(result!.todaySteps, 250);
    expect(result.appliedDriveIds, [7]);
    final box = await openBox();
    expect(box.get('drivingStepsToday'), 250);
    expect(box.get('appliedDriveIds'), [7]);
  });

  test('logs the sync and the ride for the activity screen', () async {
    await seed(steps: 100, baseline: 1000, goal: 10000);
    await openBox();

    await saveStepsInBackground(
      1500,
      drives: [const Drive(id: 7, enterSteps: 1200, exitSteps: 1450)],
      now: today,
    );

    final box = await openBox();
    final day = ActivityLog.fromJson(box.get('activityLog')).day(today);
    expect(day.checks.map((c) => (c.at, c.steps, c.source)), [
      (today, 250, CheckSource.background),
    ]);
    expect(day.rides.map((r) => (r.id, r.steps)), [(7, 250)]);
  });

  test('steps walked before midnight finish off the day before', () async {
    // Last sync 23:00 with 9000 saved; next run at 1:00, 2000 counted since.
    final lastSync = DateTime(2026, 10, 11, 23);
    await seed(lastDate: '2026-10-11', steps: 9000, baseline: 1000);
    (await openBox()).putAll({
      'lastSyncMs': lastSync.millisecondsSinceEpoch,
      'lastCoinStep': 9000,
      'coins': 5,
      'weeklySteps': '0,0,0,0,0,0,9000',
      'dailyHistory': '{"2026-10-11":9000}',
    });

    final result = await run(12000, now: DateTime(2026, 10, 12, 1));

    expect(result!.todaySteps, 1000);
    // Sent to Firestore too, so the cloud's yesterday isn't left at 9000.
    expect(result.yesterdaySteps, 10000);
    final box = await openBox();
    expect(box.get('currentSteps'), 1000);
    expect(box.get('dailyHistory'), contains('"2026-10-11":10000'));
    // 1000 more yesterday: 10 coins; 1000 today: 10 more.
    expect(box.get('coins'), 25);
    // Sunday 11 Oct belongs to last week; Monday 12 Oct starts a new one.
    expect(box.get('weeklySteps'), '1000,0,0,0,0,0,0');
    final log = ActivityLog.fromJson(box.get('activityLog'));
    expect(
      log.day(lastSync).checks.last.steps,
      10000,
      reason: 'logged at the end of the day before',
    );
  });

  test('without a saved yesterday there is nothing to send for it', () async {
    await seed(steps: 41, baseline: 1000);
    final result = await run(1075);

    expect(result!.yesterdaySteps, isNull);
  });

  test('reports whose data it saved, for the Firestore sync', () async {
    await seed(steps: 41, baseline: 1000);
    await (await openBox()).put('dataOwner', 'a');
    final result = await run(1075);
    expect(result!.dataOwner, 'a');
    expect(result.hadLocalData, isTrue);
  });

  test('data saved before the owner was stored has no owner', () async {
    await seed(steps: 41, baseline: 1000);
    final result = await run(1075);
    expect(result!.dataOwner, isNull);
    expect(result.hadLocalData, isTrue);
  });

  test(
    'a new week drops the days of last week the phone never synced',
    () async {
      // Last synced Wednesday 7 Oct 2026; next run Monday 12 Oct.
      await seed(lastDate: '2026-10-07', steps: 12000, baseline: 1000);
      (await openBox()).putAll({
        'weeklySteps': '8000,9000,12000,0,0,0,0',
        'dailyHistory':
            '{"2026-10-05":8000,"2026-10-06":9000,"2026-10-07":12000}',
      });

      final result = await run(1500);

      // Only Monday, today, is in this week.
      final week = [result!.todaySteps, 0, 0, 0, 0, 0, 0];
      expect(result.weekly, week);
      expect((await openBox()).get('weeklySteps'), week.join(','));
    },
  );
}
