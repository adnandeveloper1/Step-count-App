import 'package:build_up/core/services/local_storage_service.dart';
import 'package:build_up/core/utils/number_format.dart';
import 'package:build_up/core/utils/step_history.dart';
import 'package:build_up/features/insight/presentation/insights_screen.dart';
import 'package:build_up/features/step_tracking/presentation/providers/step_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart' hide StepState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

// Every day of the window walked 7,000 steps, except the same weekday
// last week which hit 12,000.
class _FakeStorage extends LocalStorageService {
  @override
  Map<String, int> getDailyHistory() {
    final now = DateTime.now();
    return {
      for (int i = 0; i < stepHistoryDays; i++)
        dateKey(DateTime(now.year, now.month, now.day - i)): i == 7
            ? 12000
            : 7000,
    };
  }
}

// A new account with no history yet, whose undated weekly array still
// holds another account's numbers.
class _EmptyStorage extends LocalStorageService {
  @override
  Map<String, int> getDailyHistory() => {};
}

class _FakeStepNotifier extends StepNotifier {
  _FakeStepNotifier({this.currentSteps = 7000, this.weeklySteps = const []});

  final int currentSteps;
  final List<int> weeklySteps;

  @override
  StepState build() => StepState(
    currentSteps: currentSteps,
    goalSteps: 10000,
    calories: 0,
    distanceKm: 0,
    isRestMode: false,
    weeklySteps: weeklySteps,
  );
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pumpInsights(
    WidgetTester tester, {
    LocalStorageService? storage,
    _FakeStepNotifier Function()? notifier,
    double width = 1080,
    double textScale = 1,
    bool disableAnimations = false,
  }) async {
    tester.view.physicalSize = Size(width, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageProvider.overrideWithValue(storage ?? _FakeStorage()),
          stepNotifierProvider.overrideWith(
            notifier ?? () => _FakeStepNotifier(),
          ),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: disableAnimations,
            ),
            child: child!,
          ),
          home: const InsightsScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  String text(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(Key(key))).data!;

  testWidgets('opens on the last 7 days with the forward arrow disabled', (
    tester,
  ) async {
    await pumpInsights(tester);

    expect(text(tester, 'insights.weekTitle'), 'LAST 7 DAYS');
    // All 7 days walked 7,000, whatever weekday today is.
    expect(text(tester, 'insights.totalSteps'), formatThousands(7000 * 7));
    final newer = tester.widget<IconButton>(
      find.byKey(const Key('insights.newerWeek')),
    );
    expect(newer.onPressed, isNull);
  });

  // Same formula as the home screen: stride from height, then distance x
  // weight x 1.036. The default profile is 170 cm and 70 kg.
  testWidgets('total burn matches the home screen formula', (tester) async {
    await pumpInsights(tester);

    // 7 days x 7,000 steps = 49,000 steps = 34.4 km = 2,494 kcal.
    expect(text(tester, 'insights.totalBurn'), '2,494');
  });

  testWidgets('back arrow shows last week with its own numbers', (
    tester,
  ) async {
    await pumpInsights(tester);

    await tester.tap(find.byKey(const Key('insights.olderWeek')));
    await tester.pumpAndSettle();

    expect(text(tester, 'insights.weekTitle'), 'PREVIOUS 7 DAYS');
    // 6 days at 7,000 and one at 12,000.
    expect(text(tester, 'insights.totalSteps'), '54,000');
  });

  testWidgets('chart card has no daily average, trend or goal-met chip', (
    tester,
  ) async {
    await pumpInsights(tester);

    expect(find.text('DAILY AVERAGE'), findsNothing);
    expect(find.textContaining('vs prev'), findsNothing);
    expect(find.textContaining('GOAL MET'), findsNothing);
  });

  // The step count shown when a bar is held was drawn above the bar, so the
  // tallest bar's count was cut off at the top of the chart card.
  testWidgets('bar tooltip stays inside the chart', (tester) async {
    await pumpInsights(tester);

    final tooltip = tester
        .widget<BarChart>(find.byType(BarChart).first)
        .data
        .barTouchData
        .touchTooltipData;
    expect(tooltip.fitInsideVertically, isTrue);
    expect(tooltip.fitInsideHorizontally, isTrue);
  });

  testWidgets('swiping right goes back a week and forward arrow returns', (
    tester,
  ) async {
    await pumpInsights(tester);

    await tester.drag(find.byType(PageView), const Offset(250, 0));
    await tester.pumpAndSettle();
    expect(text(tester, 'insights.weekTitle'), 'PREVIOUS 7 DAYS');

    await tester.tap(find.byKey(const Key('insights.newerWeek')));
    await tester.pumpAndSettle();
    expect(text(tester, 'insights.weekTitle'), 'LAST 7 DAYS');
  });

  testWidgets('back arrow stops at the oldest week in the history', (
    tester,
  ) async {
    await pumpInsights(tester);

    for (int i = 0; i < 10; i++) {
      final older = find.byKey(const Key('insights.olderWeek'));
      if (tester.widget<IconButton>(older).onPressed == null) break;
      await tester.tap(older);
      await tester.pumpAndSettle();
    }

    // 31 days fill 5 pages of 7.
    expect(text(tester, 'insights.weekTitle'), '4 WEEKS AGO');
  });

  testWidgets('every bar is drawn at full brightness', (tester) async {
    await pumpInsights(tester);

    final context = tester.element(find.byType(InsightsScreen));
    final primary = Theme.of(context).primaryColor;
    final rods = tester
        .widget<BarChart>(find.byType(BarChart).first)
        .data
        .barGroups
        .expand((group) => group.barRods);
    // 7,000 is under the 10,000 goal, so these used to be dimmed.
    expect(rods.map((rod) => rod.color), everyElement(primary));
  });

