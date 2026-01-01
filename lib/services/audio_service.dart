import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:signsync/core/logging/logger_service.dart';
import 'package:signsync/models/noise_event.dart';

/// Service for real-time microphone monitoring.
///
/// Provides:
/// - PCM streaming (16kHz mono)
/// - Noise level monitoring
/// - Lightweight sound classification (heuristic with optional ML future)
/// - Waveform + spectrum data streams for visualization
/// - Event history + smart alert hooks
class AudioService with ChangeNotifier {
  FlutterSoundRecorder? _recorder;

  StreamSubscription? _audioSubscription;

  bool _isRecording = false;
  bool _isInitialized = false;
  String? _error;

  final List<NoiseEvent> _detectedEvents = [];

  // Visualization streams
  final _audioLevelController = StreamController<double>.broadcast();
  final _dbLevelController = StreamController<double>.broadcast();
  final _waveformController = StreamController<List<double>>.broadcast();
  final _spectrumController = StreamController<List<double>>.broadcast();
  final _eventController = StreamController<NoiseEvent>.broadcast();

  // Settings
  double _noiseAlertThreshold = 0.30; // normalized RMS [0..1]
  Duration _eventCooldown = const Duration(seconds: 2);
  bool _hapticsEnabled = true;

  // Internal state
  double _prevRms = 0.0;
  DateTime? _lastEventAt;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isRecording => _isRecording;
  String? get error => _error;
  List<NoiseEvent> get detectedEvents => List.unmodifiable(_detectedEvents);

  Stream<double> get audioLevelStream => _audioLevelController.stream;
  Stream<double> get dbLevelStream => _dbLevelController.stream;
  Stream<List<double>> get waveformStream => _waveformController.stream;
  Stream<List<double>> get spectrumStream => _spectrumController.stream;
  Stream<NoiseEvent> get eventsStream => _eventController.stream;

  bool get hapticsEnabled => _hapticsEnabled;

  set hapticsEnabled(bool value) {
    _hapticsEnabled = value;
  }

