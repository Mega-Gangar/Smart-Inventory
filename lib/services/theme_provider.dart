import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  static const String _themeKey = "user_theme_preference";

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isSystemMode => _themeMode == ThemeMode.system;

  ThemeProvider() {
    _loadTheme();
  }

  // Toggles or changes the theme and saves the string configuration to disk
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners(); // Triggers immediate UI change across the app

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.toString());
  }

  // Legacy support for your existing settings toggle switch
  Future<void> toggleTheme(bool value) async {
    final targetMode = value ? ThemeMode.dark : ThemeMode.light;
    await setThemeMode(targetMode);
  }

  // Internal method to fetch saved configuration on startup
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedThemeStr = prefs.getString(_themeKey);

    if (savedThemeStr != null) {
      // Parse the saved string back into the correct ThemeMode enum
      _themeMode = ThemeMode.values.firstWhere(
            (e) => e.toString() == savedThemeStr,
        orElse: () => ThemeMode.system,
      );
    } else {
      // If the user has never set a preference, strictly follow the phone system
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }
}