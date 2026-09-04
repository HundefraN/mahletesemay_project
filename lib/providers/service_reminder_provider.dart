import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mahlete_semay_project/models/service_reminder_model.dart';
import 'package:mahlete_semay_project/services/alarm_service.dart';
import 'package:mahlete_semay_project/services/notification_service.dart';
import 'package:mahlete_semay_project/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Status of a single alert slot in the notification timeline.
enum AlertSlotStatus {
  /// The alert time has passed — it already fired.
  fired,

  /// This is the very next alert that will fire.
  nextUp,

  /// The alert is scheduled and waiting.
  scheduled,

  /// The alert was skipped (e.g. service already started).
  skipped,
}

/// A single entry in the notification timeline shown to the user.
@immutable
class AlertSlotInfo {
  const AlertSlotInfo({
    required this.label,
    required this.dateTime,
    required this.status,
    required this.isAlarm,
  });

  /// Human-readable label like "5 days before", "Morning of", "2 hours before".
  final String label;

  /// The exact date/time this alert fires (or would have fired).
  final DateTime dateTime;

  /// Whether this slot has fired, is next, is scheduled, or was skipped.
  final AlertSlotStatus status;

  /// Whether this alert is an alarm-class notification (full-screen intent).
  final bool isAlarm;
}

class ServiceReminderProvider with ChangeNotifier {
  /// Countdown alerts sent before a service, expressed as whole days out.
  /// Index 0 is the morning of the service itself.
  static const List<int> countdownDays = <int>[5, 4, 3, 2, 1, 0];

  /// Slot used for the final "starting soon" alert. Kept distinct from the
  /// day offsets so notification ids stay unique.
  static const int startingSoonSlot = 6;

  /// Slot used for the exact service start time alert.
  static const int serviceStartTimeSlot = 7;

  static const Duration startingSoonLeadTime = Duration(hours: 2);

  List<ServiceReminder> _reminders = [];
  bool _isLoaded = false;

  List<ServiceReminder> get reminders => _reminders;
  bool get isLoaded => _isLoaded;

  List<ServiceReminder> get upcomingReminders {
    final now = DateTime.now();
    return _reminders
        .where((r) => r.serviceDateTime.isAfter(now))
        .toList(growable: false);
  }

  /// Loads saved reminders and re-applies their notification schedule.
  ///
  /// Rescheduling on every launch is what keeps reminders alive after events
  /// that silently drop pending alarms: a reinstall, a timezone change, or
  /// notification permission being granted after the reminder was created.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedRemindersJson = [];

    try {
      savedRemindersJson =
          prefs.getStringList(prefServiceReminderDateTime) ?? [];
    } catch (error) {
      // Older builds stored a single value under this key rather than a list.
      debugPrint('ServiceReminderProvider: clearing legacy format ($error)');
      await prefs.remove(prefServiceReminderDateTime);
    }

    _reminders = savedRemindersJson
        .map((json) => ServiceReminder.fromJson(json))
        .toList();
    _reminders.sort((a, b) => a.serviceDateTime.compareTo(b.serviceDateTime));

    await _pruneExpiredReminders();

    _isLoaded = true;
    notifyListeners();

