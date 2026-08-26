import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// The kinds of notification this app can raise. The [wireName] is what gets
/// embedded in the notification payload, so it must stay stable across releases
/// or already-scheduled notifications will stop routing correctly.
enum NotificationKind {
  dailyPractice('vocal_exercises'),
  serviceReminder('service_reminder'),
  practiceContinuation('practice_continuation'),
  newContent('new_content'),
  test('test');

  const NotificationKind(this.wireName);

  final String wireName;

  static NotificationKind? fromWireName(String? name) {
    if (name == null) return null;
    for (final kind in NotificationKind.values) {
      if (kind.wireName == name) return kind;
    }
    return null;
  }
}

/// A decoded notification payload. [reference] carries the id of the domain
/// object the notification was raised for (a service reminder id, a song id…).
@immutable
class NotificationPayload {
  const NotificationPayload(this.kind, {this.reference});

  final NotificationKind kind;
  final String? reference;

  String encode() => jsonEncode({
        'k': kind.wireName,
        if (reference != null) 'r': reference,
      });

  /// Tolerates the bare-string payloads written by older versions of the app,
  /// which may still be sitting in the system's scheduled-notification queue.
  static NotificationPayload? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final kind = NotificationKind.fromWireName(decoded['k'] as String?);
        if (kind == null) return null;
        return NotificationPayload(kind, reference: decoded['r'] as String?);
      }
    } on FormatException {
      // Fall through to the legacy plain-string format.
    }

    final legacyKind = NotificationKind.fromWireName(raw);
    return legacyKind == null ? null : NotificationPayload(legacyKind);
  }
}

/// Describes what the OS currently lets the app do, so the UI can explain the
/// real state to the user instead of silently dropping reminders.
@immutable
class NotificationPermissionStatus {
  const NotificationPermissionStatus({
    required this.notificationsEnabled,
    required this.canScheduleExactAlarms,
  });

  final bool notificationsEnabled;

  /// When false, scheduled reminders still fire but the OS may delay them to
  /// batch them with other wakeups.
  final bool canScheduleExactAlarms;

  bool get isFullyEnabled => notificationsEnabled && canScheduleExactAlarms;
}

