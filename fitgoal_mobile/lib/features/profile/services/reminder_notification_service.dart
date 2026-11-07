import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import 'web_reminder_notifications_stub.dart'
    if (dart.library.html) 'web_reminder_notifications_web.dart'
    as web_reminders;

class ReminderNotificationService {
  ReminderNotificationService._();

  static final ReminderNotificationService instance =
      ReminderNotificationService._();

  static const workoutNotificationId = 1001;
  static const waterNotificationId = 1002;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  Future<void>? _initialization;

  Future<void> initialize() {
    if (kIsWeb) return Future<void>.value();
    return _initialization ??= _initialize();
  }

  Future<void> _initialize() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );

    timezone_data.initializeTimeZones();
    final localTimezone = await FlutterTimezone.getLocalTimezone();
    timezone.setLocalLocation(timezone.getLocation(localTimezone.identifier));
  }

  Future<bool> requestPermission() async {
    if (kIsWeb) return web_reminders.requestNotificationPermission();
    await initialize();

    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }

    if (defaultTargetPlatform == TargetPlatform.macOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                MacOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }

    return true;
  }

  Future<void> scheduleWorkoutReminder({
    required int hour,
    required int minute,
  }) {
    return _scheduleDaily(
      id: workoutNotificationId,
      title: 'Workout reminder',
      body: 'It is time to work toward your fitness goal.',
      hour: hour,
      minute: minute,
    );
  }

  Future<void> scheduleWaterReminder({required int hour, required int minute}) {
    return _scheduleDaily(
      id: waterNotificationId,
      title: 'Water reminder',
      body: 'Take a moment to drink some water.',
      hour: hour,
      minute: minute,
    );
  }

  Future<void> cancelWorkoutReminder() async {
    if (kIsWeb) {
      await web_reminders.cancelNotification(workoutNotificationId);
      return;
    }
    await _plugin.cancel(id: workoutNotificationId);
  }

  Future<void> cancelWaterReminder() async {
    if (kIsWeb) {
      await web_reminders.cancelNotification(waterNotificationId);
      return;
    }
    await _plugin.cancel(id: waterNotificationId);
  }

  Future<void> _scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    if (kIsWeb) {
      await web_reminders.scheduleDailyNotification(
        id: id,
        title: title,
        body: body,
        hour: hour,
        minute: minute,
      );
      return;
    }
    await initialize();

    final now = timezone.TZDateTime.now(timezone.local);
    var scheduledDate = timezone.TZDateTime(
      timezone.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduledDate.isAfter(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'fitgoal_reminders',
          'FitGoal reminders',
          channelDescription: 'Daily workout and water reminders',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
