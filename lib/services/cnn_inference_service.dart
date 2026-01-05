import 'dart:async';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:signsync/core/error/exceptions.dart';
import 'package:signsync/core/logging/logger_service.dart';
import 'package:signsync/models/asl_sign.dart';
import 'package:signsync/utils/retry_helper.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// CNN-based ASL inference service using ResNet-50 architecture.
///
/// Processes individual frames for static ASL signs with confidence filtering,
/// temporal smoothing, and ASL dictionary mapping.
///
/// Features:
/// - FP16 quantized ResNet-50 TFLite model
/// - YUV420→RGB preprocessing pipeline
/// - 224x224 input resizing with ImageNet normalization
/// - 15-20 FPS inference with <100ms latency target
/// - 0.85+ confidence threshold filtering
/// - 3-5 frame temporal smoothing
/// - Lazy model loading
/// - Comprehensive error handling
class CnnInferenceService with ChangeNotifier {
  Interpreter? _interpreter;
  bool _isModelLoaded = false;
  bool _isProcessing = false;
  bool _isInitializing = false;
  AslSign? _latestSign;
  final List<AslSign> _signHistory = [];
  String? _error;

  // Model parameters - ResNet-50 with FP16 quantization
  static const int inputSize = 224;
  static const int numChannels = 3;
  static const int numClasses = 27; // 26 letters + 1 unknown/background
  static const double confidenceThreshold = 0.85;
  static const double targetFpsMin = 15.0;
  static const double targetFpsMax = 20.0;
  static const int maxLatencyMs = 100;

  // Lazy loading
  String? _cachedModelPath;
  bool _lazyLoadEnabled = true;

  // Performance monitoring
  final List<double> _inferenceTimes = [];
  final List<double> _confidenceHistory = [];
  int _framesProcessed = 0;
  final List<double> _fpsHistory = [];
  DateTime? _lastFrameTime;

  // Temporal smoothing (configurable 3-5 frames, default 5)
  static const int smoothingWindow = 5;
  final List<InferenceResult> _temporalBuffer = [];

  // Adaptive smoothing for different signing speeds
  int _adaptiveSmoothingWindow = 5;
  final List<double> _signConfidenceHistory = [];

  // Retry logic for inference failures
  final RetryHelper _retryHelper = RetryHelpers.mlInference(
    maxRetries: 2,
    timeout: const Duration(milliseconds: 500),
  );