/// Central entry point for every notification the app raises.
///
/// All scheduling funnels through [_schedule] so that timezone handling,
/// permission checks and the exact-alarm fallback are applied consistently.
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // Android resources. These names must match files under android/app/src/main/res.
  static const String _smallIcon = 'ic_notification';
  static const String _largeIcon = 'notification_large_icon';

  /// Channels are versioned because Android freezes a channel's importance and
  /// sound at creation time; bumping the suffix is the only way to push
  /// corrected settings to users who already have the app installed.
  static const String _channelVersion = 'v3';

  static const AndroidNotificationChannel _dailyChannel =
      AndroidNotificationChannel(
    'daily_practice_$_channelVersion',
    'Daily Practice Reminders',
    description: 'Your daily nudge to run through your vocal workout.',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  /// Distinctive double-buzz vibration so users recognise service alerts by
  /// feel alone, even in a noisy environment.
  static const List<int> _serviceVibrationPattern = <int>[
    0, 400, 200, 400, 200, 800,
  ];

  static final AndroidNotificationChannel _serviceChannel =
      AndroidNotificationChannel(
    'service_reminders_$_channelVersion',
    'Service Reminders',
    description: 'Countdown alerts for your upcoming worship services.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    vibrationPattern: Int64List.fromList(_serviceVibrationPattern),
  );

  static const AndroidNotificationChannel _practiceChannel =
      AndroidNotificationChannel(
    'practice_continuation_$_channelVersion',
    'Practice Follow-ups',
    description: 'Reminders to finish a vocal plan you started.',
    importance: Importance.defaultImportance,
    playSound: true,
  );

  static const AndroidNotificationChannel _contentChannel =
      AndroidNotificationChannel(
    'content_updates_$_channelVersion',
    'New Songs & Content',
    description: 'Alerts when new songs and lessons are added to the library.',
    importance: Importance.defaultImportance,
    playSound: true,
  );

  /// Channels shipped by earlier builds.
  static const List<String> _retiredChannelIds = <String>[
    'daily_reminder_channel_id',
    'service_reminder_channel_id',
    'daily_practice_v2',
    'service_reminders_v2',
    'practice_continuation_v2',
    'content_updates_v2',
  ];

  // Reserved id ranges keep the different notification kinds from evicting
  // each other, since posting a notification reuses any id already in flight.
  static const int dailyPracticeId = 100;
  static const int practiceContinuationId = 200;
  static const int testId = 999;
  static const int _serviceIdBase = 1000000;
  static const int _contentIdBase = 2000000;
  static const int _contentIdSpan = 1000;

  static bool _initialized = false;
  static void Function(NotificationPayload payload)? _tapHandler;

  /// Holds a tap that arrived before the UI could handle it, which is the
  /// normal case when a notification cold-starts the app.
  static NotificationPayload? _pendingTap;

  /// Deterministic id for the [dayOffset]-th countdown alert of a service
  /// reminder. Stable across launches so the alerts can be cancelled later.
  static int serviceNotificationId(String reminderId, int dayOffset) =>
      _serviceIdBase +
      ((reminderId.hashCode & 0x7FFFFFFF) % 100000) * 10 +
      dayOffset;

  static Future<void> initialize() async {
    if (_initialized) return;

    await _configureTimezone();

    const InitializationSettings settings = InitializationSettings(
      android: AndroidInitializationSettings(_smallIcon),
      iOS: DarwinInitializationSettings(
        // Permissions are requested explicitly later so the app can show its
        // own rationale first rather than prompting on a cold start.
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _dispatchTap(NotificationPayload.decode(response.payload));
      },
    );

    await _createChannels();
    await _captureLaunchPayload();

    _initialized = true;
  }

  static Future<void> _configureTimezone() async {
    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone()));
    } catch (error) {
      debugPrint('NotificationService: falling back to UTC ($error)');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }

  static Future<void> _createChannels() async {
    final android = _androidPlugin;
    if (android == null) return;

    await Future.wait([
      ..._retiredChannelIds.map((id) => android.deleteNotificationChannel(id)),
      ...[
        _dailyChannel,
        _serviceChannel,
        _practiceChannel,
        _contentChannel,
      ].map((channel) => android.createNotificationChannel(channel)),
    ]);
  }

  /// Picks up a notification tap that launched the app from a terminated state.
  /// The plugin's response callback does not fire for this case.
  static Future<void> _captureLaunchPayload() async {
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp ?? false) {
        _pendingTap =
            NotificationPayload.decode(details!.notificationResponse?.payload);
      }
    } catch (error) {
      debugPrint('NotificationService: could not read launch details ($error)');
    }
  }

  /// Registers the handler used to route notification taps. Any tap captured
  /// before this point (for example a cold start) is delivered immediately.
  static void setTapHandler(void Function(NotificationPayload payload) handler) {
    _tapHandler = handler;
    final pending = _pendingTap;
    if (pending != null) {
      _pendingTap = null;
      handler(pending);
    }
  }

  static void _dispatchTap(NotificationPayload? payload) {
    if (payload == null) return;
    final handler = _tapHandler;
    if (handler == null) {
      _pendingTap = payload;
      return;
    }
    handler(payload);
  }

  static AndroidFlutterLocalNotificationsPlugin? get _androidPlugin =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  static IOSFlutterLocalNotificationsPlugin? get _iosPlugin =>
      _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();

  /// Prompts for notification access. Returns whether notifications may be
  /// posted afterwards.
  static Future<bool> requestPermission() async {
    if (Platform.isIOS) {
      final granted = await _iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    final granted = await _androidPlugin?.requestNotificationsPermission();
    // Older Android versions have no runtime notification permission and
    // return null, in which case notifications are already allowed.
    return granted ?? await areNotificationsEnabled();
  }

  /// Opens the system screen where the user can allow exact alarms. Only
  /// meaningful on Android 12+; elsewhere this is a no-op.
  static Future<void> requestExactAlarmPermission() async {
    if (!Platform.isAndroid) return;
    try {
      await _androidPlugin?.requestExactAlarmsPermission();
    } catch (error) {
      debugPrint('NotificationService: exact alarm request failed ($error)');
    }
  }

  static Future<bool> areNotificationsEnabled() async {
    try {
      if (Platform.isAndroid) {
        return await _androidPlugin?.areNotificationsEnabled() ?? true;
      }
      final options = await _iosPlugin?.checkPermissions();
      return options?.isEnabled ?? false;
    } catch (error) {
      debugPrint('NotificationService: permission check failed ($error)');
      return false;
    }
  }

  static Future<bool> canScheduleExactAlarms() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _androidPlugin?.canScheduleExactNotifications() ?? true;
    } catch (error) {
      debugPrint('NotificationService: exact alarm check failed ($error)');
      return false;
    }
  }

  static Future<NotificationPermissionStatus> permissionStatus() async =>
      NotificationPermissionStatus(
        notificationsEnabled: await areNotificationsEnabled(),
        canScheduleExactAlarms: await canScheduleExactAlarms(),
      );

  static NotificationDetails _details({
    required AndroidNotificationChannel channel,
    required String title,
    required String body,
    bool isAlarm = false,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: channel.importance,
        priority: channel.importance == Importance.max
            ? Priority.max
            : Priority.defaultPriority,
        color: const Color(0xFF1E88E5),
        // Expands long reminder text instead of truncating it to one line.
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          summaryText: channel.name,
        ),
        largeIcon: const DrawableResourceAndroidBitmap(_largeIcon),
        category: isAlarm
            ? AndroidNotificationCategory.alarm
            : AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.public,
        playSound: channel.playSound,
        enableVibration: channel.enableVibration,
        vibrationPattern: channel == _serviceChannel
            ? Int64List.fromList(_serviceVibrationPattern)
            : null,
        ticker: title,
        // Full-screen intent wakes the device and shows an alarm-style overlay
        // on the lock screen for critical alerts (morning-of & starting-soon).
        fullScreenIntent: isAlarm,
        ongoing: isAlarm,
        autoCancel: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: isAlarm
            ? InterruptionLevel.critical
            : (channel.importance == Importance.max
                ? InterruptionLevel.timeSensitive
                : InterruptionLevel.active),
      ),
    );
  }

  static Future<void> _show({
    required int id,
    required AndroidNotificationChannel channel,
    required String title,
    required String body,
    required NotificationPayload payload,
  }) async {
    if (!await areNotificationsEnabled()) return;
    try {
      await _plugin.show(
        id,
        title,
        body,
        _details(channel: channel, title: title, body: body),
        payload: payload.encode(),
      );
    } catch (error) {
      debugPrint('NotificationService: show($id) failed ($error)');
    }
  }

  /// Schedules a notification, degrading to an inexact alarm when the OS will
  /// not grant exact ones rather than dropping the reminder entirely.
  static Future<bool> _schedule({
    required int id,
    required AndroidNotificationChannel channel,
    required String title,
    required String body,
    required tz.TZDateTime when,
    required NotificationPayload payload,
    DateTimeComponents? repeatOn,
    bool isAlarm = false,
  }) async {
    if (!await areNotificationsEnabled()) return false;

    final details = _details(
      channel: channel,
      title: title,
      body: body,
      isAlarm: isAlarm,
    );
    final mode = await canScheduleExactAlarms()
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    Future<void> attempt(AndroidScheduleMode scheduleMode) => _plugin.zonedSchedule(
          id,
          title,
          body,
          when,
          details,
          payload: payload.encode(),
          androidScheduleMode: scheduleMode,
          matchDateTimeComponents: repeatOn,
        );

    try {
      await attempt(mode);
      return true;
    } catch (error) {
      debugPrint('NotificationService: exact schedule($id) failed ($error)');
    }

    // A device can revoke exact-alarm access between the check and the call.
    try {
      await attempt(AndroidScheduleMode.inexactAllowWhileIdle);
      return true;
    } catch (error) {
      debugPrint('NotificationService: schedule($id) failed ($error)');
      return false;
    }
  }

  /// Schedules the repeating daily practice reminder at [hour]:[minute].
  /// Replaces any previously scheduled one.
  static Future<bool> scheduleDailyPracticeReminder({
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    await cancel(dailyPracticeId);
    return _schedule(
      id: dailyPracticeId,
      channel: _dailyChannel,
      title: title,
      body: body,
      when: _nextInstanceOf(hour, minute),
      payload: const NotificationPayload(NotificationKind.dailyPractice),
      repeatOn: DateTimeComponents.time,
    );
  }

  static Future<bool> scheduleServiceReminder({
    required int id,
    required String reminderId,
    required String title,
    required String body,
    required DateTime when,
    bool isAlarm = false,
  }) async {
    if (!when.isAfter(DateTime.now())) return false;
    return _schedule(
      id: id,
      channel: _serviceChannel,
      title: title,
      body: body,
      when: tz.TZDateTime.from(when, tz.local),
      payload: NotificationPayload(
        NotificationKind.serviceReminder,
        reference: reminderId,
      ),
      isAlarm: isAlarm,
    );
  }

  static Future<bool> schedulePracticeContinuation({
    required Duration delay,
    required String title,
    required String body,
  }) async {
    await cancel(practiceContinuationId);
    return _schedule(
      id: practiceContinuationId,
      channel: _practiceChannel,
      title: title,
      body: body,
      when: tz.TZDateTime.now(tz.local).add(delay),
      payload: const NotificationPayload(NotificationKind.practiceContinuation),
    );
  }

  static Future<void> showNewContentNotification({
    required String title,
    required String body,
    String? songId,
  }) async {
    // Cycles through a small id range so consecutive alerts stack in the
    // shade instead of overwriting one another.
    final id = _contentIdBase +
        (DateTime.now().millisecondsSinceEpoch ~/ 1000) % _contentIdSpan;
    await _show(
      id: id,
      channel: _contentChannel,
      title: title,
      body: body,
      payload: NotificationPayload(
        NotificationKind.newContent,
        reference: songId,
      ),
    );
  }

  static Future<void> showTestNotification() async {
    await _show(
      id: testId,
      channel: _dailyChannel,
      title: 'Notifications are working',
      body:
          'This is how your reminders will look. Tap it to open your vocal exercises.',
      payload: const NotificationPayload(NotificationKind.test),
    );
  }

  static Future<void> cancel(int id) async {
    try {
      await _plugin.cancel(id);
    } catch (error) {
      debugPrint('NotificationService: cancel($id) failed ($error)');
    }
  }

  static Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (error) {
      debugPrint('NotificationService: cancelAll failed ($error)');
    }
  }

  static Future<List<PendingNotificationRequest>> pendingNotifications() async {
    try {
      return await _plugin.pendingNotificationRequests();
    } catch (error) {
      debugPrint('NotificationService: pending lookup failed ($error)');
      return const <PendingNotificationRequest>[];
    }
  }

  static tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
