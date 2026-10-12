import 'package:build_up/app/theme/theme_extensions.dart';
import 'package:build_up/features/settings/presentation/setting_screen.dart';
import 'package:build_up/features/shop/presentation/screens/store_screen.dart';
import 'package:build_up/features/step_tracking/presentation/screens/step_details_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/widgets/pro_avatar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/step_provider.dart';
import '../providers/active_duration_provider.dart';
import '../widgets/glass_step_card.dart';
import '../widgets/metric_glass_card.dart';
import '../widgets/step_gauge.dart';

class DashboardView extends ConsumerStatefulWidget {
  const DashboardView({super.key});

  @override
  ConsumerState<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends ConsumerState<DashboardView> {
  /// Debug builds only: long-press the ring to preview it at these fractions
  /// of the goal (overflow laps included) without touching saved data.
  static const _debugGaugePreviews = [0.5, 1.0, 1.35, 2.0, 2.5];
  int? _debugGaugePreview;

  void _cycleDebugGaugePreview() {
    setState(() {
      final next = (_debugGaugePreview ?? -1) + 1;
      _debugGaugePreview = next < _debugGaugePreviews.length ? next : null;
    });
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(stepNotifierProvider.notifier).initializeTracking();
      ref.read(activeDurationProvider.notifier).startTracking();
    });
  }

  @override
  Widget build(BuildContext context) {
    final stepState = ref.watch(stepNotifierProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final profile = profileAsync.value;
    final avatar = profile?['avatarUrl'] ?? '👦';
    final isProAvatarUnlocked =
        (profile?['unlockedItems'] as List?)?.contains('avatar_pro') ?? false;

    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    final screenHeight = size.height;
    Color currentTierColor = stepState.currentLeague.color;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.05,
                vertical: 10,
              ),
              child: SizedBox(
                height: 50,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SettingsScreen(),
                            ),
                          ),
                          child: isProAvatarUnlocked
                              ? ProAvatar(
                                  emojiAvatar: avatar,
                                  radius: 22,
                                  isPro: true,
                                )
                              : Container(
                                  height: 44,
                                  width: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: context.cardColor,
                                    border: Border.all(
                                      color: currentTierColor,
                                      width: 2,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      avatar,
                                      style: const TextStyle(fontSize: 22),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                    Text(
                      'BUILD UP',
                      style: GoogleFonts.sora(
                        fontSize: screenWidth * 0.065,
                        fontWeight: FontWeight.w900,
                        color: context.textPrimary,
                        letterSpacing: .1,
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: GlassCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 08,
                            vertical: 8,
                          ),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const StoreScreen(),
                                ),
                              );
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.monetization_on_outlined,
                                  color: context.primaryColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  key: const Key('dashboard_coins'),
                                  '${stepState.coins} ',
                                  style: GoogleFonts.inter(
                                    color: context.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: context.primaryColor,
                backgroundColor: context.cardColor,
                onRefresh: () async => await ref
                    .read(stepNotifierProvider.notifier)
                    .forceRefresh(),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.05,
                    ),
                    child: Column(
                      children: [
                        SizedBox(height: screenHeight * 0.02),
                        Center(
                          child: GestureDetector(
                            onLongPress: kDebugMode
                                ? _cycleDebugGaugePreview
                                : null,
                            child: StepGauge(
                              steps: _debugGaugePreview == null
                                  ? stepState.currentSteps
                                  : (stepState.goalSteps *
                                            _debugGaugePreviews[_debugGaugePreview!])
                                        .round(),
                              goal: stepState.goalSteps,
                              size: screenWidth * 0.6,
                            ),
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.042),
                        GlassCard(
                          padding: EdgeInsets.all(screenWidth * 0.06),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    stepState.calories.toStringAsFixed(0),
                                    style: GoogleFonts.sora(
                                      fontSize: screenWidth * 0.09,
                                      fontWeight: FontWeight.w700,
                                      color: context.textPrimary,
                                    ),
                                  ),
                                  SizedBox(height: screenHeight * 0.005),
                                  Text(
                                    'KCAL BURNED',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: screenWidth * 0.03,
                                      fontWeight: FontWeight.w600,
                                      color: context.textSecondary,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: EdgeInsets.all(screenWidth * 0.035),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: context.primaryColor.withValues(
                                    alpha: 0.15,
                                  ),
                                ),
                                child: Icon(
                                  Icons.local_fire_department,
                                  color: context.primaryColor,
                                  size: screenWidth * 0.07,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.02),
                        Row(
                          children: [
                            Expanded(
                              child: MetricGlassCard(
                                label: 'Distance',
                                value: stepState.distanceKm.toStringAsFixed(1),
                                unit: 'km',
                                icon: Icons.map,
                              ),
                            ),
                            SizedBox(width: screenWidth * 0.025),
                            Expanded(
                              child: MetricGlassCard(
                                label: 'Active Time',
                                value: stepState.activeDuration,
                                unit: '',
                                icon: Icons.timer,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: screenHeight * 0.02),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const StepDetailsScreen(),
                              ),
                            );
                          },
                          child: GlassCard(
                            padding: EdgeInsets.all(screenWidth * 0.06),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(screenWidth * 0.03),
                                  decoration: BoxDecoration(
                                    color: context.primaryColor.withValues(
                                      alpha: 0.2,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      screenWidth * 0.04,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.history,
                                    color: context.primaryColor,
                                    size: screenWidth * 0.07,
                                  ),
                                ),
                                SizedBox(width: screenWidth * 0.04),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Workout History',
                                        style: GoogleFonts.sora(
                                          fontSize: screenWidth * 0.045,
                                          fontWeight: FontWeight.w600,
                                          color: context.textPrimary,
                                          letterSpacing: .8,
                                        ),
                                      ),
                                      SizedBox(height: screenHeight * 0.005),
                                      Text(
                                        'View past Steps',
                                        style: GoogleFonts.sora(
                                          fontSize: screenWidth * 0.03,
                                          fontWeight: FontWeight.w600,
                                          color: context.textSecondary,
                                          letterSpacing: .8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: context.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
