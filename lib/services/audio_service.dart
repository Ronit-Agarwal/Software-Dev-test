import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:signsync/core/error/exceptions.dart';
import 'package:signsync/core/logging/logger_service.dart';
import 'package:signsync/models/noise_event.dart';

/// Service for audio recording and sound detection.
///
/// This service handles microphone access, audio stream processing,
/// and noise event detection for the sound alerts feature.
class AudioService with ChangeNotifier {
  FlutterSoundRecorder? _recorder;
  FlutterSoundPlayer? _player;
  StreamSubscription? _audioSubscription;
  bool _isRecording = false;
  bool _isInitialized = false;
  String? _error;
  List<NoiseEvent> _detectedEvents = [];

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isRecording => _isRecording;
  String? get error => _error;
  List<NoiseEvent> get detectedEvents => _detectedEvents;

  double _alertThreshold = 0.3;

  static const int _waveformSamples = 256;
  static const int _spectrumBins = 48;

  // Audio streams for visualization
  final _audioLevelController = StreamController<double>.broadcast();
  final _waveformController = StreamController<List<double>>.broadcast();
  final _spectrumController = StreamController<List<double>>.broadcast();

  Stream<double> get audioLevelStream => _audioLevelController.stream;
  Stream<List<double>> get waveformStream => _waveformController.stream;
  Stream<List<double>> get spectrumStream => _spectrumController.stream;

  /// Initializes the audio service.
  Future<void> initialize() async {
    if (_isInitialized) {
      LoggerService.warn('Audio service already initialized');
      return;
    }

    try {
      LoggerService.info('Initializing audio service');

      _recorder = FlutterSoundRecorder();
      _player = FlutterSoundPlayer();

      // Open the audio session
      await _recorder!.openAudioSession(
        focus: AudioFocus.requestFocusAndDuckOthers,
        category: SessionCategory.playAndRecord,
        mode: SessionMode.modeDefault,
        device: AudioDevice.speaker,
      );

      await _player!.openAudioSession();

      _isInitialized = true;
      notifyListeners();
      LoggerService.info('Audio service initialized successfully');
    } catch (e, stack) {
      _error = 'Failed to initialize audio: $e';
      LoggerService.error('Audio initialization failed', error: e, stack: stack);
      rethrow;
    }
  }

  /// Starts recording audio for sound detection.
  ///
  /// [onNoiseDetected] - Callback when a noise event is detected.
  /// [alertThreshold] - Minimum RMS level required to emit a detection event.
  Future<void> startRecording({
    void Function(NoiseEvent event)? onNoiseDetected,
    double alertThreshold = 0.3,
  }) async {
    if (!_isInitialized) {
      throw const AudioException('Audio service not initialized');
    }

    if (_isRecording) {
      LoggerService.warn('Already recording');
      return;
    }

    try {
      LoggerService.info('Starting audio recording');
      _error = null;
      _alertThreshold = alertThreshold.clamp(0.0, 1.0);

      // Configure the recorder
      await _recorder!.setSubscriptionDuration(const Duration(milliseconds: 100));

      // Start recording to a stream
      final stream = await _recorder!.startRecorder(
        toStream: true,
        codec: Codec.pcm16,
        sampleRate: 16000,
        numChannels: 1,
      );

      _isRecording = true;
      notifyListeners();

      // Subscribe to audio stream
      _audioSubscription = stream!.listen((data) {
        _processAudioData(data, onNoiseDetected);
      });

      LoggerService.info('Audio recording started');
    } catch (e, stack) {
      _error = 'Failed to start recording: $e';
      LoggerService.error('Failed to start recording', error: e, stack: stack);
      _isRecording = false;
      rethrow;
    }
  }

  /// Processes audio data for noise detection.
  void _processAudioData(
    Uint8List data,
    void Function(NoiseEvent event)? onNoiseDetected,
  ) {
    // Calculate audio level from PCM16 data.
    // We use RMS to get a stable amplitude estimate.
    final samples = Int16List.view(data.buffer);
    if (samples.isEmpty) return;

    double sumSq = 0.0;
    for (final s in samples) {
      final normalized = s / 32768.0;
      sumSq += normalized * normalized;
    }

    final level = math.sqrt(sumSq / samples.length).clamp(0.0, 1.0);

    // Emit level for visualization
    if (!_audioLevelController.isClosed) {
      _audioLevelController.add(level);
    }

    // Emit waveform and spectrum for visualization.
    final waveform = _extractWaveform(samples);
    if (!_waveformController.isClosed) {
      _waveformController.add(waveform);
    }

    final spectrum = _computeSpectrum(waveform);
    if (!_spectrumController.isClosed) {
      _spectrumController.add(spectrum);
    }

    // Detect sound events based on threshold.
    if (level > _alertThreshold) {
      final zcr = _zeroCrossingRate(waveform);
      final centroid = _spectralCentroid(spectrum);
      final type = _classifyNoise(level: level, zcr: zcr, centroid: centroid);

      final event = NoiseEvent.fromAudio(
        type: type,
        intensity: level,
        alertThreshold: _alertThreshold,
        metadata: {
          'zcr': zcr,
          'centroid': centroid,
          'sampleRate': 16000,
        },
      );

      _detectedEvents.add(event);
      if (_detectedEvents.length > 200) {
        _detectedEvents.removeAt(0);
      }

      onNoiseDetected?.call(event);
      notifyListeners();

      LoggerService.debug(
        'Noise detected: ${event.type.displayName} '
        '(intensity: ${event.intensity.toStringAsFixed(2)})',
      );
    }
  }

