import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _twoFactorEnabledKey = 'two_factor_enabled';

  ThemeMode _themeMode = ThemeMode.dark;
  bool _isBiometricEnabled = false;
  bool _isTwoFactorEnabled = false;
  late SharedPreferences _prefs;
  bool _isInitialized = false;

  ThemeMode get themeMode => _themeMode;
  bool get isBiometricEnabled => _isBiometricEnabled;
  bool get isTwoFactorEnabled => _isTwoFactorEnabled;
  bool get isInitialized => _isInitialized;

  SettingsProvider() {
    _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    
    // Load theme
    final themeIndex = _prefs.getInt(_themeKey) ?? ThemeMode.dark.index;
    _themeMode = ThemeMode.values[themeIndex];

    // Load biometric setting
    _isBiometricEnabled = _prefs.getBool(_biometricEnabledKey) ?? false;
    _isTwoFactorEnabled = _prefs.getBool(_twoFactorEnabledKey) ?? false;

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs.setInt(_themeKey, mode.index);
    notifyListeners();
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    _isBiometricEnabled = enabled;
    await _prefs.setBool(_biometricEnabledKey, enabled);
    notifyListeners();
  }

  Future<void> setTwoFactorEnabled(bool enabled) async {
    _isTwoFactorEnabled = enabled;
    await _prefs.setBool(_twoFactorEnabledKey, enabled);
    notifyListeners();
  }

  void toggleTheme() {
    if (_themeMode == ThemeMode.light) {
      setThemeMode(ThemeMode.dark);
    } else {
      setThemeMode(ThemeMode.light);
    }
  }
}
