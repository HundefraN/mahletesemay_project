import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';

const String _prefAlarmMetaPrefix = 'service_alarm_meta_';
const String _prefActiveAlarmKey = 'currently_ringing_alarm';

/// Model representing the metadata of a scheduled alarm.
class ServiceAlarmMetadata {
  final int id;
  final String reminderId;
  final String title;
  final String body;
  final DateTime serviceDateTime;
  final String? notes;

  const ServiceAlarmMetadata({
    required this.id,
    required this.reminderId,
    required this.title,
    required this.body,
    required this.serviceDateTime,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'reminderId': reminderId,
        'title': title,
        'body': body,
        'serviceDateTime': serviceDateTime.toIso8601String(),
        'notes': notes,
      };

  factory ServiceAlarmMetadata.fromMap(Map<String, dynamic> map) =>
      ServiceAlarmMetadata(
        id: map['id'] as int,
        reminderId: map['reminderId'] as String,
        title: map['title'] as String,
        body: map['body'] as String,
        serviceDateTime: DateTime.parse(map['serviceDateTime'] as String),
        notes: map['notes'] as String?,
      );

  String toJson() => jsonEncode(toMap());
  factory ServiceAlarmMetadata.fromJson(String str) =>
      ServiceAlarmMetadata.fromMap(jsonDecode(str) as Map<String, dynamic>);
}

/// Top-level callback executed by AlarmManager even when the app is completely killed.
@pragma('vm:entry-point')
void serviceAlarmCallback(int id) async {
  debugPrint('AlarmService: serviceAlarmCallback triggered for alarm id $id');

  try {
    final prefs = await SharedPreferences.getInstance();
    final metaJson = prefs.getString('$_prefAlarmMetaPrefix$id');

    ServiceAlarmMetadata? meta;
    if (metaJson != null) {
      try {
        meta = ServiceAlarmMetadata.fromJson(metaJson);
      } catch (e) {
        debugPrint('AlarmService: could not parse alarm meta ($e)');
      }
    }

    final title = meta?.title ?? '🔔 Worship Service Reminder';
    final body = meta?.body ?? 'Your service is scheduled to begin now.';
    final reminderId = meta?.reminderId ?? 'alarm_$id';

    // 1. Initialize notification service in background isolate
    await NotificationService.initialize();

    // 2. Mark this alarm as actively ringing in prefs
    await prefs.setString(_prefActiveAlarmKey, metaJson ?? title);

    // 3. Trigger full-screen intent notification
    await NotificationService.showFullScreenAlarmNotification(
      id: id,
      reminderId: reminderId,
      title: title,
      body: body,
      serviceDateTime: meta?.serviceDateTime ?? DateTime.now(),
    );

    // 4. Notify in-memory stream if app isolate is running
    AlarmService.broadcastRingingAlarm(meta);
  } catch (e, stack) {
    debugPrint('AlarmService: serviceAlarmCallback error: $e\n$stack');
  }
}

/// Production-grade service handling exact alarms, lock-screen wakeups,
/// looping audio, and vibration.
class AlarmService {
  AlarmService._();

  static bool _isInitialized = false;
  static AudioPlayer? _audioPlayer;
  static Timer? _vibrationTimer;

  // Stream to notify active UI when an alarm is triggered
  static final StreamController<ServiceAlarmMetadata> _ringingAlarmController =
      StreamController<ServiceAlarmMetadata>.broadcast();
  static Stream<ServiceAlarmMetadata> get onAlarmRinging =>
      _ringingAlarmController.stream;

  /// Initializes AndroidAlarmManager. Guarded to run only on Android.
  static Future<void> initialize() async {
    if (kIsWeb || !Platform.isAndroid) return;
    if (_isInitialized) return;

    try {
      final success = await AndroidAlarmManager.initialize();
      _isInitialized = success;
      debugPrint('AlarmService: AndroidAlarmManager initialized: $success');
    } catch (e) {
      debugPrint('AlarmService: AndroidAlarmManager init failed: $e');
    }
  }

  /// Broadcasts an active ringing alarm to any connected UI listener.
  static void broadcastRingingAlarm(ServiceAlarmMetadata? meta) {
    if (meta != null) {
      _ringingAlarmController.add(meta);
    }
  }

