import 'dart:async';

import 'package:flutter/material.dart';
import 'package:build_up/core/widgets/coin_icon.dart';
import 'package:build_up/core/widgets/pro_avatar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/theme/app_theme_model.dart';
import '../../../../app/theme/theme_extensions.dart';
import '../../data/shop_cloud.dart';
import '../../models/pro_avatar_item.dart';
import '../providers/theme_provider.dart';
import '../widgets/rewarded_ads_section.dart';
import '../../../step_tracking/presentation/widgets/glass_step_card.dart';
import '../../../step_tracking/presentation/providers/step_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Asks before spending [price] coins on [name]; true when the user agreed.
Future<bool> confirmPurchase(
  BuildContext context, {
  required String name,
  required int price,
}) async {
  final agreed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text('Buy $name for $price coins?'),
      actions: [
        TextButton(
          key: const Key('purchase.cancel'),
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('purchase.confirm'),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Buy'),
        ),
      ],
    ),
  );
  return agreed ?? false;
}

class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key});

  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen> {
  /// A purchase is being asked about or made; other buy taps are ignored, so
  /// a double tap can't charge twice.
  bool _buying = false;

  /// Items bought here that the account doesn't list yet (it updates after
  /// the write, later still offline), so they can't be bought again.
  final _boughtItems = <String>{};

  bool _hasCoins(int price) => ref.read(stepNotifierProvider).coins >= price;

  Future<void> _buyTheme(AppThemeModel theme) async {
    if (_buying) return;
    if (!_hasCoins(theme.costCoins)) {
      context.showAppSnackBar(
        'Not enough coins! Need ${theme.costCoins} coins.',
        isError: true,
      );
      return;
    }
    _buying = true;
    try {
      final agreed = await confirmPurchase(
        context,
        name: theme.name,
        price: theme.costCoins,
      );
      if (!agreed || !mounted) return;
      if (ref.read(themeProvider.notifier).purchaseTheme(theme)) {
        context.showAppSnackBar(
          'Purchased and equipped ${theme.name}!',
          backgroundColor: theme.primaryColor,
        );
      } else {
        context.showAppSnackBar(
          'Not enough coins! Need ${theme.costCoins} coins.',
          isError: true,
        );
      }
    } finally {
      _buying = false;
    }
  }

  Future<void> _buyItem(String id, String title) async {
    if (_buying || _boughtItems.contains(id)) return;
    // Items are kept on the account only: nobody to save it to, no charge.
    if (!ref.read(shopCloudProvider).isSignedIn) return;
    if (!_hasCoins(proAvatarPrice)) {
      context.showAppSnackBar(
        'Not enough coins! Need $proAvatarPrice coins.',
        isError: true,
      );
      return;
    }
    _buying = true;
    try {
      final agreed = await confirmPurchase(
        context,
        name: title,
        price: proAvatarPrice,
      );
      if (!agreed || !mounted) return;
      if (!ref
          .read(stepNotifierProvider.notifier)
          .deductCoins(proAvatarPrice)) {
        context.showAppSnackBar(
          'Not enough coins! Need $proAvatarPrice coins.',
          isError: true,
        );
        return;
      }
      setState(() => _boughtItems.add(id));
      unawaited(ref.read(shopCloudProvider).buyItem(id));
      context.showAppSnackBar('Purchased and equipped $title!');
    } finally {
      _buying = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final stepState = ref.watch(stepNotifierProvider);
    ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);

    final otherShopItems = [
      {
        'id': proAvatarItemId,
        'title': 'Pro Avatar Frame',
        'icon': Icons.account_circle,
      },
      {'id': 'icon_dark', 'title': 'Dark App Icon', 'icon': Icons.apps},
      {
        'id': 'analytics',
        'title': 'Premium Analytics',
        'icon': Icons.analytics,
      },
    ];

    final profile = ref.watch(userProfileProvider).value;
    final unlockedItems =
        (profile?['unlockedItems'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final isProAvatarEquipped = showsProAvatar(profile);
    final savedAvatar = profile?['avatarUrl'];
    final avatar = savedAvatar is String && savedAvatar.isNotEmpty
        ? savedAvatar
        : '👤';

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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        const CoinIcon(size: 20),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: context.primaryColor,
                      size: 20,
                    ),
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
                      const RewardedAdsSection(),
                      const SizedBox(height: 24),
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
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
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
                                context.showAppSnackBar(
                                  'Equipped ${theme.name}!',
                                  backgroundColor: theme.primaryColor,
                                );
                              } else {
                                _buyTheme(theme);
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
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.85,
                            ),
                        itemCount: otherShopItems.length,
                        itemBuilder: (context, index) {
                          final item = otherShopItems[index];
                          final id = item['id'] as String;
                          // Bought here, not on the account yet: buying
                          // equips it.
                          final justBought =
                              _boughtItems.contains(id) &&
                              !unlockedItems.contains(id);
                          final isOwned =
                              justBought || unlockedItems.contains(id);
                          final isEquipped =
                              isOwned && (justBought || isProAvatarEquipped);
                          final title = item['title'] as String;

                          return ShopItemCard(
                            id: id,
                            title: title,
                            icon: item['icon'] as IconData,
                            // The frame around the user's own avatar.
                            preview: id == proAvatarItemId
                                ? ProAvatar(emojiAvatar: avatar, radius: 30)
                                : null,
                            price: proAvatarPrice,
                            isOwned: isOwned,
                            isEquipped: isEquipped,
                            onPurchase: () => _buyItem(id, title),
                            onToggleEquip: () {
                              final equip = !isEquipped;
                              unawaited(
                                ref
                                    .read(shopCloudProvider)
                                    .setProAvatarEquipped(equip),
                              );
                              context.showAppSnackBar(
                                equip
                                    ? 'Equipped $title!'
                                    : 'Unequipped $title',
                              );
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
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
            key: Key('theme.buy.${theme.id}'),
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
                      : (isOwned ? theme.primaryColor : context.primaryColor),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isActive) ...[
                    Icon(
                      Icons.check_circle,
                      color: theme.primaryColor,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                  ] else if (!isOwned && theme.costCoins > 0) ...[
                    const CoinIcon(size: 14),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    isActive
                        ? 'EQUIPPED'
                        : (isOwned
                              ? 'EQUIP'
                              : (theme.costCoins == 0
                                    ? 'FREE'
                                    : '${theme.costCoins} COINS')),
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
  final int price;
  final bool isOwned;
  final bool isEquipped;
  final VoidCallback onPurchase;
  final VoidCallback? onToggleEquip;

  /// Shown instead of [icon] when set, e.g. what the item looks like.
  final Widget? preview;

  const ShopItemCard({
    super.key,
    required this.id,
    required this.title,
    required this.icon,
    this.preview,
    this.price = 0,
    this.isOwned = false,
    this.isEquipped = false,
    required this.onPurchase,
    this.onToggleEquip,
  });

  @override
  Widget build(BuildContext context) {
    final isComingSoon = id != proAvatarItemId;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Opacity(
        opacity: isComingSoon ? 0.5 : 1.0,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            preview ?? Icon(icon, color: context.textSecondary, size: 48),
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
              key: Key('item.buy.$id'),
              onTap: isComingSoon
                  ? null
                  : (isOwned ? onToggleEquip : onPurchase),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isEquipped
                      ? context.primaryColor.withValues(alpha: 0.2)
                      : (isComingSoon
                            ? Colors.transparent
                            : (isOwned
                                  ? context.primaryColor
                                  : context.primaryColor.withValues(
                                      alpha: 0.15,
                                    ))),
                  border: Border.all(
                    color: isComingSoon
                        ? context.textSecondary.withValues(alpha: 0.3)
                        : context.primaryColor,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isComingSoon)
                      Icon(Icons.lock, color: context.textSecondary, size: 14)
                    else if (isEquipped)
                      Icon(
                        Icons.check_circle,
                        color: context.primaryColor,
                        size: 14,
                      )
                    else if (!isOwned)
                      const CoinIcon(size: 14),
                    if (isComingSoon || isEquipped || !isOwned)
                      const SizedBox(width: 4),
                    Text(
                      isComingSoon
                          ? 'COMING SOON'
                          : (isEquipped
                                ? 'UNEQUIP'
                                : (isOwned ? 'EQUIP' : '$price COINS')),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: isComingSoon
                            ? context.textSecondary
                            : (isEquipped
                                  ? context.primaryColor
                                  : (isOwned
                                        ? Colors.black
                                        : context.textPrimary)),
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
