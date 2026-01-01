import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Application configuration that can be customized by the user.
///
/// This configuration affects app-wide settings like theme mode,
/// text scaling, and accessibility features.
class AppConfig with ChangeNotifier {
  static const appName = 'SignSync';

  // Preference keys
  static const _kThemeMode = 'theme_mode';
  static const _kTextScale = 'text_scale';
  static const _kHighContrast = 'high_contrast';
  static const _kReduceMotion = 'reduce_motion';
  static const _kLanguageCode = 'language_code';

  static const _kTtsEnabled = 'tts_enabled';
  static const _kTtsVolume = 'tts_volume';
  static const _kTtsRate = 'tts_rate';
  static const _kTtsPitch = 'tts_pitch';
  static const _kTtsSpatialCues = 'tts_spatial_cues';

  static const _kObjectAudioAlertsEnabled = 'object_audio_alerts_enabled';
  static const _kObjectAudioAlertsCooldownMs = 'object_audio_alerts_cooldown_ms';
  static const _kObjectMinConfidence = 'object_min_confidence';

  static const _kSoundMonitoringEnabled = 'sound_monitoring_enabled';
  static const _kSoundMonitoringBackground = 'sound_monitoring_background';
  static const _kSoundAlertThreshold = 'sound_alert_threshold';
  static const _kSoundHapticsEnabled = 'sound_haptics_enabled';
  static const _kSoundVoiceAlertsEnabled = 'sound_voice_alerts_enabled';

  static const _kAiSpeakResponses = 'ai_speak_responses';
  static const _kAiOfflineFallback = 'ai_offline_fallback';

  static const _kEnglishToAslUseAi = 'english_to_asl_use_ai';
  static const _kAslPlaybackSpeed = 'asl_playback_speed';

  SharedPreferences? _prefs;
  bool _isLoaded = false;

  ThemeMode _themeMode = ThemeMode.system;
  double _textScaleFactor = 1.0;
  bool _highContrastMode = false;
  bool _reduceMotion = false;
  String _languageCode = 'en';

  // TTS / audio alerts
  bool _ttsEnabled = true;
  double _ttsVolume = 0.9;
  double _ttsRate = 0.5;
  double _ttsPitch = 1.0;
  bool _ttsSpatialCues = true;

  bool _objectAudioAlertsEnabled = true;
  int _objectAudioAlertsCooldownMs = 2500;
  double _objectMinConfidence = 0.6;

  // Sound monitoring
  bool _soundMonitoringEnabled = false;
  bool _soundMonitoringBackground = false;
  double _soundAlertThreshold = 0.6;
  bool _soundHapticsEnabled = true;
  bool _soundVoiceAlertsEnabled = false;

  // AI assistant
  bool _aiSpeakResponses = false;
  bool _aiOfflineFallback = true;

  // English → ASL
  bool _englishToAslUseAi = false;
  double _aslPlaybackSpeed = 1.0;

  /// Creates an [AppConfig] instance and begins loading persisted settings.
  AppConfig() {
    unawaited(_load());
  }

  bool get isLoaded => _isLoaded;

  // Getters
  ThemeMode get themeMode => _themeMode;
  double get textScaleFactor => _textScaleFactor;
  bool get highContrastMode => _highContrastMode;
  bool get reduceMotion => _reduceMotion;
  String get languageCode => _languageCode;

  bool get ttsEnabled => _ttsEnabled;
  double get ttsVolume => _ttsVolume;
  double get ttsRate => _ttsRate;
  double get ttsPitch => _ttsPitch;
  bool get ttsSpatialCues => _ttsSpatialCues;

  bool get objectAudioAlertsEnabled => _objectAudioAlertsEnabled;
  Duration get objectAudioAlertsCooldown => Duration(milliseconds: _objectAudioAlertsCooldownMs);
  double get objectMinConfidence => _objectMinConfidence;

  bool get soundMonitoringEnabled => _soundMonitoringEnabled;
  bool get soundMonitoringBackground => _soundMonitoringBackground;
  double get soundAlertThreshold => _soundAlertThreshold;
  bool get soundHapticsEnabled => _soundHapticsEnabled;
  bool get soundVoiceAlertsEnabled => _soundVoiceAlertsEnabled;

  bool get aiSpeakResponses => _aiSpeakResponses;
  bool get aiOfflineFallback => _aiOfflineFallback;

  bool get englishToAslUseAi => _englishToAslUseAi;
  double get aslPlaybackSpeed => _aslPlaybackSpeed;

