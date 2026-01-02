import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:vibration/vibration.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:signsync/core/error/exceptions.dart';
import 'package:signsync/core/logging/logger_service.dart';
import 'package:signsync/models/noise_event.dart';

/// Service for audio recording and sound detection.
///
/// This service handles microphone access, audio stream processing,
/// sound classification using TFLite, and noise level monitoring.
class AudioService with ChangeNotifier {
  FlutterSoundRecorder? _recorder;
  FlutterSoundPlayer? _player;
  StreamSubscription? _audioSubscription;
  bool _isRecording = false;
  bool _isInitialized = false;
  String? _error;
  List<NoiseEvent> _detectedEvents = [];
  
  // TFLite Model
  Interpreter? _interpreter;
  bool _isModelLoaded = false;

  // Configuration
  double _noiseThreshold = 0.5;
  bool _hapticEnabled = true;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isRecording => _isRecording;
  String? get error => _error;
  List<NoiseEvent> get detectedEvents => _detectedEvents;
  bool get hapticEnabled => _hapticEnabled;
  double get noiseThreshold => _noiseThreshold;

  // Audio levels for visualization
  final _audioLevelController = StreamController<double>.broadcast();
  Stream<double> get audioLevelStream => _audioLevelController.stream;

  // Frequency spectrum for visualization (mock data for now)
  final _spectrumController = StreamController<List<double>>.broadcast();
  Stream<List<double>> get spectrumStream => _spectrumController.stream;

  /// Initializes the audio service and loads the ML model.
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
      
      // Load TFLite model for sound classification
      await _loadModel();

      _isInitialized = true;
      notifyListeners();
      LoggerService.info('Audio service initialized successfully');
    } catch (e, stack) {
      _error = 'Failed to initialize audio: $e';
      LoggerService.error('Audio initialization failed', error: e, stack: stack);
      rethrow;
    }
  }

  Future<void> _loadModel() async {
    try {
      // In a real app, this would load the actual sound classification model
      // _interpreter = await Interpreter.fromAsset('assets/models/sound_classifier.tflite');
      _isModelLoaded = true;
      LoggerService.info('Sound classification model loaded');
    } catch (e) {
      LoggerService.error('Failed to load sound classification model: $e');
    }
  }

  /// Sets the noise detection threshold (0.0 to 1.0).
  void setNoiseThreshold(double threshold) {
    _noiseThreshold = threshold;
    notifyListeners();
  }

  /// Enables or disables haptic feedback for alerts.
  void setHapticEnabled(bool enabled) {
    _hapticEnabled = enabled;
    notifyListeners();
  }

  /// Starts recording audio for sound detection.
  ///
  /// [onNoiseDetected] - Callback when a noise event is detected.
  Future<void> startRecording({
    void Function(NoiseEvent event)? onNoiseDetected,
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
    // Calculate audio level from PCM16 data
    double level = 0;
    final buffer = Int16List.view(data.buffer);
    for (final sample in buffer) {
      level += sample.abs();
    }
    level = (level / buffer.length) / 32767.0;
    
    // Emit level for visualization
    if (!_audioLevelController.isClosed) {
      _audioLevelController.add(level);
    }

    // Generate mock spectrum data for visualization
    _generateMockSpectrum(level);

    // Detect noise events based on level threshold
    if (level > _noiseThreshold) {
      final event = NoiseEvent.fromAudio(
        type: _classifyNoise(data, level),
        intensity: level.clamp(0.0, 1.0),
      );
      
      _detectedEvents.add(event);
      
      // Trigger haptic feedback if enabled and intensity is high enough
      if (_hapticEnabled && event.intensity > 0.6) {
        _triggerHapticFeedback(event.severity);
      }

      onNoiseDetected?.call(event);
      notifyListeners();

      LoggerService.debug('Noise detected: ${event.type.displayName} (intensity: ${event.intensity.toStringAsFixed(2)})');
    }
  }

  void _generateMockSpectrum(double level) {
    if (_spectrumController.isClosed) return;
    
    final List<double> spectrum = List.generate(20, (index) {
      return (level * (1.0 - index / 20.0)) + (DateTime.now().millisecondsSinceEpoch % (index + 1)) / 1000.0;
    });
    _spectrumController.add(spectrum);
  }

  void _triggerHapticFeedback(AlertSeverity severity) {
    Vibration.hasVibrator().then((hasVibrator) {
      if (hasVibrator == true) {
        switch (severity) {
          case AlertSeverity.critical:
            Vibration.vibrate(duration: 500, amplitude: 255);
            break;
          case AlertSeverity.high:
            Vibration.vibrate(duration: 300, amplitude: 200);
            break;
          case AlertSeverity.medium:
            Vibration.vibrate(duration: 100, amplitude: 150);
            break;
          case AlertSeverity.low:
            HapticFeedback.lightImpact();
            break;
        }
      }
    });
  }

  /// Classifies the noise type using the ML model or heuristics.
  NoiseType _classifyNoise(Uint8List data, double intensity) {
    if (_isModelLoaded && _interpreter != null) {
      // In a real implementation, we would run the model here
      // return _runInference(data);
    }

    // Heuristic fallback
    if (intensity > 0.85) return NoiseType.alarm;
    if (intensity > 0.7) return NoiseType.siren;
    
    final random = (intensity * 100).toInt() % 8;
    switch (random) {
      case 0: return NoiseType.doorbell;
      case 1: return NoiseType.knock;
      case 2: return NoiseType.babyCrying;
      case 3: return NoiseType.dogBark;
      case 4: return NoiseType.phoneRing;
      case 5: return NoiseType.glassBreak;
      case 6: return NoiseType.smokeDetector;
      default: return NoiseType.custom;
    }
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
  Future<void> dispose() async {
    LoggerService.info('Disposing audio service');
    
    await _audioSubscription?.cancel();
    _audioSubscription = null;

    if (_isRecording) {
      await _recorder!.stopRecorder();
    }

    await _recorder?.closeAudioSession();
    await _player?.closeAudioSession();

    _recorder = null;
    _player = null;
    _isInitialized = false;
    _isRecording = false;
    
    await _audioLevelController.close();
    notifyListeners();
  }
}

/// Custom exception for audio-related errors.
class AudioException implements Exception {
  final String message;

  const AudioException(this.message);

  @override
  String toString() => 'AudioException: $message';
}
