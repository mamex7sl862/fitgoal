import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

final Map<int, Timer> _scheduledNotifications = {};

Future<bool> requestNotificationPermission() async {
  var permission = web.Notification.permission;
  if (permission == 'default') {
    permission = (await web.Notification.requestPermission().toDart).toDart;
  }
  return permission == 'granted';
}

Future<void> scheduleDailyNotification({
  required int id,
  required String title,
  required String body,
  required int hour,
  required int minute,
}) async {
  if (web.Notification.permission != 'granted') {
    throw StateError('Allow browser notifications for FitGoal first.');
  }

  await cancelNotification(id);
  final now = DateTime.now();
  var nextReminder = DateTime(now.year, now.month, now.day, hour, minute);
  if (!nextReminder.isAfter(now)) {
    nextReminder = nextReminder.add(const Duration(days: 1));
  }

  _scheduledNotifications[id] = Timer(nextReminder.difference(now), () {
    web.Notification(title, web.NotificationOptions(body: body));
    _scheduledNotifications[id] = Timer.periodic(
      const Duration(days: 1),
      (_) => web.Notification(title, web.NotificationOptions(body: body)),
    );
  });
}

Future<void> cancelNotification(int id) async {
  _scheduledNotifications.remove(id)?.cancel();
}
