import 'dart:async';

import 'package:build_up/core/ads/rewarded_ad_limits.dart';
import 'package:build_up/core/services/local_storage_service.dart';
import 'package:build_up/features/shop/presentation/widgets/rewarded_ads_section.dart';
import 'package:build_up/features/step_tracking/presentation/providers/step_provider.dart';
import 'package:flutter/material.dart' hide StepState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class _FakeStorage extends LocalStorageService {
  final watched = <RewardedAdKind, int>{};

  @override
  int rewardedAdsLeft(RewardedAdKind kind, DateTime now) =>
      kind.dailyLimit - (watched[kind] ?? 0);

  @override
  void recordRewardedAd(RewardedAdKind kind, DateTime now) =>
      watched[kind] = (watched[kind] ?? 0) + 1;
}

class _FakeStepNotifier extends StepNotifier {
  final int initialSteps;
  bool canFill = true;
  int fillCalls = 0;

  _FakeStepNotifier(this.initialSteps);

  @override
  StepState build() => StepState(
    currentSteps: initialSteps,
    goalSteps: 10000,
    calories: 0,
    distanceKm: 0,
    isRestMode: false,
  );

  // No Firebase in tests.
  @override
  void addCoins(int amount) =>
      state = state.copyWith(coins: state.coins + amount);

  @override
  Future<bool> canFillStepsToGoal() async => canFill;

  @override
  Future<bool> fillStepsToGoal() async {
    fillCalls++;
    if (!canFill) return false;
    state = state.copyWith(currentSteps: state.goalSteps);
    return true;
  }
}

final _coinsTile = find.byKey(const Key('rewardedAd_coins'));
final _goalTile = find.byKey(const Key('rewardedAd_goal'));

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late _FakeStorage storage;
  late _FakeStepNotifier steps;
  late int adsShown;

  Future<void> pump(
    WidgetTester tester, {
    int initialSteps = 3000,
    ShowRewardedAd? showAd,
  }) async {
    storage = _FakeStorage();
    steps = _FakeStepNotifier(initialSteps);
    adsShown = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageProvider.overrideWithValue(storage),
          stepNotifierProvider.overrideWith(() => steps),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: RewardedAdsSection(
              showAd:
                  showAd ??
                  () async {
                    adsShown++;
                    return true;
                  },
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('a watched coin ad gives 50 coins and counts the view', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(_coinsTile);
    await tester.pumpAndSettle();

    expect(steps.state.coins, 50);
    expect(storage.watched[RewardedAdKind.coins], 1);
    expect(find.text('2 of 3 left today'), findsOneWidget);
  });

  testWidgets('an ad closed early gives nothing and is not counted', (
    tester,
  ) async {
    await pump(tester, showAd: () async => false);

    await tester.tap(_coinsTile);
    await tester.pumpAndSettle();

    expect(steps.state.coins, 0);
    expect(storage.watched, isEmpty);
    expect(find.text('Watch the whole ad to get the reward.'), findsOneWidget);
  });

  testWidgets('the coin ad stops after 3 views today', (tester) async {
    await pump(tester);

    for (var i = 0; i < 4; i++) {
      await tester.tap(_coinsTile);
      await tester.pumpAndSettle();
    }

    expect(adsShown, 3);
    expect(steps.state.coins, 150);
    expect(find.text('Come back tomorrow'), findsOneWidget);
  });

  testWidgets('a double tap opens only one ad', (tester) async {
    final ad = Completer<bool>();
    await pump(
      tester,
      showAd: () {
        adsShown++;
        return ad.future;
      },
    );

    await tester.tap(_coinsTile);
    await tester.pump();
    await tester.tap(_coinsTile);
    await tester.tap(_goalTile);
    await tester.pump();
    ad.complete(true);
    await tester.pumpAndSettle();

    expect(adsShown, 1);
    expect(steps.state.coins, 50);
  });

  testWidgets('the goal ad fills today once, without coins', (tester) async {
    await pump(tester);

    await tester.tap(_goalTile);
    await tester.pumpAndSettle();

    expect(steps.state.currentSteps, 10000);
    expect(steps.state.coins, 0);
    expect(storage.watched[RewardedAdKind.goal], 1);
    expect(find.text('Goal already reached today'), findsOneWidget);
  });

  testWidgets('no goal ad is shown when today\'s steps can\'t be read', (
    tester,
  ) async {
    await pump(tester);
    steps.canFill = false;

    await tester.tap(_goalTile);
    await tester.pumpAndSettle();

    expect(adsShown, 0);
    expect(steps.fillCalls, 0);
    expect(storage.watched, isEmpty);
  });

  testWidgets('the goal ad is off once the goal is reached', (tester) async {
    await pump(tester, initialSteps: 12000);

    await tester.tap(_goalTile);
    await tester.pumpAndSettle();

    expect(adsShown, 0);
    expect(find.text('Goal already reached today'), findsOneWidget);
  });
}
