import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../step_tracking/presentation/providers/step_provider.dart';

class ThemeState {
  final String activeThemeId;
  final List<String> purchasedThemes;
  final Color primaryColor;

  ThemeState({
    required this.activeThemeId,
    required this.purchasedThemes,
    required this.primaryColor,
  });

  ThemeState copyWith({
    String? activeThemeId,
    List<String>? purchasedThemes,
    Color? primaryColor,
  }) {
    return ThemeState(
      activeThemeId: activeThemeId ?? this.activeThemeId,
      purchasedThemes: purchasedThemes ?? this.purchasedThemes,
      primaryColor: primaryColor ?? this.primaryColor,
    );
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeState>(ThemeNotifier.new);

class ThemeNotifier extends Notifier<ThemeState> {
  final Map<String, Color> themeColors = {
    'default': const Color(0xFF10B981),
    'neon': const Color(0xFF1de9b6),
    'ocean': const Color(0xFF0EA5E9),
    'sunset': const Color(0xFFF97316),
    'amethyst': const Color(0xFF8B5CF6),
    'avatar_pro': const Color(0xFFFFD700),
    'icon_dark': const Color(0xFF1F2937),
    'analytics': const Color(0xFF3B82F6),
  };
  @override
  ThemeState build() {
    final storage = ref.watch(storageProvider);
    final active = storage.getActiveTheme();
    final purchased = storage.getPurchasedThemes();

    return ThemeState(
      activeThemeId: active,
      purchasedThemes: purchased,
      primaryColor: themeColors[active] ?? themeColors['default']!,
    );
  }

  bool purchaseTheme(String themeId, int cost) {
    if (state.purchasedThemes.contains(themeId)) return false;

    final stepNotifier = ref.read(stepNotifierProvider.notifier);
    final success = stepNotifier.deductCoins(cost);

    if (success) {
      final storage = ref.read(storageProvider);
      final updatedPurchased = List<String>.from(state.purchasedThemes)..add(themeId);

      storage.savePurchasedThemes(updatedPurchased);
      state = state.copyWith(purchasedThemes: updatedPurchased);
      return true;
    }

    return false;
  }

  void setActiveTheme(String themeId) {
    if (!state.purchasedThemes.contains(themeId)) return;

    final storage = ref.read(storageProvider);
    storage.saveActiveTheme(themeId);

    state = state.copyWith(
      activeThemeId: themeId,
      primaryColor: themeColors[themeId] ?? themeColors['default']!,
    );
  }
}