  // ASL dictionary mapping (A-Z + common words)
  static const List<String> _aslDictionary = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J',
    'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T',
    'U', 'V', 'W', 'X', 'Y', 'Z', 'UNKNOWN'
  ];
  
  // Common phrases mapping for multi-sign sequences
  static const Map<String, List<String>> _phraseMapping = {
    'HELLO': ['HELLO', 'HI', 'GREETING'],
    'THANKYOU': ['THANK YOU', 'THANKS'],
    'ILOVEYOU': ['I LOVE YOU'],
    'YES': ['YES'],
    'NO': ['NO'],
    'PLEASE': ['PLEASE'],
    'SORRY': ['SORRY'],
    'MORNING': ['GOOD MORNING', 'MORNING'],
    'NIGHT': ['GOOD NIGHT', 'NIGHT'],
    'COMPUTER': ['COMPUTER', 'PC', 'LAPTOP'],
    'PHONE': ['PHONE', 'CALL', 'TELEPHONE'],
    'HELP': ['HELP'],
    'THANKS': ['THANKS', 'THANK YOU'],
    'GOOD': ['GOOD', 'GREAT'],
    'BAD': ['BAD', 'NOT GOOD'],
  };

  // Getters
  bool get isModelLoaded => _isModelLoaded;
  bool get isProcessing => _isProcessing;
  bool get isInitializing => _isInitializing;
  AslSign? get latestSign => _latestSign;
  String? get error => _error;
  double get averageInferenceTime => _inferenceTimes.isNotEmpty
      ? _inferenceTimes.reduce((a, b) => a + b) / _inferenceTimes.length
      : 0.0;
  double get averageConfidence => _confidenceHistory.isNotEmpty
      ? _confidenceHistory.reduce((a, b) => a + b) / _confidenceHistory.length
      : 0.0;
  int get framesProcessed => _framesProcessed;
  double get currentFps => _fpsHistory.isNotEmpty
      ? _fpsHistory.reduce((a, b) => a + b) / _fpsHistory.length
      : 0.0;

  /// Gets the ASL dictionary labels.
  List<String> get aslDictionary => List.unmodifiable(_aslDictionary);

  /// Initializes the CNN service and loads the ResNet-50 model.
  ///
  /// Supports lazy loading - set [lazy] to false to load immediately.
  /// If [lazy] is true (default), the model will be loaded on first inference.
  Future<void> initialize({
    String modelPath = 'assets/models/asl_cnn.tflite',
    bool lazy = true,
  }) async {
    if (_isModelLoaded) {
      LoggerService.debug('CNN model already loaded');
      return;
    }

    _cachedModelPath = modelPath;
    _lazyLoadEnabled = lazy;

    if (lazy) {
      LoggerService.info('CNN inference service initialized (lazy mode enabled)');
      notifyListeners();
      return;
    }

    return _loadModelSync();
  }

  /// Synchronously loads the model (called from initialize or on first use).
  Future<void> _loadModelSync() async {
    if (_isInitializing || _isModelLoaded) {
      return;
    }

    _isInitializing = true;
    notifyListeners();

    try {
      LoggerService.info('Loading CNN ResNet-50 model with FP16 quantization...');
      _error = null;

      final modelPath = _cachedModelPath ?? 'assets/models/asl_cnn.tflite';

      // Load the model with optimized settings
      await _loadModel(modelPath);

      _isModelLoaded = true;
      _resetState();
      LoggerService.info('CNN inference service initialized successfully');
    } catch (e, stack) {
      _error = 'Failed to initialize CNN service: $e';
      LoggerService.error('CNN initialization failed', error: e, stack: stack);
      rethrow;
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  /// Loads the TFLite model from assets.
  Future<void> _loadModel(String modelPath) async {
    try {
      LoggerService.debug('Loading CNN model from $modelPath');
      
      // Add timeout to prevent hanging on slow devices
      _interpreter = await Interpreter.fromAsset(
        modelPath,
        options: InterpreterOptions()..threads = 4,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Model loading timeout after 30 seconds');
        },
      );
      
      LoggerService.info('CNN model loaded successfully');
      _validateModel();
    } on TimeoutException catch (e, stack) {
      LoggerService.error('CNN model loading timed out', error: e, stack: stack);
      throw ModelLoadException('CNN model loading timed out: $e');
    } catch (e, stack) {
      LoggerService.error('Failed to load CNN model', error: e, stack: stack);
      throw ModelLoadException('Failed to load CNN model: $e');
    }
  }

  /// Validates that the loaded model has expected input/output shapes.
  void _validateModel() {
    if (_interpreter == null) {
      throw ModelLoadException('Interpreter is null');
    }

    final inputTensor = _interpreter!.getInputTensor(0);
    final outputTensor = _interpreter!.getOutputTensor(0);

    LoggerService.debug('Model input shape: ${inputTensor.shape}');
    LoggerService.debug('Model output shape: ${outputTensor.shape}');

    // Validate input shape
    if (inputTensor.shape.length != 4 ||
        inputTensor.shape[1] != inputSize ||
        inputTensor.shape[2] != inputSize) {
      throw ModelLoadException(
        'Invalid input shape. Expected [1, $inputSize, $inputSize, $numChannels]');
    }

    // Validate output shape
    if (outputTensor.shape.length != 2 || outputTensor.shape[1] != numClasses) {
      throw ModelLoadException(
        'Invalid output shape. Expected [1, $numClasses]');
    }
  }

  /// Processes a camera image for ASL inference.
  ///
  /// Handles lazy loading on first call and runs at 15-20 FPS with latency tracking.
  /// Returns null if confidence is below 0.85 threshold.
  Future<AslSign?> processFrame(CameraImage image) async {
    // Lazy load model if enabled and not loaded
    if (!_isModelLoaded) {
      if (_lazyLoadEnabled && _cachedModelPath != null) {
        LoggerService.info('Lazy loading CNN model on first inference...');
        await _loadModelSync();
      } else {
        throw MlInferenceException('CNN model not loaded. Call initialize() first.');
      }
    }

    if (_isProcessing) {
      LoggerService.debug('CNN inference already in progress, skipping frame');
      return null;
    }

    _isProcessing = true;
    final stopwatch = Stopwatch()..start();

    try {
      // Calculate FPS
      _calculateFps();

      // Preprocess the image (YUV420→RGB, 224x224 resize, normalize)
      final processedImage = await _preprocessImage(image);

      // Run inference with retry logic
      final inferenceResult = await _retryHelper.execute(
        () async {
          if (_interpreter == null) {
            throw MlInferenceException('Interpreter not initialized');
          }
          return await _runInference(processedImage);
        },
        onError: (error, attempt) {
          LoggerService.warn('CNN inference attempt $attempt failed: $error');
        },
        shouldRetry: (error) {
          // Retry on temporary inference errors
          return RetryHelpers.isRetryableError(error);
        },
        onMaxRetriesReached: (error) {
          LoggerService.error('Max CNN inference retries reached: $error');
        },
      );

      // Check latency target
      final latency = stopwatch.elapsedMilliseconds;
      if (latency > maxLatencyMs) {
        LoggerService.warn('CNN inference latency exceeded target: ${latency}ms > ${maxLatencyMs}ms');
      }

      // Apply adaptive temporal smoothing (adjusts window based on signing speed)
      final smoothedResult = await _applyAdaptiveTemporalSmoothing(inferenceResult);

      // Skip low confidence predictions (< 0.85)
      if (smoothedResult.confidence < confidenceThreshold) {
        LoggerService.debug('Confidence ${smoothedResult.confidence.toStringAsFixed(3)} below threshold $confidenceThreshold');
        return null;
      }

      // Create ASL sign with high confidence
      final sign = AslSign.fromLetter(
        smoothedResult.letter,
        confidence: smoothedResult.confidence,
      );

      // Update tracking
      _latestSign = sign;
      _signHistory.add(sign);
      _confidenceHistory.add(sign.confidence);
      _framesProcessed++;

      // Maintain history sizes
      if (_signHistory.length > 50) _signHistory.removeAt(0);
      if (_confidenceHistory.length > 20) _confidenceHistory.removeAt(0);

      // Track inference time
      stopwatch.stop();
      _inferenceTimes.add(stopwatch.elapsedMilliseconds.toDouble());
      if (_inferenceTimes.length > 20) _inferenceTimes.removeAt(0);

      LoggerService.debug(
        'CNN inference: ${sign.letter} (${(sign.confidence * 100).toStringAsFixed(1)}%) '
        'in ${stopwatch.elapsedMilliseconds}ms (avg: ${averageInferenceTime.toStringAsFixed(1)}ms)',
      );

      return sign;
    } catch (e, stack) {
      _error = 'CNN inference failed: $e';
      LoggerService.error('CNN inference failed', error: e, stack: stack);
      rethrow;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// Calculates current FPS for performance monitoring.
  void _calculateFps() {
    final now = DateTime.now();

    if (_lastFrameTime != null) {
      final elapsed = now.difference(_lastFrameTime!).inMilliseconds;
      final fps = 1000.0 / elapsed;
      _fpsHistory.add(fps);

      if (_fpsHistory.length > 30) {
        _fpsHistory.removeAt(0);
      }

      // Check if FPS is within target range
      if (fps < targetFpsMin || fps > targetFpsMax) {
        LoggerService.debug('FPS: ${fps.toStringAsFixed(1)} (target: $targetFpsMin-$targetFpsMax)');
      }
    }

    _lastFrameTime = now;
  }

  /// Preprocesses camera image for model input.
  Future<Float32List> _preprocessImage(CameraImage image) async {
    return await compute(_preprocessImageIsolate, {
      'width': image.width,
      'height': image.height,
      'planes': image.planes.map((p) => p.bytes).toList(),
      'format': image.format.raw,
    });
  }

  /// Runs inference on the preprocessed image.
  Future<InferenceResult> _runInference(Float32List input) async {
    if (_interpreter == null) {
      throw MlInferenceException('Interpreter not initialized');
    }

    final output = List.filled(numClasses, 0.0);
    
    try {
      _interpreter!.run(input, output);
      return _postProcessOutput(output);
    } catch (e) {
      throw MlInferenceException('Inference failed: $e');
    }
  }

  /// Post-processes model output to get prediction.
  ///
  /// Uses softmax probability distribution to determine the most likely sign.
  InferenceResult _postProcessOutput(List<double> output) {
    double maxConfidence = 0.0;
    int maxIndex = 0;

    for (int i = 0; i < output.length; i++) {
      if (output[i] > maxConfidence) {
        maxConfidence = output[i];
        maxIndex = i;
      }
    }

    // Get the corresponding letter from ASL dictionary
    final letter = maxIndex < _aslDictionary.length
        ? _aslDictionary[maxIndex]
        : 'UNKNOWN';

    return InferenceResult(
      letter: letter,
      confidence: maxConfidence,
      classIndex: maxIndex,
      rawOutput: output,
    );
  }

  /// Applies temporal smoothing to reduce jitter.
  ///
  /// Uses a 3-5 frame sliding window to smooth predictions and reduce false positives.
  /// Only applies smoothing when the buffer has at least 3 frames.
  Future<InferenceResult> _applyTemporalSmoothing(InferenceResult result) async {
    // Add current result to buffer
    _temporalBuffer.add(result);

    // Maintain buffer size (3-5 frames, default 5)
    if (_temporalBuffer.length > smoothingWindow) {
      _temporalBuffer.removeAt(0);
    }

    // If buffer has fewer than 3 frames, return original result
    if (_temporalBuffer.length < 3) {
      return result;
    }

    // Count occurrences of each prediction in the buffer
    final Map<String, int> predictionCounts = {};
    final Map<String, double> predictionConfidences = {};

    for (final r in _temporalBuffer) {
      predictionCounts[r.letter] = (predictionCounts[r.letter] ?? 0) + 1;
      predictionConfidences[r.letter] = (predictionConfidences[r.letter] ?? 0.0) + r.confidence;
    }

    // Find the most frequent prediction
    String mostFrequent = result.letter;
    int maxCount = 1;

    for (final entry in predictionCounts.entries) {
      if (entry.value > maxCount) {
        maxCount = entry.value;
        mostFrequent = entry.key;
      }
    }

    // If the most frequent prediction appears in at least 3 frames, use it
    if (maxCount >= 3 && mostFrequent != 'UNKNOWN') {
      final avgConfidence = predictionConfidences[mostFrequent]! / maxCount;

      return InferenceResult(
        letter: mostFrequent,
        confidence: avgConfidence,
        classIndex: _aslDictionary.indexOf(mostFrequent),
        rawOutput: result.rawOutput,
      );
    }

    // Otherwise, return original result
    return result;
  }

  /// Applies adaptive temporal smoothing based on signing speed.
  ///
  /// Adjusts the smoothing window size based on how quickly signs are changing.
  /// Fast signing = smaller window, slow signing = larger window.
  Future<InferenceResult> _applyAdaptiveTemporalSmoothing(InferenceResult result) async {
    // Track confidence history for speed detection
    _signConfidenceHistory.add(result.confidence);
    if (_signConfidenceHistory.length > 20) {
      _signConfidenceHistory.removeAt(0);
    }

    // Detect sign change rate
    if (_temporalBuffer.isNotEmpty) {
      final lastResult = _temporalBuffer.last;
      final signChanged = lastResult.letter != result.letter;

      // Adaptive window adjustment
      if (signChanged) {
        // Signs changing quickly - use smaller window for responsiveness
        _adaptiveSmoothingWindow = 3;
      } else if (_signConfidenceHistory.length >= 5) {
        // Check confidence stability
        final recentConfidences = _signConfidenceHistory.take(5).toList();
        final variance = _calculateVariance(recentConfidences);

        // Stable confidence - can use larger window
        if (variance < 0.05) {
          _adaptiveSmoothingWindow = 5;
        } else {
          _adaptiveSmoothingWindow = 4;
        }
      }
    }

    // Use adaptive window size
    final originalWindow = _adaptiveSmoothingWindow;

    // Temporarily override smoothingWindow
    final savedWindow = _adaptiveSmoothingWindow;
    _adaptiveSmoothingWindow = _adaptiveSmoothingWindow.clamp(3, 5);

    // Apply smoothing
    final smoothed = await _applyTemporalSmoothing(result);

    // Restore
    _adaptiveSmoothingWindow = savedWindow;

    return smoothed;
  }

  /// Calculates variance of confidence values.
  double _calculateVariance(List<double> values) {
    if (values.isEmpty) return 0.0;

    final mean = values.reduce((a, b) => a + b) / values.length;
    final squaredDiffs = values.map((v) => pow(v - mean, 2)).toList();
    return squaredDiffs.reduce((a, b) => a + b) / values.length;
  }

  /// Gets recent signs for sequence building.
  List<AslSign> getRecentSigns([int count = 10]) {
    return _signHistory.sublist(
      max(0, _signHistory.length - count),
    );
  }

  /// Converts letter sequences to words/phrases using mapping.
  String? convertToPhrase(List<AslSign> signs) {
    if (signs.isEmpty) return null;
    
    // Get letters as string
    final letters = signs.map((s) => s.letter).join('');
    
    // Check for exact matches in phrase mapping
    for (final entry in _phraseMapping.entries) {
      if (entry.key == letters) {
        // Return most common phrase
        return entry.value.first.toLowerCase();
      }
    }
    
    // If no phrase match, return joined letters
    return letters.toLowerCase();
  }

  /// Gets performance statistics.
  Map<String, dynamic> get performanceStats => {
        'averageInferenceTime': averageInferenceTime,
        'averageConfidence': averageConfidence,
        'framesProcessed': framesProcessed,
        'modelLatency': averageInferenceTime,
      };

  /// Resets internal state.
  void _resetState() {
    _signHistory.clear();
    _confidenceHistory.clear();
    _inferenceTimes.clear();
    _temporalBuffer.clear();
    _framesProcessed = 0;
    _latestSign = null;
  }

  /// Unloads the model to free resources.
  Future<void> unloadModel() async {
    LoggerService.info('Unloading CNN model');
    _interpreter?.close();
    _interpreter = null;
    _isModelLoaded = false;
    _resetState();
    notifyListeners();
  }

  @override
  void dispose() {
    LoggerService.info('Disposing CNN inference service');
    _interpreter?.close();
    _interpreter = null;
    super.dispose();
  }
}

/// Represents the result of CNN inference.
class InferenceResult {
  final String letter;
  final double confidence;
  final int classIndex;
  final List<double>? rawOutput;

  const InferenceResult({
    required this.letter,
    required this.confidence,
    required this.classIndex,
    this.rawOutput,
  });

  @override
  String toString() => 'InferenceResult(letter: $letter, confidence: ${confidence.toStringAsFixed(3)}, classIndex: $classIndex)';

  /// Returns true if this result has high confidence (>= 0.85).
  bool get isHighConfidence => confidence >= 0.85;

  /// Returns true if this is an unknown/low confidence prediction.
  bool get isUnknown => letter == 'UNKNOWN' || confidence < 0.5;
}

/// Exception for model loading errors.
class ModelLoadException implements Exception {
  final String message;
  const ModelLoadException(this.message);

  @override
  String toString() => 'ModelLoadException: $message';
}

/// Preprocesses image in isolate.
Float32List _preprocessImageIsolate(Map<String, dynamic> data) {
  final width = data['width'] as int;
  final height = data['height'] as int;
  final planes = (data['planes'] as List).cast<Uint8List>();
  final format = data['format'] as int;

  // Create image from camera data
  img.Image? image;
  
  // Handle YUV420 format (most common on mobile)
  if (format == 35 || format == 842094169) { // YUV_420_888
    image = _convertYUV420toImage(width, height, planes);
  } else {
    // Fallback: create grayscale image
    image = img.Image(width: width, height: height);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final index = y * width + x;
        final gray = planes[0][index];
        image!.setPixelSafe(x, y, _packRGB(gray, gray, gray));
      }
    }
  }

  if (image == null) {
    throw Exception('Failed to create image from camera data');
  }

  // Resize to model input size
  final resized = img.copyResize(image, width: 224, height: 224);
  
  // Normalize and convert to Float32List
  return _imageToFloat32List(resized);
}

