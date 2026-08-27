import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = true;
  bool get isDarkMode => _isDarkMode;

  double _lyricsFontSize = 15.0; // Default font size
  double get lyricsFontSize => _lyricsFontSize;

  final String _themePreferenceKey = 'isDarkMode';
  final String _fontSizePreferenceKey = 'lyricsFontSize';

  ThemeProvider() {
    _loadPreferences();
  }

  void _loadPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_themePreferenceKey) ?? true;
    _lyricsFontSize = prefs.getDouble(_fontSizePreferenceKey) ?? 15.0;
    notifyListeners();
  }

  void toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themePreferenceKey, _isDarkMode);
    notifyListeners();
  }

  void setLyricsFontSize(double newSize) async {
    _lyricsFontSize = newSize;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontSizePreferenceKey, newSize);
    notifyListeners();
  }
}