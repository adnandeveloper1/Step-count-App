import 'package:build_up/core/services/local_storage_service.dart';
import 'package:build_up/core/utils/activity_log.dart';
import 'package:build_up/core/utils/step_counter_math.dart';
import 'package:build_up/features/step_tracking/presentation/providers/step_provider.dart';
import 'package:build_up/features/step_tracking/presentation/screens/activity_log_screen.dart';
import 'package:flutter/material.dart' hide StepState;
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

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageProvider.overrideWithValue(_FakeStorage()),
          stepNotifierProvider.overrideWith(_FakeStepNotifier.new),
        ],
        child: const MaterialApp(home: ActivityLogScreen()),
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
}
