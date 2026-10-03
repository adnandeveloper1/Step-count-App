import 'package:build_up/features/workout_goal/widgets/programs_catrgory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/theme/app_colors.dart';
import 'workout_goal_screen.dart';
import '../step_tracking/presentation/providers/step_provider.dart';
import 'providers/workout_completion_provider.dart';

class GoalCalculatorScreen extends ConsumerStatefulWidget {
  const GoalCalculatorScreen({super.key});

  @override
  ConsumerState<GoalCalculatorScreen> createState() => _GoalCalculatorScreenState();
}

class _GoalCalculatorScreenState extends ConsumerState<GoalCalculatorScreen> {
  final TextEditingController _nameController = TextEditingController(text: "My Personal Plan");
  List<WorkoutExercise> customExercises = [
    const WorkoutExercise(id: '1', name: 'Morning Walk', target: 'Daily', duration: '15 mins'),
  ];
  
  double currentWeight = 80.0;
  double targetWeight = 75.0;
  double planDays = 30.0;
  String activityLevel = 'Active';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final existing = ref.read(customProgramProvider);
      if (existing != null) {
        setState(() {
          _nameController.text = existing.title;
          customExercises = List.from(existing.dailyExercises);
          // If we want to restore weight/days, we would need to store them in the provider too.
          // For now, we at least restore the exercises and name.
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 8,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showAddTaskDialog() {
    String taskName = "";
    String amount = "";
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: CustomColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Add New Task', style: AppText.sora(18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              onChanged: (v) => taskName = v,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Task Name (e.g. Pushups)',
                labelStyle: AppText.mono(10, color: CustomColors.outline),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: CustomColors.surfaceHighest)),
              ),
            ),
            TextField(
              onChanged: (v) => amount = v,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Amount (e.g. 3 sets or 10 mins)',
                labelStyle: AppText.mono(10, color: CustomColors.outline),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: CustomColors.surfaceHighest)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: CustomColors.outline)),
          ),
          TextButton(
            onPressed: () {
              if (taskName.isNotEmpty) {
                setState(() {
                  customExercises.add(WorkoutExercise(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: taskName,
                    target: "Custom",
                    duration: amount,
                  ));
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Add', style: TextStyle(color: CustomColors.lime, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showExerciseLibrary() {
    final List<WorkoutExercise> library = [];
    final Set<String> seenNames = {};

    for (var p in allPrograms) {
      for (var ex in p.dailyExercises) {
        if (!seenNames.contains(ex.name)) {
          library.add(ex);
          seenNames.add(ex.name);
        }
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: CustomColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: CustomColors.surfaceHighest,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text('Exercise Library', style: AppText.sora(20)),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: library.length,
                itemBuilder: (context, index) {
                  final ex = library[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: CustomColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(ex.icon, color: CustomColors.lime, size: 20),
                    ),
                    title: Text(ex.name, style: AppText.sora(15)),
                    subtitle: Text('${ex.target} • Default: ${ex.duration}', 
                      style: AppText.mono(10, color: CustomColors.outline)),
                    trailing: const Icon(Icons.add_circle_outline, color: CustomColors.lime),
                    onTap: () {
                      setState(() {
                        customExercises.add(WorkoutExercise(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          name: ex.name,
                          target: ex.target,
                          duration: ex.duration,
                          icon: ex.icon,
                        ));
                      });
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  double getActivityCoefficient() {
    switch (activityLevel) {
      case 'Sedentary': return 1.2;
      case 'Active': return 1.5;
      case 'Athlete': return 1.9;
      default: return 1.5;
    }
  }

  String _fmt(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

  @override
  Widget build(BuildContext context) {
    final customProgram = ref.watch(customProgramProvider);
    final activeProgramId = ref.watch(activeProgramIdProvider);
    final isCustomActive = customProgram != null && activeProgramId == customProgram.title;

    double weightDiff = currentWeight - targetWeight;
    if (weightDiff < 0) weightDiff = 0;
    double dailyDeficit = (weightDiff * 7700) / planDays; 
    int targetSteps = (6000 + (dailyDeficit / 0.05)).round();
    targetSteps = (targetSteps * getActivityCoefficient() / 1.5).round().clamp(4000, 50000);

    return Scaffold(
      backgroundColor: CustomColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Custom Plan Builder', style: AppText.sora(18)),
        centerTitle: true,
        actions: [
          if (customProgram != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: CustomColors.error),
              tooltip: 'Delete Custom Plan',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: CustomColors.surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    title: Text('Delete Plan?', style: AppText.sora(18)),
                    content: Text('Are you sure you want to delete your custom plan?', style: AppText.body(14)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () {
                          ref.read(customProgramProvider.notifier).state = null;
                          if (activeProgramId == customProgram.title) {
                            ref.read(activeProgramIdProvider.notifier).state = null;
                          }
                          Navigator.pop(context);
                          _showCustomSnackBar('Custom plan deleted');
                          // Reset to defaults
                          setState(() {
                            _nameController.text = "My Personal Plan";
                            customExercises = [
                              const WorkoutExercise(id: '1', name: 'Morning Walk', target: 'Daily', duration: '15 mins'),
                            ];
                          });
                        },
                        child: const Text('Delete', style: TextStyle(color: CustomColors.error)),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
          children: [
            Text('PLAN DETAILS', style: AppText.mono(12, color: CustomColors.lime)),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              style: AppText.sora(20, color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Name your plan',
                labelStyle: AppText.mono(12, color: CustomColors.outline),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: CustomColors.surfaceHighest)),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: CustomColors.lime)),
              ),
            ),
            const SizedBox(height: 32),
            _buildSliderRow(
              label: 'PLAN DURATION',
              value: '${planDays.round()} Days',
              valueDouble: planDays,
              min: 7,
              max: 90,
              onChanged: (val) => setState(() => planDays = val),
            ),
            const SizedBox(height: 24),
            Text('PERSONAL GOALS', style: AppText.mono(12, color: CustomColors.lime)),
            const SizedBox(height: 20),
            _buildSliderRow(
              label: 'CURRENT WEIGHT',
              value: '${currentWeight.toStringAsFixed(1)} kg',
              valueDouble: currentWeight,
              min: 40,
              max: 150,
              onChanged: (val) => setState(() => currentWeight = val),
            ),
            const SizedBox(height: 24),
            _buildSliderRow(
              label: 'TARGET WEIGHT',
              value: '${targetWeight.toStringAsFixed(1)} kg',
              valueDouble: targetWeight,
              min: 40,
              max: 150,
              onChanged: (val) => setState(() => targetWeight = val),
            ),
            const SizedBox(height: 24),
            Text('HOW ACTIVE ARE YOU?', style: AppText.mono(11, color: CustomColors.outline)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: CustomColors.surfaceHigh,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: CustomColors.surfaceHighest),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: activityLevel,
                  dropdownColor: CustomColors.surfaceHigh,
                  icon: const Icon(Icons.keyboard_arrow_down, color: CustomColors.lime),
                  items: ['Sedentary', 'Active', 'Athlete'].map((String level) {
                    return DropdownMenuItem<String>(
                      value: level,
                      child: Text(level, style: AppText.sora(15, color: Colors.white)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => activityLevel = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('YOUR DAILY TASKS', style: AppText.mono(12, color: CustomColors.lime)),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _showExerciseLibrary,
                      icon: const Icon(Icons.list_alt, size: 16, color: CustomColors.lime),
                      label: Text('Library', style: AppText.mono(10, color: CustomColors.lime)),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _showAddTaskDialog,
                      icon: const Icon(Icons.add, size: 16, color: CustomColors.lime),
                      label: Text('Manual', style: AppText.mono(10, color: CustomColors.lime)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (customExercises.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(child: Text('No extra tasks added.', style: AppText.body(12, color: CustomColors.outline))),
              ),
            ...List.generate(customExercises.length, (index) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CustomColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: CustomColors.surfaceHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(customExercises[index].icon, size: 16, color: CustomColors.lime),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(customExercises[index].name, style: AppText.sora(14)),
                          if (customExercises[index].duration.isNotEmpty)
                            Text(customExercises[index].duration, style: AppText.mono(10, color: CustomColors.outline)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: CustomColors.error),
                      onPressed: () => setState(() => customExercises.removeAt(index)),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: CustomColors.surfaceLowest,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: CustomColors.surfaceHighest.withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('DAILY STEP GOAL', style: AppText.mono(10, color: CustomColors.outline)),
                  const SizedBox(height: 6),
                  Text(
                    '${_fmt(targetSteps)} Steps',
                    style: AppText.sora(32, color: CustomColors.lime, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'To lose ${weightDiff.toStringAsFixed(1)} kg in ${planDays.round()} days.',
                    style: AppText.mono(11, color: CustomColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: CustomColors.lime,
                  foregroundColor: CustomColors.onLime,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: const StadiumBorder(),
                ),
                onPressed: () {
                  final planTitle = _nameController.text.trim().isEmpty ? "My Custom Plan" : _nameController.text;
                  final newCustomProgram = Program(
                    title: planTitle,
                    desc: 'Custom plan generated to lose ${weightDiff.toStringAsFixed(1)} kg.',
                    days: '${planDays.round()} DAYS',
                    level: activityLevel.toUpperCase(),
                    category: ProgramCategory.enrolled,
                    icon: Icons.auto_awesome,
                    stat1: ProgramStat(Icons.timer_outlined, '${planDays.round()} Days'),
                    stat2: ProgramStat(Icons.local_fire_department, '${_fmt(targetSteps)} Steps', highlight: true),
                    dailyExercises: List.from(customExercises),
                  );
                  ref.read(customProgramProvider.notifier).state = newCustomProgram;
                  ref.read(activeProgramIdProvider.notifier).state = planTitle;
                  ref.read(workoutCompletionProvider.notifier).setStartDate(DateTime.now());
                  ref.read(workoutCompletionProvider.notifier).reset();
                  ref.read(stepNotifierProvider.notifier).updateGoal(targetSteps);
                  ref.read(widgetServiceProvider).updateWidgetData(steps: 0, goal: targetSteps, distance: 0.0, calories: 0.0);
                  _showCustomSnackBar('Plan Started: $planTitle');
                  Navigator.pop(context);
                },
                child: Text(customProgram != null ? 'Update My Plan' : 'Start My Plan', style: AppText.sora(16, color: CustomColors.onLime)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderRow({required String label, required String value, required double valueDouble, required double min, required double max, required ValueChanged<double> onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppText.mono(11, color: CustomColors.outline)),
            Text(value, style: AppText.sora(14, color: Colors.white)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: CustomColors.lime,
            inactiveTrackColor: CustomColors.surfaceHighest,
            thumbColor: CustomColors.lime,
            overlayColor: CustomColors.lime.withOpacity(0.15),
            trackHeight: 4,
          ),
          child: Slider(value: valueDouble, min: min, max: max, onChanged: onChanged),
        ),
      ],
    );
  }
}
