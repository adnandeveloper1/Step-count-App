import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

class WorkoutCompletionState {
  final List<String> completedIds;
  final DateTime? startDate;

  WorkoutCompletionState({
    this.completedIds = const [],
    this.startDate,
  });

  WorkoutCompletionState copyWith({
    List<String>? completedIds,
    DateTime? startDate,
  }) {
    return WorkoutCompletionState(
      completedIds: completedIds ?? this.completedIds,
      startDate: startDate ?? this.startDate,
    );
  }
}

final workoutCompletionProvider = StateNotifierProvider<WorkoutCompletionNotifier, WorkoutCompletionState>((ref) {
  return WorkoutCompletionNotifier();
});

class WorkoutCompletionNotifier extends StateNotifier<WorkoutCompletionState> {
  WorkoutCompletionNotifier() : super(WorkoutCompletionState());

  void setStartDate(DateTime date) {
    state = state.copyWith(startDate: date);
  }

  void toggleExercise(String id) {
    final completed = state.completedIds;
    if (completed.contains(id)) {
      state = state.copyWith(
        completedIds: completed.where((item) => item != id).toList(),
      );
    } else {
      state = state.copyWith(
        completedIds: [...completed, id],
      );
    }
  }

  bool isCompleted(String id) => state.completedIds.contains(id);

  double getProgress(int totalItems) {
    if (totalItems == 0) return 0.0;
    return state.completedIds.length / totalItems;
  }

  void reset() => state = WorkoutCompletionState();
}
