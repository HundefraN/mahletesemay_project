import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VocalProgressProvider with ChangeNotifier {
  String? _gender;
  String? get gender => _gender;

  Map<String, int> _progress = {}; // Key: Plan Title, Value: Current Step Index
  Map<String, int> get progress => _progress;

  final String _genderKey = 'userGender';
  final String _dailyProgressKey = 'dailyPlanProgress';
  // Add keys for weekly, monthly etc. as you build them out

  VocalProgressProvider() {
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    _gender = prefs.getString(_genderKey);
    _progress = {
      'Daily Foundation': prefs.getInt(_dailyProgressKey) ?? 0,
    };
    notifyListeners();
  }

  Future<void> setGender(String gender) async {
    _gender = gender;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_genderKey, gender);
    notifyListeners();
  }

  Future<void> completeStep(String planTitle) async {
    int currentStep = _progress[planTitle] ?? 0;
    _progress[planTitle] = currentStep + 1;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dailyProgressKey, _progress[planTitle]!);
    notifyListeners();
  }

  void resetProgress(String planTitle) async {
    _progress[planTitle] = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dailyProgressKey, 0);
    notifyListeners();
  }
}