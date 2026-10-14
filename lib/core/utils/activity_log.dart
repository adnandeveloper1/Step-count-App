import 'dart:convert';

import 'step_counter_math.dart';

/// Who read the step counter.
enum CheckSource { app, background }

/// One step sync: today's total at [at].
class StepCheck {
  final DateTime at;
  final int steps;
  final CheckSource source;

  const StepCheck(this.at, this.steps, this.source);
}

/// A vehicle ride as last seen by a sync. [start] and [end] are null when
/// Activity Recognition gave no time; [end] is also null while [status] is
/// [RideStatus.ongoing].
class LoggedRide {
  final int id;
  final DateTime? start;
  final DateTime? end;
  final int steps;
  final RideStatus status;

  const LoggedRide({
    required this.id,
    this.start,
    this.end,
    required this.steps,
    required this.status,
  });
}

/// One day's step syncs and rides, oldest first.
class DayLog {
  final List<StepCheck> checks;
  final List<LoggedRide> rides;

  const DayLog({this.checks = const [], this.rides = const []});
}

/// How many days the log keeps, today included.
const activityLogDays = 7;

/// The step syncs and vehicle rides of the last [activityLogDays] days, keyed
/// by date (yyyy-MM-dd). Kept in local storage and shown on the activity
/// screen.
class ActivityLog {
  final Map<String, DayLog> days;

  const ActivityLog([this.days = const {}]);

  DayLog day(DateTime date) => days[dayKey(date)] ?? const DayLog();

  /// Adds a sync that saved [todaySteps] at [now], updates [rides], and drops
  /// days older than [activityLogDays].
  ///
  /// A run of syncs with the same total keeps only its first and last, so a
  /// phone lying still all night costs two entries.
  ActivityLog record({
    required DateTime now,
    required int todaySteps,
    required CheckSource source,
    List<RideSteps> rides = const [],
  }) {
    final key = dayKey(now);
    final updated = {
      for (final entry in days.entries)
        if (_isKept(entry.key, now))
          entry.key: DayLog(
            checks: [...entry.value.checks],
            rides: [...entry.value.rides],
          ),
    };

    final today = updated[key] ??= DayLog(checks: [], rides: []);
    final checks = today.checks;
    final check = StepCheck(now, todaySteps, source);
    final n = checks.length;
    if (n >= 2 &&
        checks[n - 1].steps == todaySteps &&
        checks[n - 2].steps == todaySteps) {
      checks[n - 1] = check;
    } else {
      checks.add(check);
    }

    for (final ride in rides) {
      final logged = LoggedRide(
        id: ride.drive.id,
        start: ride.drive.enteredAt,
        end: ride.status == RideStatus.ongoing ? null : ride.drive.exitedAt,
        steps: ride.steps,
        status: ride.status,
      );
      // A ride stays on the day it started, even when it ends after midnight.
      final home = updated.entries
          .where((e) => e.value.rides.any((r) => r.id == logged.id))
          .map((e) => e.key)
          .firstOrNull;
      final rideKey = home ?? dayKey(logged.start ?? now);
      if (!_isKept(rideKey, now)) continue;
      final dayRides = (updated[rideKey] ??= DayLog(
        checks: [],
        rides: [],
      )).rides;
      final index = dayRides.indexWhere((r) => r.id == logged.id);
      if (index == -1) {
        dayRides.add(logged);
      } else {
        dayRides[index] = logged;
      }
    }

    return ActivityLog(updated);
  }

  static bool _isKept(String key, DateTime now) {
    final oldest = DateTime(now.year, now.month, now.day - activityLogDays + 1);
    return key.compareTo(dayKey(oldest)) >= 0;
  }

  String toJson() => jsonEncode({
    for (final MapEntry(:key, :value) in days.entries)
      key: {
        'c': [
          for (final c in value.checks)
            [c.at.millisecondsSinceEpoch, c.steps, c.source.index],
        ],
        'r': [
          for (final r in value.rides)
            {
              'id': r.id,
              's': r.start?.millisecondsSinceEpoch,
              'e': r.end?.millisecondsSinceEpoch,
              'n': r.steps,
              'st': r.status.name,
            },
        ],
      },
  });

