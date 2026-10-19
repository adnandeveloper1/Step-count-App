import 'dart:io';
import 'dart:typed_data';

import 'package:build_up/core/services/local_storage_service.dart';
import 'package:build_up/core/services/native_health_service.dart';
import 'package:build_up/core/utils/activity_log.dart';
import 'package:build_up/core/utils/step_counter_math.dart';
import 'package:build_up/features/step_tracking/presentation/providers/step_provider.dart';
import 'package:build_up/features/step_tracking/presentation/screens/activity_log_screen.dart';
import 'package:flutter/material.dart' hide StepState;
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

final _now = DateTime.now();
DateTime _today(int hour, [int minute = 0]) =>
    DateTime(_now.year, _now.month, _now.day, hour, minute);

/// Today: a walk 9:00–9:30, then a 40-minute ride that left out 312 steps.
class _FakeStorage extends LocalStorageService {
  @override
  ActivityLog getActivityLog() {
    var log = const ActivityLog();
    for (final (at, steps) in [
      (_today(9), 0),
      (_today(9, 15), 400),
      (_today(9, 30), 640),
    ]) {
      log = log.record(now: at, todaySteps: steps, source: CheckSource.app);
    }
    return log.record(
      now: _today(14),
      todaySteps: 640,
      source: CheckSource.background,
      rides: [
        RideSteps(
          Drive(
            id: 5,
            enterSteps: 1000,
            exitSteps: 1312,
            enteredAt: _today(13),
            exitedAt: _today(13, 40),
          ),
          312,
          RideStatus.ended,
        ),
      ],
    );
  }

  @override
  Map<String, int> getDailyHistory() => {};
}

/// Today: the app's first sync at 10:35 already had 908 steps.
class _LateFirstSyncStorage extends LocalStorageService {
  @override
  ActivityLog getActivityLog() => const ActivityLog().record(
    now: _today(10, 35),
    todaySteps: 908,
    source: CheckSource.app,
  );

  @override
  Map<String, int> getDailyHistory() => {};
}

/// Today's log as given.
class _LogStorage extends LocalStorageService {
  final ActivityLog log;

  _LogStorage(this.log);

  @override
  ActivityLog getActivityLog() => log;

  @override
  Map<String, int> getDailyHistory() => {};
}

class _FakeStepNotifier extends StepNotifier {
  @override
  StepState build() => const StepState(
    currentSteps: 640,
    goalSteps: 10000,
    calories: 0,
    distanceKm: 0,
    isRestMode: false,
  );
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pumpScreen(
    WidgetTester tester, {
    LocalStorageService? storage,
    double textScale = 1,
    RecordedSteps? recorded,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageProvider.overrideWithValue(storage ?? _FakeStorage()),
          stepNotifierProvider.overrideWith(_FakeStepNotifier.new),
          recordedStepsProvider.overrideWith((ref, day) async => recorded),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const ActivityLogScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows today\'s total, the walk and the ride', (tester) async {
    await pumpScreen(tester);

    expect(
      tester.widget<Text>(find.byKey(const Key('activity_log_total'))).data,
      '640',
    );
    expect(find.text('640 steps'), findsOneWidget);
    expect(find.text('9:00 AM – 9:30 AM'), findsOneWidget);
    expect(find.byKey(const Key('activity_log_ride_5')), findsOneWidget);
    expect(
      find.text('1:00 PM – 1:40 PM · 312 steps not counted'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('activity_log_ride_steps')), findsOneWidget);
    // Step checks stay hidden until the title is long-pressed.
    expect(find.byKey(const Key('activity_log_syncs')), findsNothing);
  });

  testWidgets('recorded steps give the walk its real times', (tester) async {
    await pumpScreen(
      tester,
      recorded: RecordedSteps(
        since: _today(0),
        minutes: [for (var m = 0; m < 10; m++) (_today(9, 10 + m), 64)],
      ),
    );
    await tester.pump();

    expect(find.text('640 steps'), findsOneWidget);
    expect(find.text('9:10 AM – 9:20 AM'), findsOneWidget);
    expect(find.textContaining('Times come from your phone'), findsOneWidget);
  });

  testWidgets('steps the recording did not see say so', (tester) async {
    // The 9:15-9:30 steps, with recording on but no walking seen.
    await pumpScreen(
      tester,
      recorded: RecordedSteps(
        since: _today(0),
        until: _today(23, 59),
        minutes: [for (var m = 0; m < 5; m++) (_today(9, 5 + m), 80)],
      ),
    );
    await tester.pump();

    expect(
      find.text('9:15 AM – 9:30 AM · not seen as walking, maybe a vehicle'),
      findsOneWidget,
    );
  });

  testWidgets('without recorded steps the times are estimates', (tester) async {
    await pumpScreen(tester);
    await tester.pump();

    expect(find.text('9:00 AM – 9:30 AM'), findsOneWidget);
    expect(find.textContaining('times are approximate'), findsOneWidget);
  });

  // On a first open Google Fonts is still loading Sora, so the timeline is
  // laid out in a fallback font, then again once Sora arrives. A row sized
  // from cached text measurements kept the old height and overflowed.
  testWidgets('timeline rows resize when the font finishes loading', (
    tester,
  ) async {
    await pumpScreen(tester);
    const subtitle = '1:00 PM – 1:40 PM · 312 steps not counted';
    final ride = find.byKey(const Key('activity_log_ride_5'));
    final heightBefore = tester.getSize(ride).height;
    final subtitleBefore = tester.getSize(find.text(subtitle)).height;

    final family = tester.widget<Text>(find.text(subtitle)).style!.fontFamily!;
    final roboto = File(
      '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/'
      'material_fonts/roboto-regular.ttf',
    ).readAsBytesSync();
    await tester.runAsync(
      () => (FontLoader(
        family,
      )..addFont(Future.value(ByteData.sublistView(roboto)))).load(),
    );
    await tester.pump();

    final rideBox = tester.getSize(ride).height;
    final content =
        tester.getSize(find.text('Vehicle ride')).height +
        2 +
        tester.getSize(find.text(subtitle)).height +
        16;
    // The swap changes how the subtitle wraps, so the row must follow it.
    expect(
      tester.getSize(find.text(subtitle)).height,
      isNot(subtitleBefore),
      reason: 'the new font should re-wrap the subtitle',
    );
    expect(rideBox, isNot(heightBefore));
    expect(rideBox, moreOrLessEquals(content, epsilon: 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('steps from before the first sync say their time is unknown', (
    tester,
  ) async {
    await pumpScreen(tester, storage: _LateFirstSyncStorage());

    expect(find.text('908 steps'), findsOneWidget);
    expect(find.text('Before 10:35 AM · time not recorded'), findsOneWidget);
  });

  testWidgets('the hour labels stay inside the chart', (tester) async {
    await pumpScreen(tester);

    final chart = tester.getRect(
      find.byKey(const Key('activity_log_hourly_chart')),
    );
    for (final label in ['12:00 AM', '6:00 PM']) {
      final rect = tester.getRect(find.text(label));
      expect(rect.left, greaterThanOrEqualTo(chart.left), reason: label);
      expect(rect.right, lessThanOrEqualTo(chart.right), reason: label);
    }
  });

  testWidgets('long-pressing the title shows every step check', (tester) async {
    await pumpScreen(tester);

    await tester.longPress(find.byKey(const Key('activity_log_title')));
    await tester.pump();

    expect(find.byKey(const Key('activity_log_syncs')), findsOneWidget);
    expect(find.text('STEP CHECKS (4)'), findsOneWidget);
    expect(find.text('+400'), findsOneWidget);
    expect(find.text('+240'), findsOneWidget);
  });

  testWidgets('an earlier day with no log says so', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('activity_log_day_1')));
    await tester.pump();

    expect(find.byKey(const Key('activity_log_empty')), findsOneWidget);
    expect(find.text('No activity logged this day.'), findsOneWidget);
  });

  for (final scale in [1.3, 2.0]) {
    testWidgets('the day chips fit text at ${scale}x', (tester) async {
      await pumpScreen(tester, textScale: scale);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('activity_log_day_0')), findsOneWidget);
    });
  }

