import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../step_tracking/presentation/widgets/glass_step_card.dart';
import '../providers/streak_provider.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  IconData _resolveIcon(String iconName) {
    switch (iconName) {
      case 'flag':
        return Icons.flag;
      case 'directions_walk':
        return Icons.directions_walk;
      case 'military_tech':
        return Icons.military_tech;
      case 'emoji_events':
        return Icons.emoji_events;
      default:
        return Icons.stars;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakState = ref.watch(streakProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'STREAKS & BADGES',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Icon(
                          Icons.local_fire_department,
                          color: AppColors.primaryEmerald,
                          size: 36,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${streakState.currentStreak} Days',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Text(
                          'Current Streak',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      height: 50,
                      width: 1,
                      color: AppColors.glassCardBorder,
                    ),
                    Column(
                      children: [
                        const Icon(
                          Icons.workspace_premium,
                          color: AppColors.primaryEmerald,
                          size: 36,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${streakState.bestStreak} Days',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Text(
                          'Best Record',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'BADGES',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.9,
                ),
                itemCount: streakState.badges.length,
                itemBuilder: (context, index) {
                  final badge = streakState.badges[index];
                  return GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: badge.isUnlocked
                              ? AppColors.primaryEmerald.withOpacity(0.2)
                              : AppColors.glassCardBorder,
                          child: Icon(
                            _resolveIcon(badge.iconName),
                            size: 28,
                            color: badge.isUnlocked
                                ? AppColors.primaryEmerald
                                : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          badge.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: badge.isUnlocked
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          badge.description,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}