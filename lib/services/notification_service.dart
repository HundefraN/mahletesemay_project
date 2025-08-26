import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();
  static Function(String?)? onNotificationTap;

  static const DarwinNotificationDetails _reminderIOSDetails =
  DarwinNotificationDetails(
    sound: 'reminder_sound.mp3',
  );

  static NotificationDetails _createBigPictureDetails({
    required String title,
    required String body,
  }) {
    final BigPictureStyleInformation bigPictureStyleInformation =
    BigPictureStyleInformation(
      const DrawableResourceAndroidBitmap('notification_banner'),
      largeIcon: const DrawableResourceAndroidBitmap('ic_launcher'),
      contentTitle: '<b>$title</b>',
      htmlFormatContentTitle: true,
      summaryText: body,
      htmlFormatSummaryText: true,
    );

    return NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_reminder_channel_id',
        'Daily Vocal Reminders',
        styleInformation: bigPictureStyleInformation,
        importance: Importance.max,
        priority: Priority.high,
        sound: const RawResourceAndroidNotificationSound('reminder_sound'),
        playSound: true,
        largeIcon: const DrawableResourceAndroidBitmap('ic_launcher'),
      ),
      iOS: _reminderIOSDetails,
    );
  }

  static Future<void> initialize({Function(String?)? onSelectNotification}) async {
    onNotificationTap = onSelectNotification;
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('notification_icon');

    const DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
    InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    try {
      tz.initializeTimeZones();
    } catch (e) {
      debugPrint('Could not initialize timezones: $e');
    }

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
    );
  }

  static void _onDidReceiveNotificationResponse(NotificationResponse response) {
    if (onNotificationTap != null) {
      onNotificationTap!(response.payload);
    }
  }

  static Future<void> showTestNotification() async {
    await _notificationsPlugin.show(
      999,
      "Test Notification",
      "Expand to see the custom design.",
      _createBigPictureDetails(
        title: "Test Notification",
        body: "If you see the banner and logo, it is working!",
      ),
      payload: 'vocal_exercises',
    );
  }

  static Future<void> scheduleStyledDailyReminder({
    required int id,
    required String title,
    required String body,
  }) async {
    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      _nextInstanceOfTenAM(),
      _createBigPictureDetails(title: title, body: body),
      payload: 'vocal_exercises',
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> scheduleContinuationReminder({
    required int id,
    required String title,
    required String body,
    required Duration delay,
  }) async {
    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.now(tz.local).add(delay),
      _createBigPictureDetails(title: title, body: body),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'vocal_exercises',
    );
  }

  static tz.TZDateTime _nextInstanceOfTenAM() {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
    tz.TZDateTime(tz.local, now.year, now.month, now.day, 10);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  static Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }
}