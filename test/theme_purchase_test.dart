import 'package:build_up/app/theme/app_theme_model.dart';
import 'package:build_up/core/services/local_storage_service.dart';
import 'package:build_up/features/shop/data/shop_cloud.dart';
import 'package:build_up/features/shop/presentation/providers/theme_provider.dart';
import 'package:build_up/features/step_tracking/presentation/providers/step_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
}

class _FakeStepNotifier extends StepNotifier {
  _FakeStepNotifier(this.startCoins);

  final int startCoins;

  @override
  StepState build() => StepState(
    currentSteps: 0,
    goalSteps: 10000,
    calories: 0,
    distanceKm: 0,
    isRestMode: false,
    coins: startCoins,
  );

  // No Firebase in tests.
  @override
  bool deductCoins(int amount) {
    if (state.coins < amount) return false;
    state = state.copyWith(coins: state.coins - amount);
    return true;
  }
}

class FakeShopCloud implements ShopCloud {
  @override
  bool get isSignedIn => true;

  final boughtThemes = <String>[];
  final activeThemes = <String>[];

  @override
  Future<void> saveThemePurchase(String themeId) async {
    boughtThemes.add(themeId);
    activeThemes.add(themeId);
  }

  @override
  Future<void> saveActiveTheme(String themeId) async =>
      activeThemes.add(themeId);

  @override
  Future<void> backUpThemes(List<String> owned) async {}

  @override
  Future<void> buyItem(String itemId) async {}

  @override
  Future<void> setProAvatarEquipped(bool equipped) async {}
}

void main() {
  late _FakeStorage storage;
  late FakeShopCloud cloud;

  ProviderContainer container({int coins = 1000}) {
    storage = _FakeStorage();
    cloud = FakeShopCloud();
    final c = ProviderContainer(
      overrides: [
        storageProvider.overrideWithValue(storage),
        stepNotifierProvider.overrideWith(() => _FakeStepNotifier(coins)),
        shopCloudProvider.overrideWithValue(cloud),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  final ocean = AppThemeCatalog.oceanWave;

  test('a bought theme is saved to the account', () {
    final c = container();

    expect(c.read(themeProvider.notifier).purchaseTheme(ocean), isTrue);

    expect(cloud.boughtThemes, ['ocean_wave']);
    expect(storage.purchased, contains('ocean_wave'));
    expect(c.read(stepNotifierProvider).coins, 1000 - themePrice);
  });

  test('without enough coins nothing is saved', () {
    final c = container(coins: themePrice - 1);

    expect(c.read(themeProvider.notifier).purchaseTheme(ocean), isFalse);

    expect(cloud.boughtThemes, isEmpty);
    expect(storage.purchased, isNot(contains('ocean_wave')));
  });

  test('a theme already owned is not charged again', () {
    final c = container();
    final themes = c.read(themeProvider.notifier);

    themes.purchaseTheme(ocean);
    expect(themes.purchaseTheme(ocean), isFalse);

    expect(c.read(stepNotifierProvider).coins, 1000 - themePrice);
    expect(cloud.boughtThemes, ['ocean_wave']);
  });

  test('equipping an owned theme is saved to the account', () {
    final c = container();
    c.read(themeProvider.notifier).setActiveTheme(AppThemeCatalog.defaultLight);

    expect(cloud.activeThemes, ['default_light']);
    expect(storage.active, 'default_light');
  });
}
