import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:signsync/config/app_config.dart';
import 'package:signsync/core/logging/logger_service.dart';
import 'package:signsync/models/noise_event.dart';
import 'package:signsync/services/audio_alert_service.dart';
import 'package:signsync/services/audio_service.dart';

/// Coordinates continuous sound monitoring and alert feedback.
///
/// This service keeps the microphone stream processing active and
/// triggers optional haptic / spoken alerts based on user settings.
class SoundMonitorService with ChangeNotifier {
  final AudioService _audioService;
  final AudioAlertService _audioAlerts;
  final AppConfig _config;

  StreamSubscription<double>? _levelSub;

  bool _isMonitoring = false;
  String? _error;

  SoundMonitorService({
    required AudioService audioService,
    required AudioAlertService audioAlerts,
    required AppConfig config,
  })  : _audioService = audioService,
        _audioAlerts = audioAlerts,
        _config = config;

  bool get isMonitoring => _isMonitoring;
  String? get error => _error;

  Stream<double> get audioLevelStream => _audioService.audioLevelStream;
  Stream<List<double>> get waveformStream => _audioService.waveformStream;
  Stream<List<double>> get spectrumStream => _audioService.spectrumStream;

  List<NoiseEvent> get events => _audioService.detectedEvents;

  Future<void> start() async {
    if (_isMonitoring) return;

    try {
      _error = null;

      await _audioService.initialize();
      await _audioService.startRecording(
        alertThreshold: _config.soundAlertThreshold,
        onNoiseDetected: _onNoiseDetected,
      );

      _isMonitoring = true;
      notifyListeners();

      _levelSub?.cancel();
      _levelSub = audioLevelStream.listen((_) {});

      LoggerService.info('Sound monitoring started');
    } catch (e, stack) {
      _error = 'Failed to start sound monitoring: $e';
      LoggerService.error('Sound monitoring start failed', error: e, stack: stack);
      _isMonitoring = false;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    if (!_isMonitoring) return;

    try {
      await _levelSub?.cancel();
      _levelSub = null;

      await _audioService.stopRecording();
      _isMonitoring = false;
      notifyListeners();
      LoggerService.info('Sound monitoring stopped');
    } catch (e, stack) {
      _error = 'Failed to stop sound monitoring: $e';
      LoggerService.error('Sound monitoring stop failed', error: e, stack: stack);
      notifyListeners();
    }
  }

  void clearHistory() {
    _audioService.clearEvents();
    notifyListeners();
  }

  void _onNoiseDetected(NoiseEvent event) {
    if (event.shouldAlert && _config.soundHapticsEnabled) {
      HapticFeedback.mediumImpact();
    }

    if (_config.soundVoiceAlertsEnabled) {
      unawaited(_audioAlerts.handleSoundEvent(event));
    }

    notifyListeners();
  }

  @override
  void dispose() {
    final sub = _levelSub;
    if (sub != null) {
      unawaited(sub.cancel());
    }
    unawaited(stop());
    super.dispose();
  }
}
