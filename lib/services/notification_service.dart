import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../utils/constants.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static Function(String?)? onNotificationTap;

  static const String _largeIconResource = 'notification_logo_white';
  static const String _notificationIconResource = 'notification_logo_white';
  static const String _bannerImageResource = 'notification_banner';
  static const String _soundResource = 'reminder_sound';

  static const AndroidNotificationChannel _reminderChannel =
      AndroidNotificationChannel(
    'daily_reminder_channel_id',
    'Daily Vocal Reminders',
    description: 'Channel for daily vocal workout reminders.',
    importance: Importance.max,
    sound: RawResourceAndroidNotificationSound(_soundResource),
    playSound: true,
  );

  static const AndroidNotificationChannel _serviceChannel =
      AndroidNotificationChannel(
    'service_reminder_channel_id',
    'Service Reminders',
    description: 'High-priority channel for upcoming service reminders.',
    importance: Importance.max,
    sound: RawResourceAndroidNotificationSound(_soundResource),
    playSound: true,
  );

  static const DarwinNotificationDetails _reminderIOSDetails =
      DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
    sound: '$_soundResource.mp3',
  );

  static NotificationDetails _createBigPictureDetails({
    required String title,
    required String body,
    bool isServiceReminder = false,
  }) {
    final BigPictureStyleInformation bigPictureStyleInformation =
        BigPictureStyleInformation(
      const DrawableResourceAndroidBitmap(_bannerImageResource),
      largeIcon: const DrawableResourceAndroidBitmap(_largeIconResource),
      contentTitle: '<b>$title</b>',
      htmlFormatContentTitle: true,
      summaryText: body,
      htmlFormatSummaryText: true,
    );

    return NotificationDetails(
      android: AndroidNotificationDetails(
        isServiceReminder ? _serviceChannel.id : _reminderChannel.id,
        isServiceReminder ? _serviceChannel.name : _reminderChannel.name,
        channelDescription: isServiceReminder
            ? _serviceChannel.description
            : _reminderChannel.description,
        styleInformation: bigPictureStyleInformation,
        importance: Importance.max,
        priority: Priority.high,
        sound:
            isServiceReminder ? _serviceChannel.sound : _reminderChannel.sound,
        playSound: true,
        largeIcon: const DrawableResourceAndroidBitmap(_largeIconResource),
        fullScreenIntent: isServiceReminder,
      ),
      iOS: _reminderIOSDetails,
    );
  }

  static Future<void> initialize(
      {Function(String?)? onSelectNotification}) async {
    onNotificationTap = onSelectNotification;
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings(_notificationIconResource);

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
      tz_data.initializeTimeZones();
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      debugPrint('Could not initialize timezones: $e');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
    );

    final androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(_reminderChannel);
      await androidImplementation.createNotificationChannel(_serviceChannel);
    }

    final iosImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (iosImplementation != null) {
      await iosImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
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
      payload: notificationPayloadVocalExercises,
    );
  }

  static Future<void> showNewContentNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    final int id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _notificationsPlugin.show(
      id,
      title,
      body,
      _createBigPictureDetails(
        title: title,
        body: body,
      ),
      payload: payload,
    );
  }

  static Future<void> _safeZonedSchedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        notificationDetails,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: matchDateTimeComponents,
      );
    } catch (e) {
      debugPrint(
          'exactAllowWhileIdle failed, falling back to inexactAllowWhileIdle: $e');
      try {
        await _notificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          notificationDetails,
          payload: payload,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: matchDateTimeComponents,
        );
      } catch (e2) {
        debugPrint('zonedSchedule fallback failed: $e2');
      }
    }
  }

  static Future<void> scheduleStyledDailyReminder({
    required int id,
    required String title,
    required String body,
  }) async {
    await _safeZonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: _nextInstanceOfTenAM(),
      notificationDetails: _createBigPictureDetails(title: title, body: body),
      payload: notificationPayloadVocalExercises,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> scheduleFullScreenReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    await _safeZonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
      notificationDetails: _createBigPictureDetails(
          title: title, body: body, isServiceReminder: true),
    );
  }

  static Future<void> scheduleContinuationReminder({
    required int id,
    required String title,
    required String body,
    required Duration delay,
  }) async {
    await _safeZonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.now(tz.local).add(delay),
      notificationDetails: _createBigPictureDetails(title: title, body: body),
      payload: notificationPayloadVocalExercises,
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

  static Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }
}