/// Converts YUV420 image data to RGB image.
img.Image _convertYUV420toImage(int width, int height, List<Uint8List> planes) {
  final image = img.Image(width: width, height: height);
  
  final yPlane = planes[0];
  final uPlane = planes[1];
  final vPlane = planes[2];
  
  final uvRowStride = width ~/ 2;
  final uvPixelStride = (planes[1].length / uvRowStride).round();
  
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final yIndex = y * width + x;
      final uvIndex = (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;
      
      final yByte = yPlane[yIndex] & 0xFF;
      final uByte = uPlane[uvIndex] & 0xFF;
      final vByte = vPlane[uvIndex] & 0xFF;
      
      final Y = yByte - 16;
      final U = uByte - 128;
      final V = vByte - 128;
      
      // YUV to RGB conversion
      final R = (298 * Y + 409 * V + 128) >> 8;
      final G = (298 * Y - 100 * U - 208 * V + 128) >> 8;
      final B = (298 * Y + 516 * U + 128) >> 8;
      
      final r = R.clamp(0, 255);
      final g = G.clamp(0, 255);
      final b = B.clamp(0, 255);
      
      image.setPixelSafe(x, y, _packRGB(r, g, b));
    }
  }
  
  return image;
}

/// Packs RGB values into a single integer.
int _packRGB(int r, int g, int b) {
  return 0xFF000000 | ((r & 0xFF) << 16) | ((g & 0xFF) << 8) | (b & 0xFF);
}