  /// Reads [toJson]'s output; anything unreadable gives an empty log.
  factory ActivityLog.fromJson(String json) {
    try {
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      DateTime? time(Object? ms) =>
          ms is int ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
      return ActivityLog({
        for (final MapEntry(:key, :value) in decoded.entries)
          key: DayLog(
            checks: [
              for (final c in (value['c'] as List? ?? const []).cast<List>())
                StepCheck(
                  time(c[0])!,
                  c[1] as int,
                  CheckSource.values[c[2] as int],
                ),
            ],
            rides: [
              for (final r in (value['r'] as List? ?? const []).cast<Map>())
                LoggedRide(
                  id: r['id'] as int,
                  start: time(r['s']),
                  end: time(r['e']),
                  steps: r['n'] as int,
                  status: RideStatus.values.byName(r['st'] as String),
                ),
            ],
          ),
      });
    } catch (_) {
      return const ActivityLog();
    }
  }
}

String dayKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// Steps counted over one or more back-to-back syncs. [start] is the sync
/// before, or midnight for the day's first, and either end is pulled in to
/// where a ride began or ended.
class WalkPeriod {
  final DateTime start;
  final DateTime end;
  final int steps;

  const WalkPeriod(this.start, this.end, this.steps);
}

/// One sync as the details list shows it: [added] is the change since the
/// sync before.
class CheckRow {
  final StepCheck check;
  final int added;

  const CheckRow(this.check, this.added);
}

/// What the activity screen shows for one day.
class DayActivity {
  /// Steps per hour of the day, 24 entries.
  final List<int> hourly;

  /// Periods with steps, oldest first.
  final List<WalkPeriod> walks;

  /// Vehicle rides, oldest first.
  final List<LoggedRide> rides;

  /// Every sync, oldest first.
  final List<CheckRow> checks;

  const DayActivity({
    required this.hourly,
    required this.walks,
    required this.rides,
    required this.checks,
  });

  /// Steps held out or removed for being in a vehicle.
  int get rideSteps => rides.fold(0, (sum, r) => sum + r.steps);
}

/// Rides closer than this (a stop at the lights, a quick errand) are shown as
/// one. Only the timeline joins them; the log keeps each ride.
const rideMergeGap = Duration(minutes: 15);

/// Walk periods with fewer steps are left off the timeline (they still count
/// in the hourly chart).
const minWalkSteps = 20;

/// Works out [day]'s hourly steps and walks from [log].
///
/// The sensor is read about every 15 minutes with the app closed (every
/// minute while open), so steps between two syncs are spread evenly over
/// the time between them, less any ride time at either end. Syncs with steps
/// join into one walk only while no still sync or ride comes between. A drop in the total (an open ride taking out steps
/// already counted) comes off the most recent hours.
DayActivity summarizeDay(DayLog log, DateTime day) {
  final midnight = DateTime(day.year, day.month, day.day);
  final hourly = List<int>.filled(24, 0);
  final walks = <WalkPeriod>[];
  final rows = <CheckRow>[];

  final rideTimes = [
    for (final r in log.rides)
      if (r.start case final start?) (start: start, end: r.end),
  ];

  var prevAt = midnight;
  var prevSteps = 0;
  // Whether the last walk can run on into the next sync's steps.
  var lastOpen = false;
  for (final check in log.checks) {
    final added = check.steps - prevSteps;
    rows.add(CheckRow(check, added));
    if (added > 0) {
      final (from, to, rideAfter) = _outsideRides(prevAt, check.at, rideTimes);
      _spread(hourly, midnight, from, to, added);
      final last = walks.lastOrNull;
      if (last != null && lastOpen && from == last.end) {
        walks.last = WalkPeriod(last.start, to, last.steps + added);
      } else {
        walks.add(WalkPeriod(from, to, added));
      }
      lastOpen = !rideAfter;
    } else if (added < 0) {
      var removed = -added;
      for (var h = _hourOf(check.at, midnight); h >= 0 && removed > 0; h--) {
        final take = removed < hourly[h] ? removed : hourly[h];
        hourly[h] -= take;
        removed -= take;
      }
      final last = walks.lastOrNull;
      if (last != null) {
        final left = last.steps + added;
        walks.last = WalkPeriod(last.start, last.end, left < 0 ? 0 : left);
      }
      lastOpen = false;
    } else {
      lastOpen = false;
    }
    prevAt = check.at;
    prevSteps = check.steps;
  }

  return DayActivity(
    hourly: hourly,
    walks: [
      for (final w in walks)
        if (w.steps >= minWalkSteps) w,
    ],
    rides: _joinRides(
      [...log.rides]..sort(
        (a, b) => (a.start ?? a.end ?? midnight).compareTo(
          b.start ?? b.end ?? midnight,
        ),
      ),
      walks,
    ),
    checks: rows,
  );
}

