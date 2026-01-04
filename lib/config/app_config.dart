import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Application configuration that can be customized by the user.
class AppConfig with ChangeNotifier {
  static const String appName = 'SignSync';
  static const bool isDebugMode = kDebugMode;
  static const List<Locale> supportedLocales = [
    Locale('en', 'US'),
    Locale('es', 'ES'),
    Locale('fr', 'FR'),
  ];

  static const String _keyThemeMode = 'theme_mode';
  static const String _keyLocale = 'locale';
  static const String _keyTextScale = 'text_scale';
  static const String _keyHighContrast = 'high_contrast';
  static const String _keyReduceMotion = 'reduce_motion';

  ThemeMode _themeMode = ThemeMode.system;
  double _textScaleFactor = 1.0;
  bool _highContrastMode = false;
  bool _reduceMotion = false;
  Locale _locale = const Locale('en', 'US');
  SharedPreferences? _prefs;

  AppConfig() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    
    final themeIndex = _prefs?.getInt(_keyThemeMode);
    if (themeIndex != null) _themeMode = ThemeMode.values[themeIndex];

    final localeCode = _prefs?.getString(_keyLocale);
    if (localeCode != null) _locale = Locale(localeCode);

    _textScaleFactor = _prefs?.getDouble(_keyTextScale) ?? 1.0;
    _highContrastMode = _prefs?.getBool(_keyHighContrast) ?? false;
    _reduceMotion = _prefs?.getBool(_keyReduceMotion) ?? false;
    
    notifyListeners();
  }

  // Getters
  ThemeMode get themeMode => _themeMode;
  double get textScaleFactor => _textScaleFactor;
  bool get highContrastMode => _highContrastMode;
  bool get reduceMotion => _reduceMotion;
  Locale get locale => _locale;

  /// Updates the theme mode and notifies listeners.
  set themeMode(ThemeMode value) {
    if (_themeMode != value) {
      _themeMode = value;
      _prefs?.setInt(_keyThemeMode, value.index);
      notifyListeners();
    }
  }

  /// Updates the locale and notifies listeners.
  set locale(Locale value) {
    if (_locale != value) {
      _locale = value;
      _prefs?.setString(_keyLocale, value.languageCode);
      notifyListeners();
    }
  }

  /// Updates the text scale factor and notifies listeners.
  set textScaleFactor(double value) {
    if (_textScaleFactor != value) {
      _textScaleFactor = value;
      _prefs?.setDouble(_keyTextScale, value);
      notifyListeners();
    }
  }

  /// Toggles high contrast mode and notifies listeners.
  set highContrastMode(bool value) {
    if (_highContrastMode != value) {
      _highContrastMode = value;
      _prefs?.setBool(_keyHighContrast, value);
      notifyListeners();
    }
  }

  /// Toggles reduced motion and notifies listeners.
  set reduceMotion(bool value) {
    if (_reduceMotion != value) {
      _reduceMotion = value;
      _prefs?.setBool(_keyReduceMotion, value);
      notifyListeners();
    }
  }

  /// Resets all settings to default values.
  void resetToDefaults() {
    _themeMode = ThemeMode.system;
    _textScaleFactor = 1.0;
    _highContrastMode = false;
    _reduceMotion = false;
    notifyListeners();
  }
}

/// Extension on ThemeMode for readable strings.
extension ThemeModeExtension on ThemeMode {
  String get displayName {
    switch (this) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }
}
