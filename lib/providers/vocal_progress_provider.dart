import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VocalProgressProvider with ChangeNotifier {
  String? _gender;
  String? get gender => _gender;

  Map<String, Set<int>> _progress = {};
  Map<String, Set<int>> get progress => _progress;

  DateTime? _lastCompletionDate;
  DateTime? get lastCompletionDate => _lastCompletionDate;

  final String _genderKey = 'userGender';
  final String _lastCompletionDateKey = 'lastCompletionDate';

  VocalProgressProvider() {
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    _gender = prefs.getString(_genderKey);

    final lastCompletionMillis = prefs.getInt(_lastCompletionDateKey);
    if (lastCompletionMillis != null) {
      _lastCompletionDate =
          DateTime.fromMillisecondsSinceEpoch(lastCompletionMillis);
    }

    _progress['male_daily'] =
        (prefs.getStringList('male_daily_progress')?.map(int.parse).toSet()) ??
            {};
    _progress['female_daily'] = (prefs
        .getStringList('female_daily_progress')
        ?.map(int.parse)
        .toSet()) ??
        {};
    _progress['male_weekly'] = (prefs
        .getStringList('male_weekly_progress')
        ?.map(int.parse)
        .toSet()) ??
        {};
    _progress['female_weekly'] = (prefs
        .getStringList('female_weekly_progress')
        ?.map(int.parse)
        .toSet()) ??
        {};

    notifyListeners();
  }

  Future<void> setGender(String gender) async {
    _gender = gender;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_genderKey, gender);
    notifyListeners();
  }

  Future<void> _updateLastCompletionDate() async {
    _lastCompletionDate = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        _lastCompletionDateKey, _lastCompletionDate!.millisecondsSinceEpoch);
    notifyListeners();
  }

  Future<void> completeDay(String planId, int dayNumber) async {
    _progress[planId] ??= {};
    _progress[planId]!.add(dayNumber);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('${planId}_progress',
        _progress[planId]!.map((d) => d.toString()).toList());

    await _updateLastCompletionDate();
    notifyListeners();
  }

  bool isDayCompleted(String planId, int dayNumber) {
    return _progress[planId]?.contains(dayNumber) ?? false;
  }

  int getLastCompletedDay(String planId) {
    if (_progress[planId] == null || _progress[planId]!.isEmpty) {
      return 0;
    }
    return _progress[planId]!.reduce((a, b) => a > b ? a : b);
  }

  void resetProgress(String planId) async {
    _progress[planId] = {};
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${planId}_progress');
    notifyListeners();
  }
}
