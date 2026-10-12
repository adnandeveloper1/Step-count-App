import 'package:build_up/core/services/local_storage_service.dart';
import 'package:build_up/core/utils/step_history.dart';
import 'package:build_up/features/auth/presentation/providers/auth_provider.dart';
import 'package:build_up/features/social/presentation/providers/challenge_provider.dart'
    hide storageProvider;
import 'package:build_up/features/step_tracking/presentation/providers/step_provider.dart';
import 'package:build_up/features/step_tracking/presentation/screens/goal_congrats_screen.dart';
import 'package:build_up/features/step_tracking/presentation/widgets/achievement_story_card.dart';
import 'package:flutter/material.dart' hide StepState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

ChallengeItem _challenge(String id, int current, int target) => ChallengeItem(
  id: id,
  title: 'Challenge $id',
  subtitle: '',
  targetSteps: target,
  rewardCoins: 75,
  durationInHours: 24,
  currentSteps: current,
  isActive: true,
);

class _FakeStepNotifier extends StepNotifier {
  @override
  StepState build() => const StepState(
    currentSteps: 8200,
    goalSteps: 8000,
    calories: 310,
    distanceKm: 5.6,
    isRestMode: false,
    weeklySteps: [9000, 8500, 8100, 0, 0, 0, 0],
  );
}

// Goal hit yesterday and the day before, missed three days ago.
class _FakeStorage extends LocalStorageService {
  @override
  Map<String, int> getDailyHistory() {
    final now = DateTime.now();
    String daysAgo(int n) =>
        dateKey(DateTime(now.year, now.month, now.day - n));
    return {daysAgo(1): 9000, daysAgo(2): 8000, daysAgo(3): 7999};
  }
}

