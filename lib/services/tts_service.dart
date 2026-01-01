import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:signsync/core/logging/logger_service.dart';

class TtsService with ChangeNotifier {
  FlutterTts? _tts;
  bool _isInitialized = false;
  bool _isAvailable = false;
  bool _isSpeaking = false;

  double _volume = 1.0;
  double _rate = 0.5;
  double _pitch = 1.0;
  String _language = 'en-US';

  bool get isInitialized => _isInitialized;
  bool get isAvailable => _isAvailable;
  bool get isSpeaking => _isSpeaking;

  double get volume => _volume;
  double get rate => _rate;
  double get pitch => _pitch;
  String get language => _language;

  Future<void> initialize({
    String language = 'en-US',
    double? volume,
    double? rate,
    double? pitch,
  }) async {
    if (_isInitialized) return;

    _language = language;
    _volume = (volume ?? _volume).clamp(0.0, 1.0);
    _rate = (rate ?? _rate).clamp(0.0, 1.0);
    _pitch = (pitch ?? _pitch).clamp(0.5, 2.0);

    try {
      _tts = FlutterTts();

      await _tts!.setLanguage(_language);
      await _tts!.setVolume(_volume);
      await _tts!.setSpeechRate(_rate);
      await _tts!.setPitch(_pitch);

      _tts!.setStartHandler(() {
        _isSpeaking = true;
        notifyListeners();
      });
      _tts!.setCompletionHandler(() {
        _isSpeaking = false;
        notifyListeners();
      });
      _tts!.setCancelHandler(() {
        _isSpeaking = false;
        notifyListeners();
      });
      _tts!.setErrorHandler((msg) {
        LoggerService.warn('TTS error: $msg');
        _isSpeaking = false;
        notifyListeners();
      });

      _isAvailable = true;
      _isInitialized = true;
      notifyListeners();
      LoggerService.info('TTS initialized');
    } on MissingPluginException catch (e) {
      _isAvailable = false;
      _isInitialized = true;
      LoggerService.warn('TTS unavailable (MissingPluginException): $e');
      notifyListeners();
    } catch (e, stack) {
      _isAvailable = false;
      _isInitialized = true;
      LoggerService.error('Failed to initialize TTS', error: e, stackTrace: stack);
      notifyListeners();
    }
  }

  void updateSettings({
    double? volume,
    double? rate,
    double? pitch,
    String? language,
  }) {
    if (volume != null) _volume = volume.clamp(0.0, 1.0);
    if (rate != null) _rate = rate.clamp(0.0, 1.0);
    if (pitch != null) _pitch = pitch.clamp(0.5, 2.0);
    if (language != null) _language = language;

    if (_tts != null && _isAvailable) {
      unawaited(_tts!.setVolume(_volume));
      unawaited(_tts!.setSpeechRate(_rate));
      unawaited(_tts!.setPitch(_pitch));
      unawaited(_tts!.setLanguage(_language));
    }

    notifyListeners();
  }

  Future<void> speak(
    String text, {
    double? volume,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (!_isAvailable || _tts == null) {
      LoggerService.debug('TTS speak skipped (unavailable): $text');
      return;
    }

    final targetVolume = (volume ?? _volume).clamp(0.0, 1.0);

    final completer = Completer<void>();
    void done() {
      if (!completer.isCompleted) completer.complete();
    }

    void Function()? prevCompletion;
    void Function()? prevCancel;

    _tts!.setCompletionHandler(() {
      _isSpeaking = false;
      notifyListeners();
      done();
      prevCompletion?.call();
    });
    _tts!.setCancelHandler(() {
      _isSpeaking = false;
      notifyListeners();
      done();
      prevCancel?.call();
    });

    try {
      await _tts!.setVolume(targetVolume);
      _isSpeaking = true;
      notifyListeners();
      await _tts!.speak(text);
      await completer.future.timeout(const Duration(seconds: 10), onTimeout: () {
        LoggerService.warn('TTS timeout');
        return;
      });
    } catch (e, stack) {
      _isSpeaking = false;
      LoggerService.error('TTS speak failed', error: e, stackTrace: stack);
      notifyListeners();
    }
  }

  Future<void> stop() async {
    if (_tts == null || !_isAvailable) return;
    try {
      await _tts!.stop();
    } catch (e) {
      LoggerService.warn('TTS stop failed: $e');
    }
  }

  @override
  void dispose() {
    unawaited(stop());
    _tts = null;
    super.dispose();
  }
}
