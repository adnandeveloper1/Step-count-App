import 'package:build_up/features/workout_goal/widgets/program_card.dart';
import 'package:build_up/features/workout_goal/widgets/programs_catrgory.dart';
import 'package:build_up/features/workout_goal/widgets/filter_chip_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../step_tracking/presentation/providers/step_provider.dart';
import 'providers/workout_completion_provider.dart';
import 'widgets/goal_calculator_card.dart';
import '../../core/services/widget_service.dart';

// widgetServiceProvider is now defined in step_provider.dart to avoid duplicates

class CustomColors {
  static const bg = Color(0xFF0B0E04);
  static const surface = Color(0xFF1E2113);
  static const surfaceHigh = Color(0xFF282B1D);
  static const surfaceHighest = Color(0xFF333627);
  static const surfaceLowest = Color(0xFF0C0F04);
  static const lime = Color(0xFFC3F400);
  static const onLime = Color(0xFF161E00);
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFFC4C9AC);
  static const outline = Color(0xFF8E9379);
  static const error = Color(0xFFFFB4AB);
}

class AppText {
  static TextStyle sora(
    double size, {
    Color color = CustomColors.textPrimary,
    FontWeight weight = FontWeight.w600,
  }) => GoogleFonts.sora(
    fontSize: size,
    color: color,
    fontWeight: weight,
    letterSpacing: -0.3,
  );

  static TextStyle mono(
    double size, {
    Color color = CustomColors.textSecondary,
  }) => GoogleFonts.jetBrainsMono(
    fontSize: size,
    color: color,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.6,
  );

  static TextStyle body(
    double size, {
    Color color = CustomColors.textSecondary,
  }) => GoogleFonts.inter(fontSize: size, color: color, height: 1.5);
}

class WorkoutGoalScreen extends ConsumerStatefulWidget {
  const WorkoutGoalScreen({super.key});

  @override
  ConsumerState<WorkoutGoalScreen> createState() => _WorkoutGoalScreenState();
}

class _WorkoutGoalScreenState extends ConsumerState<WorkoutGoalScreen> {
  String selected = ProgramCategory.all;
  int navIndex = 0;

  @override
  Widget build(BuildContext context) {
    final activeProgramId = ref.watch(activeProgramIdProvider);
    final customProgram = ref.watch(customProgramProvider);

    final visible = filterPrograms(
      allPrograms, 
      selected, 
      activeId: activeProgramId,
      customProgram: customProgram,
    );
    
    final width = MediaQuery.sizeOf(context).width;
    final titleSize = (width * 0.07).clamp(24.0, 32.0);

    return Scaffold(
      backgroundColor: CustomColors.bg,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 130),
              children: [
                Center(
                  child: Text(
                    'BUILD UP',
                    style: AppText.sora(24, weight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 25),

                // 1. Simplified Header
                Text(
                  'WORKOUT PLANS • 2026',
                  style: AppText.mono(12, color: CustomColors.lime),
                ),
                const SizedBox(height: 8),
                Text('Workout & Goal Programs', style: AppText.sora(titleSize)),
                const SizedBox(height: 8),
                Text(
                  'Simple plans designed to help you get fit and stay active.',
                  style: AppText.body(16),
                ),
                const SizedBox(height: 24),

                // 2. Custom Goal Calculator (Now at the top)
                const GoalCalculatorCard(),
                const SizedBox(height: 32),

                // 3. Filter Bar (All Programs, Muscle, etc.)
                FilterChipBar(
                  selected: selected,
                  onSelected: (v) => setState(() => selected = v),
                ),
                const SizedBox(height: 28),

                // 4. Dynamic Section Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.fitness_center,
                          color: CustomColors.lime,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          // Change text based on what is selected
                          selected == ProgramCategory.all
                              ? 'Available Programs'
                              : '$selected Programs',
                          style: AppText.sora(20),
                        ),
                      ],
                    ),
                    Text(
                      '${visible.length} Tracks',
                      style: AppText.mono(12, color: CustomColors.outline),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 5. List of Program Cards
                if (visible.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'No programs in this category yet',
                        style: AppText.body(14),
                      ),
                    ),
                  ),
                for (final p in visible)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: ProgramCard(
                      program: p,
                      onEnroll: () {
                        // Set program as active
                        ref.read(activeProgramIdProvider.notifier).state =
                            p.title;

                        // Set start date for tracking days
                        ref.read(workoutCompletionProvider.notifier).setStartDate(DateTime.now());
                        ref.read(workoutCompletionProvider.notifier).reset(); // Reset progress when enrolling in new program

                        // Calculate dynamic step target
                        int targetGoal = p.highIntensity ? 12000 : 8000;

                        // Sync with Dashboard & Widget
                        ref
                            .read(stepNotifierProvider.notifier)
                            .updateGoal(targetGoal);
                        ref.read(widgetServiceProvider).updateWidgetData(
                          steps: 0,
                          goal: targetGoal,
                          distance: 0.0,
                          calories: 0.0,
                        );

                        _showAppSnackBar(context, 'Enrolled in ${p.title}!');
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAppSnackBar(BuildContext context, String message,
      {bool isError = false}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message.toUpperCase(),
          textAlign: TextAlign.center,
          style: AppText.sora(
            14,
            color: isError ? Colors.white : CustomColors.onLime,
          ),
        ),
        backgroundColor: isError ? Colors.redAccent : CustomColors.lime,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 8,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