class _FakeChallengeNotifier extends ChallengeNotifier {
  @override
  List<ChallengeItem> build() => [
    _challenge('3', 2500, 5000),
    _challenge('4', 100, 8000).copyWith(isActive: false),
    _challenge('5', 9000, 10000).copyWith(isCompleted: true),
  ];
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  void usePhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpView(
    WidgetTester tester, {
    int steps = 10420,
    int goal = 10000,
    int streak = 12,
    List<ChallengeItem> challenges = const [],
    VoidCallback? onContinue,
    VoidCallback? onShare,
  }) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: GoalCongratsView(
          steps: steps,
          goalSteps: goal,
          distanceKm: 7.8,
          calories: 542,
          activeTime: const Duration(hours: 1, minutes: 24),
          streakDays: streak,
          challenges: challenges,
          onContinue: onContinue,
          onShare: onShare,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 5));
  }

  group('GoalCongratsView', () {
    testWidgets('shows steps, goal, stats and streak', (tester) async {
      await pumpView(tester);

      expect(find.text('10,420'), findsOneWidget);
      expect(find.text('/ 10,000 GOAL'), findsOneWidget);
      expect(find.text('TARGET EXCEEDED +420'), findsOneWidget);
      expect(find.text('12-DAY STREAK'), findsOneWidget);
      expect(find.text('1h 24m'), findsOneWidget);
      expect(find.textContaining('7.8'), findsOneWidget);
      expect(find.textContaining('542'), findsOneWidget);
    });

    testWidgets('says GOAL REACHED when steps equal the goal', (tester) async {
      await pumpView(tester, steps: 10000);

      expect(find.text('10,000'), findsOneWidget);
      expect(find.text('GOAL REACHED'), findsOneWidget);
    });

    testWidgets('shows 30+ once the streak fills the 31 day history', (
      tester,
    ) async {
      await pumpView(tester, streak: 31);

      expect(find.text('30+ DAY STREAK'), findsOneWidget);
    });

    testWidgets('shows steps left when opened before the goal', (tester) async {
      await pumpView(tester, steps: 41, goal: 60);

      expect(find.text('19 TO GO'), findsOneWidget);
      expect(find.text('GOAL REACHED'), findsNothing);
      expect(find.text('DAILY GOAL COMPLETE'), findsNothing);
      expect(find.textContaining('STREAK'), findsNothing);
    });

    testWidgets('hides streak count for a one-day streak', (tester) async {
      await pumpView(tester, streak: 1);

      expect(find.text('DAILY GOAL COMPLETE'), findsOneWidget);
      expect(find.textContaining('STREAK'), findsNothing);
    });

    testWidgets('hides the challenges section when none are active', (
      tester,
    ) async {
      await pumpView(tester);

      expect(find.text('ACTIVE CHALLENGES'), findsNothing);
    });

    testWidgets('shows the two challenges closest to done, then a count', (
      tester,
    ) async {
      await pumpView(
        tester,
        challenges: [
          _challenge('1', 200, 1000),
          _challenge('2', 2700, 3000),
          _challenge('3', 2500, 5000),
        ],
      );

      expect(find.text('ACTIVE CHALLENGES'), findsOneWidget);
      expect(find.byKey(const Key('goalCongrats.challenge.2')), findsOneWidget);
      expect(find.byKey(const Key('goalCongrats.challenge.3')), findsOneWidget);
      expect(find.byKey(const Key('goalCongrats.challenge.1')), findsNothing);
      expect(find.text('2,700 / 3,000 STEPS'), findsOneWidget);
      expect(find.text('+1 MORE'), findsOneWidget);
    });

    testWidgets('continue, close and share call their callbacks', (
      tester,
    ) async {
      var continued = 0;
      var shared = 0;
      await pumpView(
        tester,
        onContinue: () => continued++,
        onShare: () => shared++,
      );

      await tester.tap(find.byKey(const Key('goalCongrats.continue')));
      await tester.tap(find.byKey(const Key('goalCongrats.close')));
      await tester.tap(find.byKey(const Key('goalCongrats.share')));

      expect(continued, 2);
      expect(shared, 1);
    });
  });

  group('Share Achievement', () {
    testWidgets('opens the story preview when no share callback is given', (
      tester,
    ) async {
      await pumpView(tester);

      await tester.tap(find.byKey(const Key('goalCongrats.share')));
      // The pulsing dot never settles, so pump past the sheet animation.
      await tester.pump(const Duration(seconds: 1));

      expect(find.byKey(const Key('goalStory.card')), findsOneWidget);
      expect(find.byKey(const Key('goalStory.share')), findsOneWidget);
      expect(find.text('GOAL CRUSHED'), findsOneWidget);
      expect(find.text('+420 STEPS OVER TARGET'), findsOneWidget);
      expect(find.text('12-DAY STREAK 🔥'), findsOneWidget);
    });

    testWidgets('story says GOAL REACHED and hides a one-day streak', (
      tester,
    ) async {
      await pumpView(tester, steps: 10000, streak: 1);

      await tester.tap(find.byKey(const Key('goalCongrats.share')));
      // The pulsing dot never settles, so pump past the sheet animation.
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('GOAL REACHED'), findsWidgets);
      expect(find.text('DAILY TARGET COMPLETE'), findsOneWidget);
      expect(find.textContaining('🔥'), findsNothing);
    });

    test('streakLabel', () {
      expect(streakLabel(0), isNull);
      expect(streakLabel(1), isNull);
      expect(streakLabel(2), '2-DAY STREAK');
      expect(streakLabel(30), '30-DAY STREAK');
      expect(streakLabel(31), '30+ DAY STREAK');
    });

    test('storyDateLabel', () {
      expect(storyDateLabel(DateTime(2026, 10, 18)), 'SUN, OCT 18');
    });
  });

  group('GoalCongratsScreen', () {
    testWidgets('reads goal, steps, streak and challenges from the app', (
      tester,
    ) async {
      usePhoneSize(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageProvider.overrideWithValue(_FakeStorage()),
            stepNotifierProvider.overrideWith(_FakeStepNotifier.new),
            challengeProvider.overrideWith(_FakeChallengeNotifier.new),
            userProfileProvider.overrideWith(
              (ref) => Stream.value({'avatarUrl': '🦊'}),
            ),
          ],
          child: const MaterialApp(home: GoalCongratsScreen()),
        ),
      );
      await tester.pump(const Duration(seconds: 5));

      expect(find.text('8,200'), findsOneWidget);
      expect(find.text('/ 8,000 GOAL'), findsOneWidget);
      expect(find.text('🦊'), findsOneWidget);
      // Today (8,200 live) + the two stored days that met the 8,000 goal.
      expect(find.text('3-DAY STREAK'), findsOneWidget);
      // Only the active, unfinished challenge is shown.
      expect(find.byKey(const Key('goalCongrats.challenge.3')), findsOneWidget);
      expect(find.byKey(const Key('goalCongrats.challenge.4')), findsNothing);
      expect(find.byKey(const Key('goalCongrats.challenge.5')), findsNothing);
    });
  });
}
