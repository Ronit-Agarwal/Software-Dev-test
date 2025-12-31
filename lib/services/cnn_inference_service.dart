import 'dart:async';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:signsync/core/error/exceptions.dart';
import 'package:signsync/core/logging/logger_service.dart';
import 'package:signsync/models/asl_sign.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// CNN-based ASL inference service using ResNet-50 architecture.
///
/// Processes individual frames for static ASL signs with confidence filtering,
/// temporal smoothing, and ASL dictionary mapping.
class CnnInferenceService with ChangeNotifier {
  Interpreter? _interpreter;
  bool _isModelLoaded = false;
  bool _isProcessing = false;
  AslSign? _latestSign;
  final List<AslSign> _signHistory = [];
  String? _error;

  // Model parameters
  static const int inputSize = 224;
  static const int numChannels = 3;
  static const int numClasses = 27; // 26 letters + 1 unknown/background
  static const double confidenceThreshold = 0.85;

  // Performance monitoring
  final List<double> _inferenceTimes = [];
  final List<double> _confidenceHistory = [];
  int _framesProcessed = 0;

  // Temporal smoothing
  static const int smoothingWindow = 5;
  final List<double> _temporalBuffer = [];
  
  // ASL dictionary mapping
  static const List<String> _aslDictionary = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J',
    'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T',
    'U', 'V', 'W', 'X', 'Y', 'Z', 'UNKNOWN'
  ];
  
  // Common phrases mapping
  static const Map<String, List<String>> _phraseMapping = {
    'HELLO': ['HELLO', 'HI', 'GREETING'],
    'THANKYOU': ['THANK YOU', 'THANKS'],
    'ILOVEYOU': ['I LOVE YOU'],
    'YES': ['YES'],
    'NO': ['NO'],
    'MORNING': ['GOOD MORNING', 'MORNING'],
    'NIGHT': ['GOOD NIGHT', 'NIGHT'],
    'COMPUTER': ['COMPUTER', 'PC'],
  };

  // Getters
  bool get isModelLoaded => _isModelLoaded;
  bool get isProcessing => _isProcessing;
  AslSign? get latestSign => _latestSign;
  String? get error => _error;
  double get averageInferenceTime => _inferenceTimes.isNotEmpty 
      ? _inferenceTimes.reduce((a, b) => a + b) / _inferenceTimes.length 
      : 0.0;
  double get averageConfidence => _confidenceHistory.isNotEmpty
      ? _confidenceHistory.reduce((a, b) => a + b) / _confidenceHistory.length
      : 0.0;
  int get framesProcessed => _framesProcessed;

  /// Initializes the CNN service and loads the ResNet-50 model.
  Future<void> initialize({String modelPath = 'assets/models/asl_cnn.tflite'}) async {
    try {
      LoggerService.info('Initializing CNN inference service');
      _error = null;

      // Load the model
      await _loadModel(modelPath);
      
      _isModelLoaded = true;
      _resetState();
      notifyListeners();
      LoggerService.info('CNN inference service initialized successfully');
    } catch (e, stack) {
      _error = 'Failed to initialize CNN service: $e';
      LoggerService.error('CNN initialization failed', error: e, stack: stack);
      rethrow;
    }
  }

  /// Loads the TFLite model from assets.
  Future<void> _loadModel(String modelPath) async {
    try {
      LoggerService.debug('Loading CNN model from $modelPath');
      
      _interpreter = await Interpreter.fromAsset(
        modelPath,
        options: InterpreterOptions()..threads = 4,
      );
      
      LoggerService.info('CNN model loaded successfully');
      _validateModel();
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
  Future<AslSign?> processFrame(CameraImage image) async {
    if (!_isModelLoaded) {
      throw MlInferenceException('CNN model not loaded. Call initialize() first.');
    }

    if (_isProcessing) {
      LoggerService.warn('CNN inference already in progress, skipping frame');
      return null;
    }

    _isProcessing = true;
    final stopwatch = Stopwatch()..start();

    try {
      // Preprocess the image
      final processedImage = await _preprocessImage(image);
      
      // Run inference
      final inferenceResult = await _runInference(processedImage);
      
      // Apply temporal smoothing
      final smoothedResult = await _applyTemporalSmoothing(inferenceResult);
      
      // Skip low confidence predictions
      if (smoothedResult.confidence < confidenceThreshold) {
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
      
      LoggerService.debug('CNN inference: ${sign.letter} (${(sign.confidence * 100).toStringAsFixed(1)}%) in ${stopwatch.elapsedMilliseconds}ms');
      
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
  InferenceResult _postProcessOutput(List<double> output) {
    double maxConfidence = 0.0;
    int maxIndex = 0;
    
    for (int i = 0; i < output.length; i++) {
      if (output[i] > maxConfidence) {
        maxConfidence = output[i];
        maxIndex = i;
      }
    }

    // Get the corresponding letter
    final letter = maxIndex < _aslDictionary.length 
        ? _aslDictionary[maxIndex] 
        : 'UNKNOWN';
    
    return InferenceResult(
      letter: letter,
      confidence: maxConfidence,
      classIndex: maxIndex,
    );
  }

  /// Applies temporal smoothing to reduce jitter.
  Future<InferenceResult> _applyTemporalSmoothing(InferenceResult result) async {
    // Add current result to buffer
    _temporalBuffer.add(result.confidence);
    if (_temporalBuffer.length > smoothingWindow) {
      _temporalBuffer.removeAt(0);
    }

    // If buffer is not full, return original result
    if (_temporalBuffer.length < smoothingWindow) {
      return result;
    }

    // Calculate average confidence
    final avgConfidence = _temporalBuffer.reduce((a, b) => a + b) / _temporalBuffer.length;
    
    // Update confidence with temporal smoothing
    if (result.confidence > avgConfidence * 0.8) {
      result = InferenceResult(
        letter: result.letter,
        confidence: avgConfidence,
        classIndex: result.classIndex,
      );
    }

    return result;
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

  const InferenceResult({
    required this.letter,
    required this.confidence,
    required this.classIndex,
  });

  @override
  String toString() => 'InferenceResult(letter: $letter, confidence: ${confidence.toStringAsFixed(3)})';
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