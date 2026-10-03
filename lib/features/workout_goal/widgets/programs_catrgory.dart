import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../social/presentation/providers/challenge_provider.dart' as social;
import '../../step_tracking/presentation/providers/step_provider.dart';
import '../providers/extra_programs.dart';

/// Category labels used by both the filter chips and the programs.
/// Keeping them in one place stops typos from breaking the filter.
class ProgramCategory {
  static const enrolled = 'Enrolled';
  static const all = 'All Programs';
  static const weightLoss = 'Weight Loss';
  static const sixPack = 'Six-Pack Abs';
  static const muscle = 'Muscle & Strength';
  static const endurance = 'Endurance / 10K';
  static const mobility = 'Mobility & Recovery';

  /// (label, emoji) in display order for the chip bar.
  static const chips = <(String, String)>[
    (enrolled, '✅'),
    (all, ''),
    (weightLoss, '🔥'),
    (sixPack, '⚡'),
    (muscle, '💪'),
    (endurance, '🏃'),
    (mobility, '🧘'),
  ];
}

/// A small stat shown at the bottom of a program card
/// (for example "12 min/day" or "+450 kcal burn").
class ProgramStat {
  final IconData icon;
  final String label;
  final bool highlight; // true = lime accent

  const ProgramStat(this.icon, this.label, {this.highlight = false});
}

class WorkoutExercise {
  final String id;
  final String name;
  final String target;
  final String duration; // e.g., "3 sets x 15 reps" or "20 mins"
  final IconData icon; // Specific icon for each exercise

  const WorkoutExercise({
    required this.id,
    required this.name,
    required this.target,
    required this.duration,
    this.icon = Icons.fitness_center,
  });
}

class Program {
  final String title;
  final String desc;
  final String days;
  final String level;
  final String category;
  final IconData icon;
  final ProgramStat stat1;
  final ProgramStat stat2;
  final bool highIntensity;
  final List<WorkoutExercise> dailyExercises;

  const Program({
    required this.title,
    required this.desc,
    required this.days,
    required this.level,
    required this.category,
    required this.icon,
    required this.stat1,
    required this.stat2,
    this.highIntensity = false,
    this.dailyExercises = const [],
  });
}

/// The merged list of all available programs.
final allPrograms = <Program>[...programs, ...extraPrograms];

/// Helper to get program by its title or ID for consistent UI across screens
Program? getProgramById(String? id, {Program? customProgram}) {
  if (id == null) return null;

  // Check if it matches the custom program
  if (customProgram != null && id == customProgram.title) {
    return customProgram;
  }
  
  // Handle Hero Program ID
  if (id == 'metabolic_shred_2026' || id == '4-Week Metabolic Shred') {
    return const Program(
      title: '4-Week Metabolic Shred',
      desc: 'High-tempo metabolic loops, core stabilization and structured step targets.',
      days: '28 DAYS',
      level: 'ZONE 3/4',
      category: ProgramCategory.weightLoss,
      icon: Icons.auto_graph,
      stat1: ProgramStat(Icons.timer_outlined, '28 Days'),
      stat2: ProgramStat(Icons.local_fire_department, '10k Steps', highlight: true),
      dailyExercises: [
        WorkoutExercise(id: 'h_1', name: 'Incline Running', target: 'Cardio', duration: '20 mins', icon: Icons.directions_run),
        WorkoutExercise(id: 'h_2', name: 'Plank Hold', target: 'Core', duration: '3 x 60s', icon: Icons.timer),
        WorkoutExercise(id: 'h_3', name: 'Leg Raises', target: 'Lower Abs', duration: '3 x 15', icon: Icons.accessibility_new),
      ],
    );
  }
  
  // Find in programs list
  try {
    return allPrograms.firstWhere((p) => p.title == id);
  } catch (_) {
    return null;
  }
}

/// Returns the programs matching [category].
/// "All Programs" returns everything.
List<Program> filterPrograms(List<Program> source, String category, {String? activeId, Program? customProgram}) {
  if (category == ProgramCategory.enrolled) {
    final prog = getProgramById(activeId, customProgram: customProgram);
    return prog != null ? [prog] : [];
  }
  if (category == ProgramCategory.all) return source;
  return source.where((p) => p.category == category).toList();
}