  /// Schedules an exact full-screen alarm using native AlarmManager setAlarmClock.
  static Future<bool> scheduleExactAlarm({
    required int id,
    required String reminderId,
    required String title,
    required String body,
    required DateTime when,
    String? notes,
  }) async {
    if (!when.isAfter(DateTime.now())) {
      debugPrint('AlarmService: schedule time is in the past ($when), skipping');
      return false;
    }

    final metadata = ServiceAlarmMetadata(
      id: id,
      reminderId: reminderId,
      title: title,
      body: body,
      serviceDateTime: when,
      notes: notes,
    );

    // Save metadata so the background isolate has complete info
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefAlarmMetaPrefix$id', metadata.toJson());
    } catch (e) {
      debugPrint('AlarmService: failed saving alarm meta ($e)');
    }

    if (!kIsWeb && Platform.isAndroid) {
      try {
        final scheduled = await AndroidAlarmManager.oneShotAt(
          when,
          id,
          serviceAlarmCallback,
          exact: true,
          wakeup: true,
          alarmClock: true, // Native AlarmManager.setAlarmClock() for Doze bypass
          rescheduleOnReboot: true,
        );
        debugPrint('AlarmService: scheduled exact alarm #$id at $when -> $scheduled');
        return scheduled;
      } catch (e) {
        debugPrint('AlarmService: AndroidAlarmManager.oneShotAt failed ($e)');
      }
    }

    return true;
  }

  /// Cancels a scheduled exact alarm and removes its metadata.
  static Future<void> cancelAlarm(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_prefAlarmMetaPrefix$id');

      final activeKey = prefs.getString(_prefActiveAlarmKey);
      if (activeKey != null && activeKey.contains('"id":$id')) {
        await prefs.remove(_prefActiveAlarmKey);
      }
    } catch (_) {}

    if (!kIsWeb && Platform.isAndroid) {
      try {
        await AndroidAlarmManager.cancel(id);
      } catch (e) {
        debugPrint('AlarmService: cancel failed for alarm #$id ($e)');
      }
    }
  }

  /// Starts continuous looping alarm sound and periodic haptic pulses for the in-app overlay.
  static Future<void> startAlarmAudioAndVibration() async {
    try {
      _audioPlayer ??= AudioPlayer();
      await _audioPlayer!.stop();
      await _audioPlayer!.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer!.setVolume(1.0);
      await _audioPlayer!.play(AssetSource('audio/alarm.mp3'));
    } catch (e) {
      debugPrint('AlarmService: could not play alarm audio: $e');
    }

    // Trigger repeating haptic vibration pattern
    _vibrationTimer?.cancel();
    _vibrationTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      HapticFeedback.heavyImpact();
    });
  }

  /// Silences alarm sound and stops vibration.
  static Future<void> stopAlarmAudioAndVibration() async {
    try {
      if (_audioPlayer != null) {
        await _audioPlayer!.stop();
      }
    } catch (e) {
      debugPrint('AlarmService: error stopping audio: $e');
    }

    _vibrationTimer?.cancel();
    _vibrationTimer = null;
  }

  /// Snoozes an alarm for [minutes] (defaults to 10 minutes).
  static Future<void> snoozeAlarm({
    required ServiceAlarmMetadata metadata,
    int minutes = 10,
  }) async {
    await stopAlarmAudioAndVibration();
    await NotificationService.cancel(metadata.id);

    final snoozeTime = DateTime.now().add(Duration(minutes: minutes));
    final snoozeId = metadata.id + 9999;

    await scheduleExactAlarm(
      id: snoozeId,
      reminderId: metadata.reminderId,
      title: '⏰ [Snoozed] ${metadata.title}',
      body: metadata.body,
      when: snoozeTime,
      notes: metadata.notes,
    );

    // Also schedule notification for redundancy
    await NotificationService.scheduleServiceReminder(
      id: snoozeId,
      reminderId: metadata.reminderId,
      title: '⏰ [Snoozed] ${metadata.title}',
      body: metadata.body,
      when: snoozeTime,
      isAlarm: true,
    );
  }

  /// Dismisses an active alarm: stops audio, cancels notification, and cleans state.
  static Future<void> dismissAlarm(int id) async {
    await stopAlarmAudioAndVibration();
    await NotificationService.cancel(id);
    await cancelAlarm(id);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefActiveAlarmKey);
    } catch (_) {}
  }
}
