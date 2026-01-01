import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:signsync/core/logging/logger_service.dart';

/// Text-to-speech service backed by native platform TTS.
///
/// - iOS: AVSpeechSynthesizer
/// - Android: TextToSpeech
class TtsService with ChangeNotifier {
  final FlutterTts _tts;

  bool _isInitialized = false;
  bool _isSpeaking = false;
  String? _error;

  String _language = 'en-US';
  double _volume = 0.9;
  double _rate = 0.5;
  double _pitch = 1.0;

  /// Creates a new [TtsService].
  TtsService({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  bool get isInitialized => _isInitialized;
  bool get isSpeaking => _isSpeaking;
  String? get error => _error;

  String get language => _language;
  double get volume => _volume;
  double get rate => _rate;
  double get pitch => _pitch;

  /// Initializes the TTS engine.
  Future<void> initialize({
    String language = 'en-US',
    double? volume,
    double? rate,
    double? pitch,
  }) async {
    if (_isInitialized) return;

    try {
      _error = null;
      _language = language;
      _volume = volume ?? _volume;
      _rate = rate ?? _rate;
      _pitch = pitch ?? _pitch;

      await _tts.setLanguage(_language);
      await _tts.setVolume(_volume);
      await _tts.setSpeechRate(_rate);
      await _tts.setPitch(_pitch);

      _tts.setStartHandler(() {
        _isSpeaking = true;
        notifyListeners();
      });
      _tts.setCompletionHandler(() {
        _isSpeaking = false;
        notifyListeners();
      });
      _tts.setErrorHandler((message) {
        _error = message;
        _isSpeaking = false;
        notifyListeners();
      });

      _isInitialized = true;
      notifyListeners();
      LoggerService.info('TTS initialized');
    } catch (e, stack) {
      _error = 'TTS init failed: $e';
      LoggerService.error('TTS initialization failed', error: e, stack: stack);
      rethrow;
    }
  }

  /// Applies runtime TTS settings.
  Future<void> applySettings({
    String? language,
    double? volume,
    double? rate,
    double? pitch,
  }) async {
    if (!_isInitialized) {
      await initialize(
        language: language ?? _language,
        volume: volume ?? _volume,
        rate: rate ?? _rate,
        pitch: pitch ?? _pitch,
      );
      return;
    }

    _language = language ?? _language;
    _volume = volume ?? _volume;
    _rate = rate ?? _rate;
    _pitch = pitch ?? _pitch;

    await _tts.setLanguage(_language);
    await _tts.setVolume(_volume);
    await _tts.setSpeechRate(_rate);
    await _tts.setPitch(_pitch);

    notifyListeners();
  }

  /// Speaks [text] using the configured TTS engine.
  Future<void> speak(
    String text, {
    bool interrupt = true,
  }) async {
    if (text.trim().isEmpty) return;

    if (!_isInitialized) {
      await initialize();
    }

    try {
      _error = null;
      if (interrupt) {
        await _tts.stop();
      }
      await _tts.speak(text);
    } catch (e, stack) {
      _error = 'TTS speak failed: $e';
      LoggerService.error('TTS speak failed', error: e, stack: stack);
      notifyListeners();
    }
  }

  /// Stops any ongoing speech.
  Future<void> stop() async {
    if (!_isInitialized) return;
    await _tts.stop();
  }

  /// Releases TTS resources.
  Future<void> disposeAsync() async {
    try {
      await _tts.stop();
    } catch (_) {
      // Ignore.
    }
  }

  @override
  void dispose() {
    unawaited(disposeAsync());
    super.dispose();
  }
}