  List<double> _extractWaveform(Int16List samples) {
    final step = math.max(1, samples.length ~/ _waveformSamples);
    final out = <double>[];

    for (int i = 0; i < samples.length && out.length < _waveformSamples; i += step) {
      out.add((samples[i] / 32768.0).clamp(-1.0, 1.0));
    }

    return out;
  }

  List<double> _computeSpectrum(List<double> waveform) {
    if (waveform.isEmpty) return const <double>[];

    final n = waveform.length;
    final bins = math.min(_spectrumBins, n);
    final magnitudes = List<double>.filled(bins, 0.0);

    for (int k = 0; k < bins; k++) {
      double re = 0.0;
      double im = 0.0;

      for (int t = 0; t < n; t++) {
        final angle = 2 * math.pi * k * t / n;
        re += waveform[t] * math.cos(angle);
        im -= waveform[t] * math.sin(angle);
      }

      magnitudes[k] = math.sqrt(re * re + im * im) / n;
    }

    final maxMag = magnitudes.fold<double>(0.0, (m, v) => math.max(m, v));
    if (maxMag <= 0) return magnitudes;

    for (int i = 0; i < magnitudes.length; i++) {
      magnitudes[i] = (magnitudes[i] / maxMag).clamp(0.0, 1.0);
    }

    return magnitudes;
  }

  double _zeroCrossingRate(List<double> waveform) {
    if (waveform.length < 2) return 0.0;

    int crossings = 0;
    for (int i = 1; i < waveform.length; i++) {
      final a = waveform[i - 1];
      final b = waveform[i];
      if ((a >= 0 && b < 0) || (a < 0 && b >= 0)) {
        crossings++;
      }
    }

    return crossings / (waveform.length - 1);
  }

  double _spectralCentroid(List<double> spectrum) {
    if (spectrum.isEmpty) return 0.0;

    double sum = 0.0;
    double weighted = 0.0;

    for (int i = 0; i < spectrum.length; i++) {
      final mag = spectrum[i];
      sum += mag;
      weighted += i * mag;
    }

    if (sum <= 0) return 0.0;
    return (weighted / sum) / (spectrum.length - 1);
  }

  /// Classifies the noise type based on simple audio features.
  NoiseType _classifyNoise({
    required double level,
    required double zcr,
    required double centroid,
  }) {
    if (level > 0.85 && centroid > 0.6) {
      return NoiseType.alarm;
    }

    if (level > 0.75 && centroid > 0.5 && zcr > 0.08) {
      return NoiseType.siren;
    }

    if (centroid < 0.18 && level > 0.35) {
      return NoiseType.vehicle;
    }

    if (level > 0.55 && zcr < 0.05) {
      return NoiseType.door;
    }

    if (level > 0.5 && zcr > 0.18 && centroid < 0.35) {
      return NoiseType.knock;
    }

    if (centroid > 0.35 && centroid < 0.7 && level > 0.25) {
      return NoiseType.speech;
    }

    if (centroid > 0.55 && level > 0.35) {
      return NoiseType.doorbell;
    }

    return NoiseType.custom;
  }

  /// Stops recording audio.
  Future<void> stopRecording() async {
    if (!_isRecording) {
      LoggerService.warn('Not currently recording');
      return;
    }

    try {
      LoggerService.info('Stopping audio recording');
      await _audioSubscription?.cancel();
      _audioSubscription = null;

      await _recorder!.stopRecorder();
      _isRecording = false;
      notifyListeners();

      LoggerService.info('Audio recording stopped');
    } catch (e, stack) {
      _error = 'Failed to stop recording: $e';
      LoggerService.error('Failed to stop recording', error: e, stack: stack);
      rethrow;
    }
  }

  /// Plays a sound for alert feedback.
  Future<void> playAlertSound() async {
    if (!_isInitialized) return;

    try {
      LoggerService.info('Playing alert sound');
      // In a real implementation, this would play a sound file
    } catch (e, stack) {
      LoggerService.error('Failed to play alert sound', error: e, stack: stack);
    }
  }

  /// Clears the detected events history.
  void clearEvents() {
    _detectedEvents.clear();
    notifyListeners();
  }

  /// Gets the current audio level for visualization.
  Future<double> getCurrentLevel() async {
    if (!_isInitialized || !_isRecording) return 0.0;
    return 0.0; // In a real implementation, this would return the current level
  }

  /// Checks if the device has a microphone.
  Future<bool> hasMicrophone() async {
    // In a real implementation, this would check device capabilities
    return true;
  }

  /// Sets the audio mode for the device.
  Future<void> setAudioMode(bool speakerMode) async {
    if (!_isInitialized) return;

    try {
      await _recorder!.setAudioFocus(
        focus: AudioFocus.requestFocusAndDuckOthers,
      );
    } catch (e, stack) {
      LoggerService.error('Failed to set audio mode', error: e, stack: stack);
    }
  }

  /// Cleans up audio resources.
  Future<void> disposeAsync() async {
    LoggerService.info('Disposing audio service');

    await _audioSubscription?.cancel();
    _audioSubscription = null;

    if (_isRecording) {
      await _recorder?.stopRecorder();
    }

    await _recorder?.closeAudioSession();
    await _player?.closeAudioSession();

    _recorder = null;
    _player = null;
    _isInitialized = false;
    _isRecording = false;

    await _audioLevelController.close();
    await _waveformController.close();
    await _spectrumController.close();
  }

  @override
  void dispose() {
    unawaited(disposeAsync());
    super.dispose();
  }
}

/// Custom exception for audio-related errors.
class AudioException implements Exception {
  final String message;

  const AudioException(this.message);

  @override
  String toString() => 'AudioException: $message';
}