  testWidgets('goal ad steps show as a reward, not a walk', (tester) async {
    final log = const ActivityLog()
        .record(now: _today(0, 30), todaySteps: 200, source: CheckSource.app)
        .record(
          now: _today(0, 40),
          todaySteps: 10000,
          source: CheckSource.goalReward,
        );
    await pumpScreen(tester, storage: _LogStorage(log));

    expect(find.text('+9,800 steps'), findsOneWidget);
    expect(find.text('9,800 steps'), findsNothing);
    expect(
      find.text('12:40 AM · goal completed with a reward'),
      findsOneWidget,
    );
    await tester.longPress(find.byKey(const Key('activity_log_title')));
    await tester.pump();
    expect(find.text('ad'), findsOneWidget);
  });

  testWidgets('steps between syncs far apart say their time is unknown', (
    tester,
  ) async {
    final log = const ActivityLog()
        .record(now: _today(0, 30), todaySteps: 100, source: CheckSource.app)
        .record(now: _today(7), todaySteps: 900, source: CheckSource.app);
    await pumpScreen(tester, storage: _LogStorage(log));

    expect(
      find.text('Between 12:30 AM and 7:00 AM · time not recorded'),
      findsOneWidget,
    );
  });

  testWidgets('a ride the counter could not read says its steps counted', (
    tester,
  ) async {
    final log = const ActivityLog().record(
      now: _today(9),
      todaySteps: 100,
      source: CheckSource.app,
      rides: [
        RideSteps(
          Drive(id: 8, enterSteps: Drive.unknown, enteredAt: _today(8, 30)),
          0,
          RideStatus.ongoing,
        ),
      ],
    );
    await pumpScreen(tester, storage: _LogStorage(log));

    expect(
      find.text('Since 8:30 AM · steps could not be measured, still counted'),
      findsOneWidget,
    );
  });

  testWidgets('a ride from the day before says so', (tester) async {
    final yesterday = DateTime(_now.year, _now.month, _now.day - 1, 23, 30);
    final log = const ActivityLog().record(
      now: _today(0, 30),
      todaySteps: 0,
      source: CheckSource.app,
      rides: [
        RideSteps(
          Drive(id: 9, enterSteps: 1000, enteredAt: yesterday),
          40,
          RideStatus.ongoing,
        ),
      ],
    );
    await pumpScreen(tester, storage: _LogStorage(log));

    expect(
      find.text('Since 11:30 PM the day before · steps paused'),
      findsOneWidget,
    );
  });

  testWidgets('a timed-out ride shows the steps it kept', (tester) async {
    final drive = Drive(id: 4, enterSteps: 1000, enteredAt: _today(0, 10));
    final log = const ActivityLog()
        .record(
          now: _today(0, 20),
          todaySteps: 0,
          source: CheckSource.app,
          rides: [RideSteps(drive, 1200, RideStatus.ongoing)],
        )
        .record(
          now: _today(4, 30),
          todaySteps: 1200,
          source: CheckSource.app,
          rides: [RideSteps(drive, 0, RideStatus.timedOut)],
        );
    await pumpScreen(tester, storage: _LogStorage(log));

    expect(
      find.text('From 12:10 AM · end not detected, 1,200 steps kept'),
      findsOneWidget,
    );
  });
}
