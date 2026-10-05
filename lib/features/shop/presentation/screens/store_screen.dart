import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../app/theme/app_theme_model.dart';
import '../../../../app/theme/theme_extensions.dart';
import '../providers/theme_provider.dart';
import '../../../step_tracking/presentation/widgets/glass_step_card.dart';
import '../../../step_tracking/presentation/providers/step_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class StoreScreen extends ConsumerWidget {
  const StoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stepState = ref.watch(stepNotifierProvider);
    ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);

    final otherShopItems = [
      {'id': 'avatar_pro', 'title': 'Pro Avatar Frame', 'icon': Icons.account_circle},
      {'id': 'icon_dark', 'title': 'Dark App Icon', 'icon': Icons.apps},
      {'id': 'analytics', 'title': 'Premium Analytics', 'icon': Icons.analytics},
    ];

    final profile = ref.watch(userProfileProvider).value;
    final unlockedItems = (profile?['unlockedItems'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'STORE',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: context.textPrimary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.monetization_on_outlined, color: context.primaryColor, size: 20),
                        const SizedBox(width: 6),
                        Text(
                          '${stepState.coins} Coins',
                          style: GoogleFonts.inter(
                            color: context.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: context.primaryColor, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '1 Coin earned for every 100 steps walked. Use coins to buy themes and items from the store.',
                        style: GoogleFonts.inter(
                          color: context.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'THEMES',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: context.textSecondary,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.88,
                        ),
                        itemCount: AppThemeCatalog.allThemes.length,
                        itemBuilder: (context, index) {
                          final theme = AppThemeCatalog.allThemes[index];
                          final isOwned = themeNotifier.isOwned(theme.id);
                          final isActive = themeNotifier.isActive(theme.id);

                          return ThemeShopItemCard(
                            theme: theme,
                            isOwned: isOwned,
                            isActive: isActive,
                            onTap: () {
                              if (isActive) return;
                              if (isOwned) {
                                themeNotifier.setActiveTheme(theme);
                                context.showAppSnackBar('Equipped ${theme.name}!');
                              } else {
                                final success = themeNotifier.purchaseTheme(theme);
                                if (success) {
                                  context.showAppSnackBar('Purchased and equipped ${theme.name}!');
                                } else {
                                  context.showAppSnackBar(
                                    'Not enough coins! Need ${theme.costCoins} coins.',
                                    isError: true,
                                  );
                                }
                              }
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'UPGRADES & ITEMS',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: context.textSecondary,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: otherShopItems.length,
                        itemBuilder: (context, index) {
                          final item = otherShopItems[index];
                          final id = item['id'] as String;
                          final isOwned = unlockedItems.contains(id);

                          return ShopItemCard(
                            id: id,
                            title: item['title'] as String,
                            icon: item['icon'] as IconData,
                            isOwned: isOwned,
                            onPurchase: () async {
                              final user = FirebaseAuth.instance.currentUser;
                              if (user != null) {
                                await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                                  'unlockedItems': FieldValue.arrayUnion([id])
                                }, SetOptions(merge: true));
                                if (context.mounted) {
                                  context.showAppSnackBar('Purchased ${item['title']}!');
                                }
                              }
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ThemeShopItemCard extends StatelessWidget {
  final AppThemeModel theme;
  final bool isOwned;
  final bool isActive;
  final VoidCallback onTap;

  const ThemeShopItemCard({
    super.key,
    required this.theme,
    required this.isOwned,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isActive
              ? theme.primaryColor
              : (isOwned
                  ? context.textSecondary.withValues(alpha: 0.2)
                  : context.textSecondary.withValues(alpha: 0.1)),
          width: isActive ? 2.5 : 1.0,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: theme.primaryColor.withValues(alpha: 0.25),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : [],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Stack(
            alignment: Alignment.topRight,
            children: [
              Container(
                width: double.infinity,
                height: 68,
                decoration: BoxDecoration(
                  color: theme.backgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.cardBorderColor.withValues(alpha: 0.5),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: theme.primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.palette,
                          color: theme.brightness == Brightness.dark
                              ? Colors.black
                              : Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 8,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: theme.textPrimary.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: 6,
                              width: 30,
                              decoration: BoxDecoration(
                                color: theme.primaryColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Text(
            theme.name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: context.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: isActive
                    ? theme.primaryColor.withValues(alpha: 0.2)
                    : (isOwned
                        ? theme.primaryColor
                        : context.primaryColor.withValues(alpha: 0.15)),
                border: Border.all(
                  color: isActive
                      ? theme.primaryColor
                      : (isOwned
                          ? theme.primaryColor
                          : context.primaryColor),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isActive) ...[
                    Icon(Icons.check_circle, color: theme.primaryColor, size: 14),
                    const SizedBox(width: 4),
                  ] else if (!isOwned && theme.costCoins > 0) ...[
                    Icon(Icons.monetization_on_outlined, color: context.primaryColor, size: 14),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    isActive
                        ? 'EQUIPPED'
                        : (isOwned
                            ? 'EQUIP'
                            : (theme.costCoins == 0 ? 'FREE' : '${theme.costCoins} COINS')),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: isActive
                          ? theme.primaryColor
                          : (isOwned ? Colors.black : context.textPrimary),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ShopItemCard extends StatelessWidget {
  final String id;
  final String title;
  final IconData icon;
  final bool isOwned;
  final VoidCallback onPurchase;

  const ShopItemCard({
    super.key,
    required this.id,
    required this.title,
    required this.icon,
    this.isOwned = false,
    required this.onPurchase,
  });

  @override
  Widget build(BuildContext context) {
    final isComingSoon = id != 'avatar_pro';

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Opacity(
        opacity: isComingSoon ? 0.5 : 1.0,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: context.textSecondary, size: 48),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: context.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                height: 1.2,
                decoration: TextDecoration.none,
              ),
            ),
            GestureDetector(
              onTap: (isComingSoon || isOwned) ? null : onPurchase,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isOwned 
                      ? context.primaryColor.withValues(alpha: 0.2)
                      : (isComingSoon ? Colors.transparent : context.primaryColor),
                  border: Border.all(
                    color: isOwned 
                        ? context.primaryColor 
                        : (isComingSoon ? context.textSecondary.withValues(alpha: 0.3) : context.primaryColor),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isOwned 
                          ? Icons.check_circle 
                          : (isComingSoon ? Icons.lock : Icons.shopping_cart),
                      color: isOwned ? context.primaryColor : (isComingSoon ? context.textSecondary : Colors.black),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isOwned 
                          ? 'OWNED' 
                          : (isComingSoon ? 'COMING SOON' : 'FREE'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: isOwned ? context.primaryColor : (isComingSoon ? context.textSecondary : Colors.black),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}