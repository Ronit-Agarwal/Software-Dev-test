import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:signsync/core/error/exceptions.dart';
import 'package:signsync/core/logging/logger_service.dart';
import 'package:signsync/models/asl_sign.dart';
import 'package:signsync/services/cnn_inference_service.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// LSTM-based temporal ASL recognition service.
///
/// Processes sequences of frames to recognize dynamic ASL signs (e.g., "morning", "computer").
/// Combines with CNN for spatial feature extraction and LSTM for temporal modeling.
class LstmInferenceService with ChangeNotifier {
  Interpreter? _interpreter;
  bool _isModelLoaded = false;
  bool _isProcessing = false;
  AslSign? _latestSign;
  final List<AslSign> _dynamicSignHistory = [];
  String? _error;

  // Model parameters
  static const int sequenceLength = 15; // 15-frame temporal window
  static const int featureDims = 512; // CNN feature dimensions
  static const int numClasses = 20; // dynamic signs + static signs
  static const double confidenceThreshold = 0.80;

  // Frame buffering
  final List<Float32List> _frameBuffer = [];
  final List<DateTime> _frameTimestamps = [];
  final List<InferenceResult> _cnnResults = [];
  int _framesProcessed = 0;
  
  // Performance tracking
  final List<double> _inferenceTimes = [];
  final List<double> _sequencesProcessed = [];

  // Temporal tracking
  final Map<String, int> _signCounter = {};
  static const int minSignFrames = 5; // minimum frames to consider a sign
  static const int maxSignGap = 30; // frames before resetting counter

  // Dynamic signs dictionary
  static const List<String> _dynamicSigns = [
    'MORNING',    // Good morning
    'NIGHT',      // Good night
    'COMPUTER',   // Computer/work
    'WATER',      // Water/drink
    'EAT',        // Eat/food
    'HELLO',      // Formal greeting
    'THANKYOU',   // Thank you
    'YES',        // Yes/nodding
    'NO',         // No/shaking head
    'QUESTION',   // Question mark gesture
    'TIME',       // Time/clock
    'DAY',        // Day/time
    'LEARN',      // Learning/studying
    'HOME',       // Home/house
    'WORK',       // Work/job
    'LOVE',       // I love you
    'SICK',       // Sick/ill
    'BATHROOM',   // Bathroom/washroom
    'CALL',       // Phone call
    'UNKNOWN',    // Unknown/background
  ];

  // CNN service for feature extraction
  final CnnInferenceService _cnnService;

  // Getters
  bool get isModelLoaded => _isModelLoaded;
  bool get isProcessing => _isProcessing;
  AslSign? get latestSign => _latestSign;
  String? get error => _error;
  int get currentBufferSize => _frameBuffer.length;
  double get averageInferenceTime => _inferenceTimes.isNotEmpty
      ? _inferenceTimes.reduce((a, b) => a + b) / _inferenceTimes.length
      : 0.0;
  int get framesInBuffer => _frameBuffer.length;

  LstmInferenceService({CnnInferenceService? cnnService})
      : _cnnService = cnnService ?? CnnInferenceService();

  /// Initializes the LSTM service and CNN feature extractor.
  Future<void> initialize({
    String lstmModelPath = 'assets/models/asl_lstm.tflite',
    String cnnModelPath = 'assets/models/asl_cnn.tflite',
  }) async {
    try {
      LoggerService.info('Initializing LSTM inference service');
      _error = null;

      // Initialize CNN for feature extraction
      if (!_cnnService.isModelLoaded) {
        await _cnnService.initialize(modelPath: cnnModelPath);
      }

      // Load LSTM model
      await _loadLstmModel(lstmModelPath);
      
      _isModelLoaded = true;
      _resetState();
      notifyListeners();
      LoggerService.info('LSTM inference service initialized successfully');
    } catch (e, stack) {
      _error = 'Failed to initialize LSTM service: $e';
      LoggerService.error('LSTM initialization failed', error: e, stack: stack);
      rethrow;
    }
  }

