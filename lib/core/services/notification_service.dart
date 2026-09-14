import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:flutter_timezone/flutter_timezone.dart';

class NotificationService {

  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();
  
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    tz_data.initializeTimeZones();
    
    String timeZoneName = 'America/New_York';
    try {
      final dynamic timeZoneInfo = await FlutterTimezone.getLocalTimezone();
      final String rawString = timeZoneInfo.toString();
      

      if (rawString.contains('TimezoneInfo(')) {
        final int startIndex = rawString.indexOf('TimezoneInfo(') + 'TimezoneInfo('.length;
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

      if (timeZoneName.contains('Karachi') || timeZoneName.contains('Asia/Karachi')) {
        tz.setLocalLocation(tz.getLocation('Asia/Karachi'));
      } else {
        tz.setLocalLocation(tz.getLocation('America/New_York'));
      }
    }

    if (Platform.isAndroid) {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
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

    await _notificationsPlugin.initialize(
      settings: initSettings,
    );

    _isInitialized = true;
  }

  Future<void> scheduleDailyWalkReminder(int hour, int minute) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'daily_walk_channel_id',
      'Daily Walk Reminders',
      channelDescription: 'Reminders for your scheduled daily walks',
      importance: Importance.high,
      priority: Priority.high,
    );
 
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.zonedSchedule(
      id: 0,
      title: 'Time to Walk!',
      body: 'Your scheduled daily walk is coming up. Let us get moving!',
      scheduledDate: _nextInstanceOfTime(hour, minute),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
    tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  Future<void> triggerSedentaryAlert() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'sedentary_channel_id',
      'Stand Alerts',
      channelDescription: 'Hourly alerts to stand and move',
      importance: Importance.high,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      id: 1,
      title: 'Stand & Move',
      body: 'You have been inactive for an hour. Time to stretch your legs!',
      notificationDetails: details,
    );
  }

  Future<void> showGoalReached(int steps) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
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
      id: 2,
      title: 'Goal Reached! 🏆',
      body: 'Incredible work. You hit $steps steps today.',
      notificationDetails: details,
    );
  }

  Future<void> showChallengeCompleted(String title) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'challenge_channel',
      'Challenges',
      channelDescription: 'Notifications for completed challenges',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(),
    );

    await _notificationsPlugin.show(
      id: DateTime.now().millisecond,
      title: 'Challenge Completed! 🌟',
      body: 'Great job! You finished the "$title" challenge.',
      notificationDetails: details,
    );
  }

  Future<void> showChallengeFailed(String title) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'challenge_channel',
      'Challenges',
      channelDescription: 'Notifications for failed or expired challenges',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS:  DarwinNotificationDetails(),
    );

    await _notificationsPlugin.show(
      id: DateTime.now().millisecond,
      title: 'Challenge Expired ⏳',
      body: 'Time ran out for the "$title" challenge. Don\'t worry, you can try again!',
      notificationDetails: details,
    );
  }
}
