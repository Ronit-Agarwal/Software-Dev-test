import 'dart:async';
import 'dart:collection';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:signsync/core/error/exceptions.dart';
import 'package:signsync/core/logging/logger_service.dart';
import 'package:signsync/models/app_mode.dart';
import 'package:signsync/models/asl_sign.dart';
import 'package:signsync/models/detected_object.dart';
import 'package:signsync/services/cnn_inference_service.dart';
import 'package:signsync/services/lstm_inference_service.dart';
import 'package:signsync/services/yolo_detection_service.dart';
import 'package:signsync/services/tts_service.dart';
import 'package:signsync/services/face_recognition_service.dart';
import 'package:signsync/services/storage_service.dart';

/// Orchestrates multiple ML models (CNN, LSTM, YOLO, Face) based on app mode.
class MlOrchestratorService with ChangeNotifier {
  // Individual model services
  final CnnInferenceService _cnnService;
  final LstmInferenceService _lstmService;
  final YoloDetectionService _yoloService;
  final TtsService _ttsService;
  final FaceRecognitionService _faceService;
  final StorageService _storageService;

  // State management
  bool _isInitialized = false;
  bool _isProcessing = false;
  AppMode _currentMode = AppMode.dashboard;
  String? _error;
  
  // Adaptive Inference configuration
  bool _adaptiveInferenceEnabled = true;
  int _inferenceFrequencyMs = 0; // 0 means process every frame

  // Audio alerts configuration
  bool _audioAlertsEnabled = true;
  bool _spatialAudioEnabled = true;
  
  // Results state
  AslSign? _latestAslSign;
  AslSign? _latestDynamicSign;
  DetectionFrame? _latestDetection;
  FaceResult? _latestFace;
  final Queue<MlResult> _resultQueue = Queue<MlResult>();
  
  // Performance monitoring
  final List<double> _processingTimes = [];
  final Map<AppMode, int> _framesPerMode = {};
  int _totalFramesProcessed = 0;
  final Stopwatch _processingStopwatch = Stopwatch();
  
  // System stats (for dashboard)
  double? _memoryUsage;
  int? _batteryLevel;
  int? _lastInferenceLatency;

  // Configuration
  bool _enableCnn = true;
  bool _enableLstm = true;
  bool _enableYolo = true;
  bool _enableFace = true;
  double _aslConfidenceThreshold = 0.85;
  double _objectConfidenceThreshold = 0.60;
  double _faceConfidenceThreshold = 0.75;

  // Mode switching protection
  DateTime? _lastModeSwitchTime;
  static const Duration _modeSwitchCooldown = Duration(milliseconds: 300);

  // Battery saver mode
  bool _batterySaverMode = false;

  // Mode state protection
  bool _modeSwitchInProgress = false;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isProcessing => _isProcessing;
  AppMode get currentMode => _currentMode;
  String? get error => _error;
  AslSign? get latestAslSign => _latestAslSign;
  AslSign? get latestDynamicSign => _latestDynamicSign;
  DetectionFrame? get latestDetection => _latestDetection;
  FaceResult? get latestFace => _latestFace;
  int get totalFramesProcessed => _totalFramesProcessed;
  double get averageProcessingTime => _processingTimes.isNotEmpty
      ? _processingTimes.reduce((a, b) => a + b) / _processingTimes.length
      : 0.0;
  int get queuedResults => _resultQueue.length;
  bool get audioAlertsEnabled => _audioAlertsEnabled;
  bool get spatialAudioEnabled => _spatialAudioEnabled;
  bool get enableFace => _enableFace;
  double? get memoryUsage => _memoryUsage;
  int? get batteryLevel => _batteryLevel;
  int? get lastInferenceLatency => _lastInferenceLatency;
  bool get adaptiveInferenceEnabled => _adaptiveInferenceEnabled;
  bool get batterySaverMode => _batterySaverMode;
  bool get modeSwitchInProgress => _modeSwitchInProgress;

  /// Creates orchestrator with optional model services (for dependency injection).
  MlOrchestratorService({
    CnnInferenceService? cnnService,
    LstmInferenceService? lstmService,
    YoloDetectionService? yoloService,
    TtsService? ttsService,
    FaceRecognitionService? faceService,
    StorageService? storageService,
  })  : _cnnService = cnnService ?? CnnInferenceService(),
        _lstmService = lstmService ?? LstmInferenceService(),
        _yoloService = yoloService ?? YoloDetectionService(),
        _ttsService = ttsService ?? TtsService(),
        _faceService = faceService ?? FaceRecognitionService(),
        _storageService = storageService ?? StorageService();

