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
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
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
        child: const MaterialApp(home: InsightsScreen()),
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
}
