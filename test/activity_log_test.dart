import 'package:build_up/core/utils/activity_log.dart';
import 'package:build_up/core/utils/step_counter_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DateTime at(int hour, [int minute = 0, int day = 12]) =>
      DateTime(2026, 10, day, hour, minute);

  ActivityLog recordAll(List<(DateTime, int)> syncs, [ActivityLog? log]) {
    var result = log ?? const ActivityLog();
    for (final (now, steps) in syncs) {
      result = result.record(
        now: now,
        todaySteps: steps,
        source: CheckSource.background,
      );
    }
    return result;
  }

  RideSteps ride(
    int id,
    RideStatus status, {
    required DateTime start,
    DateTime? end,
    int steps = 0,
  }) => RideSteps(
    Drive(
      id: id,
      enterSteps: 1000,
      exitSteps: status == RideStatus.ongoing ? null : 1000 + steps,
      enteredAt: start,
      exitedAt: end,
    ),
    steps,
    status,
  );

  group('record', () {
    test('keeps only the first and last of a run with the same total', () {
      final log = recordAll([
        (at(8), 100),
        (at(9), 100),
        (at(10), 100),
        (at(11), 100),
        (at(12), 300),
      ]);
      expect(log.day(at(0)).checks.map((c) => (c.at.hour, c.steps)), [
        (8, 100),
        (11, 100),
        (12, 300),
      ]);
    });

    test('drops days older than a week', () {
      final log = recordAll([(at(9, 0, 5), 10), (at(9, 0, 6), 20)]);
      final later = recordAll([(at(9, 0, 12), 30)], log);
      expect(later.days.keys, ['2026-10-06', '2026-10-12']);
    });

    test('updates a ride in place as it goes from ongoing to ended', () {
      var log = const ActivityLog().record(
        now: at(13, 30),
        todaySteps: 500,
        source: CheckSource.app,
        rides: [ride(7, RideStatus.ongoing, start: at(13), steps: 40)],
      );
      log = log.record(
        now: at(14),
        todaySteps: 500,
        source: CheckSource.app,
        rides: [
          ride(7, RideStatus.ended, start: at(13), end: at(13, 45), steps: 90),
        ],
      );
      final rides = log.day(at(0)).rides;
      expect(rides, hasLength(1));
      expect(
        (rides.single.status, rides.single.steps, rides.single.end),
        (RideStatus.ended, 90, at(13, 45)),
      );
    });

    test('splits a ride over midnight between its two days', () {
      var log = const ActivityLog().record(
        now: at(23, 50, 11),
        todaySteps: 500,
        source: CheckSource.app,
        rides: [ride(3, RideStatus.ongoing, start: at(23, 30, 11), steps: 300)],
      );
      log = log.record(
        now: at(0, 20),
        todaySteps: 0,
        source: CheckSource.app,
        rides: [
          ride(
            3,
            RideStatus.ended,
            start: at(23, 30, 11),
            end: at(0, 10),
            steps: 30,
          ),
        ],
      );
      // The day before keeps what it held out, now ended; today has the rest.
      final before = log.day(at(0, 0, 11)).rides.single;
      expect(
        (before.steps, before.status, before.end),
        (300, RideStatus.ended, at(0, 10)),
      );
      final today = log.day(at(0)).rides.single;
      expect((today.steps, today.start), (30, at(23, 30, 11)));
    });

    test('a ride still going after midnight shows on the new day', () {
      var log = const ActivityLog().record(
        now: at(23, 50, 11),
        todaySteps: 500,
        source: CheckSource.app,
        rides: [ride(3, RideStatus.ongoing, start: at(23, 30, 11), steps: 300)],
      );
      log = log.record(
        now: at(0, 20),
        todaySteps: 0,
        source: CheckSource.app,
        rides: [ride(3, RideStatus.ongoing, start: at(23, 30, 11), steps: 40)],
      );
      expect(log.day(at(0, 0, 11)).rides.single.steps, 300);
      expect(log.day(at(0)).rides.single.status, RideStatus.ongoing);
    });

    test(
      'a ride that ended before midnight but synced after stays on its day',
      () {
        final log = const ActivityLog().record(
          now: at(0, 20),
          todaySteps: 0,
          source: CheckSource.app,
          rides: [
            ride(
              3,
              RideStatus.ended,
              start: at(23, 10, 11),
              end: at(23, 40, 11),
              steps: 25,
            ),
          ],
        );
        expect(log.day(at(0, 0, 11)).rides.single.steps, 25);
        expect(log.day(at(0)).rides, isEmpty);
      },
    );

    test('a ride that times out remembers the steps it gave back', () {
      var log = const ActivityLog().record(
        now: at(11),
        todaySteps: 1000,
        source: CheckSource.app,
        rides: [ride(1, RideStatus.ongoing, start: at(8), steps: 3000)],
      );
      log = log.record(
        now: at(12, 16),
        todaySteps: 4000,
        source: CheckSource.app,
        rides: [ride(1, RideStatus.timedOut, start: at(8))],
      );
      final r = log.day(at(0)).rides.single;
      expect((r.steps, r.kept, r.keptAt), (0, 3000, at(12, 16)));
      final back = ActivityLog.fromJson(log.toJson()).day(at(0)).rides.single;
      expect((back.kept, back.keptAt), (3000, at(12, 16)));
    });

    test('marks a ride the step counter could not read as unmeasured', () {
      final log = const ActivityLog().record(
        now: at(14),
        todaySteps: 900,
        source: CheckSource.app,
        rides: [
          RideSteps(
            Drive(id: 1, enterSteps: Drive.unknown, enteredAt: at(13)),
            0,
            RideStatus.ongoing,
          ),
          ride(2, RideStatus.ended, start: at(9), end: at(9, 30), steps: 5),
        ],
      );
      expect(log.day(at(0)).rides.map((r) => r.measured), [false, true]);
      final back = ActivityLog.fromJson(log.toJson()).day(at(0)).rides;
      expect(back.map((r) => r.measured), [false, true]);
    });

    test('never folds a goal reward into a run of equal totals', () {
      final log = const ActivityLog()
          .record(now: at(9), todaySteps: 10000, source: CheckSource.app)
          .record(now: at(9, 5), todaySteps: 10000, source: CheckSource.app)
          .record(
            now: at(9, 6),
            todaySteps: 10000,
            source: CheckSource.goalReward,
          );
      expect(log.day(at(0)).checks.last.source, CheckSource.goalReward);
    });

    test('survives a JSON round trip', () {
      final log = const ActivityLog().record(
        now: at(14),
        todaySteps: 900,
        source: CheckSource.app,
        rides: [
          ride(1, RideStatus.ended, start: at(13), end: at(13, 40), steps: 80),
          ride(2, RideStatus.timedOut, start: at(8)),
        ],
      );
      final back = ActivityLog.fromJson(log.toJson());
      final day = back.day(at(0));
      expect(day.checks.map((c) => (c.at, c.steps, c.source)), [
        (at(14), 900, CheckSource.app),
      ]);
      expect(day.rides.map((r) => (r.id, r.start, r.end, r.steps, r.status)), [
        (1, at(13), at(13, 40), 80, RideStatus.ended),
        (2, at(8), null, 0, RideStatus.timedOut),
      ]);
    });

    test('reads anything unreadable as an empty log', () {
      expect(ActivityLog.fromJson('not json').days, isEmpty);
      expect(ActivityLog.fromJson('{"2026-10-12": 5}').days, isEmpty);
    });

    test('a damaged entry costs only that entry, not the week', () {
      final good = recordAll([(at(9, 0, 10), 100), (at(9), 200)]);
      final json = good.toJson().replaceFirst(
        '"2026-10-12":{"c":[',
        '"2026-10-12":{"c":[[1,"x",0],',
      );
      final back = ActivityLog.fromJson(json);
      expect(back.days.keys, ['2026-10-10', '2026-10-12']);
      expect(back.day(at(0)).checks.map((c) => c.steps), [200]);
    });
  });

  group('summarizeDay', () {
    DayActivity summarize(List<(DateTime, int)> syncs) =>
        summarizeDay(recordAll(syncs).day(at(0)), at(0));

    test('spreads steps between two syncs over the hours between them', () {
      // 600 steps between 9:30 and 10:30: half in each hour.
      final day = summarize([(at(9, 30), 0), (at(10, 30), 600)]);
      expect(day.hourly[9], 300);
      expect(day.hourly[10], 300);
      expect(day.hourly.reduce((a, b) => a + b), 600);
    });

    test('an early first sync of the day counts from midnight', () {
      final day = summarize([(at(0, 50), 200)]);
      expect(day.hourly.sublist(0, 2), [200, 0]);
      expect(day.walks.single.start, at(0));
      expect(day.walks.single.timeUnknown, isFalse);
    });

    test('a late first sync leaves its steps off the chart', () {
      // Installed at 10:35 with 908 steps already taken: when is unknown.
      final day = summarize([(at(10, 35), 908), (at(10, 50), 1000)]);
      expect(day.hourly.reduce((a, b) => a + b), 92);
      expect(day.hourly[10], 92);
      expect(day.walks.map((w) => (w.end, w.steps, w.timeUnknown)), [
        (at(10, 35), 908, true),
        (at(10, 50), 92, false),
      ]);
    });

    test('joins back-to-back syncs with steps into one walk', () {
      final day = summarize([(at(9), 0), (at(9, 15), 300), (at(9, 30), 500)]);
      expect(day.walks.map((w) => (w.start, w.end, w.steps)), [
        (at(9), at(9, 30), 500),
      ]);
    });

    test('any still sync in between starts a new walk', () {
      final day = summarize([
        (at(9), 0),
        (at(9, 15), 300),
        (at(9, 17), 300), // 2 min still: a new walk after it
        (at(9, 30), 500),
        (at(10), 500),
        (at(10, 15), 900),
      ]);
      expect(day.walks.map((w) => (w.start, w.end, w.steps)), [
        (at(9), at(9, 15), 300),
        (at(9, 17), at(9, 30), 200),
        (at(10), at(10, 15), 400),
      ]);
    });

    DayActivity summarizeWithRides(
      List<(DateTime, int)> syncs,
      List<RideSteps> rides,
    ) {
      final (lastAt, lastSteps) = syncs.last;
      final log = recordAll(syncs).record(
        now: lastAt.add(const Duration(seconds: 1)),
        todaySteps: lastSteps,
        source: CheckSource.app,
        rides: rides,
      );
      return summarizeDay(log.day(at(0)), at(0));
    }

    test('a walk window stops where a ride starts and resumes after it', () {
      // Steps counted 10:09–10:29 were taken before the 10:12 ride; steps
      // counted 10:29–10:40 after it ended at 10:30.
      final day = summarizeWithRides(
        [(at(10, 9), 0), (at(10, 29), 100), (at(10, 40), 160)],
        [
          ride(
            1,
            RideStatus.ended,
            start: at(10, 12),
            end: at(10, 30),
            steps: 50,
          ),
        ],
      );
      expect(day.walks.map((w) => (w.start, w.end, w.steps)), [
        (at(10, 9), at(10, 12), 100),
        (at(10, 30), at(10, 40), 60),
      ]);
    });

    test('a walk that starts as a ride ends runs on into the next sync', () {
      final day = summarizeWithRides(
        [(at(10), 0), (at(10, 9), 90), (at(10, 12), 190)],
        [ride(1, RideStatus.ended, start: at(9, 59), end: at(10, 6))],
      );
      expect(day.walks.map((w) => (w.start, w.end, w.steps)), [
        (at(10, 6), at(10, 12), 190),
      ]);
    });

    test('rides with steps counted between them stay apart', () {
      // 10:58–11:11 was a walk between two rides 13 minutes apart.
      final day = summarizeWithRides(
        [(at(10, 30), 0), (at(10, 58), 0), (at(11, 11), 285)],
        [
          ride(1, RideStatus.ended, start: at(10, 30), end: at(10, 58)),
          ride(2, RideStatus.ended, start: at(11, 11), end: at(11, 14)),
        ],
      );
      expect(day.rides.map((r) => r.id), [1, 2]);
    });

    test('the chart puts steps at the trimmed walk times', () {
      // Counted 9:00–11:00, but a ride took 9:20–11:00: all in hour 9.
      final day = summarizeWithRides(
        [(at(9), 0), (at(11), 300)],
        [ride(1, RideStatus.ended, start: at(9, 20), end: at(11), steps: 40)],
      );
      expect(day.hourly[9], 300);
      expect(day.hourly[10], 0);
      expect(day.walks.single.end, at(9, 20));
    });

    test('goal ad steps are not drawn as a walk', () {
      final log = recordAll([(at(10), 2000)])
          .record(
            now: at(10, 5),
            todaySteps: 10000,
            source: CheckSource.goalReward,
          )
          .record(now: at(10, 20), todaySteps: 10300, source: CheckSource.app);
      final day = summarizeDay(log.day(at(0)), at(0));
      expect(day.walks.map((w) => w.steps), [2000, 300]);
      expect(day.hourly.reduce((a, b) => a + b), 300);
      expect(day.goalRewards.single.added, 8000);
      expect(day.checks.map((c) => c.added), [2000, 8000, 300]);
    });

    test('steps far from any sync are not spread over the night', () {
      // Nothing synced from 0:30 to 22:00 (the phone held the task back).
      final day = summarize([(at(0, 30), 500), (at(22), 5000)]);
      expect(day.walks.last.timeUnknown, isTrue);
      expect(day.walks.last.start, at(0, 30));
      expect(day.hourly.reduce((a, b) => a + b), 500);
      expect(day.hourly[3], 0);
    });

    test('syncs two hours apart still spread their steps', () {
      final day = summarize([(at(9), 0), (at(11), 600)]);
      expect(day.hourly.sublist(9, 11), [300, 300]);
      expect(day.walks.single.timeUnknown, isFalse);
    });

    DayActivity timedOut() {
      var log = recordAll([(at(7, 55), 1000)]);
      for (var h = 8; h <= 12; h++) {
        log = log.record(
          now: at(h, 15),
          todaySteps: 1000,
          source: CheckSource.app,
          rides: [
            ride(1, RideStatus.ongoing, start: at(8), steps: (h - 7) * 600),
          ],
        );
      }
      log = log.record(
        now: at(12, 16),
        todaySteps: 4000,
        source: CheckSource.app,
        rides: [ride(1, RideStatus.timedOut, start: at(8))],
      );
      for (final (time, steps) in [
        (at(15), 4000),
        (at(15, 15), 4300),
        (at(15, 30), 4600),
        (at(15, 45), 4900),
      ]) {
        log = log.record(now: time, todaySteps: steps, source: CheckSource.app);
      }
      return summarizeDay(log.day(at(0)), at(0));
    }

    test('steps a timed-out ride gives back are spread over the ride', () {
      final day = timedOut();
      // 3000 held 8:00 until the 12:15 sync before the timeout.
      expect(day.hourly.sublist(8, 13), [706, 706, 706, 706, 176]);
      expect(day.walks.where((w) => w.end == at(12, 16)), isEmpty);
    });

    test('a timed-out ride does not split later walks', () {
      final afternoon = timedOut().walks.where((w) => w.start.hour >= 15);
      expect(afternoon.map((w) => (w.start, w.end, w.steps)), [
        (at(15), at(15, 45), 900),
      ]);
    });

    test('leaves tiny walks off the timeline but not the chart', () {
      final day = summarize([(at(9), 0), (at(9, 15), 5)]);
      expect(day.walks, isEmpty);
      expect(day.hourly[9], 5);
    });

    test('a drop in the total comes off the latest hours', () {
      // A ride that started at 10:50 took 150 already-counted steps back.
      final day = summarize([
        (at(9), 0),
        (at(10), 400),
        (at(10, 50), 600),
        (at(11), 450),
      ]);
      expect(day.hourly[9], 400);
      expect(day.hourly[10], 50);
      expect(day.hourly.reduce((a, b) => a + b), 450);
      expect(day.checks.last.added, -150);
    });

    test('adds up the steps rides left out', () {
      final log = const ActivityLog().record(
        now: at(14),
        todaySteps: 900,
        source: CheckSource.app,
        rides: [
          ride(1, RideStatus.ended, start: at(13), end: at(13, 40), steps: 80),
          ride(2, RideStatus.ongoing, start: at(13, 50), steps: 15),
        ],
      );
      expect(summarizeDay(log.day(at(0)), at(0)).rideSteps, 95);
    });

    DayActivity withRides(List<RideSteps> rides) => summarizeDay(
      const ActivityLog()
          .record(
            now: at(20),
            todaySteps: 900,
            source: CheckSource.app,
            rides: rides,
          )
          .day(at(0)),
      at(0),
    );

    test('joins rides with short stops into one', () {
      final day = withRides([
        ride(4, RideStatus.ended, start: at(16, 1), end: at(16, 5), steps: 9),
        ride(3, RideStatus.ended, start: at(15, 55), end: at(15, 57), steps: 8),
        ride(2, RideStatus.ended, start: at(15, 31), end: at(15, 54), steps: 7),
        ride(1, RideStatus.ended, start: at(15, 24), end: at(15, 25), steps: 6),
      ]);
      expect(day.rides, hasLength(1));
      final joined = day.rides.single;
      expect(joined.start, at(15, 24));
      expect(joined.end, at(16, 5));
      expect(joined.steps, 30);
      expect(joined.status, RideStatus.ended);
      expect(day.rideSteps, 30);
    });

    test('keeps rides with a long stop apart', () {
      final day = withRides([
        ride(1, RideStatus.ended, start: at(9), end: at(9, 30), steps: 5),
        ride(2, RideStatus.ended, start: at(9, 46), end: at(10), steps: 5),
      ]);
      expect(day.rides.map((r) => r.id), [1, 2]);
    });

    test('a ride still going joins the one just before it', () {
      final day = withRides([
        ride(1, RideStatus.ended, start: at(9), end: at(9, 30), steps: 5),
        ride(2, RideStatus.ongoing, start: at(9, 35), steps: 3),
      ]);
      final joined = day.rides.single;
      expect(joined.start, at(9));
      expect(joined.end, isNull);
      expect(joined.status, RideStatus.ongoing);
      expect(joined.steps, 8);
    });

    test('a timed-out ride or one without times stays on its own', () {
      final day = withRides([
        ride(1, RideStatus.ended, start: at(9), end: at(9, 30), steps: 5),
        ride(2, RideStatus.timedOut, start: at(9, 32), steps: 3),
        ride(3, RideStatus.ended, start: at(11), end: at(11, 10), steps: 4),
        RideSteps(
          Drive(id: 4, enterSteps: 1000, exitSteps: 1002),
          2,
          RideStatus.ended,
        ),
      ]);
      expect(day.rides, hasLength(4));
    });
  });
}
