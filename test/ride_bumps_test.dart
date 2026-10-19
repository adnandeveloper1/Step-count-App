import 'package:build_up/core/utils/activity_log.dart';
import 'package:build_up/core/utils/ride_bumps.dart';
import 'package:build_up/core/utils/step_counter_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DateTime at(int hour, [int minute = 0, int day = 19]) =>
      DateTime(2026, 10, day, hour, minute);

  // The bike ride of 2026-10-19: the last check was at 11:28, the ride was
  // noticed at 2:33 PM and ended at 2:42 PM, the next check came at 2:51 PM.
  // No enter or exit time.
  const bike = Drive(id: 4, enterSteps: 1140, exitSteps: 1498);
  Drive bikeRide({
    int enterSteps = 1140,
    int? exitSteps = 1498,
    DateTime? enteredAt,
    DateTime? exitedAt,
    bool enteredBeforeBoot = false,
    int id = 4,
  }) => Drive(
    id: id,
    enterSteps: enterSteps,
    exitSteps: exitSteps,
    enteredAt: enteredAt ?? at(14, 33),
    exitedAt: exitSteps == null ? null : exitedAt ?? at(14, 42),
    enteredBeforeBoot: enteredBeforeBoot,
  );

  List<BumpCheck> checksAt2_51({
    List<Drive>? drives,
    Set<String> queued = const {},
    DateTime? lastSyncAt,
    int? lastReading = 1000,
    int hardwareSteps = 1515,
    DateTime? now,
  }) => newBumpChecks(
    drives: drives ?? [bikeRide()],
    queued: queued,
    lastSyncAt: lastSyncAt ?? at(11, 28),
    lastReading: lastReading,
    hardwareSteps: hardwareSteps,
    now: now ?? at(14, 51),
  );

  RecordedSteps recording(
    List<(DateTime, int)> minutes, {
    DateTime? since,
    DateTime? until,
  }) => RecordedSteps(
    since: since ?? at(0),
    until: until ?? at(14, 51),
    minutes: minutes,
  );

  group('newBumpChecks', () {
    test('checks before and after a ride, with the counter steps', () {
      expect(
        checksAt2_51().map((c) => (c.key, c.rideId, c.from, c.to, c.steps)),
        [
          ('in:4', 4, at(11, 28), at(14, 33), 140),
          ('out:4', 4, at(14, 42), at(14, 51), 17),
        ],
      );
    });

    test('a ride still going is only checked before', () {
      final checks = checksAt2_51(drives: [bikeRide(exitSteps: null)]);
      expect(checks.map((c) => c.key), ['in:4']);
    });

    test('never checks the same side of a ride twice', () {
      expect(checksAt2_51(queued: {'in:4', 'out:4'}), isEmpty);
      expect(checksAt2_51(queued: {'in:4'}).map((c) => c.key), ['out:4']);
    });

    test('needs a counter reading on both sides', () {
      expect(checksAt2_51(lastReading: null).map((c) => c.key), ['out:4']);
      expect(
        checksAt2_51(
          drives: [bikeRide(enterSteps: Drive.unknown)],
        ).map((c) => c.key),
        ['out:4'],
      );
      expect(
        checksAt2_51(
          drives: [bikeRide(exitSteps: Drive.unknown)],
        ).map((c) => c.key),
        ['in:4'],
      );
    });

    test('skips a ride from before the phone restarted', () {
      final checks = checksAt2_51(drives: [bikeRide(enteredBeforeBoot: true)]);
      expect(checks.map((c) => c.key), ['out:4']);
    });

    test('skips a ride noticed before the last check', () {
      final checks = checksAt2_51(lastSyncAt: at(14, 35));
      expect(checks.map((c) => c.key), ['out:4']);
    });

    test('skips a reading from before a restart', () {
      // The counter restarted: the last reading is above the enter.
      expect(checksAt2_51(lastReading: 5000).map((c) => c.key), ['out:4']);
      expect(checksAt2_51(hardwareSteps: 1400), isEmpty);
    });

    test('skips stretches that cross midnight', () {
      final checks = checksAt2_51(lastSyncAt: at(23, 0, 18));
      expect(checks.map((c) => c.key), ['out:4']);
    });

    test('skips a stretch another ride falls in', () {
      final checks = checksAt2_51(
        drives: [
          bikeRide(
            id: 3,
            enterSteps: 1020,
            exitSteps: 1060,
            enteredAt: at(12),
            exitedAt: at(12, 20),
          ),
          bikeRide(),
        ],
      );
      expect(checks.map((c) => c.key), ['in:3', 'out:4']);
    });

    test('a stretch without steps needs no check', () {
      expect(checksAt2_51(lastReading: 1140, hardwareSteps: 1498), isEmpty);
    });

    test('a ride with no times is not checked', () {
      expect(checksAt2_51(drives: [bike]), isEmpty);
    });
  });

  group('bumpsIn', () {
    final leadIn = BumpCheck(
      key: 'in:4',
      rideId: 4,
      from: at(11, 28),
      to: at(14, 33),
      steps: 140,
    );

    test('takes out the steps the recording did not see as walking', () {
      expect(bumpsIn(leadIn, recording([(at(12, 5), 10)])), 130);
    });

    test('keeps them when the recording saw at least half', () {
      expect(bumpsIn(leadIn, recording([(at(12, 5), 70)])), 0);
    });

    test('ignores small differences', () {
      final small = BumpCheck(
        key: 'out:4',
        rideId: 4,
        from: at(14, 42),
        to: at(14, 51),
        steps: 17,
      );
      expect(bumpsIn(small, recording(const [], until: at(16))), 0);
    });

    test('waits while the recording may not have saved the stretch', () {
      expect(bumpsIn(leadIn, recording(const [], until: at(14, 40))), isNull);
    });

    test('cannot tell before recording began', () {
      expect(bumpsIn(leadIn, recording(const [], since: at(13))), 0);
    });

    test('only counts recorded minutes inside the stretch', () {
      expect(
        bumpsIn(
          leadIn,
          recording([(at(11, 0), 500), (at(14, 33), 500), (at(12), 20)]),
        ),
        120,
      );
    });

    test('survives a JSON round trip', () {
      final back = BumpCheck.fromJson(leadIn.toJson());
      expect(
        (back.key, back.rideId, back.from, back.to, back.steps),
        (leadIn.key, leadIn.rideId, leadIn.from, leadIn.to, leadIn.steps),
      );
    });
  });

  group('withoutBumps', () {
    const result = StepCounterResult(
      todaySteps: 270,
      baseline: 728,
      drivingSteps: 358,
      appliedDriveIds: [4],
    );

    test('moves the bumps from today into the baseline', () {
      final after = withoutBumps(result, 130);
      expect(after.todaySteps, 140);
      expect(after.baseline, 858);
      expect(after.drivingSteps, 358 + 130);
      expect(after.appliedDriveIds, [4]);
    });

    test('never takes out more than today has', () {
      final after = withoutBumps(result, 400);
      expect(after.todaySteps, 0);
      expect(after.baseline, 728 + 270);
    });

    test('no bumps changes nothing', () {
      expect(withoutBumps(result, 0), same(result));
    });
  });

  group('the activity log', () {
    ActivityLog bikeLog() {
      var log = const ActivityLog();
      for (final (now, steps) in [(at(11, 28), 113), (at(14, 51), 270)]) {
        log = log.record(
          now: now,
          todaySteps: steps,
          source: CheckSource.app,
          rides: [
            if (now == at(14, 51)) RideSteps(bikeRide(), 358, RideStatus.ended),
          ],
        );
      }
      return log;
    }

    test('a later check takes the bumps off the checks since', () {
      // Found at 3:51 PM: 130 bumps before the 2:33 PM ride.
      final log = bikeLog().addRideBumps(
        rideId: 4,
        steps: 130,
        after: at(14, 33),
        before: at(15, 51),
      );
      final day = log.day(at(0));
      expect(day.checks.map((c) => c.steps), [113, 140]);
      expect(day.rides.single.bumps, 130);
      expect(summarizeDay(day, at(0)).rideSteps, 358 + 130);
    });

    test('the check that found them is left alone', () {
      // Found at 2:51 PM itself: that check already saved the lower total.
      final log = bikeLog().addRideBumps(
        rideId: 4,
        steps: 130,
        after: at(14, 33),
        before: at(14, 51),
      );
      expect(log.day(at(0)).checks.map((c) => c.steps), [113, 270]);
    });

    test('later syncs keep the bumps on the ride', () {
      final log = bikeLog()
          .addRideBumps(
            rideId: 4,
            steps: 130,
            after: at(14, 33),
            before: at(15),
          )
          .record(
            now: at(15, 5),
            todaySteps: 150,
            source: CheckSource.app,
            rides: [RideSteps(bikeRide(), 358, RideStatus.ended)],
          );
      expect(log.day(at(0)).rides.single.bumps, 130);
    });

    test('bumps survive a JSON round trip', () {
      final log = bikeLog().addRideBumps(
        rideId: 4,
        steps: 130,
        after: at(14, 33),
        before: at(15),
      );
      expect(
        ActivityLog.fromJson(log.toJson()).day(at(0)).rides.single.bumps,
        130,
      );
    });

    test('the bike day no longer shows the bumps as a walk', () {
      final log = bikeLog().addRideBumps(
        rideId: 4,
        steps: 130,
        after: at(14, 33),
        before: at(15, 51),
      );
      final day = summarizeDay(
        log.day(at(0)),
        at(0),
        recorded: RecordedSteps(
          since: at(0),
          until: at(15, 51),
          minutes: [
            for (var m = 0; m < 9; m++) (at(10, 40 + m), 13),
            for (var m = 0; m < 9; m++) (at(14, 42 + m), 3),
          ],
        ),
      );
      expect(day.walks.where((w) => w.unseen), isEmpty);
      expect(day.rides.single.bumps, 130);
    });
  });
}
