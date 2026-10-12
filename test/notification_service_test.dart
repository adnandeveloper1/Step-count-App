import 'package:build_up/core/services/notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('challengeNotificationId', () {
    test('is the same for a challenge every time', () {
      expect(
        NotificationService.challengeNotificationId('walk_5k'),
        NotificationService.challengeNotificationId('walk_5k'),
      );
    });

    test('differs between challenges', () {
      // Challenge IDs are '1', '2', ... (see challenge_provider.dart).
      final ids = List.generate(
        50,
        (i) => '${i + 1}',
      ).map(NotificationService.challengeNotificationId).toSet();
      expect(ids, hasLength(50));
    });

    test('never uses the walk reminder or goal IDs and fits in 32 bits', () {
      for (final id in ['', 'a', 'challenge_with_a_long_name_1234567890']) {
        final n = NotificationService.challengeNotificationId(id);
        expect(n, greaterThanOrEqualTo(1000));
        expect(n, lessThan(0x7fffffff));
      }
    });
  });

  group('walkReminderFrom', () {
    PendingNotificationRequest request(int id, String? payload) =>
        PendingNotificationRequest(id, 'Time to Walk!', '', payload);

    test('is null when no walk reminder is pending', () {
      expect(NotificationService.walkReminderFrom([]), isNull);
      // The goal (2) and challenge (1000+) notifications are not reminders.
      expect(
        NotificationService.walkReminderFrom([
          request(2, null),
          request(1000, null),
        ]),
        isNull,
      );
    });

    test('reads the chosen days and the time', () {
      // 11 is Monday ... 17 is Sunday.
      final reminder = NotificationService.walkReminderFrom([
        request(11, '20:5'),
        request(13, '20:5'),
        request(15, '20:5'),
      ]);
      expect(reminder, isNotNull);
      expect(reminder!.time, (hour: 20, minute: 5));
      expect(reminder.weekdays, {
        DateTime.monday,
        DateTime.wednesday,
        DateTime.friday,
      });
    });

    test("an older version's daily reminder is every day", () {
      final reminder = NotificationService.walkReminderFrom([
        request(0, '7:30'),
      ]);
      expect(reminder!.time, (hour: 7, minute: 30));
      expect(reminder.weekdays, NotificationService.everyDay);
    });

    test("an older version's reminder without a saved time is on, with no "
        'known time', () {
      for (final payload in [null, '', 'bad']) {
        final reminder = NotificationService.walkReminderFrom([
          request(0, payload),
        ]);
        expect(reminder, isNotNull, reason: 'payload: $payload');
        expect(reminder!.time, isNull);
        expect(reminder.weekdays, NotificationService.everyDay);
      }
    });
  });
}
