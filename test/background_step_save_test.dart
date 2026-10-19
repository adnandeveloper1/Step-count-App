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

  group('bike bumps before a ride', () {
    // 2026-10-19: checked at 11:28 with 113 steps (counter 1000). The bike
    // ride started about 2:20 PM but was noticed at 2:33 PM and ended at
    // 2:42 PM; the next check came at 2:51 PM (counter 1515).
    DateTime at(int hour, [int minute = 0]) =>
        DateTime(2026, 10, 19, hour, minute);
    final ride = Drive(
      id: 4,
      enterSteps: 1140,
      exitSteps: 1498,
      enteredAt: at(14, 33),
      exitedAt: at(14, 42),
    );

    Future<void> seedMorning({int coins = 0, int lastCoinStep = 0}) async {
      await seed(
        lastDate: '2026-10-19',
        steps: 113,
        baseline: 887,
        goal: 10000,
      );
      final log = const ActivityLog().record(
        now: at(11, 28),
        todaySteps: 113,
        source: CheckSource.app,
      );
      await (await openBox()).putAll({
        'lastSyncMs': at(11, 28).millisecondsSinceEpoch,
        'lastSyncReading': 1000,
        'activityLog': log.toJson(),
        'coins': coins,
        'lastCoinStep': lastCoinStep,
      });
    }

    /// Recording on all day, with no walking seen.
    Future<RecordedSteps?> noWalking(DateTime now) async =>
        RecordedSteps(since: at(0), until: now, minutes: const []);

    Future<BackgroundSyncResult?> runAt(
      DateTime now,
      int hardwareSteps, {
      List<Drive> drives = const [],
      Future<RecordedSteps?> Function(DateTime now)? readRecorded,
    }) async {
      await openBox();
      return saveStepsInBackground(
        hardwareSteps,
        drives: drives,
        now: now,
        readRecorded: readRecorded ?? noWalking,
      );
    }

    test('takes the bumps out with the ride', () async {
      await seedMorning();
      final result = await runAt(at(14, 51), 1515, drives: [ride]);

      // 515 counted since 11:28: 358 on the ride, 140 before it was
      // noticed with no walking recorded, 17 after it.
      expect(result!.todaySteps, 113 + 17);
      final box = await openBox();
      expect(box.get('currentSteps'), 113 + 17);
      expect(box.get('hardwareBaseline'), 887 + 358 + 140);
      expect(box.get('drivingStepsToday'), 358 + 140);
      final day = ActivityLog.fromJson(box.get('activityLog')).day(at(0));
      expect(day.rides.single.notCounted, 358 + 140);
      expect(day.checks.map((c) => c.steps), [113, 113 + 17]);
    });

    test('later checks keep counting from the lower total', () async {
      await seedMorning();
      await runAt(at(14, 51), 1515, drives: [ride]);
      final result = await runAt(at(15, 51), 1733);
      expect(result!.todaySteps, 113 + 17 + 218);
    });

    test('waits until the recording has saved the stretch', () async {
      await seedMorning();
      // Checked at 2:38 PM: the minutes before 2:33 may not be saved yet.
      final early = Drive(id: 4, enterSteps: 1140, enteredAt: at(14, 33));
      final first = await runAt(at(14, 38), 1160, drives: [early]);
      expect(first!.todaySteps, 113 + 140);

      final later = await runAt(at(14, 51), 1515, drives: [ride]);
      expect(later!.todaySteps, 113 + 17);
      final box = await openBox();
      final day = ActivityLog.fromJson(box.get('activityLog')).day(at(0));
      // The 2:38 PM check counted the bumps; it no longer does.
      expect(day.checks.map((c) => (c.at, c.steps)), [
        (at(11, 28), 113),
        (at(14, 38), 113),
        (at(14, 51), 113 + 17),
      ]);
      expect(day.rides.single.notCounted, 358 + 140);
    });

    test('takes nothing out when the recording saw the walking', () async {
      await seedMorning();
      final result = await runAt(
        at(14, 51),
        1515,
        drives: [ride],
        readRecorded: (now) async => RecordedSteps(
          since: at(0),
          until: now,
          minutes: [for (var m = 0; m < 14; m++) (at(14, 5 + m), 10)],
        ),
      );
      expect(result!.todaySteps, 113 + 157);
    });

    test('takes nothing out without the recording', () async {
      await seedMorning();
      final result = await runAt(
        at(14, 51),
        1515,
        drives: [ride],
        readRecorded: (_) async => null,
      );
      expect(result!.todaySteps, 113 + 157);
    });

    test('never takes back coins', () async {
      // 100 more steps had already earned a coin before the ride.
      await seedMorning(coins: 7, lastCoinStep: 200);
      await runAt(at(14, 51), 1515, drives: [ride]);
      final box = await openBox();
      expect(box.get('coins'), 7);
      expect(box.get('lastCoinStep'), 200);
    });

    test('takes nothing out on a day the goal ad filled', () async {
      await seedMorning();
      final box = await openBox();
      final log = ActivityLog.fromJson(
        box.get('activityLog'),
      ).record(now: at(12), todaySteps: 10000, source: CheckSource.goalReward);
      await box.putAll({
        'activityLog': log.toJson(),
        'currentSteps': 10000,
        'hardwareBaseline': 887 - 9887,
        'lastSyncMs': at(12).millisecondsSinceEpoch,
      });
      final result = await runAt(at(14, 51), 1515, drives: [ride]);
      expect(result!.todaySteps, 10000 + 157);
    });

    test('does not read the recording with nothing to check', () async {
      await seedMorning();
      var reads = 0;
      await runAt(
        at(12),
        1050,
        readRecorded: (now) async {
          reads++;
          return null;
        },
      );
      expect(reads, 0);
    });
  });
}
