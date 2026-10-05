import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_theme_model.dart';
import '../../features/social/presentation/providers/challenge_provider.dart';
import '../../features/step_tracking/presentation/providers/step_provider.dart' hide storageProvider;

class ThemeState {
  final AppThemeModel activeTheme;
  final List<String> purchasedThemeIds;

  ThemeState({
    required this.activeTheme,
    required this.purchasedThemeIds,
  });

  ThemeState copyWith({
    AppThemeModel? activeTheme,
    List<String>? purchasedThemeIds,
  }) {
    return ThemeState(
      activeTheme: activeTheme ?? this.activeTheme,
      purchasedThemeIds: purchasedThemeIds ?? this.purchasedThemeIds,
    );
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeState>(ThemeNotifier.new);

class ThemeNotifier extends Notifier<ThemeState> {
  @override
  ThemeState build() {
    final storage = ref.watch(storageProvider);
    final activeId = storage.getActiveTheme();

    // Unlocked themes by default
    final defaultPurchased = ['default_dark', 'default_light'];
    final savedPurchased = storage.getPurchasedThemes();
    final purchased = {...defaultPurchased, ...savedPurchased}.toList();

    return ThemeState(
      activeTheme: AppThemeCatalog.getById(activeId),
      purchasedThemeIds: purchased,
    );
  }

  bool isOwned(String themeId) => state.purchasedThemeIds.contains(themeId);
  bool isActive(String themeId) => state.activeTheme.id == themeId;

  // Buy a theme using Coins
  bool purchaseTheme(AppThemeModel theme) {
    if (isOwned(theme.id)) return false;

    final stepNotifier = ref.read(stepNotifierProvider.notifier);
    final success = stepNotifier.deductCoins(theme.costCoins);

    if (success) {
      final storage = ref.read(storageProvider);
      final updatedPurchased = [...state.purchasedThemeIds, theme.id];

      storage.savePurchasedThemes(updatedPurchased);
      state = state.copyWith(
        purchasedThemeIds: updatedPurchased,
        activeTheme: theme, // Automatically equip on purchase
      );
      storage.saveActiveTheme(theme.id);
      return true;
    }
    return false;
  }

  // Switch active theme
  void setActiveTheme(AppThemeModel theme) {
    if (!isOwned(theme.id)) return;

    final storage = ref.read(storageProvider);
    storage.saveActiveTheme(theme.id);
    state = state.copyWith(activeTheme: theme);
  }
}