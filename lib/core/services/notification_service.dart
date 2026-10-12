import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:flutter_timezone/flutter_timezone.dart';

/// A walk reminder that is set.
class WalkReminder {
  /// The time it fires, or null when an older version of the app set it:
  /// those did not save the time with it.
  final ({int hour, int minute})? time;

  /// The days it fires, as [DateTime.monday] to [DateTime.sunday].
  final Set<int> weekdays;

  const WalkReminder(this.time, this.weekdays);
}

class NotificationService {
  /// Notification IDs. Challenge notifications use [challengeNotificationId],
  /// which stays above these.
  static const int _goalReachedId = 2;

  /// The daily walk reminder of older versions, which fired every day.
  static const int _legacyWalkReminderId = 0;

  /// The walk reminder fires once a week on each chosen day, each with its
  /// own ID: this base plus the weekday (11 for Monday to 17 for Sunday).
  static const int _walkReminderDayIdBase = 10;

  static const Set<int> everyDay = {1, 2, 3, 4, 5, 6, 7};

  static int _walkReminderId(int weekday) => _walkReminderDayIdBase + weekday;

  static List<int> get _allWalkReminderIds => [
    _legacyWalkReminderId,
    for (final day in everyDay) _walkReminderId(day),
  ];

  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Sets up the plugin. The background task passes
  /// [requestPermission] false: it has no screen to ask from.
  Future<void> init({bool requestPermission = true}) async {
    if (_isInitialized) return;

    tz_data.initializeTimeZones();

    String timeZoneName = 'America/New_York';
    try {
      final dynamic timeZoneInfo = await FlutterTimezone.getLocalTimezone();
      final String rawString = timeZoneInfo.toString();

      if (rawString.contains('TimezoneInfo(')) {
        final int startIndex =
            rawString.indexOf('TimezoneInfo(') + 'TimezoneInfo('.length;
        final int endIndex = rawString.indexOf(',', startIndex);
        if (endIndex != -1) {
          timeZoneName = rawString.substring(startIndex, endIndex).trim();
        } else {
          final int closeParen = rawString.indexOf(')', startIndex);
          if (closeParen != -1) {
            timeZoneName = rawString.substring(startIndex, closeParen).trim();
          }
        }
      } else {
        timeZoneName = rawString;
      }
    } catch (_) {
      timeZoneName = 'America/New_York';
    }

    try {
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      if (timeZoneName.contains('Karachi') ||
          timeZoneName.contains('Asia/Karachi')) {
        tz.setLocalLocation(tz.getLocation('Asia/Karachi'));
      } else {
        tz.setLocalLocation(tz.getLocation('America/New_York'));
      }
    }

    if (requestPermission && Platform.isAndroid) {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }

    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _notificationsPlugin.initialize(settings: initSettings);

    _isInitialized = true;
  }

