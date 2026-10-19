import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../step_tracking/presentation/providers/step_provider.dart';

/// Whether onboarding has been finished on this device.
final onboardingSeenProvider = NotifierProvider<OnboardingSeenNotifier, bool>(
  OnboardingSeenNotifier.new,
);

class OnboardingSeenNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(storageProvider).getOnboardingSeen();

  void complete() {
    ref.read(storageProvider).saveOnboardingSeen(true);
    state = true;
  }
}
