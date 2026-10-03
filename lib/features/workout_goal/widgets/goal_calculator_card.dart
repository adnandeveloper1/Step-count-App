import 'package:build_up/features/workout_goal/widgets/glass_panal.dart';
import 'package:build_up/features/workout_goal/widgets/program_details_screen.dart';
import 'package:build_up/features/workout_goal/widgets/programs_catrgory.dart';
import 'package:build_up/features/workout_goal/workout_goal_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../goal_calculator_screen.dart';

class GoalCalculatorCard extends ConsumerWidget {
  final int currentSteps;
  final int currentKcal;

  const GoalCalculatorCard({
    super.key,
    this.currentSteps = 8432,
    this.currentKcal = 620,
  });

  String _fmt(int n) => n.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeProgramId = ref.watch(activeProgramIdProvider);
    final customProgram = ref.watch(customProgramProvider);
    
    final isCustomActive = customProgram != null && activeProgramId == customProgram.title;

    return GestureDetector(
      onTap: isCustomActive ? () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProgramDetailsScreen(program: customProgram),
          ),
        );
      } : null,
      child: GlassPanel(
        color: CustomColors.surfaceHigh.withValues(alpha: .6),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: CustomColors.lime.withValues(alpha: .2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    isCustomActive ? Icons.auto_awesome : Icons.calculate_outlined,
                    color: CustomColors.lime,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        children: [
                          Text(
                            isCustomActive ? customProgram.title : 'Custom Plan Builder', 
                            style: AppText.sora(16),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: CustomColors.surfaceHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'NEURAL AI',
                              style: AppText.mono(9, color: CustomColors.lime),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isCustomActive 
                          ? 'Your personalized neural workout plan is active. Tap to view exercises.'
                          : 'Create your own personalized workout routine with custom exercises and targets.',
                        style: AppText.body(12),
                      ),
                    ],
                  ),
                ),
                if (isCustomActive)
                  const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CustomColors.surfaceLowest.withValues(alpha: .9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCustomActive ? 'PLAN STATUS' : 'CURRENT PACE',
                          style: AppText.mono(10, color: CustomColors.outline),
                        ),
                        Text(
                          isCustomActive 
                            ? '${customProgram.dailyExercises.length} Exercises • ${customProgram.days}'
                            : '${_fmt(currentSteps)} steps • $currentKcal kcal/day',
                          style: AppText.mono(12, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const GoalCalculatorScreen(),
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: CustomColors.lime,
                      foregroundColor: CustomColors.onLime,
                      shape: const StadiumBorder(),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isCustomActive ? 'Edit Plan' : 'Build Plan',
                          style: AppText.mono(12, color: CustomColors.onLime),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward, size: 14),
                      ],
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
