import 'package:build_up/core/services/local_storage_service.dart';
import 'package:build_up/core/utils/step_history.dart';
import 'package:build_up/features/auth/presentation/providers/auth_provider.dart';
import 'package:build_up/features/social/presentation/providers/challenge_provider.dart'
    hide storageProvider;
import 'package:build_up/features/step_tracking/presentation/providers/step_provider.dart';
import 'package:build_up/features/step_tracking/presentation/widgets/goal_celebration_listener.dart';
import 'package:flutter/material.dart' hide StepState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class _FakeStorage extends LocalStorageService {
  String celebratedDate;

  _FakeStorage({this.celebratedDate = ''});

  @override
  String getGoalCelebratedDate() => celebratedDate;

  @override
  void saveGoalCelebratedDate(String date) => celebratedDate = date;

  @override
  Map<String, int> getDailyHistory() => {};
}

class _FakeStepNotifier extends StepNotifier {
  final int initialSteps;

  _FakeStepNotifier(this.initialSteps);

  @override
  StepState build() => StepState(
    currentSteps: initialSteps,
    goalSteps: 1000,
    calories: 0,
    distanceKm: 0,
    isRestMode: false,
  );

  void setSteps(int steps) => state = state.copyWith(currentSteps: steps);
}

class _NoChallenges extends ChallengeNotifier {
  @override
  List<ChallengeItem> build() => [];
}

final _congrats = find.byKey(const Key('goalCongrats.continue'));

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('shouldCelebrateGoal', () {
    final today = DateTime(2026, 10, 12, 15);
    bool check(int steps, int goal, String date) => shouldCelebrateGoal(
      steps: steps,
      goalSteps: goal,
      celebratedDate: date,
      today: today,
    );

    expect(check(999, 1000, ''), isFalse);
    expect(check(1000, 1000, ''), isTrue);
    expect(check(5000, 1000, '2026-10-11'), isTrue);
    expect(check(5000, 1000, '2026-10-12'), isFalse);
    expect(check(5000, 0, ''), isFalse);
  });

  late _FakeStorage storage;
  late _FakeStepNotifier steps;

  Future<void> pumpHome(
    WidgetTester tester, {
    int initialSteps = 0,
    String celebratedDate = '',
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    storage = _FakeStorage(celebratedDate: celebratedDate);
    steps = _FakeStepNotifier(initialSteps);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageProvider.overrideWithValue(storage),
          stepNotifierProvider.overrideWith(() => steps),
          challengeProvider.overrideWith(_NoChallenges.new),
          userProfileProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const MaterialApp(
          home: GoalCelebrationListener(child: Scaffold(body: Text('home'))),
        ),
      ),
    );
    await tester.pump();
  }

  // One frame for the step change to reach the listener and push, then
  // time for the transition. The congrats screen animates forever
  // (pulsing dot), so pumpAndSettle would never return.
  Future<void> pumpRoute(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('stays hidden below the goal', (tester) async {
    await pumpHome(tester, initialSteps: 500);

    steps.setSteps(999);
    await pumpRoute(tester);

    expect(_congrats, findsNothing);
    expect(storage.celebratedDate, '');
  });

  testWidgets('opens when steps reach the goal and saves today', (
    tester,
  ) async {
    await pumpHome(tester, initialSteps: 500);

    steps.setSteps(1000);
    await pumpRoute(tester);

    expect(_congrats, findsOneWidget);
    expect(storage.celebratedDate, dateKey(DateTime.now()));
  });

  testWidgets('only opens once a day', (tester) async {
    await pumpHome(tester, initialSteps: 500);
    steps.setSteps(1000);
    await pumpRoute(tester);

    await tester.tap(_congrats);
    await pumpRoute(tester);
    expect(_congrats, findsNothing);

    steps.setSteps(1500);
    await pumpRoute(tester);
    expect(_congrats, findsNothing);
  });

  testWidgets('skips when already shown today', (tester) async {
    await pumpHome(
      tester,
      initialSteps: 2000,
      celebratedDate: dateKey(DateTime.now()),
    );
    await pumpRoute(tester);

    expect(_congrats, findsNothing);
  });

  testWidgets('opens on start when the goal was met while closed', (
    tester,
  ) async {
    await pumpHome(tester, initialSteps: 1200, celebratedDate: '2020-01-01');
    await pumpRoute(tester);

    expect(_congrats, findsOneWidget);
  });

  testWidgets('waits for the app to come back to the front', (tester) async {
    await pumpHome(tester, initialSteps: 500);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    steps.setSteps(1000);
    await pumpRoute(tester);
    expect(_congrats, findsNothing);
    expect(storage.celebratedDate, '');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await pumpRoute(tester);
    expect(_congrats, findsOneWidget);
  });
}
