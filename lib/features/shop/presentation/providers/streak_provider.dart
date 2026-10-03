import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../step_tracking/presentation/providers/step_provider.dart';
import '../../models/badge_model.dart';

class StreakState {
  final int currentStreak;
  final int bestStreak;
  final List<BadgeModel> badges;

  const StreakState({
    required this.currentStreak,
    required this.bestStreak,
    required this.badges,
  });

  StreakState copyWith({
    int? currentStreak,
    int? bestStreak,
    List<BadgeModel>? badges,
  }) {
    return StreakState(
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      badges: badges ?? this.badges,
    );
  }
}

final streakProvider =
NotifierProvider<StreakNotifier, StreakState>(StreakNotifier.new);

class StreakNotifier extends Notifier<StreakState> {
  @override
  StreakState build() {
    final initialBadges = [
      const BadgeModel(
        id: 'first_step',
        title: 'First Step',
        description: 'Record your first 1,000 steps',
        requiredSteps: 1000,
        isUnlocked: true,
        iconName: 'flag',
      ),
      const BadgeModel(
        id: 'walker_bronze',
        title: 'Daily Mover',
        description: 'Complete 5,000 steps in a single day',
        requiredSteps: 5000,
        isUnlocked: true,
        iconName: 'directions_walk',
      ),
      const BadgeModel(
        id: 'walker_silver',
        title: 'Goal Crusher',
        description: 'Reach 10,000 steps in a single day',
        requiredSteps: 10000,
        isUnlocked: false,
        iconName: 'military_tech',
      ),
      const BadgeModel(
        id: 'walker_gold',
        title: 'Marathoner',
        description: 'Hit 20,000 steps in a single day',
        requiredSteps: 20000,
        isUnlocked: false,
        iconName: 'emoji_events',
      ),
    ];

    return StreakState(
      currentStreak: 5,
      bestStreak: 12,
      badges: initialBadges,
    );
  }

  void checkAchievements() {
    final stepState = ref.read(stepNotifierProvider);
    final updatedBadges = state.badges.map((badge) {
      if (!badge.isUnlocked && stepState.currentSteps >= badge.requiredSteps) {
        return badge.copyWith(isUnlocked: true);
      }
      return badge;
    }).toList();

    state = state.copyWith(badges: updatedBadges);
  }
}