  /// Initializes the ML orchestrator with all required models.
  Future<void> initialize({
    required AppMode initialMode,
    String? cnnModelPath,
    String? lstmModelPath,
    String? yoloModelPath,
    String? faceModelPath,
    Locale? locale,
  }) async {
    if (_isInitialized) {
      LoggerService.warn('ML orchestrator already initialized');
      return;
    }

    try {
      LoggerService.info('Initializing ML orchestrator for mode: $initialMode');
      _processingStopwatch.start();
      _currentMode = initialMode;

      // Initialize TTS service for audio alerts
      await _ttsService.initialize();
      if (locale != null) {
        await _ttsService.setLocale(locale);
      }

      // Initialize models based on mode
      switch (initialMode) {
        case AppMode.dashboard:
        case AppMode.translation:
          if (_enableCnn) {
            await _cnnService.initialize(modelPath: cnnModelPath ?? 'assets/models/asl_cnn.tflite');
          }
          if (_enableLstm) {
            await _lstmService.initialize(
              lstmModelPath: lstmModelPath ?? 'assets/models/asl_lstm.tflite',
              cnnModelPath: cnnModelPath ?? 'assets/models/asl_cnn.tflite',
            );
          }
          break;
        case AppMode.detection:
          if (_enableYolo) {
            await _yoloService.initialize(modelPath: yoloModelPath ?? 'assets/models/yolov11.tflite');
          }
          if (_enableFace) {
            await _faceService.initialize(modelPath: faceModelPath ?? 'assets/models/face_recognition.tflite');
          }
          break;
        case AppMode.sound:
          // Sound mode doesn't use visual models
          break;
        case AppMode.chat:
          // Chat mode may use different models in future
          break;
      }

      _isInitialized = true;
      _error = null;
      notifyListeners();
      LoggerService.info('ML orchestrator initialized successfully');
    } catch (e, stack) {
      _error = 'Failed to initialize ML orchestrator: $e';
      LoggerService.error('ML orchestrator initialization failed', error: e, stack: stack);
      rethrow;
    }
  }

  /// Processes a camera frame with the current model pipeline.
  Future<MlResult> processFrame(CameraImage image) async {
    if (!_isInitialized) {
      throw MlOrchestratorException('ML orchestrator not initialized. Call initialize() first.');
    }

    // Skip processing if mode switch is in progress
    if (_modeSwitchInProgress) {
      return MlResult.skipped();
    }

    if (_isProcessing) {
      LoggerService.warn('ML processing already in progress, skipping frame');
      return MlResult.skipped();
    }

    final nowTime = DateTime.now();

    // Adaptive inference based on battery level and battery saver mode
    if (_adaptiveInferenceEnabled && _batteryLevel != null) {
      if (_batterySaverMode) {
        _inferenceFrequencyMs = 1000; // 1 FPS in battery saver
      } else if (_batteryLevel! < 20) {
        _inferenceFrequencyMs = 500; // 2 FPS at low battery
      } else if (_batteryLevel! < 50) {
        _inferenceFrequencyMs = 200; // 5 FPS at medium battery
      } else {
        _inferenceFrequencyMs = 0; // Max FPS otherwise
      }
    }

    // Check if enough time has passed since last inference
    if (_inferenceFrequencyMs > 0 && _lastInferenceLatency != null) {
      final now = nowTime.millisecondsSinceEpoch;
      final lastInferenceEnd = now - (_lastInferenceLatency ?? 0);
      // Simple frequency limiting
      if (lastInferenceEnd < _inferenceFrequencyMs) {
        return MlResult.skipped();
      }
    }

    _isProcessing = true;
    _processingStopwatch.reset();
    _processingStopwatch.start();
    final frameStartTime = nowTime;

    try {
      MlResult result;

      switch (_currentMode) {
        case AppMode.dashboard:
        case AppMode.translation:
          result = await _processAslFrame(image);
          break;
        case AppMode.detection:
          result = await _processDetectionFrame(image);
          break;
        case AppMode.sound:
          result = MlResult.skipped(); // Sound mode doesn't process frames
          break;
        case AppMode.chat:
          result = MlResult.skipped(); // Chat mode may use different processing
          break;
      }

      // Update metrics
      _processingStopwatch.stop();
      final processingTime = _processingStopwatch.elapsedMilliseconds.toDouble();
      _processingTimes.add(processingTime);
      _totalFramesProcessed++;
      _lastInferenceLatency = processingTime.toInt();

      _framesPerMode[_currentMode] = (_framesPerMode[_currentMode] ?? 0) + 1;

      // Simulate system stats (in real implementation, use device_info_plus)
      if (_totalFramesProcessed % 30 == 0) {
        _memoryUsage = 120 + (_totalFramesProcessed % 50).toDouble();
        _batteryLevel = (90 - (_totalFramesProcessed / 100)).toInt().clamp(0, 100);
      }

      if (_processingTimes.length > 30) {
        _processingTimes.removeAt(0);
      }

      // Cache significant results
      if (result.type != MlResultType.skipped && result.type != MlResultType.error) {
        if (result.hasSign || result.hasObjects) {
          unawaited(_storageService.cacheResult(
            'res_${result.timestamp.millisecondsSinceEpoch}',
            result.type.name,
            result.toJson(),
          ));
        }
      }

      // Add to result queue for temporal analysis
      _resultQueue.add(result);
      if (_resultQueue.length > 50) {
        _resultQueue.removeFirst();
      }

      LoggerService.debug('ML processing: $result in ${processingTime}ms');

      notifyListeners();
      return result;
    } catch (e, stack) {
      _error = 'ML processing failed: $e';
      LoggerService.error('ML processing failed', error: e, stack: stack);
      return MlResult.error('Processing failed: $e');
    } finally {
      _isProcessing = false;
    }
  }

