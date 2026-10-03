import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../step_tracking/presentation/widgets/glass_step_card.dart';
import '../../../step_tracking/presentation/providers/step_provider.dart';

class StoreScreen extends ConsumerWidget {
  const StoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stepState = ref.watch(stepNotifierProvider);

    final shopItems = [
      {'id': 'neon', 'title': 'Neon Mint Theme', 'icon': Icons.palette},
      {'id': 'ocean', 'title': 'Ocean Blue Theme', 'icon': Icons.water_drop},
      {'id': 'sunset', 'title': 'Sunset Orange Theme', 'icon': Icons.wb_sunny},
      {'id': 'amethyst', 'title': 'Amethyst Purple Theme', 'icon': Icons.auto_awesome},
      {'id': 'avatar_pro', 'title': 'Pro Avatar Frame', 'icon': Icons.account_circle},
      {'id': 'icon_dark', 'title': 'Dark App Icon', 'icon': Icons.apps},
      {'id': 'analytics', 'title': 'Premium Analytics', 'icon': Icons.analytics},
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
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
                      color: AppColors.textPrimary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.monetization_on_outlined, color: AppColors.primaryEmerald, size: 20),
                        const SizedBox(width: 6),
                        Text(
                          '${stepState.coins} Coins',
                          style: GoogleFonts.inter(
                            color: AppColors.textPrimary,
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
                    const Icon(Icons.info_outline, color: AppColors.primaryEmerald, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '1 Coin earned for every 100 steps walked. Use coins to buy themes and items from the store.',
                        style: GoogleFonts.inter(
                          color: AppColors.textSecondary,
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
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: shopItems.length,
                  itemBuilder: (context, index) {
                    final item = shopItems[index];

                    return ShopItemCard(
                      title: item['title'] as String,
                      icon: item['icon'] as IconData,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ShopItemCard extends StatelessWidget {
  final String title;
  final IconData icon;

  const ShopItemCard({
    super.key,
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Opacity(
        opacity: 0.5,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 48),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                height: 1.2,
                decoration: TextDecoration.none,
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border.all(
                  color: AppColors.textSecondary.withOpacity(0.3),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.lock,
                    color: AppColors.textSecondary,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'COMING SOON',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}