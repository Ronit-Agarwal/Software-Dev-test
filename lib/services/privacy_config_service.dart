import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signsync/core/logging/logger_service.dart';
import 'package:signsync/core/privacy/privacy_settings.dart';

class PrivacyConfigService with ChangeNotifier {
  static const _keyAcceptedPrivacyPolicy = 'privacy.accepted_policy';
  static const _keyCrashReporting = 'privacy.crash_reporting';
  static const _keyAnalytics = 'privacy.analytics';
  static const _keyCloudAi = 'privacy.cloud_ai';

  SharedPreferences? _prefs;
  bool _isInitialized = false;

  bool _acceptedPolicy = false;
  bool _crashReportingEnabled = false;
  bool _analyticsEnabled = false;
  bool _cloudAiEnabled = false;

  bool get isInitialized => _isInitialized;
  bool get acceptedPolicy => _acceptedPolicy;
  bool get crashReportingEnabled => _crashReportingEnabled;
  bool get analyticsEnabled => _analyticsEnabled;
  bool get cloudAiEnabled => _cloudAiEnabled;

  Future<void> initialize() async {
    if (_isInitialized) return;

    _prefs = await SharedPreferences.getInstance();
    _acceptedPolicy = _prefs?.getBool(_keyAcceptedPrivacyPolicy) ?? false;
    _crashReportingEnabled = _prefs?.getBool(_keyCrashReporting) ?? false;
    _analyticsEnabled = _prefs?.getBool(_keyAnalytics) ?? false;
    _cloudAiEnabled = _prefs?.getBool(_keyCloudAi) ?? false;

    PrivacySettings.update(
      crashReporting: _crashReportingEnabled,
      analytics: _analyticsEnabled,
      cloudAi: _cloudAiEnabled,
    );

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> setAcceptedPolicy(bool value) async {
    await _ensurePrefs();
    _acceptedPolicy = value;
    await _prefs!.setBool(_keyAcceptedPrivacyPolicy, value);
    notifyListeners();
  }

  Future<void> setCrashReportingEnabled(bool value) async {
    await _ensurePrefs();
    _crashReportingEnabled = value;
    await _prefs!.setBool(_keyCrashReporting, value);
    PrivacySettings.update(
      crashReporting: _crashReportingEnabled,
      analytics: _analyticsEnabled,
      cloudAi: _cloudAiEnabled,
    );
    notifyListeners();
  }

  Future<void> setAnalyticsEnabled(bool value) async {
    await _ensurePrefs();
    _analyticsEnabled = value;
    await _prefs!.setBool(_keyAnalytics, value);
    PrivacySettings.update(
      crashReporting: _crashReportingEnabled,
      analytics: _analyticsEnabled,
      cloudAi: _cloudAiEnabled,
    );
    notifyListeners();
  }

  Future<void> setCloudAiEnabled(bool value) async {
    await _ensurePrefs();
    _cloudAiEnabled = value;
    await _prefs!.setBool(_keyCloudAi, value);
    PrivacySettings.update(
      crashReporting: _crashReportingEnabled,
      analytics: _analyticsEnabled,
      cloudAi: _cloudAiEnabled,
    );
    notifyListeners();
  }

  Future<void> reset() async {
    await _ensurePrefs();
    await _prefs!.remove(_keyAcceptedPrivacyPolicy);
    await _prefs!.remove(_keyCrashReporting);
    await _prefs!.remove(_keyAnalytics);
    await _prefs!.remove(_keyCloudAi);

    _acceptedPolicy = false;
    _crashReportingEnabled = false;
    _analyticsEnabled = false;
    _cloudAiEnabled = false;

    PrivacySettings.update(
      crashReporting: _crashReportingEnabled,
      analytics: _analyticsEnabled,
      cloudAi: _cloudAiEnabled,
    );

    notifyListeners();
  }

  Future<void> _ensurePrefs() async {
    if (_prefs != null) return;
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (e) {
      LoggerService.warn('Failed to access SharedPreferences in PrivacyConfigService', error: e);
      rethrow;
    }
  }
}