  void updateSettings({
    double? noiseAlertThreshold,
    Duration? eventCooldown,
  }) {
    if (noiseAlertThreshold != null) {
      _noiseAlertThreshold = noiseAlertThreshold.clamp(0.05, 0.95);
    }
    if (eventCooldown != null) {
      _eventCooldown = eventCooldown;
    }
    notifyListeners();
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      LoggerService.info('Initializing audio service');
      _recorder = FlutterSoundRecorder();

      await _recorder!.openAudioSession(
        focus: AudioFocus.requestFocusAndDuckOthers,
        category: SessionCategory.playAndRecord,
        mode: SessionMode.modeDefault,
        device: AudioDevice.speaker,
      );

      _isInitialized = true;
      notifyListeners();
    } catch (e, stack) {
      _error = 'Failed to initialize audio: $e';
      LoggerService.error('Audio initialization failed', error: e, stackTrace: stack);
      rethrow;
    }
  }

  Future<void> startRecording({
    void Function(NoiseEvent event)? onNoiseDetected,
  }) async {
    if (!_isInitialized) {
      throw const AudioException('Audio service not initialized');
    }
    if (_isRecording) return;

    try {
      _error = null;
      _prevRms = 0.0;
      _lastEventAt = null;

      await _recorder!.setSubscriptionDuration(const Duration(milliseconds: 80));

      final stream = await _recorder!.startRecorder(
        toStream: true,
        codec: Codec.pcm16,
        sampleRate: 16000,
        numChannels: 1,
      );

      _isRecording = true;
      notifyListeners();

      _audioSubscription = stream!.listen((data) {
        _processAudioData(data, onNoiseDetected);
      });

      LoggerService.info('Audio recording started');
    } catch (e, stack) {
      _error = 'Failed to start recording: $e';
      LoggerService.error('Failed to start recording', error: e, stackTrace: stack);
      _isRecording = false;
      notifyListeners();
      rethrow;
    }
  }

  void _processAudioData(
    Uint8List data,
    void Function(NoiseEvent event)? onNoiseDetected,
  ) {
    if (data.isEmpty) return;

    // PCM16 from flutter_sound is little-endian signed.
    final samples = Int16List.view(data.buffer, data.offsetInBytes, data.lengthInBytes ~/ 2);
    if (samples.isEmpty) return;

    final rms = _computeRms(samples);
    final level = rms.clamp(0.0, 1.0);

    final db = _dbfsFromRms(rms);

    if (!_audioLevelController.isClosed) {
      _audioLevelController.add(level);
    }
    if (!_dbLevelController.isClosed) {
      _dbLevelController.add(db);
    }

    // Waveform (downsample)
    if (!_waveformController.isClosed) {
      _waveformController.add(_downsample(samples, points: 128));
    }

    // Spectrum (32 bands)
    if (!_spectrumController.isClosed) {
      _spectrumController.add(_computeSpectrumBands(samples, sampleRate: 16000, bands: 32));
    }

    final now = DateTime.now();
    final canEmit = _lastEventAt == null || now.difference(_lastEventAt!) >= _eventCooldown;

    // Transient detection (knock-like)
    final transient = level > _noiseAlertThreshold && _prevRms < (_noiseAlertThreshold * 0.6);

    if (canEmit && (level > _noiseAlertThreshold || transient)) {
      final type = _classify(samples, level: level, db: db, transient: transient);

      final event = NoiseEvent.fromAudio(
        type: type,
        intensity: level,
      );

      _detectedEvents.insert(0, event);
      if (_detectedEvents.length > 200) {
        _detectedEvents.removeRange(200, _detectedEvents.length);
      }

      _lastEventAt = now;
      onNoiseDetected?.call(event);
      if (!_eventController.isClosed) {
        _eventController.add(event);
      }

      if (_hapticsEnabled && event.shouldAlert) {
        HapticFeedback.mediumImpact();
      }

      notifyListeners();
      LoggerService.debug(
        'Sound detected: ${event.type.displayName}',
        extra: {
          'level': level.toStringAsFixed(3),
          'dbfs': db.toStringAsFixed(1),
        },
      );
    }

    _prevRms = level;
  }

  double _computeRms(Int16List samples) {
    double sumSq = 0.0;
    for (final s in samples) {
      final v = s / 32768.0;
      sumSq += v * v;
    }
    return sqrt(sumSq / samples.length);
  }

  double _dbfsFromRms(double rms) {
    if (rms <= 0) return -120.0;
    return 20.0 * (log(rms) / ln10);
  }

  List<double> _downsample(Int16List samples, {required int points}) {
    if (samples.isEmpty || points <= 0) return const [];
    final out = List<double>.filled(points, 0.0);

    final step = max(1, samples.length ~/ points);
    int idx = 0;
    for (int i = 0; i < points; i++) {
      final start = idx;
      final end = min(samples.length, idx + step);
      double acc = 0;
      for (int j = start; j < end; j++) {
        acc += samples[j] / 32768.0;
      }
      out[i] = (acc / max(1, end - start)).clamp(-1.0, 1.0);
      idx = end;
      if (idx >= samples.length) break;
    }

    return out;
  }

  List<double> _computeSpectrumBands(
    Int16List samples, {
    required int sampleRate,
    required int bands,
  }) {
    // Goertzel-based rough magnitude bands (fast and dependency-free)
    final n = min(512, samples.length);
    if (n < 64) return List<double>.filled(bands, 0.0);

    final windowed = List<double>.filled(n, 0.0);
    for (int i = 0; i < n; i++) {
      final w = 0.5 - 0.5 * cos(2 * pi * i / (n - 1));
      windowed[i] = (samples[i] / 32768.0) * w;
    }

    final maxFreq = sampleRate / 2;
    final minFreq = 80;
    final stepHz = (maxFreq - minFreq) / bands;

    final mags = List<double>.filled(bands, 0.0);
    for (int b = 0; b < bands; b++) {
      final target = minFreq + stepHz * b;
      mags[b] = _goertzel(windowed, sampleRate, target);
    }

    final maxMag = mags.fold<double>(0.0, (a, v) => v > a ? v : a);
    if (maxMag <= 0) return List<double>.filled(bands, 0.0);
    return mags.map((m) => (m / maxMag).clamp(0.0, 1.0)).toList();
  }

  double _goertzel(List<double> x, int sampleRate, double freq) {
    final n = x.length;
    final k = (0.5 + (n * freq / sampleRate)).floor();
    final w = (2.0 * pi / n) * k;
    final cosine = cos(w);
    final coeff = 2.0 * cosine;

    double q0 = 0, q1 = 0, q2 = 0;
    for (final v in x) {
      q0 = coeff * q1 - q2 + v;
      q2 = q1;
      q1 = q0;
    }

    final real = q1 - q2 * cosine;
    final imag = q2 * sin(w);
    return sqrt(real * real + imag * imag);
  }

  NoiseType _classify(
    Int16List samples, {
    required double level,
    required double db,
    required bool transient,
  }) {
    // Very lightweight heuristic classifier.
    if (transient && level > 0.45) return NoiseType.knock;

    // compute zcr on subset
    final n = min(samples.length, 400);
    int zc = 0;
    for (int i = 1; i < n; i++) {
      if ((samples[i - 1] >= 0) != (samples[i] >= 0)) zc++;
    }
    final zcr = zc / max(1, n - 1);

    final spectrum = _computeSpectrumBands(samples, sampleRate: 16000, bands: 16);
    double centroid = 0;
    double sum = 0;
    for (int i = 0; i < spectrum.length; i++) {
      final f = (i + 1) / spectrum.length;
      centroid += f * spectrum[i];
      sum += spectrum[i];
    }
    centroid = sum > 0 ? centroid / sum : 0;

    final peak = spectrum.isEmpty ? 0.0 : spectrum.reduce(max);
    final mean = spectrum.isEmpty ? 0.0 : spectrum.reduce((a, b) => a + b) / spectrum.length;

    if (level > 0.75 && peak > 0.85 && peak / max(0.01, mean) > 3.0) {
      return NoiseType.alarm;
    }

    // Vehicle-like: louder + energy concentrated low (low centroid)
    if (level > 0.35 && centroid < 0.35) {
      return NoiseType.vehicle;
    }

    // Speech-like: moderate loudness + higher zcr + mid centroid
    if (level > 0.22 && zcr > 0.10 && centroid >= 0.35 && centroid <= 0.75) {
      return NoiseType.speech;
    }

    if (level > 0.50 && centroid > 0.80) {
      return NoiseType.glassBreak;
    }

    return NoiseType.custom;
  }

  Future<void> stopRecording() async {
    if (!_isRecording) return;

    try {
      await _audioSubscription?.cancel();
      _audioSubscription = null;
      await _recorder!.stopRecorder();
      _isRecording = false;
      notifyListeners();
      LoggerService.info('Audio recording stopped');
    } catch (e, stack) {
      _error = 'Failed to stop recording: $e';
      LoggerService.error('Failed to stop recording', error: e, stackTrace: stack);
      rethrow;
    }
  }

  void clearEvents() {
    _detectedEvents.clear();
    notifyListeners();
  }

  Future<void> shutdown() async {
    try {
      await stopRecording();
    } catch (_) {}

    try {
      await _recorder?.closeAudioSession();
    } catch (_) {}

    _recorder = null;
    _isInitialized = false;

    await _audioLevelController.close();
    await _dbLevelController.close();
    await _waveformController.close();
    await _spectrumController.close();
    await _eventController.close();
  }

  @override
  void dispose() {
    unawaited(shutdown());
    super.dispose();
  }
}

class AudioException implements Exception {
  final String message;

  const AudioException(this.message);

  @override
  String toString() => 'AudioException: $message';
}