/// Sample data.
const programs = <Program>[
  Program(
    title: 'Six-Pack Abs & Core Power',
    desc:
    'Post-run isometric circuits, hanging leg raises, plank holds & structured brisk step quotas.',
    days: '21 DAYS',
    level: 'LEVEL 2',
    category: ProgramCategory.sixPack,
    icon: Icons.grid_goldenratio_rounded,
    stat1: ProgramStat(Icons.timer_outlined, '12 min/day'),
    stat2: ProgramStat(Icons.local_fire_department, '+450 kcal burn', highlight: true),
    dailyExercises: [
      WorkoutExercise(id: 'abs_1', name: 'Hanging Leg Raises', target: 'Lower Abs', duration: '3 x 12 reps', icon: Icons.accessibility_new),
      WorkoutExercise(id: 'abs_2', name: 'Plank Hold', target: 'Core Stability', duration: '3 x 60 sec', icon: Icons.timer),
      WorkoutExercise(id: 'abs_3', name: 'Russian Twists', target: 'Obliques', duration: '3 x 30 reps', icon: Icons.loop),
    ],
  ),
  Program(
    title: 'Rapid Fat Burn & Deficit',
    desc:
    'High-tempo incline walking intervals, 12,000 daily steps and steady-state morning cardio.',
    days: '30 DAYS',
    level: 'LEVEL 3 • HIGH INTENSITY',
    category: ProgramCategory.weightLoss,
    icon: Icons.speed_rounded,
    highIntensity: true,
    stat1: ProgramStat(Icons.timer_outlined, '35 min/day'),
    stat2: ProgramStat(Icons.local_fire_department, '+700 kcal deficit', highlight: true),
    dailyExercises: [
      WorkoutExercise(id: 'fat_1', name: 'Incline Jogging', target: 'Cardio', duration: '30 mins', icon: Icons.directions_run),
      WorkoutExercise(id: 'fat_2', name: 'Burpees', target: 'Full Body', duration: '4 x 10 reps', icon: Icons.bolt),
      WorkoutExercise(id: 'fat_3', name: 'Mountain Climbers', target: 'Fat Burn', duration: '3 x 45 sec', icon: Icons.terrain),
    ],
  ),
  Program(
    title: 'Lean Mass & Athletic Power',
    desc:
    'Progressive calisthenics, plyometrics and active recovery walks to retain lean mass.',
    days: '6 WEEKS',
    level: 'ALL LEVELS',
    category: ProgramCategory.muscle,
    icon: Icons.fitness_center,
    stat1: ProgramStat(Icons.timer_outlined, '25 min/day'),
    stat2: ProgramStat(Icons.sync_alt, 'Strength / Cardio'),
    dailyExercises: [
      WorkoutExercise(id: 'lean_1', name: 'Pushups', target: 'Chest', duration: '3 x 20', icon: Icons.horizontal_rule),
      WorkoutExercise(id: 'lean_2', name: 'Squats', target: 'Legs', duration: '3 x 20', icon: Icons.arrow_downward),
      WorkoutExercise(id: 'lean_3', name: 'Pullups', target: 'Back', duration: '3 x 10', icon: Icons.arrow_upward),
    ],
  ),
  Program(
    title: 'Zero to 10K Endurance Builder',
    desc:
    'Cadence ladders, run/walk interval pacing and VO2 Max step development.',
    days: '8 WEEKS',
    level: 'FOUNDATION',
    category: ProgramCategory.endurance,
    icon: Icons.directions_run,
    stat1: ProgramStat(Icons.event_repeat, '3 runs/week'),
    stat2: ProgramStat(Icons.self_improvement, 'Mobility'),
    dailyExercises: [
      WorkoutExercise(id: 'run_1', name: 'Easy Run', target: 'Endurance', duration: '30 mins', icon: Icons.directions_run),
      WorkoutExercise(id: 'run_2', name: 'Interval Sprints', target: 'Speed', duration: '5 x 400m', icon: Icons.speed),
      WorkoutExercise(id: 'run_3', name: 'Recovery Walk', target: 'Recovery', duration: '20 mins', icon: Icons.directions_walk),
    ],
  ),
];

class ProgramRecommendation {
  final String id;
  final String tag;
  final String title;
  final int avgSteps;
  final String zone;
  final String timeline;
  final String timelineSub;
  final String deficit;
  final String deficitSub;
  final String quota;
  final String quotaSub;

  const ProgramRecommendation({
    required this.id,
    required this.tag,
    required this.title,
    required this.avgSteps,
    required this.zone,
    required this.timeline,
    required this.timelineSub,
    required this.deficit,
    required this.deficitSub,
    required this.quota,
    required this.quotaSub,
  });

  ProgramRecommendation copyWith({
    int? avgSteps,
    String? quota,
    String? timeline,
  }) {
    return ProgramRecommendation(
      id: id,
      tag: tag,
      title: title,
      avgSteps: avgSteps ?? this.avgSteps,
      zone: zone,
      timeline: timeline ?? this.timeline,
      timelineSub: timelineSub,
      deficit: deficit,
      deficitSub: deficitSub,
      quota: quota ?? this.quota,
      quotaSub: quotaSub,
    );
  }
}

final activeProgramIdProvider = StateProvider<String?>((ref) => null);

final customProgramProvider = StateProvider<Program?>((ref) => null);

final workoutRecommendationProvider = NotifierProvider<WorkoutRecommendationNotifier, ProgramRecommendation>(
  WorkoutRecommendationNotifier.new,
);

class WorkoutRecommendationNotifier extends Notifier<ProgramRecommendation> {
  @override
  ProgramRecommendation build() {
    return const ProgramRecommendation(
      id: 'metabolic_shred_2026',
      tag: 'FAT LOSS + CORE FOCUS',
      title: '4-Week Metabolic Shred',
      avgSteps: 8432,
      zone: 'Zone 3/4',
      timeline: '28 Days',
      timelineSub: '4 Microcycles',
      deficit: '-3.5 kg',
      deficitSub: '-18,000 kcal',
      quota: '10k Steps',
      quotaSub: '+15m Core',
    );
  }

  void tuneTargets({required int customSteps, required String customDuration}) {
    state = state.copyWith(
      avgSteps: customSteps,
      quota: '${(customSteps / 1000).toStringAsFixed(1)}k Steps',
      timeline: customDuration,
    );
  }

  void enrollInProgram() {
    final storage = ref.read(social.storageProvider);
    storage.saveChallengeData(state.avgSteps.toString());
    storage.saveActiveStepGoal(state.avgSteps);
    ref.read(activeProgramIdProvider.notifier).state = state.id;
    ref.read(widgetServiceProvider).updateWidgetData(
      steps: 0,
      goal: state.avgSteps,
      distance: 0.0,
      calories: 0.0,
    );
  }
}
