import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppThemeModel {
  final String id;
  final String name;
  final int costCoins;
  final Brightness brightness;
  final Color primaryColor;
  final Color backgroundColor;
  final Color cardColor;
  final Color cardBorderColor;
  final Color textPrimary;
  final Color textSecondary;

  const AppThemeModel({
    required this.id,
    required this.name,
    required this.costCoins,
    required this.brightness,
    required this.primaryColor,
    required this.backgroundColor,
    required this.cardColor,
    required this.cardBorderColor,
    required this.textPrimary,
    required this.textSecondary,
  });

  bool get isFree => costCoins == 0;
}

// 🎨 Theme Catalog: All buyable and default themes in the app
class AppThemeCatalog {
  static AppThemeModel get defaultDark => AppThemeModel(
    id: 'default_dark',
    name: 'Emerald Dark (Default)',
    costCoins: 0,
    brightness: Brightness.dark,
    primaryColor: AppColors.emeraldPrimary,
    backgroundColor: AppColors.emeraldBackground,
    cardColor: AppColors.emeraldCard,
    cardBorderColor: AppColors.emeraldCardBorder,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
  );

  static AppThemeModel get defaultLight => AppThemeModel(
    id: 'default_light',
    name: 'Clean Light',
    costCoins: 0,
    brightness: Brightness.light,
    primaryColor: AppColors.lightPrimary,
    backgroundColor: AppColors.lightBackground,
    cardColor: AppColors.lightCard,
    cardBorderColor: AppColors.lightCardBorder,
    textPrimary: AppColors.lightTextPrimary,
    textSecondary: AppColors.lightTextSecondary,
  );

  static AppThemeModel get oceanWave => AppThemeModel(
    id: 'ocean_wave',
    name: 'Ocean Wave',
    costCoins: 0,
    brightness: Brightness.dark,
    primaryColor: AppColors.oceanPrimary,
    backgroundColor: AppColors.oceanBackground,
    cardColor: AppColors.oceanCard,
    cardBorderColor: AppColors.oceanCardBorder,
    textPrimary: Colors.white,
    textSecondary: AppColors.oceanTextSecondary,
  );

  static AppThemeModel get sunsetGlow => AppThemeModel(
    id: 'sunset_glow',
    name: 'Sunset Glow',
    costCoins: 0,
    brightness: Brightness.dark,
    primaryColor: AppColors.sunsetPrimary,
    backgroundColor: AppColors.sunsetBackground,
    cardColor: AppColors.sunsetCard,
    cardBorderColor: AppColors.sunsetCardBorder,
    textPrimary: Colors.white,
    textSecondary: AppColors.sunsetTextSecondary,
  );

  static AppThemeModel get cyberpunkNeon => AppThemeModel(
    id: 'cyberpunk_neon',
    name: 'Cyberpunk Neon',
    costCoins: 0,
    brightness: Brightness.dark,
    primaryColor: AppColors.cyberpunkPrimary,
    backgroundColor: AppColors.cyberpunkBackground,
    cardColor: AppColors.cyberpunkCard,
    cardBorderColor: AppColors.cyberpunkCardBorder,
    textPrimary: Colors.white,
    textSecondary: AppColors.cyberpunkTextSecondary,
  );

  static AppThemeModel get amethystPurple => AppThemeModel(
    id: 'amethyst_purple',
    name: 'Amethyst Purple',
    costCoins: 0,
    brightness: Brightness.dark,
    primaryColor: AppColors.amethystPrimary,
    backgroundColor: AppColors.amethystBackground,
    cardColor: AppColors.amethystCard,
    cardBorderColor: AppColors.amethystCardBorder,
    textPrimary: Colors.white,
    textSecondary: AppColors.amethystTextSecondary,
  );

  static AppThemeModel get midnightGold => AppThemeModel(
    id: 'midnight_gold',
    name: 'Midnight Gold',
    costCoins: 0,
    brightness: Brightness.dark,
    primaryColor: AppColors.goldPrimary,
    backgroundColor: AppColors.goldBackground,
    cardColor: AppColors.goldCard,
    cardBorderColor: AppColors.goldCardBorder,
    textPrimary: Colors.white,
    textSecondary: AppColors.goldTextSecondary,
  );

  static List<AppThemeModel> get allThemes => [
    defaultDark,
    defaultLight,
    oceanWave,
    sunsetGlow,
    amethystPurple,
    cyberpunkNeon,
    midnightGold,
  ];

  static AppThemeModel getById(String id) {
    return allThemes.firstWhere(
      (t) => t.id == id,
      orElse: () => defaultDark,
    );
  }
}