import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Application configuration that can be customized by the user.
///
/// NOTE: This is currently in-memory only (no persistence). Task 9 will likely
/// introduce a dashboard/settings persistence layer.
class AppConfig with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  double _textScaleFactor = 1.0;
  bool _highContrastMode = false;
  bool _reduceMotion = false;

  // Accessibility / Alerts
  bool _hapticFeedbackEnabled = true;

  // TTS
  bool _ttsEnabled = true;
  double _ttsVolume = 1.0;
  double _ttsRate = 0.5;
  double _ttsPitch = 1.0;
  bool _spatialCuesEnabled = true;

  // Object detection audio alerts
  bool _objectAudioAlertsEnabled = true;

  // Sound detection
  double _soundAlertThreshold = 0.30; // normalized RMS threshold

  ThemeMode get themeMode => _themeMode;
  double get textScaleFactor => _textScaleFactor;
  bool get highContrastMode => _highContrastMode;
  bool get reduceMotion => _reduceMotion;

  bool get hapticFeedbackEnabled => _hapticFeedbackEnabled;

  bool get ttsEnabled => _ttsEnabled;
  double get ttsVolume => _ttsVolume;
  double get ttsRate => _ttsRate;
  double get ttsPitch => _ttsPitch;
  bool get spatialCuesEnabled => _spatialCuesEnabled;

  bool get objectAudioAlertsEnabled => _objectAudioAlertsEnabled;

  double get soundAlertThreshold => _soundAlertThreshold;

  set themeMode(ThemeMode value) {
    if (_themeMode != value) {
      _themeMode = value;
      notifyListeners();
    }
  }

  set textScaleFactor(double value) {
    final next = value.clamp(0.8, 2.0);
    if (_textScaleFactor != next) {
      _textScaleFactor = next;
      notifyListeners();
    }
  }

  set highContrastMode(bool value) {
    if (_highContrastMode != value) {
      _highContrastMode = value;
      notifyListeners();
    }
  }

  set reduceMotion(bool value) {
    if (_reduceMotion != value) {
      _reduceMotion = value;
      notifyListeners();
    }
  }

  set hapticFeedbackEnabled(bool value) {
    if (_hapticFeedbackEnabled != value) {
      _hapticFeedbackEnabled = value;
      notifyListeners();
    }
  }

  set ttsEnabled(bool value) {
    if (_ttsEnabled != value) {
      _ttsEnabled = value;
      notifyListeners();
    }
  }

  set ttsVolume(double value) {
    final next = value.clamp(0.0, 1.0);
    if (_ttsVolume != next) {
      _ttsVolume = next;
      notifyListeners();
    }
  }

  set ttsRate(double value) {
    final next = value.clamp(0.0, 1.0);
    if (_ttsRate != next) {
      _ttsRate = next;
      notifyListeners();
    }
  }

  set ttsPitch(double value) {
    final next = value.clamp(0.5, 2.0);
    if (_ttsPitch != next) {
      _ttsPitch = next;
      notifyListeners();
    }
  }

  set spatialCuesEnabled(bool value) {
    if (_spatialCuesEnabled != value) {
      _spatialCuesEnabled = value;
      notifyListeners();
    }
  }

  set objectAudioAlertsEnabled(bool value) {
    if (_objectAudioAlertsEnabled != value) {
      _objectAudioAlertsEnabled = value;
      notifyListeners();
    }
  }

  set soundAlertThreshold(double value) {
    final next = value.clamp(0.05, 0.95);
    if (_soundAlertThreshold != next) {
      _soundAlertThreshold = next;
      notifyListeners();
    }
  }

  void resetToDefaults() {
    _themeMode = ThemeMode.system;
    _textScaleFactor = 1.0;
    _highContrastMode = false;
    _reduceMotion = false;

    _hapticFeedbackEnabled = true;

    _ttsEnabled = true;
    _ttsVolume = 1.0;
    _ttsRate = 0.5;
    _ttsPitch = 1.0;
    _spatialCuesEnabled = true;

    _objectAudioAlertsEnabled = true;

    _soundAlertThreshold = 0.30;

    notifyListeners();
  }
}

final appConfigProvider = ChangeNotifierProvider<AppConfig>((_) {
  return AppConfig();
});

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
