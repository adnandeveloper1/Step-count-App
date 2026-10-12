import 'package:build_up/core/notification_provider/notification_provider.dart';
import 'package:build_up/core/services/notification_service.dart';
import 'package:build_up/features/settings/presentation/scheduler_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Records reminder changes instead of scheduling alarms.
class FakeNotificationService implements NotificationService {
  FakeNotificationService(this.reminder);

  WalkReminder? reminder;
  final List<String> calls = [];

  @override
  Future<WalkReminder?> walkReminder() async => reminder;

  @override
  Future<void> scheduleWalkReminder({
    required int hour,
    required int minute,
    required Set<int> weekdays,
  }) async {
    final days = weekdays.toList()..sort();
    calls.add('schedule $hour:$minute $days');
    reminder = WalkReminder((hour: hour, minute: minute), weekdays);
  }

  @override
  Future<void> cancelWalkReminder() async {
    calls.add('cancel');
    reminder = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<FakeNotificationService> pumpScreen(
    WidgetTester tester,
    WalkReminder? reminder,
  ) async {
    final fake = FakeNotificationService(reminder);
    // A phone-sized screen (Pixel 7a), so the whole page is on screen.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [notificationServiceProvider.overrideWithValue(fake)],
        child: const MaterialApp(home: WalkSchedulerScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return fake;
  }

  bool switchValue(WidgetTester tester) => tester
      .widget<Switch>(find.byKey(const Key('walk_reminder_switch')))
      .value;

  testWidgets('shows the saved reminder: on, its time and its days', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      const WalkReminder((hour: 9, minute: 30), {1, 3, 5}),
    );

    expect(switchValue(tester), isTrue);
    expect(find.text('9:30 AM'), findsOneWidget);
    expect(find.text('Mon, Wed, Fri'), findsOneWidget);
  });

  testWidgets('is off with no reminder, and turning it on schedules it', (
    tester,
  ) async {
    final fake = await pumpScreen(tester, null);
    expect(switchValue(tester), isFalse);
    expect(find.text('Off'), findsOneWidget);

    await tester.tap(find.byKey(const Key('walk_reminder_switch')));
    await tester.pumpAndSettle();

    expect(fake.calls, ['schedule 8:0 [1, 2, 3, 4, 5, 6, 7]']);
    expect(find.textContaining('Next:'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('changing days while on reschedules with the new days', (
    tester,
  ) async {
    final fake = await pumpScreen(
      tester,
      WalkReminder((hour: 7, minute: 0), NotificationService.everyDay),
    );

    await tester.tap(find.byKey(const Key('walk_reminder_day_7')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weekends'));
    await tester.pumpAndSettle();

    expect(fake.calls, [
      'schedule 7:0 [1, 2, 3, 4, 5, 6]',
      'schedule 7:0 [6, 7]',
    ]);
  });

  testWidgets('changing days while off schedules nothing', (tester) async {
    final fake = await pumpScreen(tester, null);

    await tester.tap(find.text('Weekdays'));
    await tester.pumpAndSettle();

    expect(fake.calls, isEmpty);
    // A preset choice is shown by its chip, not repeated as a summary.
    expect(find.text('Weekdays'), findsOneWidget);
    expect(find.text('Mon, Tue, Wed, Thu, Fri'), findsNothing);
  });

  testWidgets('the last selected day cannot be removed', (tester) async {
    final fake = await pumpScreen(
      tester,
      const WalkReminder((hour: 7, minute: 0), {3}),
    );

    await tester.tap(find.byKey(const Key('walk_reminder_day_3')));
    await tester.pumpAndSettle();

    expect(fake.calls, isEmpty);
    expect(find.text('Wed'), findsOneWidget);
  });

  testWidgets('turning it off cancels the reminder', (tester) async {
    final fake = await pumpScreen(
      tester,
      WalkReminder((hour: 7, minute: 0), NotificationService.everyDay),
    );

    await tester.tap(find.byKey(const Key('walk_reminder_switch')));
    await tester.pumpAndSettle();

    expect(fake.calls, ['cancel']);
    expect(switchValue(tester), isFalse);
  });

  testWidgets('an older reminder with no saved time is not rescheduled at a '
      'made-up time when days change', (tester) async {
    final fake = await pumpScreen(
      tester,
      WalkReminder(null, NotificationService.everyDay),
    );
    expect(find.text('--:--'), findsOneWidget);
    expect(switchValue(tester), isTrue);

    await tester.tap(find.text('Weekdays'));
    await tester.pumpAndSettle();

    expect(fake.calls, isEmpty);
  });
}
