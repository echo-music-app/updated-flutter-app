import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ThemeModeController extends ChangeNotifier {
  ThemeModeController({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage() {
    _load();
  }

  static const _themeModeKey = 'theme_mode';

  final FlutterSecureStorage _storage;
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode {
    switch (_themeMode) {
      case ThemeMode.dark:
        return true;
      case ThemeMode.light:
      case ThemeMode.system:
        return false;
    }
  }

  Future<void> _load() async {
    try {
      final value = await _storage.read(key: _themeModeKey);
      _themeMode = _parseThemeMode(value);
      notifyListeners();
    } catch (_) {
      _themeMode = ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    await _save(mode);
  }

  Future<void> toggle() async {
    await setThemeMode(_themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }

  Future<void> _save(ThemeMode mode) async {
    try {
      await _storage.write(key: _themeModeKey, value: mode.name);
    } catch (_) {
      // Ignore persistence failures; runtime mode still updates.
    }
  }

  ThemeMode _parseThemeMode(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}
