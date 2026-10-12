import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/step_history.dart';
import '../providers/step_provider.dart';
import '../screens/goal_congrats_screen.dart';

// True once per day, the first time today's steps reach the goal.
bool shouldCelebrateGoal({
  required int steps,
  required int goalSteps,
  required String celebratedDate,
  required DateTime today,
}) {
  return goalSteps > 0 &&
      steps >= goalSteps &&
      celebratedDate != dateKey(today);
}

// Opens the goal congrats screen over [child] once a day when the goal is
// hit. It waits until the app is in front of the user, so a goal reached
// in the background (or a tap on the goal notification) shows it on return.
class GoalCelebrationListener extends ConsumerStatefulWidget {
  final Widget child;

  const GoalCelebrationListener({super.key, required this.child});

  @override
  ConsumerState<GoalCelebrationListener> createState() =>
      _GoalCelebrationListenerState();
}

class _GoalCelebrationListenerState
    extends ConsumerState<GoalCelebrationListener> {
  late final AppLifecycleListener _lifecycle;
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _maybeCelebrate);
    // Goal may already be met from steps counted while the app was closed.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeCelebrate());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  bool get _isInForeground {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  void _maybeCelebrate() {
    if (!mounted || _showing || !_isInForeground) return;
    final stepState = ref.read(stepNotifierProvider);
    final storage = ref.read(storageProvider);
    final today = DateTime.now();
    if (!shouldCelebrateGoal(
      steps: stepState.currentSteps,
      goalSteps: stepState.goalSteps,
      celebratedDate: storage.getGoalCelebratedDate(),
      today: today,
    )) {
      return;
    }

    // Saved before opening so quick step updates can't open it twice.
    storage.saveGoalCelebratedDate(dateKey(today));
    _showing = true;
    Navigator.of(context)
        .push(
          PageRouteBuilder<void>(
            transitionDuration: const Duration(milliseconds: 450),
            reverseTransitionDuration: const Duration(milliseconds: 300),
            pageBuilder: (_, _, _) => const GoalCongratsScreen(),
            transitionsBuilder: (_, animation, _, child) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              );
              return FadeTransition(
                opacity: curved,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
                  child: child,
                ),
              );
            },
          ),
        )
        .whenComplete(() => _showing = false);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(stepNotifierProvider, (_, _) => _maybeCelebrate());
    return widget.child;
  }
}