    for (final reminder in upcomingReminders) {
      await _scheduleNotifications(reminder);
    }
  }

  /// Drops services that finished more than a day ago so the list and the
  /// notification queue do not grow without bound.
  Future<bool> _pruneExpiredReminders() async {
    final cutoff = DateTime.now().subtract(const Duration(days: 1));
    final expired = _reminders
        .where((r) => r.serviceDateTime.isBefore(cutoff))
        .toList(growable: false);
    if (expired.isEmpty) return false;

    for (final reminder in expired) {
      await _cancelNotifications(reminder);
      _reminders.remove(reminder);
    }
    await _saveReminders();
    return true;
  }

  Future<void> _saveReminders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      prefServiceReminderDateTime,
      _reminders.map((r) => r.toJson()).toList(),
    );
  }

  bool hasConflict(DateTime newDateTime, {String? excludeReminderId}) {
    return _reminders.any((reminder) {
      if (reminder.id == excludeReminderId) return false;
      final existing = reminder.serviceDateTime;
      return existing.year == newDateTime.year &&
          existing.month == newDateTime.month &&
          existing.day == newDateTime.day &&
          existing.hour == newDateTime.hour;
    });
  }

  Future<void> addReminder(ServiceReminder reminder) async {
    _reminders.add(reminder);
    _reminders.sort((a, b) => a.serviceDateTime.compareTo(b.serviceDateTime));
    await _saveReminders();
    await _scheduleNotifications(reminder);
    notifyListeners();
  }

  Future<void> updateReminder(ServiceReminder updatedReminder) async {
    final index = _reminders.indexWhere((r) => r.id == updatedReminder.id);
    if (index == -1) return;

    await _cancelNotifications(_reminders[index]);
    _reminders[index] = updatedReminder;
    _reminders.sort((a, b) => a.serviceDateTime.compareTo(b.serviceDateTime));
    await _saveReminders();
    await _scheduleNotifications(updatedReminder);
    notifyListeners();
  }

  Future<void> cancelReminder(String id) async {
    final index = _reminders.indexWhere((r) => r.id == id);
    if (index == -1) return;

    await _cancelNotifications(_reminders[index]);
    _reminders.removeAt(index);
    await _saveReminders();
    notifyListeners();
  }

  /// Number of alerts currently queued for [reminder]. Lets the UI tell the
  /// user whether a reminder will actually notify them.
  int scheduledAlertCount(ServiceReminder reminder) {
    final now = DateTime.now();
    var count = countdownDays
        .where((day) => countdownTime(reminder, day).isAfter(now))
        .length;
    if (reminder.serviceDateTime
        .subtract(startingSoonLeadTime)
        .isAfter(now)) {
      count++;
    }
    return count;
  }

  /// Builds the full notification timeline for [reminder] so the UI can
  /// render each alert slot with its status, label, and time.
  List<AlertSlotInfo> getNotificationTimeline(ServiceReminder reminder) {
    final now = DateTime.now();
    final slots = <AlertSlotInfo>[];
    bool foundNextUp = false;

    for (final daysBefore in countdownDays) {
      final when = countdownTime(reminder, daysBefore);
      final bool isAlarmSlot = daysBefore == 0;

      // The morning-of alert is skipped once the service has begun.
      final bool skipped = daysBefore == 0 && !when.isBefore(reminder.serviceDateTime);

      AlertSlotStatus status;
      if (skipped) {
        status = AlertSlotStatus.skipped;
      } else if (when.isBefore(now)) {
        status = AlertSlotStatus.fired;
      } else if (!foundNextUp) {
        status = AlertSlotStatus.nextUp;
        foundNextUp = true;
      } else {
        status = AlertSlotStatus.scheduled;
      }

      final String label;
      if (daysBefore == 0) {
        label = 'Morning of service';
      } else if (daysBefore == 1) {
        label = '1 day before';
      } else {
        label = '$daysBefore days before';
      }

      slots.add(AlertSlotInfo(
        label: label,
        dateTime: when,
        status: status,
        isAlarm: isAlarmSlot,
      ));
    }

    // "Starting soon" slot
    final startingSoonWhen = reminder.serviceDateTime.subtract(startingSoonLeadTime);
    AlertSlotStatus startingSoonStatus;
    if (startingSoonWhen.isBefore(now)) {
      startingSoonStatus = AlertSlotStatus.fired;
    } else if (!foundNextUp) {
      startingSoonStatus = AlertSlotStatus.nextUp;
    } else {
      startingSoonStatus = AlertSlotStatus.scheduled;
    }

    slots.add(AlertSlotInfo(
      label: '2 hours before',
      dateTime: startingSoonWhen,
      status: startingSoonStatus,
      isAlarm: true,
    ));

    return slots;
  }

  DateTime countdownTime(ServiceReminder reminder, int daysBefore) {
    final date = reminder.serviceDateTime.subtract(Duration(days: daysBefore));
    // Morning-of alerts land earlier so they arrive before the service starts.
    final hour = daysBefore == 0 ? 8 : 10;
    return DateTime(date.year, date.month, date.day, hour);
  }

  Future<void> _scheduleNotifications(ServiceReminder reminder) async {
    final serviceDate = DateFormat.yMMMEd().format(reminder.serviceDateTime);
    final serviceTime = DateFormat.jm().format(reminder.serviceDateTime);

    for (final daysBefore in countdownDays) {
      final when = countdownTime(reminder, daysBefore);

      // The morning-of alert is pointless once the service has begun.
      if (daysBefore == 0 && !when.isBefore(reminder.serviceDateTime)) continue;

      final bool isAlarmSlot = daysBefore == 0;
      final id = NotificationService.serviceNotificationId(reminder.id, daysBefore);

      final String title;
      final String body;
      if (daysBefore == 0) {
        title = '🔔 ${reminder.title} is TODAY!';
        body = 'Your service starts at $serviceTime. '
            '${_notesSuffix(reminder) ?? 'Warm up your voice before you go.'}';
      } else {
        final dayLabel = daysBefore == 1 ? '⏰ Tomorrow' : '📅 $daysBefore days to go';
        title = '$dayLabel: ${reminder.title}';
        body = '$serviceDate at $serviceTime. '
            '${_notesSuffix(reminder) ?? 'Time to rehearse your set.'}';
      }

      await NotificationService.scheduleServiceReminder(
        id: id,
        reminderId: reminder.id,
        title: title,
        body: body,
        when: when,
        isAlarm: isAlarmSlot,
      );

      if (isAlarmSlot) {
        await AlarmService.scheduleExactAlarm(
          id: id,
          reminderId: reminder.id,
          title: title,
          body: body,
          when: when,
          notes: reminder.notes,
        );
      }
    }

    // "Starting soon" is also alarm-class (full-screen intent).
    final startingSoonTime = reminder.serviceDateTime.subtract(startingSoonLeadTime);
    final startingSoonId = NotificationService.serviceNotificationId(
      reminder.id,
      startingSoonSlot,
    );
    final startingSoonTitle = '🚨 ${reminder.title} starts in 2 hours!';
    final startingSoonBody = 'Starting at $serviceTime. '
        '${_notesSuffix(reminder) ?? 'Run through your warm-ups now.'}';

    await NotificationService.scheduleServiceReminder(
      id: startingSoonId,
      reminderId: reminder.id,
      title: startingSoonTitle,
      body: startingSoonBody,
      when: startingSoonTime,
      isAlarm: true,
    );
    await AlarmService.scheduleExactAlarm(
      id: startingSoonId,
      reminderId: reminder.id,
      title: startingSoonTitle,
      body: startingSoonBody,
      when: startingSoonTime,
      notes: reminder.notes,
    );

    // Exact Service Start Time alarm
    final serviceStartId = NotificationService.serviceNotificationId(
      reminder.id,
      serviceStartTimeSlot,
    );
    final serviceStartTitle = '🔔 ${reminder.title} is starting now!';
    final serviceStartBody = 'It\'s time for ${reminder.title} ($serviceTime). '
        '${_notesSuffix(reminder) ?? 'May your worship be blessed!'}';

    await NotificationService.scheduleServiceReminder(
      id: serviceStartId,
      reminderId: reminder.id,
      title: serviceStartTitle,
      body: serviceStartBody,
      when: reminder.serviceDateTime,
      isAlarm: true,
    );
    await AlarmService.scheduleExactAlarm(
      id: serviceStartId,
      reminderId: reminder.id,
      title: serviceStartTitle,
      body: serviceStartBody,
      when: reminder.serviceDateTime,
      notes: reminder.notes,
    );
  }

  String? _notesSuffix(ServiceReminder reminder) {
    final notes = reminder.notes?.trim();
    return (notes == null || notes.isEmpty) ? null : notes;
  }

  Future<void> _cancelNotifications(ServiceReminder reminder) async {
    for (final slot in <int>[...countdownDays, startingSoonSlot, serviceStartTimeSlot]) {
      final id = NotificationService.serviceNotificationId(reminder.id, slot);
      await NotificationService.cancel(id);
      await AlarmService.cancelAlarm(id);
    }
  }
}
