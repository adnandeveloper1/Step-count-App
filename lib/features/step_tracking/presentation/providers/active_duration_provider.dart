import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'step_provider.dart';

class ActiveDurationState {
  final int activeSeconds;
  final bool isTracking;

  const ActiveDurationState({
    required this.activeSeconds,
    required this.isTracking,
  });

  String get formattedDuration {
    final minutes = (activeSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (activeSeconds % 60).toString().padLeft(2, '0');
    final hours = (activeSeconds ~/ 3600).toString().padLeft(2, '0');
    return hours == '00' ? '$minutes:$seconds' : '$hours:$minutes:$seconds';
  }

  ActiveDurationState copyWith({
    int? activeSeconds,
    bool? isTracking,
  }) {
    return ActiveDurationState(
      activeSeconds: activeSeconds ?? this.activeSeconds,
      isTracking: isTracking ?? this.isTracking,
    );
  }
}

final activeDurationProvider =
NotifierProvider<ActiveDurationNotifier, ActiveDurationState>(
    ActiveDurationNotifier.new);

class ActiveDurationNotifier extends Notifier<ActiveDurationState> {
  Timer? _timer;
  int _lastStepCount = 0;

  @override
  ActiveDurationState build() {
    return const ActiveDurationState(activeSeconds: 0, isTracking: false);
  }

  void startTracking() {
    if (state.isTracking) return;

    state = state.copyWith(isTracking: true);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final stepState = ref.read(stepNotifierProvider);

      if (stepState.isRestMode) return;

      if (stepState.pedestrianStatus == 'walking' ||
          stepState.currentSteps > _lastStepCount) {
        state = state.copyWith(activeSeconds: state.activeSeconds + 1);
        _lastStepCount = stepState.currentSteps;
      }
    });
  }

  void pauseTracking() {
    _timer?.cancel();
    state = state.copyWith(isTracking: false);
  }

  void resetTracking() {
    _timer?.cancel();
    state = const ActiveDurationState(activeSeconds: 0, isTracking: false);
  }
}