  /// Processes an ASL translation frame (CNN + LSTM).
  Future<MlResult> _processAslFrame(CameraImage image) async {
    AslSign? detectedSign;
    AslSign? dynamicSign;
    String? message;

    // Run CNN for static signs if enabled
    if (_enableCnn) {
      try {
        detectedSign = await _cnnService.processFrame(image);
        if (detectedSign != null && detectedSign.confidence >= _aslConfidenceThreshold) {
          _latestAslSign = detectedSign;
          message = 'Detected: ${detectedSign.letter}';
        }
      } catch (e) {
        LoggerService.warn('CNN processing failed: $e');
      }
    }

    // Run LSTM for dynamic signs if enabled
    if (_enableLstm && detectedSign != null) {
      try {
        dynamicSign = await _lstmService.processFrame(image);
        if (dynamicSign != null && dynamicSign.confidence >= _aslConfidenceThreshold) {
          _latestDynamicSign = dynamicSign;
          message = 'Dynamic: ${dynamicSign.word}';
        }
      } catch (e) {
        LoggerService.warn('LSTM processing failed: $e');
      }
    }

    return MlResult.asl(
      staticSign: detectedSign,
      dynamicSign: dynamicSign,
      message: message,
    );
  }

  /// Processes an object detection frame (YOLO) and face recognition.
  Future<MlResult> _processDetectionFrame(CameraImage image) async {
    if (!_enableYolo) {
      return MlResult.skipped();
    }

    try {
      final detection = await _yoloService.detect(image);

      if (detection != null) {
        _latestDetection = detection;
        final objects = detection.highConfidenceObjects();
        String message = 'Detected ${objects.length} objects';

        // Check for persons to run face recognition
        FaceResult? faceResult;
        if (_enableFace) {
          final persons = objects.where((obj) => obj.label == 'person').toList();
          if (persons.isNotEmpty) {
            // Extract all face bounding boxes for multiple face handling
            final faceRects = persons.map((p) => p.boundingBox).toList();
            
            // Run face recognition with all detected faces
            faceResult = await _faceService.processFrame(
              image, 
              faceRect: persons.first.boundingBox,
              allFaces: faceRects,
            );
            
            if (faceResult != null && faceResult.confidence >= _faceConfidenceThreshold) {
              _latestFace = faceResult;
              message = '${faceResult.profile.name} detected at ${persons.first.distance?.toStringAsFixed(1)} feet';
            }
          }
        }

        // Generate audio alerts for detected objects and faces
        if (_audioAlertsEnabled && objects.isNotEmpty) {
          unawaited(_generateAudioAlerts(objects, faceResult));
        }

        return MlResult.detection(
          frame: detection,
          objects: objects,
          faceResult: faceResult,
          message: message,
        );
      }

      return MlResult.detection(
        frame: DetectionFrame(
          id: 'empty_${DateTime.now().millisecondsSinceEpoch}',
          objects: [],
          timestamp: DateTime.now(),
          frameIndex: _totalFramesProcessed,
        ),
        objects: [],
        message: 'No objects detected',
      );
    } catch (e) {
      LoggerService.error('Detection processing failed', error: e);
      return MlResult.error('Detection failed: $e');
    }
  }