  /// Sets the walk reminder for [hour]:[minute] on [weekdays]
  /// ([DateTime.monday] to [DateTime.sunday]), replacing any set before.
  Future<void> scheduleWalkReminder({
    required int hour,
    required int minute,
    required Set<int> weekdays,
  }) async {
    assert(weekdays.isNotEmpty && weekdays.every(everyDay.contains));
    await cancelWalkReminder();

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'daily_walk_channel_id',
          'Daily Walk Reminders',
          channelDescription: 'Reminders for your scheduled daily walks',
          importance: Importance.high,
          priority: Priority.high,
        );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    for (final weekday in weekdays) {
      await _notificationsPlugin.zonedSchedule(
        id: _walkReminderId(weekday),
        title: 'Time to Walk!',
        body: 'Your scheduled daily walk is coming up. Let us get moving!',
        scheduledDate: _nextInstanceOf(weekday, hour, minute),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        // Lets the scheduler screen read back the time (see walkReminder).
        payload: '$hour:$minute',
      );
    }
  }

  /// Stops the walk reminder on every day, including one set by an older
  /// version.
  Future<void> cancelWalkReminder() async {
    for (final id in _allWalkReminderIds) {
      await _notificationsPlugin.cancel(id: id);
    }
  }

  /// The walk reminder, or null when it is off. Read from Android's pending
  /// alarms, so it survives restarts and sign-out.
  Future<WalkReminder?> walkReminder() async => walkReminderFrom(
    await _notificationsPlugin.pendingNotificationRequests(),
  );

  /// Makes Android's alarms match the reminder the plugin has on record.
  /// Call on app start.
  ///
  /// - On record with a known time: set again, because force-stopping the
  ///   app (or a battery saver) deletes its alarms while the record stays.
  ///   This also moves an older version's daily reminder to the weekly ones.
  /// - Not on record: cancelled, because an alarm the plugin lost track of
  ///   still fires but can't be seen or turned off. Cancelling when none is
  ///   set does nothing.
  Future<void> syncWalkReminder() async {
    final reminder = await walkReminder();
    final time = reminder?.time;
    if (reminder == null) {
      await cancelWalkReminder();
    } else if (time != null) {
      await scheduleWalkReminder(
        hour: time.hour,
        minute: time.minute,
        weekdays: reminder.weekdays,
      );
    }
  }

  /// Finds the walk reminder in [pending].
  static WalkReminder? walkReminderFrom(
    List<PendingNotificationRequest> pending,
  ) {
    final weekdays = <int>{};
    ({int hour, int minute})? time;
    var legacy = false;
    for (final request in pending) {
      final weekday = request.id - _walkReminderDayIdBase;
      if (everyDay.contains(weekday)) {
        weekdays.add(weekday);
      } else if (request.id == _legacyWalkReminderId) {
        legacy = true;
      } else {
        continue;
      }
      time ??= _parseTime(request.payload);
    }
    if (weekdays.isEmpty && !legacy) return null;
    return WalkReminder(time, weekdays.isEmpty ? everyDay : weekdays);
  }

  static ({int hour, int minute})? _parseTime(String? payload) {
    final parts = (payload ?? '').split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return (hour: hour, minute: minute);
  }

  /// The next [weekday] at [hour]:[minute], today included if still ahead.
  tz.TZDateTime _nextInstanceOf(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var date = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    while (date.weekday != weekday || date.isBefore(now)) {
      date = tz.TZDateTime(
        tz.local,
        date.year,
        date.month,
        date.day + 1,
        hour,
        minute,
      );
    }
    return date;
  }

  Future<void> showGoalReached(int steps) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'step_goals',
          'Step Goals',
          channelDescription: 'Alerts when you reach your daily step goal',
          importance: Importance.max,
          priority: Priority.high,
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      id: _goalReachedId,
      title: 'Goal Reached! 🏆',
      body: 'Incredible work. You hit $steps steps today.',
      notificationDetails: details,
    );
  }

  Future<void> showChallengeCompleted(String challengeId, String title) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'challenge_channel',
          'Challenges',
          channelDescription: 'Notifications for completed challenges',
          importance: Importance.high,
          priority: Priority.high,
        );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notificationsPlugin.show(
      id: challengeNotificationId(challengeId),
      title: 'Challenge Completed! 🌟',
      body: 'Great job! You finished the "$title" challenge.',
      notificationDetails: details,
    );
  }

  Future<void> showChallengeFailed(String challengeId, String title) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'challenge_channel',
          'Challenges',
          channelDescription: 'Notifications for failed or expired challenges',
          importance: Importance.high,
          priority: Priority.high,
        );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notificationsPlugin.show(
      id: challengeNotificationId(challengeId),
      title: 'Challenge Expired ⏳',
      body:
          'Time ran out for the "$title" challenge. Don\'t worry, you can try again!',
      notificationDetails: details,
    );
  }

  /// One notification ID per challenge, so notifications for different
  /// challenges never replace each other, while a challenge's later
  /// notification replaces its earlier one. FNV-1a, because String.hashCode
  /// is not guaranteed to be the same between runs.
  static int challengeNotificationId(String challengeId) {
    var hash = 0x811c9dc5;
    for (final unit in challengeId.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    return 1000 + (hash & 0x3fffffff);
  }
}
