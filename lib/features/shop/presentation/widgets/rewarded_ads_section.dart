import 'package:build_up/core/widgets/coin_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/theme_extensions.dart';
import '../../../../core/ads/rewarded_ad.dart';
import '../../../../core/ads/rewarded_ad_limits.dart';
import '../../../../core/utils/number_format.dart';
import '../../../step_tracking/presentation/providers/step_provider.dart';
import '../../../step_tracking/presentation/widgets/glass_step_card.dart';

/// Signature of [showRewardedAd]; tests pass a fake.
typedef ShowRewardedAd = Future<bool> Function();

/// Store section with the rewarded ads: coins, and filling today's steps up
/// to the goal. Each has a daily limit (see [RewardedAdKind]).
class RewardedAdsSection extends ConsumerStatefulWidget {
  final ShowRewardedAd showAd;

  const RewardedAdsSection({super.key, this.showAd = showRewardedAd});

  @override
  ConsumerState<RewardedAdsSection> createState() => _RewardedAdsSectionState();
}

class _RewardedAdsSectionState extends ConsumerState<RewardedAdsSection> {
  /// The ad being loaded or shown; both buttons are off meanwhile so a
  /// double tap can't open two ads.
  RewardedAdKind? _busy;

  Future<void> _watch(RewardedAdKind kind) async {
    if (_busy != null) return;
    setState(() => _busy = kind);
    try {
      final notifier = ref.read(stepNotifierProvider.notifier);
      if (kind == RewardedAdKind.goal && !await notifier.canFillStepsToGoal()) {
        _snack("Today's steps couldn't be read. Try again in a moment.");
        return;
      }
      if (!mounted) return;

      final earned = await widget.showAd();
      if (!mounted) return;
      if (!earned) {
        _snack('Watch the whole ad to get the reward.');
        return;
      }

      final storage = ref.read(storageProvider);
      switch (kind) {
        case RewardedAdKind.coins:
          storage.recordRewardedAd(kind, DateTime.now());
          notifier.addCoins(coinAdReward);
          _snack('+$coinAdReward coins added!');
        case RewardedAdKind.goal:
          if (await notifier.fillStepsToGoal()) {
            storage.recordRewardedAd(kind, DateTime.now());
            _snack("Today's step goal is complete!");
          } else {
            _snack("Today's steps couldn't be read. Try again in a moment.");
          }
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final stepState = ref.watch(stepNotifierProvider);
    final storage = ref.watch(storageProvider);
    final now = DateTime.now();
    final coinsLeft = storage.rewardedAdsLeft(RewardedAdKind.coins, now);
    final goalLeft = storage.rewardedAdsLeft(RewardedAdKind.goal, now);
    final goalReached =
        stepState.goalSteps > 0 &&
        stepState.currentSteps >= stepState.goalSteps;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FREE REWARDS',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: context.textSecondary,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        _RewardTile(
          key: const Key('rewardedAd_coins'),
          leading: const CoinIcon(size: 26),
          title: 'Watch an ad: +$coinAdReward coins',
          subtitle: coinsLeft > 0
              ? '$coinsLeft of ${RewardedAdKind.coins.dailyLimit} left today'
              : 'Come back tomorrow',
          enabled: coinsLeft > 0 && _busy == null,
          loading: _busy == RewardedAdKind.coins,
          onTap: () => _watch(RewardedAdKind.coins),
        ),
        const SizedBox(height: 12),
        _RewardTile(
          key: const Key('rewardedAd_goal'),
          leading: Icon(Icons.flag_rounded, color: context.primaryColor),
          title: "Watch an ad: complete today's goal",
          subtitle: goalReached
              ? 'Goal already reached today'
              : goalLeft > 0
              ? 'Fills your steps to ${formatThousands(stepState.goalSteps)} '
                    '(once a day)'
              : 'Come back tomorrow',
          enabled: !goalReached && goalLeft > 0 && _busy == null,
          loading: _busy == RewardedAdKind.goal,
          onTap: () => _watch(RewardedAdKind.goal),
        ),
      ],
    );
  }
}

class _RewardTile extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  const _RewardTile({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled || loading ? 1 : 0.5,
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        color: context.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        color: context.textSecondary,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (loading)
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: context.primaryColor,
                  ),
                )
              else
                Icon(
                  Icons.play_circle_fill_rounded,
                  color: context.primaryColor,
                  size: 28,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
