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

  group('resolveTodaySteps with drives', () {
    StepCounterResult resolve({
      required int hardwareSteps,
      int baseline = 27000,
      int savedToday = 1000,
      bool isNewDay = false,
      required List<Drive> drives,
    }) => resolveTodaySteps(
      hardwareSteps: hardwareSteps,
      baseline: baseline,
      savedToday: savedToday,
      isNewDay: isNewDay,
      drives: drives,
    )!;

    test('removes the steps counted during a finished drive', () {
      final r = resolve(
        hardwareSteps: 30000,
        drives: [const Drive(id: 1, enterSteps: 28000, exitSteps: 29500)],
      );
      expect(r.todaySteps, 1500);
      expect(r.baseline, 28500);
      expect(r.drivingSteps, 1500);
      expect(r.appliedDriveIds, [1]);
    });

    test('a drive with zero steps changes nothing but is applied', () {
      final r = resolve(
        hardwareSteps: 30000,
        drives: [const Drive(id: 4, enterSteps: 28000, exitSteps: 28000)],
      );
      expect((r.todaySteps, r.baseline, r.drivingSteps), (3000, 27000, 0));
      expect(r.appliedDriveIds, [4]);
    });

    test('an unfinished drive freezes the count at the enter reading', () {
      final r = resolve(
        hardwareSteps: 29200,
        drives: [const Drive(id: 2, enterSteps: 28000)],
      );
      expect(r.todaySteps, 1000);
      // Nothing is folded into the baseline until the exit arrives.
      expect(r.baseline, 27000);
      expect(r.drivingSteps, 0);
      expect(r.appliedDriveIds, isEmpty);
    });

    test('the same drive, once finished, keeps the total it showed', () {
      final during = resolve(
        hardwareSteps: 29500,
        drives: [const Drive(id: 2, enterSteps: 28000)],
      );
      final after = resolve(
        hardwareSteps: 30000,
        baseline: during.baseline,
        savedToday: during.todaySteps,
        drives: [const Drive(id: 2, enterSteps: 28000, exitSteps: 29500)],
      );
      expect(during.todaySteps, 1000);
      expect(after.todaySteps, 1500);
    });

    test('applies several finished drives and an open one', () {
      final r = resolve(
        hardwareSteps: 33000,
        drives: [
          const Drive(id: 1, enterSteps: 28000, exitSteps: 29000),
          const Drive(id: 2, enterSteps: 30000, exitSteps: 30500),
          const Drive(id: 3, enterSteps: 32000),
        ],
      );
      // 6000 raw, 1000 + 500 driven, 1000 hidden while driving.
      expect(r.todaySteps, 3500);
      expect(r.baseline, 28500);
      expect(r.drivingSteps, 1500);
      expect(r.appliedDriveIds, [1, 2]);
    });

    test('an unknown reading removes nothing', () {
      final r = resolve(
        hardwareSteps: 30000,
        drives: [
          const Drive(id: 1, enterSteps: -1, exitSteps: 29000),
          const Drive(id: 2, enterSteps: 29000, exitSteps: -1),
          const Drive(id: 3, enterSteps: -1),
        ],
      );
      expect((r.todaySteps, r.drivingSteps), (3000, 0));
      expect(r.appliedDriveIds, [1, 2]);
    });

    test("a drive before today's start is applied without removing steps", () {
      // Yesterday's drive, first read today.
      final r = resolve(
        hardwareSteps: 30000,
        isNewDay: true,
        drives: [const Drive(id: 1, enterSteps: 25000, exitSteps: 26000)],
      );
      expect((r.todaySteps, r.baseline, r.drivingSteps), (0, 30000, 0));
      expect(r.appliedDriveIds, [1]);
    });

    test("a drive that started before today only removes today's part", () {
      final r = resolve(
        hardwareSteps: 30000,
        drives: [const Drive(id: 1, enterSteps: 26000, exitSteps: 28000)],
      );
      expect((r.todaySteps, r.drivingSteps), (2000, 1000));
    });

    test("today's total is never negative", () {
      // Fewer steps saved today than the drive covers (e.g. after a restore).
      final r = resolve(
        hardwareSteps: 28500,
        baseline: 28000,
        savedToday: 500,
        drives: [const Drive(id: 1, enterSteps: 27000, exitSteps: 28400)],
      );
      expect(r.todaySteps, greaterThanOrEqualTo(0));
    });

    test('a reading above the current counter (reboot) removes nothing', () {
      final r = resolve(
        hardwareSteps: 400,
        savedToday: 8051,
        drives: [
          const Drive(id: 1, enterSteps: 28000, exitSteps: 29000),
          const Drive(id: 2, enterSteps: 29500),
        ],
      );
      expect((r.todaySteps, r.drivingSteps), (8451, 0));
      expect(r.appliedDriveIds, [1]);
    });

    test('a drive already folded into the baseline is not removed twice', () {
      // Saved, but the app stopped before the native drive was deleted.
      final first = resolve(
        hardwareSteps: 30000,
        drives: [const Drive(id: 1, enterSteps: 28000, exitSteps: 29500)],
      );
      final again = resolveTodaySteps(
        hardwareSteps: 30000,
        baseline: first.baseline,
        savedToday: first.todaySteps,
        isNewDay: false,
        drives: [const Drive(id: 1, enterSteps: 28000, exitSteps: 29500)],
        appliedDriveIds: first.appliedDriveIds,
      )!;
      expect((again.todaySteps, again.drivingSteps), (1500, 0));
      expect(again.appliedDriveIds, isEmpty);
    });

    test('after sign-out, drives left natively remove nothing', () {
      // Sign-out clears the baseline, saved steps and applied ids, but the
      // drives recorded before it are still in native storage.
      final r = resolve(
        hardwareSteps: 30000,
        baseline: 0,
        savedToday: 0,
        drives: [const Drive(id: 1, enterSteps: 28000, exitSteps: 29500)],
      );
      expect((r.todaySteps, r.baseline, r.drivingSteps), (0, 30000, 0));
      expect(r.appliedDriveIds, [1]);
    });

    test('no drives (no Play Services) counts exactly as before', () {
      final before = resolveTodaySteps(
        hardwareSteps: 30000,
        baseline: 27000,
        savedToday: 2500,
        isNewDay: false,
      )!;
      final r = resolve(hardwareSteps: 30000, savedToday: 2500, drives: []);
      expect((r.todaySteps, r.baseline), (before.todaySteps, before.baseline));
      expect(r.drivingSteps, 0);
      expect(r.appliedDriveIds, isEmpty);
    });
  });

  group('drives across restarts and days (#3)', () {
    final now = DateTime(2026, 10, 12, 18);

    StepCounterResult resolve({
      required int hardwareSteps,
      int baseline = 27000,
      int savedToday = 1000,
      bool isNewDay = false,
      required List<Drive> drives,
    }) => resolveTodaySteps(
      hardwareSteps: hardwareSteps,
      baseline: baseline,
      savedToday: savedToday,
      isNewDay: isNewDay,
      drives: drives,
      now: now,
    )!;

    test("a drive across midnight only removes today's part", () {
      // 23:50 enter at 26000; first read today at 27000 (baseline) while
      // still driving; exit at 27800.
      final during = resolve(
        hardwareSteps: 27000,
        baseline: 26500,
        isNewDay: true,
        drives: [const Drive(id: 1, enterSteps: 26000)],
      );
      expect((during.todaySteps, during.baseline), (0, 27000));

      final after = resolve(
        hardwareSteps: 28300,
        baseline: during.baseline,
        savedToday: during.todaySteps,
        drives: [const Drive(id: 1, enterSteps: 26000, exitSteps: 27800)],
      );
      // 1300 since the day started, 800 of them in the vehicle.
      expect((after.todaySteps, after.drivingSteps), (500, 800));
    });

    test('a drive across midnight never makes today negative', () {
      final r = resolve(
        hardwareSteps: 27100,
        baseline: 27000,
        savedToday: 100,
        drives: [const Drive(id: 1, enterSteps: 20000, exitSteps: 27100)],
      );
      expect(r.todaySteps, 0);
    });

    test('a reboot during a drive removes the steps since the reboot', () {
      // 8051 saved before the reboot; entered the vehicle before it, the
      // counter restarted, and the exit came at 300 after the reboot.
      final r = resolve(
        hardwareSteps: 700,
        baseline: 27205,
        savedToday: 8051,
        drives: [
          const Drive(
            id: 1,
            enterSteps: 35000,
            exitSteps: 300,
            enteredBeforeBoot: true,
          ),
        ],
      );
      // Only the 400 steps walked after getting out are new.
      expect((r.todaySteps, r.drivingSteps), (8451, 300));
    });

    test('a reboot during an open drive keeps the count frozen', () {
      final r = resolve(
        hardwareSteps: 300,
        baseline: 27205,
        savedToday: 8051,
        drives: [const Drive(id: 1, enterSteps: 1200, enteredBeforeBoot: true)],
      );
      expect(r.todaySteps, 8051);
    });

    test('a drive before the reboot removes nothing after it', () {
      // Enter 200 and exit 900 were before the reboot, and the counter has
      // passed both since; those steps are not in today's count anymore.
      final r = resolve(
        hardwareSteps: 1500,
        baseline: -8051,
        savedToday: 9551,
        drives: [
          const Drive(
            id: 1,
            enterSteps: 200,
            exitSteps: 900,
            enteredBeforeBoot: true,
            exitedBeforeBoot: true,
          ),
        ],
      );
      expect((r.todaySteps, r.drivingSteps), (9551, 0));
      expect(r.appliedDriveIds, [1]);
    });

    test('an open drive whose exit never arrives stops hiding steps', () {
      final r = resolve(
        hardwareSteps: 30000,
        drives: [
          Drive(
            id: 1,
            enterSteps: 28000,
            enteredAt: now.subtract(
              openDriveTimeout + const Duration(minutes: 1),
            ),
          ),
        ],
      );
      expect((r.todaySteps, r.drivingSteps), (3000, 0));
      // Applied, so it is deleted natively and a new enter can start.
      expect(r.appliedDriveIds, [1]);
    });

    test('an exit that comes after the timeout removes nothing', () {
      // The steps were already counted again once the drive timed out.
      final r = resolve(
        hardwareSteps: 30000,
        drives: [
          Drive(
            id: 1,
            enterSteps: 28000,
            exitSteps: 29500,
            enteredAt: now.subtract(const Duration(hours: 6)),
            exitedAt: now.subtract(const Duration(hours: 1)),
          ),
        ],
      );
      expect((r.todaySteps, r.drivingSteps), (3000, 0));
      expect(r.appliedDriveIds, [1]);
    });

    test('a long drive confirmed recently keeps hiding steps', () {
      final r = resolve(
        hardwareSteps: 30000,
        drives: [
          Drive(
            id: 1,
            enterSteps: 28000,
            enteredAt: now.subtract(const Duration(hours: 6)),
            confirmedAt: now.subtract(const Duration(hours: 1)),
          ),
        ],
      );
      expect(r.todaySteps, 1000);
      expect(r.appliedDriveIds, isEmpty);
    });

    test('a long drive, confirmed along the way, is removed in full', () {
      final r = resolve(
        hardwareSteps: 30000,
        drives: [
          Drive(
            id: 1,
            enterSteps: 28000,
            exitSteps: 29500,
            enteredAt: now.subtract(const Duration(hours: 7)),
            confirmedAt: now.subtract(const Duration(hours: 3)),
            exitedAt: now.subtract(const Duration(hours: 1)),
          ),
        ],
      );
      expect((r.todaySteps, r.drivingSteps), (1500, 1500));
    });

    test('an open drive within the timeout keeps hiding steps', () {
      final r = resolve(
        hardwareSteps: 30000,
        drives: [
          Drive(
            id: 1,
            enterSteps: 28000,
            enteredAt: now.subtract(
              openDriveTimeout - const Duration(minutes: 1),
            ),
          ),
        ],
      );
      expect(r.todaySteps, 1000);
      expect(r.appliedDriveIds, isEmpty);
    });
  });

  group('needsDriveCheck', () {
    final now = DateTime(2026, 10, 12, 18);

    Drive open({required Duration enteredAgo, Duration? confirmedAgo}) => Drive(
      id: 1,
      enterSteps: 28000,
      enteredAt: now.subtract(enteredAgo),
      confirmedAt: confirmedAgo == null ? null : now.subtract(confirmedAgo),
    );

    test('asks once an open drive has gone a while without a sign', () {
      final drive = open(
        enteredAgo: driveCheckInterval + const Duration(minutes: 1),
      );
      expect(needsDriveCheck([drive], now), isTrue);
    });

    test('does not ask for a drive that just started', () {
      final drive = open(
        enteredAgo: driveCheckInterval - const Duration(minutes: 1),
      );
      expect(needsDriveCheck([drive], now), isFalse);
    });

    test('a recent confirmation counts as a sign', () {
      final drive = open(
        enteredAgo: const Duration(hours: 3),
        confirmedAgo: const Duration(minutes: 5),
      );
      expect(needsDriveCheck([drive], now), isFalse);
    });

    test('does not ask without an open drive', () {
      final finished = Drive(
        id: 1,
        enterSteps: 28000,
        exitSteps: 29000,
        enteredAt: now.subtract(const Duration(hours: 3)),
      );
      expect(needsDriveCheck([finished], now), isFalse);
      expect(needsDriveCheck([], now), isFalse);
    });
  });

  group('rememberAppliedDrives', () {
    test('adds the new ids and keeps only the most recent ones', () {
      final ids = rememberAppliedDrives(
        List.generate(appliedDrivesKept, (i) => i),
        [100, 101],
      );
      expect(ids.length, appliedDrivesKept);
      expect(ids.last, 101);
      expect(ids.first, 2);
    });
  });

  group('Drive.fromMap', () {
    test('reads a finished drive from the platform channel', () {
      final d = Drive.fromMap({'id': 3, 'enterSteps': 100, 'exitSteps': 250});
      expect((d.id, d.enterSteps, d.exitSteps, d.isOpen), (3, 100, 250, false));
    });

    test('reads an open drive', () {
      final d = Drive.fromMap({'id': 3, 'enterSteps': 100, 'exitSteps': null});
      expect(d.isOpen, isTrue);
    });

    test('reads the enter time and readings from an earlier boot', () {
      final d = Drive.fromMap({
        'id': 3,
        'enterSteps': 100,
        'enterMs': 1791746148188,
        'exitSteps': 250,
        'exitMs': 1791746160119,
        'confirmedMs': 1791746150000,
        'enterBeforeBoot': true,
        'exitBeforeBoot': false,
      });
      expect(d.enteredAt, DateTime.fromMillisecondsSinceEpoch(1791746148188));
      expect(d.exitedAt, DateTime.fromMillisecondsSinceEpoch(1791746160119));
      expect(d.confirmedAt, DateTime.fromMillisecondsSinceEpoch(1791746150000));
      expect((d.enteredBeforeBoot, d.exitedBeforeBoot), (true, false));
    });
  });
}