  // The weekly array has no dates and is restored from the signed-in
  // account's cloud document, so it once showed another account's steps.
  testWidgets('a new account never shows the old weekly array', (tester) async {
    await pumpInsights(
      tester,
      storage: _EmptyStorage(),
      notifier: () => _FakeStepNotifier(
        currentSteps: 0,
        weeklySteps: const [9000, 9000, 9000, 9000, 9000, 9000, 9000],
      ),
    );

    expect(text(tester, 'insights.totalSteps'), '0');
  });

  group('chart', () {
    BarChartData chart(WidgetTester tester) =>
        tester.widget<BarChart>(find.byType(BarChart).first).data;

    List<int> shownTooltips(WidgetTester tester) => [
      for (final g in chart(tester).barGroups)
        if (g.showingTooltipIndicators.isNotEmpty) g.x,
    ];

    // The chart's first and last bars, by their day label.
    String labelAt(int index) {
      const names = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
      final now = DateTime.now();
      final day = DateTime(now.year, now.month, now.day - 6 + index);
      return names[day.weekday - 1];
    }

    Future<void> tapBar(WidgetTester tester, int index) async {
      final label = tester.getCenter(find.text(labelAt(index)).first);
      await tester.tapAt(label - const Offset(0, 60));
      await tester.pumpAndSettle();
    }

    testWidgets('a tap keeps the step count open', (tester) async {
      await pumpInsights(tester);

      await tapBar(tester, 2);

      expect(chart(tester).barTouchData.handleBuiltInTouches, isFalse);
      expect(shownTooltips(tester), [2]);
    });

    testWidgets('tapping the same bar again closes it', (tester) async {
      await pumpInsights(tester);

      await tapBar(tester, 2);
      await tapBar(tester, 2);

      expect(shownTooltips(tester), isEmpty);
    });

    testWidgets('tapping another bar moves it', (tester) async {
      await pumpInsights(tester);

      await tapBar(tester, 2);
      await tapBar(tester, 4);

      expect(shownTooltips(tester), [4]);
    });

    testWidgets('a short bar can be tapped anywhere on its track', (
      tester,
    ) async {
      await pumpInsights(tester);

      expect(chart(tester).barTouchData.allowTouchBarBackDraw, isTrue);
    });

    testWidgets('changing week closes the open count', (tester) async {
      await pumpInsights(tester);
      await tapBar(tester, 2);

      await tester.tap(find.byKey(const Key('insights.olderWeek')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('insights.newerWeek')));
      await tester.pumpAndSettle();

      expect(shownTooltips(tester), isEmpty);
    });

    testWidgets('the count names the day', (tester) async {
      await pumpInsights(tester);

      final data = chart(tester);
      final group = data.barGroups[6];
      final item = data.barTouchData.touchTooltipData.getTooltipItem(
        group,
        6,
        group.barRods.single,
        0,
      )!;
      final text = item.text + item.children!.map((s) => s.text).join();
      expect(text, contains('Today'));
      expect(text, contains('7,000 steps'));

      final monday = data.barGroups[0];
      final first = data.barTouchData.touchTooltipData.getTooltipItem(
        monday,
        0,
        monday.barRods.single,
        0,
      )!;
      const full = {
        'MON': 'Monday',
        'TUE': 'Tuesday',
        'WED': 'Wednesday',
        'THU': 'Thursday',
        'FRI': 'Friday',
        'SAT': 'Saturday',
        'SUN': 'Sunday',
      };
      expect(first.text, contains(full[labelAt(0)]!));
    });

    testWidgets('screen readers hear every day of the week', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpInsights(tester);

      final label = tester
          .getSemantics(find.byKey(const Key('insights.chart')))
          .label;
      expect(label, contains('Steps for'));
      expect(label, contains('Today, 7,000 steps'));
      expect(label.split('steps').length - 1, greaterThanOrEqualTo(7));
      handle.dispose();
    });

    testWidgets('reduced motion stops the bar and week animations', (
      tester,
    ) async {
      await pumpInsights(tester, disableAnimations: true);

      final bar = tester.widget<BarChart>(find.byType(BarChart).first);
      expect(bar.duration, Duration.zero);

      await tester.tap(find.byKey(const Key('insights.olderWeek')));
      await tester.pump();
      expect(text(tester, 'insights.weekTitle'), 'PREVIOUS 7 DAYS');
    });

    for (final (width, scale) in [(832.0, 1.0), (1080.0, 2.0), (832.0, 2.0)]) {
      testWidgets(
        'day labels fit at ${(width / 2.6).round()}dp, text x$scale',
        (tester) async {
          await pumpInsights(tester, width: width, textScale: scale);

          expect(tester.takeException(), isNull);
          final chartRect = tester.getRect(find.byType(BarChart).first);
          for (int i = 0; i < 7; i++) {
            final rect = tester.getRect(find.text(labelAt(i)).first);
            expect(
              rect.bottom,
              lessThanOrEqualTo(chartRect.bottom + 0.5),
              reason: '${labelAt(i)} cut off',
            );
          }
        },
      );
    }

    testWidgets('bars keep a round top on a narrow phone', (tester) async {
      await pumpInsights(tester, width: 832);

      for (final rod in chart(tester).barGroups.map((g) => g.barRods.single)) {
        expect(rod.borderRadius!.topLeft.x, lessThanOrEqualTo(rod.width / 2));
      }
    });
  });
}
