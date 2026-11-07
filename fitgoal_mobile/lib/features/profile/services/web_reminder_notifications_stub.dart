Future<bool> requestNotificationPermission() async => false;

Future<void> scheduleDailyNotification({
  required int id,
  required String title,
  required String body,
  required int hour,
  required int minute,
}) async {
  throw UnsupportedError('Browser notifications are not available.');
}

Future<void> cancelNotification(int id) async {}
