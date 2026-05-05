import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = false;
  static const String _themeKey = "isDarkMode";

  bool get isDarkMode => _isDarkMode;

  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  ThemeProvider() {
    _loadTheme();
  }

  // Toggles the theme and saves the new value to disk
  Future<void> toggleTheme(bool value) async {
    _isDarkMode = value;
    notifyListeners(); // Triggers immediate UI update

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, value); // Saves preference
  }

  // Internal method to fetch the saved value on startup
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    // Default to false (light mode) if no value is found
    _isDarkMode = prefs.getBool(_themeKey) ?? false;
    notifyListeners();
  }
}