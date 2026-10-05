import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_theme_model.dart';
import '../../../step_tracking/presentation/providers/step_provider.dart';

class ThemeState {
  final String activeThemeId;
  final List<String> purchasedThemeIds;

  ThemeState({
    required String? activeThemeId,
    required this.purchasedThemeIds,
  }) : activeThemeId = (activeThemeId == null || activeThemeId.isEmpty) ? 'default_dark' : activeThemeId;

  // ⚡ Computed getter: Always fetches the latest AppThemeModel from catalog
  // Safe null check prevents Hot Reload state mismatch errors!
  AppThemeModel get activeTheme => AppThemeCatalog.getById(activeThemeId);

  ThemeState copyWith({
    String? activeThemeId,
    List<String>? purchasedThemeIds,
  }) {
    return ThemeState(
      activeThemeId: activeThemeId ?? this.activeThemeId,
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

    final defaultPurchased = ['default_dark', 'default_light'];
    final savedPurchased = storage.getPurchasedThemes();
    final purchased = {...defaultPurchased, ...savedPurchased}.toList();

    return ThemeState(
      activeThemeId: activeId,
      purchasedThemeIds: purchased,
    );
  }

  bool isOwned(String themeId) => state.purchasedThemeIds.contains(themeId);
  bool isActive(String themeId) => state.activeThemeId == themeId;

  bool purchaseTheme(AppThemeModel theme) {
    if (isOwned(theme.id)) return false;

    if (theme.costCoins == 0) {
      final storage = ref.read(storageProvider);
      final updatedPurchased = [...state.purchasedThemeIds, theme.id];
      storage.savePurchasedThemes(updatedPurchased);
      state = state.copyWith(
        purchasedThemeIds: updatedPurchased,
        activeThemeId: theme.id,
      );
      storage.saveActiveTheme(theme.id);
      return true;
    }

    final stepNotifier = ref.read(stepNotifierProvider.notifier);
    final success = stepNotifier.deductCoins(theme.costCoins);

    if (success) {
      final storage = ref.read(storageProvider);
      final updatedPurchased = [...state.purchasedThemeIds, theme.id];

      storage.savePurchasedThemes(updatedPurchased);
      state = state.copyWith(
        purchasedThemeIds: updatedPurchased,
        activeThemeId: theme.id,
      );
      storage.saveActiveTheme(theme.id);
      return true;
    }
    return false;
  }

  void setActiveTheme(AppThemeModel theme) {
    if (!isOwned(theme.id)) return;

    final storage = ref.read(storageProvider);
    storage.saveActiveTheme(theme.id);
    state = state.copyWith(activeThemeId: theme.id);
  }
}