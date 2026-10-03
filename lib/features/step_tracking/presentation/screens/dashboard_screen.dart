import 'dart:ui';
import 'package:build_up/features/settings/presentation/setting_screen.dart';
import 'package:build_up/features/shop/presentation/screens/store_screen.dart';
import 'package:build_up/features/step_tracking/presentation/screens/step_details_screen.dart';
import 'package:build_up/features/workout_goal/providers/workout_completion_provider.dart';
import 'package:build_up/features/workout_goal/widgets/program_details_screen.dart';
import 'package:build_up/features/workout_goal/workout_goal_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../workout_goal/widgets/programs_catrgory.dart';
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

  void _showCustomSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message.toUpperCase(),
          textAlign: TextAlign.center,
          style: GoogleFonts.sora(
            color: isError ? Colors.white : AppColors.backgroundDark,
            fontWeight: FontWeight.w500,
            fontSize: 14,
            letterSpacing: 1.2,
          ),
        ),
        backgroundColor: isError ? Colors.redAccent : AppColors.primaryEmerald,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 8,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _confirmCancelPlan() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2113),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('STOP TRAINING?', 
          style: GoogleFonts.sora(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
        content: Text('This will clear your current training plan and reset daily protocol logs. Your step progress will remain.',
            style: GoogleFonts.inter(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CONTINUE', style: GoogleFonts.jetBrainsMono(color: Colors.white54, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () {
              ref.read(activeProgramIdProvider.notifier).state = null;
              ref.read(workoutCompletionProvider.notifier).reset();
              Navigator.pop(context);
              _showCustomSnackBar('Training stopped');
            },
            child: Text('STOP PLAN', style: GoogleFonts.jetBrainsMono(color: Colors.redAccent, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeProgramId = ref.watch(activeProgramIdProvider);
    final customProgram = ref.watch(customProgramProvider);
    final stepState = ref.watch(stepNotifierProvider);
    final completionState = ref.watch(workoutCompletionProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final profile = profileAsync.value;
    final avatar = profile?['avatarUrl'] ?? '👦';

    final activeProgram = getProgramById(activeProgramId, customProgram: customProgram);

    int currentDay = 1;
    if (completionState.startDate != null) {
      currentDay = DateTime.now().difference(completionState.startDate!).inDays + 1;
    }

    final double exerciseProgress = activeProgram != null && activeProgram.dailyExercises.isNotEmpty
        ? (completionState.completedIds.length / activeProgram.dailyExercises.length).clamp(0.0, 1.0)
        : 0.0;

    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    final screenHeight = size.height;
    Color currentLeagueColor = stepState.currentLeague.color;
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
            color: AppColors.primaryEmerald,
            backgroundColor: AppColors.glassCardBackground,
            onRefresh: () async {
              await ref.read(stepNotifierProvider.notifier).forceRefresh();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),

        child: SafeArea(
          child: Padding(
            padding:  EdgeInsets.all(screenWidth * 0.05),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: (){
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) =>  SettingsScreen()),
                        );
                      },
                      child: Container(
                        height: screenWidth * 0.12,
                        width: screenWidth * 0.11,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF1E293B),
                          border: Border.all(
                            color: currentLeagueColor,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            avatar,
                            style: TextStyle(fontSize: screenWidth * 0.0625),
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
                    GlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 08, vertical: 8),
                      child: GestureDetector(
                        onTap: (){
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const StoreScreen()),
                          );
                        },
                        child: Row(
                          children: [
                            const Icon(Icons.monetization_on_outlined, color: AppColors.primaryEmerald, size: 20),
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
                  ],
                ),
                SizedBox(height: screenHeight * 0.028),

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
                                ? (stepState.currentSteps / stepState.goalSteps)
                                    .clamp(0.0, 1.0)
                                : 0.0,
                            strokeWidth: screenWidth * 0.05,
                            backgroundColor:
                                AppColors.primaryEmerald.withOpacity(0.1),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.primaryEmerald),
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        ClipOval(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              height: screenWidth * 0.525,
                              width: screenWidth * 0.525,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.glassCardBackground,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
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
                          color: AppColors.primaryEmerald.withOpacity(0.15),
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

                // Active Program Progress Card
                if (activeProgram != null) ...[
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProgramDetailsScreen(program: activeProgram),
                        ),
                      );
                    },
                    child: GlassCard(
                      padding: EdgeInsets.all(screenWidth * 0.06),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: EdgeInsets.all(screenWidth * 0.03),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryEmerald.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(screenWidth * 0.04),
                                ),
                                child: Icon(
                                  activeProgram.category == ProgramCategory.enrolled ? Icons.auto_awesome : Icons.bolt,
                                  color: AppColors.primaryEmerald,
                                  size: 24,
                                ),
                              ),
                              SizedBox(width: screenWidth * 0.04),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'ACTIVE TRACK',
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: screenWidth * 0.026,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primaryEmerald,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'DAY $currentDay',
                                            style: GoogleFonts.jetBrainsMono(
                                              fontSize: screenWidth * 0.024,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: _confirmCancelPlan,
                                          child: const Icon(Icons.close, color: Colors.white38, size: 18),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      activeProgram.title,
                                      style: GoogleFonts.sora(
                                        fontSize: screenWidth * 0.042,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'DAILY PROTOCOL PROGRESS',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 9,
                                  color: Colors.white54,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                '${(exerciseProgress * 100).toInt()}%',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryEmerald,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: exerciseProgress,
                              minHeight: 6,
                              backgroundColor: AppColors.primaryEmerald.withOpacity(0.05),
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryEmerald),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                SizedBox(height: screenHeight * 0.02),
                ],
                // History Card
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const WorkoutGoalScreen ()),
                    );
                  },
                  child: GlassCard(
                    padding: EdgeInsets.all(screenWidth * 0.06),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(screenWidth * 0.03),
                          decoration: BoxDecoration(
                            color: AppColors.primaryEmerald.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(screenWidth * 0.04),
                          ),
                          child: Icon(
                            Icons.fitness_center,
                            color: AppColors.primaryEmerald,
                            size: screenWidth * 0.07,
                          ),
                        ),
                        SizedBox(width: screenWidth * 0.04),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activeProgram != null ? 'Manage Training' : 'Start Training',
                                style: GoogleFonts.sora(
                                  fontSize: screenWidth * 0.045,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                  letterSpacing: .8,
                                ),
                              ),
                              Text(
                                activeProgram != null 
                                  ? 'Switch or edit your current routine'
                                  : 'Browse pre-made or custom routines',
                                style: GoogleFonts.inter(
                                  fontSize: screenWidth * 0.028,
                                  color: Colors.white54,
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
      )
    );
  }
}
