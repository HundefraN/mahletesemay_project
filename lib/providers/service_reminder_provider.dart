import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mahlete_semay_project/models/service_reminder_model.dart';
import 'package:mahlete_semay_project/services/notification_service.dart';
import 'package:mahlete_semay_project/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ServiceReminderProvider with ChangeNotifier {
  /// Countdown alerts sent before a service, expressed as whole days out.
  /// Index 0 is the morning of the service itself.
  static const List<int> _countdownDays = <int>[5, 4, 3, 2, 1, 0];

  /// Slot used for the final "starting soon" alert. Kept distinct from the
  /// day offsets so notification ids stay unique.
  static const int _startingSoonSlot = 6;

  static const Duration _startingSoonLeadTime = Duration(hours: 2);

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
    var count = _countdownDays
        .where((day) => _countdownTime(reminder, day).isAfter(now))
        .length;
    if (reminder.serviceDateTime
        .subtract(_startingSoonLeadTime)
        .isAfter(now)) {
      count++;
    }
    return count;
  }

  DateTime _countdownTime(ServiceReminder reminder, int daysBefore) {
    final date = reminder.serviceDateTime.subtract(Duration(days: daysBefore));
    // Morning-of alerts land earlier so they arrive before the service starts.
    final hour = daysBefore == 0 ? 8 : 10;
    return DateTime(date.year, date.month, date.day, hour);
  }

  Future<void> _scheduleNotifications(ServiceReminder reminder) async {
    final serviceDate = DateFormat.yMMMEd().format(reminder.serviceDateTime);
    final serviceTime = DateFormat.jm().format(reminder.serviceDateTime);

    for (final daysBefore in _countdownDays) {
      final when = _countdownTime(reminder, daysBefore);

      // The morning-of alert is pointless once the service has begun.
      if (daysBefore == 0 && !when.isBefore(reminder.serviceDateTime)) continue;

      final String title;
      final String body;
      if (daysBefore == 0) {
        title = '${reminder.title} is today';
        body = 'Your service starts at $serviceTime. '
            '${_notesSuffix(reminder) ?? 'Warm up your voice before you go.'}';
      } else {
        final dayLabel = daysBefore == 1 ? 'Tomorrow' : '$daysBefore days to go';
        title = '$dayLabel: ${reminder.title}';
        body = '$serviceDate at $serviceTime. '
            '${_notesSuffix(reminder) ?? 'Time to rehearse your set.'}';
      }

      await NotificationService.scheduleServiceReminder(
        id: NotificationService.serviceNotificationId(reminder.id, daysBefore),
        reminderId: reminder.id,
        title: title,
        body: body,
        when: when,
      );
    }

    await NotificationService.scheduleServiceReminder(
      id: NotificationService.serviceNotificationId(
        reminder.id,
        _startingSoonSlot,
      ),
      reminderId: reminder.id,
      title: '${reminder.title} starts soon',
      body: 'Starting at $serviceTime. '
          '${_notesSuffix(reminder) ?? 'Run through your warm-ups now.'}',
      when: reminder.serviceDateTime.subtract(_startingSoonLeadTime),
    );
  }

  String? _notesSuffix(ServiceReminder reminder) {
    final notes = reminder.notes?.trim();
    return (notes == null || notes.isEmpty) ? null : notes;
  }

  Future<void> _cancelNotifications(ServiceReminder reminder) async {
    for (final slot in <int>[..._countdownDays, _startingSoonSlot]) {
      await NotificationService.cancel(
        NotificationService.serviceNotificationId(reminder.id, slot),
      );
    }
  }
}
