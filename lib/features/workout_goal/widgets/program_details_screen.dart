import 'package:build_up/features/workout_goal/widgets/programs_catrgory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/workout_completion_provider.dart';
import '../workout_goal_screen.dart';

class ProgramDetailsScreen extends ConsumerWidget {
  final Program program;

  const ProgramDetailsScreen({super.key, required this.program});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completionState = ref.watch(workoutCompletionProvider);
    final completionNotifier = ref.read(workoutCompletionProvider.notifier);

    final progress = completionNotifier.getProgress(program.dailyExercises.length);
    final allDone = progress >= 1.0 && program.dailyExercises.isNotEmpty;

    // Calculate dynamic day
    int currentDay = 1;
    if (completionState.startDate != null) {
      currentDay = DateTime.now().difference(completionState.startDate!).inDays + 1;
    }

    return Scaffold(
      backgroundColor: CustomColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(program.title, style: AppText.sora(18)),
      ),
      body: Column(
        children: [
          // 1. Progress Header
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DAILY PROTOCOL',
                            style: AppText.mono(12, color: CustomColors.lime)),
                        const SizedBox(height: 4),
                        Text('Day $currentDay of ${program.days}',
                            style: AppText.sora(22)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: CustomColors.lime.withOpacity(0.1),
                        border:
                            Border.all(color: CustomColors.lime.withOpacity(0.3)),
                      ),
                      child: Text(
                        '${(progress * 100).toInt()}%',
                        style: AppText.mono(16, color: CustomColors.lime),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: CustomColors.surfaceHighest,
                    color: CustomColors.lime,
                  ),
                ),
              ],
            ),
          ),

          // 2. Exercises List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: program.dailyExercises.length,
              itemBuilder: (context, index) {
                final ex = program.dailyExercises[index];
                final isDone = completionState.completedIds.contains(ex.id);

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDone
                        ? CustomColors.surface.withOpacity(0.3)
                        : CustomColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDone
                          ? CustomColors.lime.withOpacity(0.5)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color:
                              isDone ? CustomColors.lime : CustomColors.surfaceHigh,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isDone ? Icons.check : ex.icon,
                          color:
                              isDone ? CustomColors.onLime : CustomColors.outline,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ex.name,
                              style: AppText.sora(16,
                                  color: isDone ? Colors.white60 : Colors.white),
                            ),
                            Text(
                              '${ex.target} • ${ex.duration}',
                              style: AppText.mono(11, color: CustomColors.outline),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => completionNotifier.toggleExercise(ex.id),
                        icon: Icon(
                          isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: isDone ? CustomColors.lime : CustomColors.outline,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // 3. Bottom Action
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: allDone
                    ? () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Great work! Daily Protocol Logged.')),
                        );
                        Navigator.pop(context);
                      }
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: CustomColors.lime,
                  disabledBackgroundColor: CustomColors.surfaceHigh,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  allDone ? 'COMPLETE DAILY LOG' : 'COMPLETE ALL EXERCISES',
                  style: AppText.sora(15,
                      color: allDone
                          ? CustomColors.onLime
                          : CustomColors.outline),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
