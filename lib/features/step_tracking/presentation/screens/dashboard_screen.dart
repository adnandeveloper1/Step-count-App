import 'dart:ui';
import 'package:build_up/features/settings/presentation/setting_screen.dart';
import 'package:build_up/features/shop/presentation/screens/store_screen.dart';
import 'package:build_up/features/step_tracking/presentation/screens/route_history_screen.dart';
import 'package:build_up/features/step_tracking/presentation/screens/step_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/step_provider.dart';
import '../providers/active_duration_provider.dart';
import '../widgets/glass_step_card.dart';
import '../widgets/metric_glass_card.dart';

class DashboardView extends ConsumerStatefulWidget {
  const DashboardView({super.key});

  @override
  ConsumerState<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends ConsumerState<DashboardView> {
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
                              builder: (context) => SettingsScreen(),
                            ),
                          ),
                          child: Container(
                            height: 44, // Fixed size for consistency
                            width: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF1E293B),
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
                        color: AppColors.textPrimary,
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
                                const Icon(
                                  Icons.monetization_on_outlined,
                                  color: AppColors.primaryEmerald,
                                  size: 20,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${stepState.coins} ',
                                  style: GoogleFonts.inter(
                                    color: AppColors.textPrimary,
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
                color: AppColors.primaryEmerald,
                backgroundColor: AppColors.glassCardBackground,
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

                        // Step Gauge
                        Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                height: screenWidth * 0.6,
                                width: screenWidth * 0.6,
                                child: CircularProgressIndicator(
                                  value: stepState.goalSteps > 0
                                      ? (stepState.currentSteps /
                                                stepState.goalSteps)
                                            .clamp(0.0, 1.0)
                                      : 0.0,
                                  strokeWidth: screenWidth * 0.05,
                                  backgroundColor: AppColors.primaryEmerald
                                      .withOpacity(0.1),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        AppColors.primaryEmerald,
                                      ),
                                  strokeCap: StrokeCap.round,
                                ),
                              ),
                              ClipOval(
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                    sigmaX: 10,
                                    sigmaY: 10,
                                  ),
                                  child: Container(
                                    height: screenWidth * 0.525,
                                    width: screenWidth * 0.525,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.glassCardBackground,
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          '${stepState.currentSteps}',
                                          style: GoogleFonts.sora(
                                            fontSize: screenWidth * 0.105,
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.textPrimary,
                                            height: 1.2,
                                          ),
                                        ),
                                        Text(
                                          '/ ${stepState.goalSteps} STEPS',
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: screenWidth * 0.03,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textSecondary,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.042),

                        // KCAL Card
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
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  SizedBox(height: screenHeight * 0.005),
                                  Text(
                                    'KCAL BURNED',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: screenWidth * 0.03,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: EdgeInsets.all(screenWidth * 0.035),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primaryEmerald.withOpacity(
                                    0.15,
                                  ),
                                ),
                                child: Icon(
                                  Icons.local_fire_department,
                                  color: AppColors.primaryEmerald,
                                  size: screenWidth * 0.07,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.02),

                        // Metrics Row
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

                        // History Card
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => StepDetailsScreen(),
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
                                    color: AppColors.primaryEmerald.withOpacity(
                                      0.2,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      screenWidth * 0.04,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.history,
                                    color: AppColors.primaryEmerald,
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
                                          color: AppColors.textPrimary,
                                          letterSpacing: .8,
                                        ),
                                      ),
                                      SizedBox(height: screenHeight * 0.005),
                                      Text(
                                        'View past Steps',
                                        style: GoogleFonts.sora(
                                          fontSize: screenWidth * 0.03,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary,
                                          letterSpacing: .8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  color: Colors.white54,
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
