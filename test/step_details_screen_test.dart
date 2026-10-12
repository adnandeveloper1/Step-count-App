import 'package:build_up/features/step_tracking/presentation/providers/step_provider.dart';
import 'package:build_up/features/step_tracking/presentation/screens/step_details_screen.dart';
import 'package:flutter/material.dart' hide StepState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class _FixedStepNotifier extends StepNotifier {
  final StepState fixed;

  _FixedStepNotifier(this.fixed);

  @override
  StepState build() => fixed;
}

Future<void> _pumpDetails(WidgetTester tester, {required int drivingSteps}) {
  // Pixel 7a screen; the default 800x600 test view is not a phone.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);

  final state = StepState(
    currentSteps: 4200,
    goalSteps: 10000,
    calories: 0,
    distanceKm: 0,
    isRestMode: false,
    drivingSteps: drivingSteps,
  );
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        stepNotifierProvider.overrideWith(() => _FixedStepNotifier(state)),
      ],
      child: const MaterialApp(home: StepDetailsScreen()),
    ),
  );
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  const drivingKey = Key('step_details_driving_steps');

  testWidgets('shows the steps removed while driving today', (tester) async {
    await _pumpDetails(tester, drivingSteps: 312);

    expect(find.byKey(drivingKey), findsOneWidget);
    expect(find.textContaining('312 steps removed while driving'), findsOne);
  });

  testWidgets('shows nothing when no driving steps were removed', (
    tester,
  ) async {
    await _pumpDetails(tester, drivingSteps: 0);

    expect(find.byKey(drivingKey), findsNothing);
  });

  testWidgets('shows nothing for an earlier day', (tester) async {
    await _pumpDetails(tester, drivingSteps: 312);

    // The oldest day in the week selector.
    final days = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(GestureDetector),
    );
    await tester.tap(days.first);
    await tester.pump();

    expect(find.byKey(drivingKey), findsNothing);
  });
}