  /// Generates audio alerts for detected objects and faces.
  Future<void> _generateAudioAlerts(List<DetectedObject> objects, [FaceResult? faceResult]) async {
    if (!_audioAlertsEnabled) return;

    try {
      // Apply spatial audio setting to TTS service
      _ttsService.setSpatialAudioEnabled(_spatialAudioEnabled);

      // If a face is recognized, announce it first
      if (faceResult != null && faceResult.confidence >= _faceConfidenceThreshold) {
        final distance = objects.firstWhere((obj) => obj.label == 'person', orElse: () => objects.first).distance;
        final feet = distance != null ? (distance * 3.28084).round() : 3;
        await _ttsService.speak('${faceResult.profile.name}, $feet feet ahead');
      }

      // Generate alerts for detected objects
      await _ttsService.generateAlerts(objects);
    } catch (e) {
      LoggerService.warn('Failed to generate audio alerts: $e');
    }
  }

  /// Switches between different ML modes.
  Future<void> switchMode(AppMode newMode, {CameraImage? currentFrame}) async {
    if (_currentMode == newMode) {
      return;
    }

    // Check mode switch cooldown to prevent rapid switching
    if (_modeSwitchInProgress) {
      LoggerService.warn('Mode switch already in progress, ignoring request');
      return;
    }

    if (_lastModeSwitchTime != null) {
      final timeSinceLastSwitch = DateTime.now().difference(_lastModeSwitchTime!);
      if (timeSinceLastSwitch < _modeSwitchCooldown) {
        LoggerService.warn('Mode switch requested too quickly, ignoring (${timeSinceLastSwitch.inMilliseconds}ms < ${_modeSwitchCooldown.inMilliseconds}ms)');
        return;
      }
    }

    _modeSwitchInProgress = true;
    notifyListeners();

    LoggerService.info('Switching ML mode from $_currentMode to $newMode');

    final oldMode = _currentMode;
    _currentMode = newMode;
    _lastModeSwitchTime = DateTime.now();

    try {
      // Load models for new mode if needed
      switch (newMode) {
        case AppMode.translation:
          if (_enableCnn && !_cnnService.isModelLoaded) {
            await _cnnService.initialize();
          }
          if (_enableLstm && !_lstmService.isModelLoaded) {
            await _lstmService.initialize();
          }
          break;
        case AppMode.detection:
          if (_enableYolo && !_yoloService.isModelLoaded) {
            await _yoloService.initialize();
          }
          break;
        case AppMode.sound:
          // No visual models needed
          break;
        case AppMode.chat:
          // May need to unload heavy models
          break;
      }

      // Unload models from old mode to free resources (only in memory pressure)
      if (_batteryLevel != null && _batteryLevel! < 30) {
        // Low battery - unload unused models
        if (oldMode == AppMode.translation) {
          // Could unload CNN/LSTM to save memory
          // For now, keep them loaded for fast switching
        } else if (oldMode == AppMode.detection) {
          // Could unload YOLO to save memory
          // For now, keep it loaded for fast switching
        }
      }

      _resetModeState();

      // Process current frame in new mode if provided
      if (currentFrame != null) {
        unawaited(processFrame(currentFrame));
      }
    } catch (e, stack) {
      LoggerService.error('Failed to switch mode', error: e, stack: stack);
      // Revert to old mode on error
      _currentMode = oldMode;
    } finally {
      _modeSwitchInProgress = false;
      notifyListeners();
    }
  }

  /// Processes results queue for temporal patterns.
  List<MlResult> getRecentResults([int count = 10]) {
    return _resultQueue.toList().sublist(
      max(0, _resultQueue.length - count),
    );
  }