  Future<void> _load() async {
    _prefs ??= await SharedPreferences.getInstance();

    _themeMode = ThemeMode.values[_prefs!.getInt(_kThemeMode) ?? ThemeMode.system.index];
    _textScaleFactor = _prefs!.getDouble(_kTextScale) ?? 1.0;
    _highContrastMode = _prefs!.getBool(_kHighContrast) ?? false;
    _reduceMotion = _prefs!.getBool(_kReduceMotion) ?? false;
    _languageCode = _prefs!.getString(_kLanguageCode) ?? 'en';

    _ttsEnabled = _prefs!.getBool(_kTtsEnabled) ?? true;
    _ttsVolume = _prefs!.getDouble(_kTtsVolume) ?? 0.9;
    _ttsRate = _prefs!.getDouble(_kTtsRate) ?? 0.5;
    _ttsPitch = _prefs!.getDouble(_kTtsPitch) ?? 1.0;
    _ttsSpatialCues = _prefs!.getBool(_kTtsSpatialCues) ?? true;

    _objectAudioAlertsEnabled = _prefs!.getBool(_kObjectAudioAlertsEnabled) ?? true;
    _objectAudioAlertsCooldownMs = _prefs!.getInt(_kObjectAudioAlertsCooldownMs) ?? 2500;
    _objectMinConfidence = _prefs!.getDouble(_kObjectMinConfidence) ?? 0.6;

    _soundMonitoringEnabled = _prefs!.getBool(_kSoundMonitoringEnabled) ?? false;
    _soundMonitoringBackground = _prefs!.getBool(_kSoundMonitoringBackground) ?? false;
    _soundAlertThreshold = _prefs!.getDouble(_kSoundAlertThreshold) ?? 0.6;
    _soundHapticsEnabled = _prefs!.getBool(_kSoundHapticsEnabled) ?? true;
    _soundVoiceAlertsEnabled = _prefs!.getBool(_kSoundVoiceAlertsEnabled) ?? false;

    _aiSpeakResponses = _prefs!.getBool(_kAiSpeakResponses) ?? false;
    _aiOfflineFallback = _prefs!.getBool(_kAiOfflineFallback) ?? true;

    _englishToAslUseAi = _prefs!.getBool(_kEnglishToAslUseAi) ?? false;
    _aslPlaybackSpeed = _prefs!.getDouble(_kAslPlaybackSpeed) ?? 1.0;

    _isLoaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    _prefs ??= await SharedPreferences.getInstance();

    await _prefs!.setInt(_kThemeMode, _themeMode.index);
    await _prefs!.setDouble(_kTextScale, _textScaleFactor);
    await _prefs!.setBool(_kHighContrast, _highContrastMode);
    await _prefs!.setBool(_kReduceMotion, _reduceMotion);
    await _prefs!.setString(_kLanguageCode, _languageCode);

    await _prefs!.setBool(_kTtsEnabled, _ttsEnabled);
    await _prefs!.setDouble(_kTtsVolume, _ttsVolume);
    await _prefs!.setDouble(_kTtsRate, _ttsRate);
    await _prefs!.setDouble(_kTtsPitch, _ttsPitch);
    await _prefs!.setBool(_kTtsSpatialCues, _ttsSpatialCues);

    await _prefs!.setBool(_kObjectAudioAlertsEnabled, _objectAudioAlertsEnabled);
    await _prefs!.setInt(_kObjectAudioAlertsCooldownMs, _objectAudioAlertsCooldownMs);
    await _prefs!.setDouble(_kObjectMinConfidence, _objectMinConfidence);

    await _prefs!.setBool(_kSoundMonitoringEnabled, _soundMonitoringEnabled);
    await _prefs!.setBool(_kSoundMonitoringBackground, _soundMonitoringBackground);
    await _prefs!.setDouble(_kSoundAlertThreshold, _soundAlertThreshold);
    await _prefs!.setBool(_kSoundHapticsEnabled, _soundHapticsEnabled);
    await _prefs!.setBool(_kSoundVoiceAlertsEnabled, _soundVoiceAlertsEnabled);

    await _prefs!.setBool(_kAiSpeakResponses, _aiSpeakResponses);
    await _prefs!.setBool(_kAiOfflineFallback, _aiOfflineFallback);

    await _prefs!.setBool(_kEnglishToAslUseAi, _englishToAslUseAi);
    await _prefs!.setDouble(_kAslPlaybackSpeed, _aslPlaybackSpeed);
  }

  // Setters

  set themeMode(ThemeMode value) {
    if (_themeMode == value) return;
    _themeMode = value;
    notifyListeners();
    unawaited(_save());
  }

  set textScaleFactor(double value) {
    final clamped = value.clamp(0.8, 2.0);
    if (_textScaleFactor == clamped) return;
    _textScaleFactor = clamped;
    notifyListeners();
    unawaited(_save());
  }

  set highContrastMode(bool value) {
    if (_highContrastMode == value) return;
    _highContrastMode = value;
    notifyListeners();
    unawaited(_save());
  }

  set reduceMotion(bool value) {
    if (_reduceMotion == value) return;
    _reduceMotion = value;
    notifyListeners();
    unawaited(_save());
  }