/// Joins each ended ride with the next when it starts within [rideMergeGap]
/// and none of [walks] falls between them. Timed-out rides (their steps were
/// kept) and rides without times stay apart.
List<LoggedRide> _joinRides(List<LoggedRide> sorted, List<WalkPeriod> walks) {
  final joined = <LoggedRide>[];
  for (final ride in sorted) {
    final last = joined.lastOrNull;
    final lastEnd = last?.end;
    final start = ride.start;
    if (last != null &&
        last.status == RideStatus.ended &&
        ride.status != RideStatus.timedOut &&
        lastEnd != null &&
        start != null &&
        start.difference(lastEnd) <= rideMergeGap &&
        !walks.any(
          (w) =>
              w.steps > 0 &&
              w.start.isBefore(start) &&
              w.end.isAfter(lastEnd) &&
              // A window around a whole ride can't say its steps fell in
              // the gap.
              !_spans(w, last.start ?? lastEnd, lastEnd) &&
              !_spans(w, start, ride.end ?? start),
        )) {
      joined.last = LoggedRide(
        id: last.id,
        start: last.start,
        end: ride.end,
        steps: last.steps + ride.steps,
        status: ride.status,
      );
    } else {
      joined.add(ride);
    }
  }
  return joined;
}

bool _spans(WalkPeriod walk, DateTime from, DateTime to) =>
    !walk.start.isAfter(from) && !walk.end.isBefore(to);

/// Cuts the ride time off the ends of [from]–[to]: steps counted then were
/// taken on foot before getting in or after getting out. A ride wholly
/// inside the window leaves it as is, since the steps could be on either
/// side. [rideAfter] is true when a ride falls after the window's first
/// steps, so the next sync's steps must not join them.
(DateTime from, DateTime to, bool rideAfter) _outsideRides(
  DateTime from,
  DateTime to,
  List<({DateTime start, DateTime? end})> rides,
) {
  var rideAfter = false;
  for (final ride in rides) {
    final rideEnd = ride.end ?? to;
    if (!ride.start.isBefore(to) || !rideEnd.isAfter(from)) continue;
    final coversStart = !ride.start.isAfter(from);
    final coversEnd = !rideEnd.isBefore(to);
    if (coversStart && !coversEnd) {
      from = rideEnd;
    } else {
      rideAfter = true;
      if (coversEnd && !coversStart) to = ride.start;
    }
  }
  return (from, to, rideAfter);
}

int _hourOf(DateTime at, DateTime midnight) {
  final h = at.difference(midnight).inHours;
  return h < 0 ? 0 : (h > 23 ? 23 : h);
}

/// Adds [steps] to [hourly], split by how much of [from]–[to] falls in each
/// hour.
void _spread(
  List<int> hourly,
  DateTime midnight,
  DateTime from,
  DateTime to,
  int steps,
) {
  final first = _hourOf(from, midnight);
  final last = _hourOf(to, midnight);
  final total = to.difference(from).inMilliseconds;
  if (first == last || total <= 0) {
    hourly[last] += steps;
    return;
  }
  var given = 0;
  for (var h = first; h <= last; h++) {
    final hourStart = midnight.add(Duration(hours: h));
    final hourEnd = midnight.add(Duration(hours: h + 1));
    final start = from.isAfter(hourStart) ? from : hourStart;
    final end = to.isBefore(hourEnd) ? to : hourEnd;
    // The last hour takes what rounding left over.
    final share = h == last
        ? steps - given
        : (steps * end.difference(start).inMilliseconds / total).round();
    hourly[h] += share;
    given += share;
  }
}
