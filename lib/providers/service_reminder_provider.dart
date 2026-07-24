import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mahlete_semay_project/models/service_reminder_model.dart';
import 'package:mahlete_semay_project/services/notification_service.dart';
import 'package:mahlete_semay_project/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ServiceReminderProvider with ChangeNotifier {
  List<ServiceReminder> _reminders = [];
  List<ServiceReminder> get reminders => _reminders;

  ServiceReminderProvider() {
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedRemindersJson = [];

    try {
      savedRemindersJson = prefs.getStringList(prefServiceReminderDateTime) ?? [];
    } catch (e) {
      // This catch block fixes the crash by handling the old data format.
      debugPrint("Could not read reminders as List, attempting to clear old format: $e");
      await prefs.remove(prefServiceReminderDateTime);
      savedRemindersJson = [];
    }

    _reminders = savedRemindersJson.map((json) => ServiceReminder.fromJson(json)).toList();
    _reminders.sort((a, b) => a.serviceDateTime.compareTo(b.serviceDateTime));
    notifyListeners();
  }

  Future<void> _saveReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final remindersJson = _reminders.map((r) => r.toJson()).toList();
    await prefs.setStringList(prefServiceReminderDateTime, remindersJson);
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
    if (index != -1) {
      final oldReminder = _reminders[index];
      await _cancelNotifications(oldReminder);
      _reminders[index] = updatedReminder;
      _reminders.sort((a, b) => a.serviceDateTime.compareTo(b.serviceDateTime));
      await _saveReminders();
      await _scheduleNotifications(updatedReminder);
      notifyListeners();
    }
  }

  Future<void> cancelReminder(String id) async {
    final reminderIndex = _reminders.indexWhere((r) => r.id == id);
    if (reminderIndex != -1) {
      final reminderToCancel = _reminders[reminderIndex];
      await _cancelNotifications(reminderToCancel);
      _reminders.removeAt(reminderIndex);
      await _saveReminders();
      notifyListeners();
    }
  }

  Future<void> _scheduleNotifications(ServiceReminder reminder) async {
    // Schedule for 5, 4, 3, 2, 1 days prior, and 0 (Day of Service)
    for (int i = 5; i >= 0; i--) {
      final notificationDate = reminder.serviceDateTime.subtract(Duration(days: i));
      final scheduledTime = DateTime(
        notificationDate.year,
        notificationDate.month,
        notificationDate.day,
        i == 0 ? 8 : 10,
        0,
      );

      if (scheduledTime.isAfter(DateTime.now())) {
        final uniqueId = (reminder.id.hashCode.abs() % 100000) * 10 + i;
        final title = i == 0
            ? "🙏 Service Today: ${reminder.title}"
            : "Service Reminder: $i Day${i == 1 ? '' : 's'} Left!";
        final body = i == 0
            ? "Reminder for '${reminder.title}' today at ${DateFormat.jm().format(reminder.serviceDateTime)}."
            : "Get ready for '${reminder.title}' on ${DateFormat.yMMMd().format(reminder.serviceDateTime)}.";

        await NotificationService.scheduleFullScreenReminder(
          id: uniqueId,
          title: title,
          body: body,
          scheduledDate: scheduledTime,
        );
      }
    }
  }

  Future<void> _cancelNotifications(ServiceReminder reminder) async {
    for (int i = 0; i <= 5; i++) {
      final uniqueId = (reminder.id.hashCode.abs() % 100000) * 10 + i;
      await NotificationService.cancelNotification(uniqueId);
    }
  }
}