  /// Gets ASL sequence from recent results.
  List<AslSign> getAslSequence({int minConfidence = 80}) {
    final sequence = <AslSign>[];
    
    for (final result in _resultQueue) {
      if (result.type == MlResultType.asl) {
        if (result.staticSign != null && result.staticSign!.confidence >= minConfidence / 100) {
          sequence.add(result.staticSign!);
        }
      }
    }
    
    return sequence;
  }

  /// Gets detection statistics across all processed frames.
  Map<String, dynamic> get performanceMetrics => {
        'totalFrames': _totalFramesProcessed,
        'framesPerMode': _framesPerMode,
        'averageProcessingTime': averageProcessingTime,
        'currentMode': _currentMode.toString(),
        'cnnStats': _cnnService.performanceStats,
        'lstmStats': _lstmService.temporalStats,
        'yoloStats': _yoloService.detectionStats,
        'ttsStats': _ttsService.statistics,
        'queueLength': _resultQueue.length,
      };

  // Configuration methods
  void setConfidenceThresholds({double? aslThreshold, double? objectThreshold}) {
    if (aslThreshold != null) {
      _aslConfidenceThreshold = aslThreshold.clamp(0.0, 1.0);
    }
    if (objectThreshold != null) {
      _objectConfidenceThreshold = objectThreshold.clamp(0.0, 1.0);
    }
    LoggerService.info('ML thresholds updated: ASL=$_aslConfidenceThreshold, Objects=$_objectConfidenceThreshold');
  }

  void setModelEnabled({bool? cnn, bool? lstm, bool? yolo}) {
    _enableCnn = cnn ?? _enableCnn;
    _enableLstm = lstm ?? _enableLstm;
    _enableYolo = yolo ?? _enableYolo;
    LoggerService.info('Model enabling: CNN=$_enableCnn, LSTM=$_enableLstm, YOLO=$_enableYolo');
  }

  /// Sets audio alerts enabled/disabled.
  void setAudioAlertsEnabled(bool enabled) {
    _audioAlertsEnabled = enabled;
    LoggerService.info('Audio alerts ${enabled ? "enabled" : "disabled"}');
    notifyListeners();
  }

  /// Sets spatial audio enabled/disabled.
  void setSpatialAudioEnabled(bool enabled) {
    _spatialAudioEnabled = enabled;
    _ttsService.setSpatialAudioEnabled(enabled);
    LoggerService.info('Spatial audio ${enabled ? "enabled" : "disabled"}');
    notifyListeners();
  }

  /// Sets TTS volume [0.0, 1.0].
  Future<void> setTtsVolume(double volume) async {
    await _ttsService.setVolume(volume);
    notifyListeners();
  }

  /// Sets TTS speech rate [0.0, 1.0].
  Future<void> setTtsSpeechRate(double rate) async {
    await _ttsService.setSpeechRate(rate);
    notifyListeners();
  }

  /// Enables or disables battery saver mode.
  void setBatterySaverMode(bool enabled) {
    _batterySaverMode = enabled;
    notifyListeners();
    LoggerService.info('Battery saver mode ${enabled ? "enabled" : "disabled"}');
  }

  /// Gets TTS service statistics.
  Map<String, dynamic> get ttsStats => _ttsService.statistics;

  void resetModeState() {
    _resetModeState();
  }

  void _resetModeState() {
    _latestAslSign = null;
    _latestDynamicSign = null;
    _latestDetection = null;
    _resultQueue.clear();
  }

  /// Sets face recognition enabled/disabled.
  void setFaceRecognitionEnabled(bool enabled) {
    _enableFace = enabled;
    _faceService.setRecognitionEnabled(enabled);
    LoggerService.info('Face recognition ${enabled ? "enabled" : "disabled"}');
    notifyListeners();
  }

  /// Starts face enrollment for a person.
  void startFaceEnrollment(String name) {
    _faceService.startEnrollment(name);
    notifyListeners();
  }

  /// Cancels face enrollment.
  void cancelFaceEnrollment() {
    _faceService.cancelEnrollment();
    notifyListeners();
  }

  /// Gets face profiles in the database.
  List<FaceProfile> getFaceProfiles() => _faceService.profiles;

  /// Updates a face profile.
  Future<void> updateFaceProfile(String id, {String? label, bool? isPrivate}) async {
    await _faceService.updateProfile(id, label: label, isPrivate: isPrivate);
    notifyListeners();
  }

