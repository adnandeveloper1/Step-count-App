import 'package:build_up/features/step_tracking/presentation/widgets/step_gauge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  group('StepGaugePainter.sweeps', () {
    test('empty or invalid progress draws nothing', () {
      expect(StepGaugePainter.sweeps(0), (base: 0.0, overflow: 0.0));
      expect(StepGaugePainter.sweeps(-1), (base: 0.0, overflow: 0.0));
      expect(StepGaugePainter.sweeps(double.nan), (base: 0.0, overflow: 0.0));
    });

    test('below the goal only the base lap moves', () {
      expect(StepGaugePainter.sweeps(0.4), (base: 0.4, overflow: 0.0));
      expect(StepGaugePainter.sweeps(1), (base: 1.0, overflow: 0.0));
    });

    test('past the goal the overflow lap shows the extra', () {
      final s = StepGaugePainter.sweeps(1.25);
      expect(s.base, 1.0);
      expect(s.overflow, closeTo(0.25, 1e-9));
    });

    test('third lap restarts the overflow arc', () {
      final s = StepGaugePainter.sweeps(2.5);
      expect(s.base, 1.0);
      expect(s.overflow, closeTo(0.5, 1e-9));
    });

    test('exact multiple of the goal shows a full overflow lap', () {
      expect(StepGaugePainter.sweeps(2), (base: 1.0, overflow: 1.0));
      expect(StepGaugePainter.sweeps(3), (base: 1.0, overflow: 1.0));
    });
  });

  group('StepGauge.overflowColor', () {
    test('differs from the primary colour in both brightnesses', () {
      const primary = Color(0xFF22C55E);
      expect(StepGauge.overflowColor(primary, isDark: true), isNot(primary));
      expect(StepGauge.overflowColor(primary, isDark: false), isNot(primary));
    });
  });

  group('StepGauge widget', () {
    setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

    Widget host(int steps, {bool disableAnimations = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Scaffold(
          body: Center(child: StepGauge(steps: steps, goal: 10000, size: 240)),
        ),
      ),
    );

    StepGaugePainter painter(WidgetTester tester) =>
        tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: find.byType(StepGauge),
                    matching: find.byType(CustomPaint),
                  ),
                )
                .painter!
            as StepGaugePainter;

    // Fonts can't be fetched in tests; ignore that error only.
    void ignoreFontErrors(WidgetTester tester) {
      final e = tester.takeException();
      if (e != null && !'$e'.contains('GoogleFonts')) throw e;
    }

    testWidgets('counts up from zero and lands on the value', (tester) async {
      await tester.pumpWidget(host(5000));
      expect(painter(tester).progress, 0);

      await tester.pump(const Duration(milliseconds: 300));
      final mid = painter(tester).progress;
      expect(mid, greaterThan(0));
      expect(mid, lessThan(0.5));

      await tester.pumpAndSettle();
      expect(painter(tester).progress, 0.5);
      expect(find.text('5000'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('dashboard_step_count'))).data,
        '5000',
      );
      expect(find.text('/ 10000 STEPS'), findsOneWidget);
      ignoreFontErrors(tester);
    });

    testWidgets('animates from the old value, not from zero', (tester) async {
      await tester.pumpWidget(host(5000));
      await tester.pumpAndSettle();

      await tester.pumpWidget(host(15000));
      await tester.pump(const Duration(milliseconds: 1));
      expect(painter(tester).progress, greaterThanOrEqualTo(0.5));

      await tester.pumpAndSettle();
      expect(painter(tester).progress, 1.5);
      expect(find.text('15000'), findsOneWidget);
      ignoreFontErrors(tester);
    });

    testWidgets('jumps straight to the value when animations are off', (
      tester,
    ) async {
      await tester.pumpWidget(host(7000, disableAnimations: true));
      await tester.pump();
      expect(painter(tester).progress, 0.7);
      expect(find.text('7000'), findsOneWidget);
      ignoreFontErrors(tester);
    });

    testWidgets('zero goal shows an empty ring', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: StepGauge(steps: 500, goal: 0, size: 240)),
      );
      await tester.pumpAndSettle();
      expect(painter(tester).progress, 0);
      ignoreFontErrors(tester);
    });
  });
}
