import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  SettingsService() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Theme
    final themeIndex = prefs.getInt(_themeKey);
    if (themeIndex != null) _themeMode = ThemeMode.values[themeIndex];

    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, mode.index);
  }

  String get themeName {
    // ... same ...
    switch (_themeMode) {
      case ThemeMode.system:
        return 'System Default';
      case ThemeMode.light:
        return 'Light Mode';
      case ThemeMode.dark:
        return 'Dark Mode';
    }
  }
}