  /// Deletes a face profile.
  Future<void> deleteFaceProfile(String id) async {
    await _faceService.deleteProfile(id);
    await _storageService.logEvent('delete_face_profile', details: 'Profile ID: $id');
    notifyListeners();
  }

  /// Wipes all local data for privacy and security.
  Future<void> wipeAllLocalData() async {
    LoggerService.warn('Wiping all local data...');
    await _storageService.wipeAllData();
    await _faceService.unloadModel();
    // Re-initialize if necessary or just notify
    notifyListeners();
  }

  /// Exports all user data.
  Future<String> exportUserData() async {
    return await _storageService.exportAllData();
  }

  /// Sets adaptive inference enabled/disabled.
  void setAdaptiveInferenceEnabled(bool enabled) {
    _adaptiveInferenceEnabled = enabled;
    LoggerService.info('Adaptive inference ${enabled ? "enabled" : "disabled"}');
    notifyListeners();
  }

  /// Unloads all models to free resources.
  Future<void> unloadAllModels() async {
    LoggerService.info('Unloading all ML models');
    
    await Future.wait([
      _cnnService.unloadModel(),
      _lstmService.unloadModel(),
      _yoloService.unloadModel(),
      _faceService.unloadModel(),
    ]);

    _isInitialized = false;
    _resetState();
    notifyListeners();
  }

  void _resetState() {
    _resetModeState();
    _processingTimes.clear();
    _framesPerMode.clear();
    _totalFramesProcessed = 0;
    _processingStopwatch.reset();
  }

  @override
  void dispose() {
    LoggerService.info('Disposing ML orchestrator service');
    _cnnService.dispose();
    _lstmService.dispose();
    _yoloService.dispose();
    _faceService.dispose();
    _resetState();
    super.dispose();
  }
}

/// Represents the result of ML orchestration.
class MlResult {
  final MlResultType type;
  final AslSign? staticSign;
  final AslSign? dynamicSign;
  final DetectionFrame? frame;
  final List<DetectedObject> objects;
  final FaceResult? faceResult;
  final String? message;
  final DateTime timestamp;

  MlResult({
    required this.type,
    this.staticSign,
    this.dynamicSign,
    this.frame,
    this.objects = const [],
    this.faceResult,
    this.message,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Creates an ASL result.
  factory MlResult.asl({
    AslSign? staticSign,
    AslSign? dynamicSign,
    String? message,
  }) {
    return MlResult(
      type: MlResultType.asl,
      staticSign: staticSign,
      dynamicSign: dynamicSign,
      message: message ?? (staticSign != null ? 'Detected: ${staticSign.letter}' : 
                        dynamicSign != null ? 'Dynamic: ${dynamicSign.word}' : 'No sign detected'),
    );
  }

  /// Creates a detection result.
  factory MlResult.detection({
    required DetectionFrame frame,
    List<DetectedObject> objects = const [],
    FaceResult? faceResult,
    String? message,
  }) {
    return MlResult(
      type: MlResultType.detection,
      frame: frame,
      objects: objects,
      faceResult: faceResult,
      message: message ?? 'Detected ${objects.length} objects',
    );
  }

  /// Creates a skipped frame result.
  factory MlResult.skipped() {
    return MlResult(
      type: MlResultType.skipped,
      message: 'Frame skipped',
    );
  }

  /// Creates an error result.
  factory MlResult.error(String error) {
    return MlResult(
      type: MlResultType.error,
      message: error,
    );
  }

  bool get isAsl => type == MlResultType.asl;
  bool get isDetection => type == MlResultType.detection;
  bool get isSkipped => type == MlResultType.skipped;
  bool get isError => type == MlResultType.error;
  bool get hasSign => staticSign != null || dynamicSign != null;
  bool get hasObjects => objects.isNotEmpty || (frame?.objects.isNotEmpty ?? false);

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'message': message,
      'timestamp': timestamp.millisecondsSinceEpoch,
      // In a real app, we would also serialize the other fields
    };
  }

  @override
  String toString() => 'MlResult(type: $type, message: $message, timestamp: $timestamp)';
}

/// Enum for ML result types.
enum MlResultType {
  asl,
  detection,
  skipped,
  error,
}

/// Exception for ML orchestrator errors.
class MlOrchestratorException implements Exception {
  final String message;
  final String? code;

  const MlOrchestratorException(this.message, {this.code});

  @override
  String toString() => 'MlOrchestratorException: $message';
}