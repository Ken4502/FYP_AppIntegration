import 'package:flutter/material.dart';
import 'package:urbangreen/services/platform/web_hardware_bridge.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _storageKey = 'urbangreen_theme_mode';
  ThemeMode _themeMode = ThemeMode.light;

  ThemeProvider() {
    _loadThemeMode();
  }

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void _loadThemeMode() {
    try {
      final saved = WebHardwareBridge.loadStorage(_storageKey);
      if (saved == 'dark') {
        _themeMode = ThemeMode.dark;
      } else if (saved == 'system') {
        _themeMode = ThemeMode.system;
      } else {
        _themeMode = ThemeMode.light;
      }
    } catch (_) {
      _themeMode = ThemeMode.light;
    }
  }

  void toggleTheme() {
    if (_themeMode == ThemeMode.dark) {
      setThemeMode(ThemeMode.light);
    } else {
      setThemeMode(ThemeMode.dark);
    }
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
    try {
      final val = mode == ThemeMode.dark
          ? 'dark'
          : (mode == ThemeMode.system ? 'system' : 'light');
      WebHardwareBridge.saveStorage(_storageKey, val);
    } catch (_) {}
  }
}