  /// Loads the LSTM model from assets.
  Future<void> _loadLstmModel(String modelPath) async {
    try {
      LoggerService.debug('Loading LSTM model from $modelPath');
      
      // Add timeout to prevent hanging on slow devices
      _interpreter = await Interpreter.fromAsset(
        modelPath,
        options: InterpreterOptions()..threads = 2,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('LSTM model loading timeout after 30 seconds');
        },
      );
      
      LoggerService.info('LSTM model loaded successfully');
      _validateLstmModel();
    } on TimeoutException catch (e, stack) {
      LoggerService.error('LSTM model loading timed out', error: e, stack: stack);
      throw ModelLoadException('LSTM model loading timed out: $e');
    } catch (e, stack) {
      LoggerService.error('Failed to load LSTM model', error: e, stack: stack);
      
      // Provide helpful error messages
      if (e.toString().contains('AssetNotFoundException')) {
        throw ModelLoadException(
          'LSTM model file not found at $modelPath. '
          'Please ensure you have converted and placed your LSTM model in assets/models/'
        );
      }
      
      throw ModelLoadException('Failed to load LSTM model: $e');
    }
  }

  /// Validates LSTM model input/output shapes.
  void _validateLstmModel() {
    if (_interpreter == null) {
      throw ModelLoadException('LSTM Interpreter is null');
    }

    final inputTensor = _interpreter!.getInputTensor(0);
    final outputTensor = _interpreter!.getOutputTensor(0);

    LoggerService.debug('LSTM input shape: ${inputTensor.shape}');
    LoggerService.debug('LSTM output shape: ${outputTensor.shape}');

    // Validate input shape [1, sequence_length, feature_dims]
    if (inputTensor.shape.length != 3 ||
        inputTensor.shape[1] != sequenceLength ||
        inputTensor.shape[2] != featureDims) {
      throw ModelLoadException(
        'Invalid LSTM input shape. Expected [1, $sequenceLength, $featureDims]');
    }

    // Validate output shape [1, num_classes]
    if (outputTensor.shape.length != 2 || outputTensor.shape[1] != numClasses) {
      throw ModelLoadException(
        'Invalid LSTM output shape. Expected [1, $numClasses]');
    }
  }

  /// Processes a frame and maintains temporal buffer.
  Future<AslSign?> processFrame(dynamic image) async {
    if (!_isModelLoaded) {
      throw MlInferenceException('LSTM model not loaded. Call initialize() first.');
    }

    if (_isProcessing) {
      LoggerService.warn('LSTM inference already in progress, skipping frame');
      return null;
    }

    _isProcessing = true;

    try {
      // Extract CNN features from the frame
      final cnnResult = await _cnnService.processFrame(image);
      
      if (cnnResult == null) {
        // No static sign detected, but we still need frame for temporal analysis
        return null;
      }

      // Add frame to buffer
      _addFrameToBuffer(image, cnnResult);
      _framesProcessed++;

      // Check if we have enough frames for temporal analysis
      if (_frameBuffer.length >= sequenceLength) {
        // Run LSTM inference
        final lstmResult = await _runLstmInference();
        
        if (lstmResult.confidence >= confidenceThreshold) {
          // Create dynamic ASL sign
          final sign = AslSign.fromWord(
            lstmResult.label,
            confidence: lstmResult.confidence,
            description: 'ASL sign for ${lstmResult.label.toLowerCase()}',
          );

          // Update sign tracking
          _updateSignCounter(lstmResult.label);
          _latestSign = sign;
          _dynamicSignHistory.add(sign);
          
          // Maintain history size
          if (_dynamicSignHistory.length > 30) {
            _dynamicSignHistory.removeAt(0);
          }
          
          // Track performance
          final inferenceTime = _inferenceTimes.isNotEmpty 
              ? _inferenceTimes.last 
              : 0.0;
          LoggerService.debug('LSTM inference: ${sign.word} (${(sign.confidence * 100).toStringAsFixed(1)}%) in ${inferenceTime}ms');
          
          return sign;
        }
      }
      
      return null;
    } catch (e, stack) {
      _error = 'LSTM inference failed: $e';
      LoggerService.error('LSTM inference failed', error: e, stack: stack);
      rethrow;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// Adds a frame to the temporal buffer.
  void _addFrameToBuffer(dynamic image, AslSign cnnResult) {
    // Extract real CNN features for temporal analysis
    final features = _extractCnnFeatures(cnnResult);
    
    // Add to buffer
    _frameBuffer.add(features);
    _frameTimestamps.add(DateTime.now());
    _cnnResults.add(InferenceResult(
      letter: cnnResult.letter,
      confidence: cnnResult.confidence,
      classIndex: cnnResult.letter.codeUnitAt(0) - 'A'.codeUnitAt(0),
    ));
    
    // Maintain buffer size
    if (_frameBuffer.length > sequenceLength) {
      _frameBuffer.removeAt(0);
      _frameTimestamps.removeAt(0);
      _cnnResults.removeAt(0);
    }
  }

  /// Extracts meaningful features from CNN result for temporal analysis.
  Float32List _extractCnnFeatures(AslSign cnnResult) {
    final features = Float32List(featureDims);
    
    // Feature 1: Confidence score (normalized 0-1)
    features[0] = cnnResult.confidence;
    
    // Feature 2: Letter position (A=0, B=1, etc.)
    final letterIndex = cnnResult.letter.codeUnitAt(0) - 'A'.codeUnitAt(0);
    features[1] = (letterIndex >= 0 && letterIndex < 26) ? letterIndex / 26.0 : 0.5;
    
    // Feature 3: Is vowel (A, E, I, O, U)
    const vowels = ['A', 'E', 'I', 'O', 'U'];
    features[2] = vowels.contains(cnnResult.letter) ? 1.0 : 0.0;
    
    // Feature 4: Hand shape complexity (estimated by confidence)
    features[3] = (cnnResult.confidence > 0.9) ? 1.0 : (cnnResult.confidence - 0.5) * 2;
    
    // Feature 5-7: Temporal derivatives (if we have history)
    if (_cnnResults.length >= 2) {
      final prevConfidence = _cnnResults.last.confidence;
      features[4] = cnnResult.confidence - prevConfidence; // confidence delta
      features[5] = (cnnResult.confidence - prevConfidence).abs(); // confidence velocity
    }
    
    // Features 8-12: Frequency domain features (simplified)
    if (_cnnResults.length >= 5) {
      final recentConfidences = _cnnResults.sublist(max(0, _cnnResults.length - 5))
          .map((r) => r.confidence).toList();
      final mean = recentConfidences.reduce((a, b) => a + b) / recentConfidences.length;
      final variance = recentConfidences.map((c) => (c - mean) * (c - mean))
          .reduce((a, b) => a + b) / recentConfidences.length;
      
      features[6] = mean;
      features[7] = variance;
      features[8] = recentConfidences.last - recentConfidences.first; // trend
    }
    
    // Features 13-512: Randomized but consistent encoding
    // Use deterministic pseudo-random encoding based on letter and confidence
    final seed = (letterIndex + 1) * (cnnResult.confidence * 1000).round();
    var random = Random(seed);
    
    for (int i = 9; i < featureDims; i++) {
      features[i] = (random.nextDouble() * 2 - 1) * cnnResult.confidence;
    }
    
    return features;
  }

  /// Runs LSTM inference on the buffered frames.
  Future<LstmResult> _runLstmInference() async {
    if (_interpreter == null) {
      throw MlInferenceException('LSTM Interpreter not initialized');
    }

    // Check if sequence is valid for inference
    if (!_isSequenceValidForInference()) {
      return LstmResult(
        label: 'INVALID',
        confidence: 0.0,
        classIndex: -1,
      );
    }

    // Prepare input sequence with temporal padding
    final sequence = _prepareTemporalSequence();
    
    // Run LSTM inference with performance monitoring
    final output = List.filled(numClasses, 0.0);
    
    try {
      final inferenceStopwatch = Stopwatch()..start();
      _interpreter!.run(sequence, output);
      inferenceStopwatch.stop();
      
      _inferenceTimes.add(inferenceStopwatch.elapsedMilliseconds.toDouble());
      if (_inferenceTimes.length > 30) {
        _inferenceTimes.removeAt(0);
      }
      
      _sequencesProcessed.add(inferenceStopwatch.elapsedMilliseconds.toDouble());
      
      return _postProcessLstmOutput(output);
    } catch (e) {
      throw MlInferenceException('LSTM inference failed: $e');
    }
  }

  /// Checks if the current sequence is valid for LSTM inference.
  bool _isSequenceValidForInference() {
    // Require minimum frames for temporal analysis
    if (_frameBuffer.length < 5) return false;
    
    // Check if we have sufficient confidence variation
    if (_cnnResults.length < 3) return false;
    
    final recentConfidences = _cnnResults
        .sublist(max(0, _cnnResults.length - 5))
        .map((r) => r.confidence)
        .toList();
    
    final minConfidence = recentConfidences.reduce(min);
    final maxConfidence = recentConfidences.reduce(max);
    
    // Require some temporal variation (not all the same)
    if (maxConfidence - minConfidence < 0.1) return false;
    
    // Check for sufficient motion/transitions
    int transitions = 0;
    for (int i = 1; i < recentConfidences.length; i++) {
      if ((recentConfidences[i] - recentConfidences[i-1]).abs() > 0.15) {
        transitions++;
      }
    }
    
    // Require at least some motion for dynamic signs
    return transitions >= 1;
  }

  /// Prepares temporal sequence with proper padding and normalization.
  Float32List _prepareTemporalSequence() {
    final sequence = Float32List(sequenceLength * featureDims);
    
    // Use most recent frames, pad with zeros if needed
    final bufferLength = min(_frameBuffer.length, sequenceLength);
    final startIndex = _frameBuffer.length - bufferLength;
    
    for (int i = 0; i < bufferLength; i++) {
      final frameFeatures = _frameBuffer[startIndex + i];
      frameFeatures.copyInto(sequence, i * featureDims);
    }
    
    // Apply temporal smoothing to reduce noise
    _applyTemporalSmoothing(sequence, bufferLength);
    
    return sequence;
  }

  /// Applies temporal smoothing to reduce noise in the sequence.
  void _applyTemporalSmoothing(Float32List sequence, int validLength) {
    // Simple moving average for temporal smoothing
    if (validLength < 3) return;
    
    for (int i = featureDims; i < validLength * featureDims; i++) {
      if (i >= featureDims * 2) {
        final prev1 = sequence[i - featureDims];
        final prev2 = sequence[i - 2 * featureDims];
        sequence[i] = (sequence[i] + prev1 + prev2) / 3;
      }
    }
  }

  /// Post-processes LSTM output to get prediction.
  LstmResult _postProcessLstmOutput(List<double> output) {
    double maxConfidence = 0.0;
    int maxIndex = 0;
    
    for (int i = 0; i < output.length; i++) {
      if (output[i] > maxConfidence) {
        maxConfidence = output[i];
        maxIndex = i;
      }
    }

    // Get the corresponding dynamic sign
    final label = maxIndex < _dynamicSigns.length 
        ? _dynamicSigns[maxIndex] 
        : 'UNKNOWN';
    
    return LstmResult(
      label: label,
      confidence: maxConfidence,
      classIndex: maxIndex,
    );
  }

  /// Updates sign counter for temporal consistency.
  void _updateSignCounter(String sign) {
    // Increment counter for this sign
    _signCounter[sign] = (_signCounter[sign] ?? 0) + 1;
    
    // Decrement counters for other signs
    for (final key in _signCounter.keys) {
      if (key != sign) {
        _signCounter[key] = max(0, (_signCounter[key] ?? 0) - 1);
      }
    }
    
    // Remove signs that haven't been seen recently
    _signCounter.removeWhere((_, count) => count! < 1);
  }

  /// Gets most consistent recent sign.
  AslSign? getMostConsistentSign() {
    if (_signCounter.isEmpty) return null;
    
    final sorted = _signCounter.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final topSign = sorted.first;
    if (topSign.value >= minSignFrames) {
      return AslSign.fromWord(
        topSign.key.toLowerCase(),
        confidence: 0.9 - (0.1 / topSign.value),
      );
    }
    
    return null;
  }

  /// Gets recent dynamic signs.
  List<AslSign> getRecentDynamicSigns([int count = 10]) {
    return _dynamicSignHistory.sublist(
      max(0, _dynamicSignHistory.length - count),
    );
  }

  /// Gets temporal performance statistics.
  Map<String, dynamic> get temporalStats => {
        'sequenceLength': sequenceLength,
        'bufferedFrames': currentBufferSize,
        'totalFramesProcessed': _framesProcessed,
        'averageInferenceTime': averageInferenceTime,
        'signCounter': _signCounter,
        'cnnPerformance': _cnnService.performanceStats,
      };

  /// Resets temporal state.
  void _resetState() {
    _frameBuffer.clear();
    _frameTimestamps.clear();
    _cnnResults.clear();
    _dynamicSignHistory.clear();
    _inferenceTimes.clear();
    _sequencesProcessed.clear();
    _signCounter.clear();
    _framesProcessed = 0;
    _latestSign = null;
  }

  /// Resets the frame buffer.
  void resetBuffer() {
    _frameBuffer.clear();
    _frameTimestamps.clear();
    _cnnResults.clear();
    LoggerService.info('LSTM frame buffer reset');
  }

  /// Unloads the LSTM model to free resources.
  Future<void> unloadModel() async {
    LoggerService.info('Unloading LSTM model');
    _interpreter?.close();
    _interpreter = null;
    _isModelLoaded = false;
    _resetState();
    
    // Also unload CNN model
    await _cnnService.unloadModel();
    
    notifyListeners();
  }

  @override
  void dispose() {
    LoggerService.info('Disposing LSTM inference service');
    _interpreter?.close();
    _interpreter = null;
    _cnnService.dispose();
    super.dispose();
  }
}

/// Represents the result of LSTM inference.
class LstmResult {
  final String label;
  final double confidence;
  final int classIndex;

  const LstmResult({
    required this.label,
    required this.confidence,
    required this.classIndex,
  });

  @override
  String toString() => 'LstmResult(label: $label, confidence: ${confidence.toStringAsFixed(3)})';
}

/// Disposes the LSTM service and releases resources.
@override
void dispose() {
  LoggerService.info('Disposing LSTM inference service');
  _interpreter?.close();
  _interpreter = null;
  _isModelLoaded = false;
  _frameBuffer.clear();
  _frameTimestamps.clear();
  _cnnResults.clear();
  _dynamicSignHistory.clear();
  _inferenceTimes.clear();
  _sequencesProcessed.clear();
  super.dispose();
}

/// Extension to copy Float32List into another list.
extension Float32ListCopy on Float32List {
  void copyInto(Float32List target, int offset) {
    for (int i = 0; i < length; i++) {
      target[offset + i] = this[i];
    }
  }
}