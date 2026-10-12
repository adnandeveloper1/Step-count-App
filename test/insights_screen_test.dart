import 'package:build_up/core/services/local_storage_service.dart';
import 'package:build_up/core/utils/number_format.dart';
import 'package:build_up/core/utils/step_history.dart';
import 'package:build_up/features/insight/presentation/insights_screen.dart';
import 'package:build_up/features/step_tracking/presentation/providers/step_provider.dart';
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

class _FakeStepNotifier extends StepNotifier {
  @override
  StepState build() => const StepState(
    currentSteps: 7000,
    goalSteps: 10000,
    calories: 0,
    distanceKm: 0,
    isRestMode: false,
  );
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pumpInsights(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageProvider.overrideWithValue(_FakeStorage()),
          stepNotifierProvider.overrideWith(_FakeStepNotifier.new),
        ],
        child: const MaterialApp(home: InsightsScreen()),
      ),
    );
    await tester.pump();
  }

  String text(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(Key(key))).data!;

  testWidgets('opens on this week with the forward arrow disabled', (
    tester,
  ) async {
    await pumpInsights(tester);

    expect(text(tester, 'insights.weekTitle'), 'THIS WEEK');
    expect(text(tester, 'insights.average'), '7,000');
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

    expect(text(tester, 'insights.weekTitle'), 'LAST WEEK');
    // 6 days at 7,000 and one at 12,000.
    expect(text(tester, 'insights.average'), formatThousands(54000 ~/ 7));
    expect(text(tester, 'insights.goalDays'), 'GOAL MET 1 OF 7 DAYS');
  });

  testWidgets('compares a full week with the week before', (tester) async {
    await pumpInsights(tester);

    await tester.tap(find.byKey(const Key('insights.olderWeek')));
    await tester.pumpAndSettle();

    // Last week averaged 7,714 against 7,000 the week before.
    expect(text(tester, 'insights.trend'), '10% vs prev');
  });

  testWidgets('hides the comparison in the first days of a week', (
    tester,
  ) async {
    await pumpInsights(tester);

    final daysIn = DateTime.now().weekday;
    expect(
      find.byKey(const Key('insights.trend')),
      daysIn < 3 ? findsNothing : findsOneWidget,
    );
  });

  testWidgets('swiping right goes back a week and forward arrow returns', (
    tester,
  ) async {
    await pumpInsights(tester);

    await tester.drag(find.byType(PageView), const Offset(250, 0));
    await tester.pumpAndSettle();
    expect(text(tester, 'insights.weekTitle'), 'LAST WEEK');

    await tester.tap(find.byKey(const Key('insights.newerWeek')));
    await tester.pumpAndSettle();
    expect(text(tester, 'insights.weekTitle'), 'THIS WEEK');
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

    // 31 days always span 5 or 6 calendar weeks.
    expect(
      text(tester, 'insights.weekTitle'),
      anyOf('4 WEEKS AGO', '5 WEEKS AGO'),
    );
  });
}
