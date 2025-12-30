import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signsync/core/theme/app_theme.dart';

/// Application configuration that can be customized by the user.
///
/// This configuration affects app-wide settings like theme mode,
/// text scaling, and accessibility features.
class AppConfig with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  double _textScaleFactor = 1.0;
  bool _highContrastMode = false;
  bool _reduceMotion = false;

  // Getters
  ThemeMode get themeMode => _themeMode;
  double get textScaleFactor => _textScaleFactor;
  bool get highContrastMode => _highContrastMode;
  bool get reduceMotion => _reduceMotion;

  /// Updates the theme mode and notifies listeners.
  set themeMode(ThemeMode value) {
    if (_themeMode != value) {
      _themeMode = value;
      notifyListeners();
    }
  }

  /// Updates the text scale factor and notifies listeners.
  set textScaleFactor(double value) {
    if (_textScaleFactor != value) {
      _textScaleFactor = value;
      notifyListeners();
    }
  }

  /// Toggles high contrast mode and notifies listeners.
  set highContrastMode(bool value) {
    if (_highContrastMode != value) {
      _highContrastMode = value;
      notifyListeners();
    }
  }

  /// Toggles reduced motion and notifies listeners.
  set reduceMotion(bool value) {
    if (_reduceMotion != value) {
      _reduceMotion = value;
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

/// Provider for the application configuration.
final appConfigProvider = ChangeNotifierProvider<AppConfig>((_) {
  return AppConfig();
});

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