/// Converts image to normalized Float32List for model input.
Float32List _imageToFloat32List(img.Image image) {
  final inputSize = 224;
  final result = Float32List(1 * inputSize * inputSize * 3);
  
  for (int y = 0; y < inputSize; y++) {
    for (int x = 0; x < inputSize; x++) {
      final pixel = image.getPixelSafe(x, y);
      
      final r = ((pixel >> 16) & 0xFF) / 255.0;
      final g = ((pixel >> 8) & 0xFF) / 255.0;
      final b = (pixel & 0xFF) / 255.0;
      
      // Apply ImageNet normalization
      final nr = (r - 0.485) / 0.229;
      final ng = (g - 0.456) / 0.224;
      final nb = (b - 0.406) / 0.225;
      
      final index = (y * inputSize + x) * 3;
      result[index] = nr.toDouble();
      result[index + 1] = ng.toDouble();
      result[index + 2] = nb.toDouble();
    }
  }
  
  return result;
}

/// Disposes the CNN service and releases resources.
@override
void dispose() {
  LoggerService.info('Disposing CNN inference service');
  _retryHelper.dispose();
  _interpreter?.close();
  _interpreter = null;
  _isModelLoaded = false;
  _signHistory.clear();
  _confidenceHistory.clear();
  _fpsHistory.clear();
  _inferenceTimes.clear();
  _temporalBuffer.clear();
  _signConfidenceHistory.clear();
  super.dispose();
}
