import 'dart:async';

import 'package:build_up/app/theme/app_theme_model.dart';
import 'package:build_up/core/ads/rewarded_ad_limits.dart';
import 'package:build_up/core/services/local_storage_service.dart';
import 'package:build_up/core/widgets/pro_avatar.dart';
import 'package:build_up/features/auth/presentation/providers/auth_provider.dart';
import 'package:build_up/features/shop/data/shop_cloud.dart';
import 'package:build_up/features/shop/models/pro_avatar_item.dart';
import 'package:build_up/features/shop/presentation/screens/store_screen.dart';
import 'package:build_up/features/step_tracking/presentation/providers/step_provider.dart';
import 'package:flutter/material.dart' hide StepState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class _FakeStorage extends LocalStorageService {
  List<String> purchased = ['default_dark', 'default_light'];
  String active = 'default_dark';

  @override
  List<String> getPurchasedThemes() => List.of(purchased);

  @override
  void savePurchasedThemes(List<String> themes) => purchased = List.of(themes);

  @override
  String getActiveTheme() => active;

  @override
  void saveActiveTheme(String themeId) => active = themeId;

  @override
  int rewardedAdsLeft(RewardedAdKind kind, DateTime now) => kind.dailyLimit;
}

class _FakeStepNotifier extends StepNotifier {
  @override
  StepState build() => const StepState(
    currentSteps: 0,
    goalSteps: 10000,
    calories: 0,
    distanceKm: 0,
    isRestMode: false,
    coins: 2000,
  );

  // No Firebase in tests.
  @override
  bool deductCoins(int amount) {
    if (state.coins < amount) return false;
    state = state.copyWith(coins: state.coins - amount);
    return true;
  }
}

class _FakeShopCloud implements ShopCloud {
  @override
  bool get isSignedIn => true;

  final items = <String>[];
  final themes = <String>[];

  @override
  Future<void> buyItem(String itemId) async => items.add(itemId);

  @override
  Future<void> saveThemePurchase(String themeId) async => themes.add(themeId);

  @override
  Future<void> saveActiveTheme(String themeId) async {}

  @override
  Future<void> backUpThemes(List<String> owned) async {}

  @override
  Future<void> setProAvatarEquipped(bool equipped) async {}
}

final _buyProAvatar = find.byKey(const Key('item.buy.$proAvatarItemId'));
final _confirm = find.byKey(const Key('purchase.confirm'));
final _cancel = find.byKey(const Key('purchase.cancel'));
Finder _buyTheme(String id) => find.byKey(Key('theme.buy.$id'));

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late _FakeStorage storage;
  late _FakeShopCloud cloud;
  late ProviderContainer container;

  // The profile never updates here, like Firestore before the purchase
  // reaches it (offline or slow).
  Future<void> pump(
    WidgetTester tester, {
    Map<String, dynamic> profile = const {},
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    storage = _FakeStorage();
    cloud = _FakeShopCloud();
    container = ProviderContainer(
      overrides: [
        storageProvider.overrideWithValue(storage),
        stepNotifierProvider.overrideWith(_FakeStepNotifier.new),
        shopCloudProvider.overrideWithValue(cloud),
        userProfileProvider.overrideWith((ref) => Stream.value(profile)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: StoreScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  int coins() => container.read(stepNotifierProvider).coins;

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  group('Pro Avatar Frame', () {
    testWidgets('the card shows the frame around the user\'s own avatar', (
      tester,
    ) async {
      await pump(tester, profile: {'avatarUrl': '🏃'});

      final preview = tester.widget<ProAvatar>(find.byType(ProAvatar));
      expect(preview.isPro, isTrue);
      expect(preview.emojiAvatar, '🏃');
    });

    testWidgets('without an avatar the frame shows a placeholder', (
      tester,
    ) async {
      await pump(tester);

      expect(
        tester.widget<ProAvatar>(find.byType(ProAvatar)).emojiAvatar,
        '👤',
      );
    });

    testWidgets('asks before spending coins', (tester) async {
      await pump(tester);

      await tap(tester, _buyProAvatar);

      expect(find.text('Buy Pro Avatar Frame for 500 coins?'), findsOneWidget);
      expect(coins(), 2000);
      expect(cloud.items, isEmpty);
    });

    testWidgets('Cancel spends nothing', (tester) async {
      await pump(tester);

      await tap(tester, _buyProAvatar);
      await tap(tester, _cancel);

      expect(coins(), 2000);
      expect(cloud.items, isEmpty);
    });

    testWidgets('Buy spends the coins once and saves the item', (tester) async {
      await pump(tester);

      await tap(tester, _buyProAvatar);
      await tap(tester, _confirm);

      expect(coins(), 2000 - proAvatarPrice);
      expect(cloud.items, [proAvatarItemId]);
    });

    testWidgets('is not charged again before the account shows it as owned', (
      tester,
    ) async {
      await pump(tester);

      await tap(tester, _buyProAvatar);
      await tap(tester, _confirm);
      await tap(tester, _buyProAvatar);

      expect(_confirm, findsNothing);
      expect(coins(), 2000 - proAvatarPrice);
      expect(cloud.items, [proAvatarItemId]);
    });

    testWidgets('a double tap opens one question', (tester) async {
      await pump(tester);
      await tester.ensureVisible(_buyProAvatar);

      await tester.tap(_buyProAvatar);
      await tester.tap(_buyProAvatar, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(_confirm, findsOneWidget);
      await tap(tester, _confirm);
      expect(coins(), 2000 - proAvatarPrice);
    });
  });

  group('themes', () {
    testWidgets('asks before spending coins', (tester) async {
      await pump(tester);

      await tap(tester, _buyTheme('ocean_wave'));

      expect(
        find.text('Buy Ocean Wave for $themePrice coins?'),
        findsOneWidget,
      );
      expect(coins(), 2000);
    });

    testWidgets('Cancel spends nothing', (tester) async {
      await pump(tester);

      await tap(tester, _buyTheme('ocean_wave'));
      await tap(tester, _cancel);

      expect(coins(), 2000);
      expect(storage.purchased, isNot(contains('ocean_wave')));
    });

    testWidgets('Buy spends the coins and equips the theme', (tester) async {
      await pump(tester);

      await tap(tester, _buyTheme('ocean_wave'));
      await tap(tester, _confirm);

      expect(coins(), 2000 - themePrice);
      expect(storage.purchased, contains('ocean_wave'));
      expect(storage.active, 'ocean_wave');
    });

    testWidgets('equipping an owned theme does not ask', (tester) async {
      await pump(tester);

      await tap(tester, _buyTheme('default_light'));

      expect(_confirm, findsNothing);
      expect(storage.active, 'default_light');
    });

    testWidgets('without enough coins nothing is asked or spent', (
      tester,
    ) async {
      await pump(tester);
      container.read(stepNotifierProvider.notifier).deductCoins(1600);

      await tap(tester, _buyTheme('ocean_wave'));

      expect(_confirm, findsNothing);
      // The snack bar shows its text in capitals.
      expect(
        find.text('NOT ENOUGH COINS! NEED $themePrice COINS.'),
        findsOneWidget,
      );
      expect(coins(), 400);
    });
  });
}