  set languageCode(String value) {
    if (_languageCode == value) return;
    _languageCode = value;
    notifyListeners();
    unawaited(_save());
  }

  set ttsEnabled(bool value) {
    if (_ttsEnabled == value) return;
    _ttsEnabled = value;
    notifyListeners();
    unawaited(_save());
  }

  set ttsVolume(double value) {
    final clamped = value.clamp(0.0, 1.0);
    if (_ttsVolume == clamped) return;
    _ttsVolume = clamped;
    notifyListeners();
    unawaited(_save());
  }

  set ttsRate(double value) {
    final clamped = value.clamp(0.1, 1.0);
    if (_ttsRate == clamped) return;
    _ttsRate = clamped;
    notifyListeners();
    unawaited(_save());
  }

  set ttsPitch(double value) {
    final clamped = value.clamp(0.5, 2.0);
    if (_ttsPitch == clamped) return;
    _ttsPitch = clamped;
    notifyListeners();
    unawaited(_save());
  }

  set ttsSpatialCues(bool value) {
    if (_ttsSpatialCues == value) return;
    _ttsSpatialCues = value;
    notifyListeners();
    unawaited(_save());
  }

  set objectAudioAlertsEnabled(bool value) {
    if (_objectAudioAlertsEnabled == value) return;
    _objectAudioAlertsEnabled = value;
    notifyListeners();
    unawaited(_save());
  }

  set objectAudioAlertsCooldownMs(int value) {
    final clamped = value.clamp(500, 15000);
    if (_objectAudioAlertsCooldownMs == clamped) return;
    _objectAudioAlertsCooldownMs = clamped;
    notifyListeners();
    unawaited(_save());
  }

  set objectMinConfidence(double value) {
    final clamped = value.clamp(0.1, 0.95);
    if (_objectMinConfidence == clamped) return;
    _objectMinConfidence = clamped;
    notifyListeners();
    unawaited(_save());
  }

  set soundMonitoringEnabled(bool value) {
    if (_soundMonitoringEnabled == value) return;
    _soundMonitoringEnabled = value;
    notifyListeners();
    unawaited(_save());
  }

  set soundMonitoringBackground(bool value) {
    if (_soundMonitoringBackground == value) return;
    _soundMonitoringBackground = value;
    notifyListeners();
    unawaited(_save());
  }

  set soundAlertThreshold(double value) {
    final clamped = value.clamp(0.05, 1.0);
    if (_soundAlertThreshold == clamped) return;
    _soundAlertThreshold = clamped;
    notifyListeners();
    unawaited(_save());
  }

  set soundHapticsEnabled(bool value) {
    if (_soundHapticsEnabled == value) return;
    _soundHapticsEnabled = value;
    notifyListeners();
    unawaited(_save());
  }

  set soundVoiceAlertsEnabled(bool value) {
    if (_soundVoiceAlertsEnabled == value) return;
    _soundVoiceAlertsEnabled = value;
    notifyListeners();
    unawaited(_save());
  }

  set aiSpeakResponses(bool value) {
    if (_aiSpeakResponses == value) return;
    _aiSpeakResponses = value;
    notifyListeners();
    unawaited(_save());
  }

  set aiOfflineFallback(bool value) {
    if (_aiOfflineFallback == value) return;
    _aiOfflineFallback = value;
    notifyListeners();
    unawaited(_save());
  }

  set englishToAslUseAi(bool value) {
    if (_englishToAslUseAi == value) return;
    _englishToAslUseAi = value;
    notifyListeners();
    unawaited(_save());
  }

  set aslPlaybackSpeed(double value) {
    final clamped = value.clamp(0.25, 2.5);
    if (_aslPlaybackSpeed == clamped) return;
    _aslPlaybackSpeed = clamped;
    notifyListeners();
    unawaited(_save());
  }

  /// Resets all settings to default values.
  Future<void> resetToDefaults() async {
    _themeMode = ThemeMode.system;
    _textScaleFactor = 1.0;
    _highContrastMode = false;
    _reduceMotion = false;
    _languageCode = 'en';

    _ttsEnabled = true;
    _ttsVolume = 0.9;
    _ttsRate = 0.5;
    _ttsPitch = 1.0;
    _ttsSpatialCues = true;

    _objectAudioAlertsEnabled = true;
    _objectAudioAlertsCooldownMs = 2500;
    _objectMinConfidence = 0.6;

    _soundMonitoringEnabled = false;
    _soundMonitoringBackground = false;
    _soundAlertThreshold = 0.6;
    _soundHapticsEnabled = true;
    _soundVoiceAlertsEnabled = false;

    _aiSpeakResponses = false;
    _aiOfflineFallback = true;

    _englishToAslUseAi = false;
    _aslPlaybackSpeed = 1.0;

    notifyListeners();
    await _save();
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
