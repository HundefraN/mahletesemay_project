import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_service.dart';
import '../utils/constants.dart';

/// Owns the user's notification preferences and keeps the scheduled
/// notifications in step with them.
///
/// Every preference change re-applies the schedule immediately, and
/// [refresh] re-applies it on app start so a reminder the user switched on
/// months ago is still queued after a reinstall, reboot or timezone change.
class NotificationSettingsProvider with ChangeNotifier {
  NotificationSettingsProvider();

  bool _isLoaded = false;
  bool _dailyRemindersEnabled = true;
  TimeOfDay _dailyReminderTime = const TimeOfDay(
    hour: defaultDailyReminderHour,
    minute: defaultDailyReminderMinute,
  );
  bool _newContentAlertsEnabled = true;
  bool _practiceFollowUpsEnabled = true;
  NotificationPermissionStatus _permission = const NotificationPermissionStatus(
    notificationsEnabled: true,
    canScheduleExactAlarms: true,
  );

  bool get isLoaded => _isLoaded;
  bool get dailyRemindersEnabled => _dailyRemindersEnabled;
  TimeOfDay get dailyReminderTime => _dailyReminderTime;
  bool get newContentAlertsEnabled => _newContentAlertsEnabled;
  bool get practiceFollowUpsEnabled => _practiceFollowUpsEnabled;
  NotificationPermissionStatus get permission => _permission;

  /// True when the user wants reminders but the OS is blocking them, which is
  /// the state the settings UI needs to surface prominently.
  bool get isBlockedBySystem =>
      !_permission.notificationsEnabled &&
      (_dailyRemindersEnabled || _newContentAlertsEnabled);

  /// Loads preferences, re-syncs the OS permission state and re-applies any
  /// schedule the preferences imply. Safe to call repeatedly.
  Future<void> refresh() async {
    final prefs = await SharedPreferences.getInstance();

    _dailyRemindersEnabled = prefs.getBool(prefDailyRemindersEnabled) ?? true;
    _dailyReminderTime = TimeOfDay(
      hour: prefs.getInt(prefDailyReminderHour) ?? defaultDailyReminderHour,
      minute:
          prefs.getInt(prefDailyReminderMinute) ?? defaultDailyReminderMinute,
    );
    _newContentAlertsEnabled =
        prefs.getBool(prefNewContentAlertsEnabled) ?? true;
    _practiceFollowUpsEnabled =
        prefs.getBool(prefPracticeFollowUpsEnabled) ?? true;
    _permission = await NotificationService.permissionStatus();
    _isLoaded = true;

    await _applyDailyReminder();
    notifyListeners();
  }

  /// Re-reads the OS permission state without touching schedules. Used when
  /// returning from the system settings screen.
  Future<void> refreshPermission() async {
    _permission = await NotificationService.permissionStatus();
    // Reminders may have been unschedulable while permission was denied.
    await _applyDailyReminder();
    notifyListeners();
  }

  Future<bool> requestPermission() async {
    final granted = await NotificationService.requestPermission();
    await refreshPermission();
    return granted;
  }

  Future<void> requestExactAlarmPermission() async {
    await NotificationService.requestExactAlarmPermission();
    await refreshPermission();
  }

  Future<void> setDailyRemindersEnabled(bool enabled) async {
    if (_dailyRemindersEnabled == enabled) return;
    _dailyRemindersEnabled = enabled;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefDailyRemindersEnabled, enabled);

    if (enabled && !_permission.notificationsEnabled) {
      await requestPermission();
    }
    await _applyDailyReminder();
    notifyListeners();
  }

  Future<void> setDailyReminderTime(TimeOfDay time) async {
    _dailyReminderTime = time;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(prefDailyReminderHour, time.hour);
    await prefs.setInt(prefDailyReminderMinute, time.minute);

    await _applyDailyReminder();
    notifyListeners();
  }

  Future<void> setNewContentAlertsEnabled(bool enabled) async {
    if (_newContentAlertsEnabled == enabled) return;
    _newContentAlertsEnabled = enabled;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefNewContentAlertsEnabled, enabled);

    if (enabled && !_permission.notificationsEnabled) {
      await requestPermission();
    }
  }

  Future<void> setPracticeFollowUpsEnabled(bool enabled) async {
    if (_practiceFollowUpsEnabled == enabled) return;
    _practiceFollowUpsEnabled = enabled;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefPracticeFollowUpsEnabled, enabled);

    if (!enabled) {
      await NotificationService.cancel(
        NotificationService.practiceContinuationId,
      );
    }
  }

  Future<void> _applyDailyReminder() async {
    if (!_dailyRemindersEnabled) {
      await NotificationService.cancel(NotificationService.dailyPracticeId);
      return;
    }

    await NotificationService.scheduleDailyPracticeReminder(
      hour: _dailyReminderTime.hour,
      minute: _dailyReminderTime.minute,
      title: 'Time for your vocal workout',
      body:
          'A few minutes of practice keeps your voice healthy and your range growing. Tap to start today\'s session.',
    );
  }
}
