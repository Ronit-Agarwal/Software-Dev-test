import 'dart:async';
import 'dart:io';
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

  // Audio levels for visualization
  final _audioLevelController = StreamController<double>.broadcast();
  Stream<double> get audioLevelStream => _audioLevelController.stream;

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
    final buffer = Uint16List.view(data.buffer);
    for (final sample in buffer) {
      level += sample;
    }
    level = level / buffer.length / 32767.0;
    
    // Emit level for visualization
    if (!_audioLevelController.isClosed) {
      _audioLevelController.add(level);
    }

    // Detect noise events based on level threshold
    if (level > 0.3) {
      final event = NoiseEvent.fromAudio(
        type: _classifyNoise(level),
        intensity: level.clamp(0.0, 1.0),
      );
      
      _detectedEvents.add(event);
      onNoiseDetected?.call(event);
      notifyListeners();

      LoggerService.debug('Noise detected: ${event.type.displayName} (intensity: ${event.intensity.toStringAsFixed(2)})');
    }
  }

  /// Classifies the noise type based on intensity and characteristics.
  NoiseType _classifyNoise(double intensity) {
    // In a real implementation, this would use ML for classification
    // For now, we use simple heuristics
    final random = (intensity * 10).toInt() % 5;
    
    switch (random) {
      case 0:
        return NoiseType.dogBark;
      case 1:
        return NoiseType.doorbell;
      case 2:
        return NoiseType.knock;
      case 3:
        return NoiseType.alarm;
      default:
        return NoiseType.custom;
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
