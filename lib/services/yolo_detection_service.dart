import 'dart:async';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:signsync/core/error/exceptions.dart';
import 'package:signsync/core/logging/logger_service.dart';
import 'package:signsync/models/detected_object.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// YOLOv11-based object detection service.
///
/// Detects 80 COCO dataset objects in real-time with optimized preprocessing,
/// NMS filtering, and confidence scoring at 24 FPS target.
class YoloDetectionService with ChangeNotifier {
  Interpreter? _interpreter;
  bool _isModelLoaded = false;
  bool _isProcessing = false;
  DetectionFrame? _latestFrame;
  String? _error;

  // Model parameters
  static const int inputSize = 640; // YOLOv11 input size
  static const int numChannels = 3;
  static const int numClasses = 80; // COCO dataset classes
  static const double confidenceThreshold = 0.60; // Filter detections by confidence threshold (0.6+)
  static const double nmsThreshold = 0.45; // Non-maximum suppression threshold

  // Monocular depth estimation constants
  static const double _focalLengthFactor = 1.0; // Heuristic focal length factor
  static const Map<String, double> _realWorldHeights = {
    'person': 1.7,
    'bicycle': 1.0,
    'car': 1.5,
    'motorcycle': 1.0,
    'bus': 3.0,
    'truck': 3.5,
    'traffic light': 0.8,
    'stop sign': 0.75,
    'bench': 0.5,
    'dog': 0.5,
    'cat': 0.25,
    'backpack': 0.45,
    'umbrella': 0.8,
    'bottle': 0.25,
    'cup': 0.12,
    'chair': 0.9,
    'couch': 0.8,
    'potted plant': 0.4,
    'dining table': 0.75,
    'tv': 0.6,
    'laptop': 0.2,
    'cell phone': 0.15,
    'book': 0.2,
    'clock': 0.25,
  };

  // Performance monitoring
  final List<double> _inferenceTimes = [];
  final List<double> _detectionCountHistory = [];
  int _framesProcessed = 0;
  int _totalObjectsDetected = 0;

  // Detection tracking and distance caching
  final List<DetectionFrame> _frameHistory = [];
  final Map<String, int> _objectFrequency = {};
  final Map<String, DateTime> _firstSeen = {};
  final Map<String, List<double>> _distanceCache = {}; // Cache for distance smoothing
  static const int _maxCacheSize = 5;

  // COCO class labels (80 classes)
  static const List<String> _cocoLabels = [
    'person', 'bicycle', 'car', 'motorcycle', 'airplane', 'bus',
    'train', 'truck', 'boat', 'traffic light', 'fire hydrant',
    'stop sign', 'parking meter', 'bench', 'bird', 'cat', 'dog',
    'horse', 'sheep', 'cow', 'elephant', 'bear', 'zebra', 'giraffe',
    'backpack', 'umbrella', 'handbag', 'tie', 'suitcase', 'frisbee',
    'skis', 'snowboard', 'sports ball', 'kite', 'baseball bat',
    'baseball glove', 'skateboard', 'surfboard', 'tennis racket',
    'bottle', 'wine glass', 'cup', 'fork', 'knife', 'spoon', 'bowl',
    'banana', 'apple', 'sandwich', 'orange', 'broccoli', 'carrot',
    'hot dog', 'pizza', 'donut', 'cake', 'chair', 'couch',
    'potted plant', 'bed', 'dining table', 'toilet', 'tv', 'laptop',
    'mouse', 'remote', 'keyboard', 'cell phone', 'microwave', 'oven',
    'toaster', 'sink', 'refrigerator', 'book', 'clock', 'vase',
    'scissors', 'teddy bear', 'hair drier', 'toothbrush'
  ];

  // Accessibility-related objects priority
  static const Set<String> _priorityObjects = {
    'person', 'chair', 'door', 'stair', 'elevator', 'bicycle',
    'car', 'traffic light', 'stop sign', 'bottle', 'cup', 'phone',
    'book', 'clock', 'laptop', 'keyboard', 'mouse'
  };

  // Getters
  bool get isModelLoaded => _isModelLoaded;
  bool get isProcessing => _isProcessing;
  DetectionFrame? get latestFrame => _latestFrame;
  String? get error => _error;
  int get framesProcessed => _framesProcessed;
  int get totalObjectsDetected => _totalObjectsDetected;
  double get averageInferenceTime => _inferenceTimes.isNotEmpty
      ? _inferenceTimes.reduce((a, b) => a + b) / _inferenceTimes.length
      : 0.0;
  List<double> get detectionHistory => List.unmodifiable(_detectionCountHistory);

  /// Initializes the YOLO detection service.
  Future<void> initialize({String modelPath = 'assets/models/yolov11.tflite'}) async {
    try {
      LoggerService.info('Initializing YOLO detection service');
      _error = null;

      // Load the model
      await _loadModel(modelPath);
      
      _isModelLoaded = true;
      _resetState();
      notifyListeners();
      LoggerService.info('YOLO detection service initialized successfully');
    } catch (e, stack) {
      _error = 'Failed to initialize YOLO service: $e';
      LoggerService.error('YOLO initialization failed', error: e, stack: stack);
      rethrow;
    }
  }

  /// Loads the YOLO model from assets.
  Future<void> _loadModel(String modelPath) async {
    try {
      LoggerService.debug('Loading YOLO model from $modelPath');
      
      _interpreter = await Interpreter.fromAsset(
        modelPath,
        options: InterpreterOptions()
          ..threads = 4
          ..useNnApiForAndroid = true,
      );
      
      LoggerService.info('YOLO model loaded successfully');
      _validateModel();
    } catch (e, stack) {
      LoggerService.error('Failed to load YOLO model', error: e, stack: stack);
      throw ModelLoadException('Failed to load YOLO model: $e');
    }
  }

  /// Validates the loaded model shapes.
  void _validateModel() {
    if (_interpreter == null) {
      throw ModelLoadException('Interpreter is null');
    }

    final inputTensor = _interpreter!.getInputTensor(0);
    final outputTensors = _interpreter!.getOutputTensors();

    LoggerService.debug('YOLO input shape: ${inputTensor.shape}');
    LoggerService.debug('YOLO output tensors: ${outputTensors.length}');

    // Validate input shape [1, 640, 640, 3]
    if (inputTensor.shape.length != 4 ||
        inputTensor.shape[1] != inputSize ||
        inputTensor.shape[2] != inputSize) {
      throw ModelLoadException(
        'Invalid YOLO input shape. Expected [1, $inputSize, $inputSize, $numChannels]');
    }

    // Check output tensors (YOLOv11 has multiple outputs for different scales)
    if (outputTensors.isEmpty) {
      throw ModelLoadException('No output tensors found');
    }
  }

  /// Detects objects in a camera frame.
  Future<DetectionFrame?> detect(CameraImage image) async {
    if (!_isModelLoaded) {
      throw MlInferenceException('YOLO model not loaded. Call initialize() first.');
    }

    if (_isProcessing) {
      LoggerService.warn('YOLO detection already in progress, skipping frame');
      return null;
    }

    _isProcessing = true;
    final stopwatch = Stopwatch()..start();

    try {
      // Preprocess the image
      final processedImage = await _preprocessImage(image);
      
      // Run inference
      final detections = await _runDetection(processedImage);
      
      // Apply NMS and filter by confidence
      final filteredDetections = await _applyNMS(detections);
      
      // Create detected objects
      final objects = await _processDetections(
        filteredDetections,
        image.width.toDouble(),
        image.height.toDouble(),
      );

      // Skip if no objects detected
      if (objects.isEmpty) {
        return null;
      }

      // Create detection frame
      stopwatch.stop();
      final frame = DetectionFrame(
        id: 'frame_${DateTime.now().millisecondsSinceEpoch}',
        objects: objects,
        timestamp: DateTime.now(),
        frameIndex: _framesProcessed,
        inferenceTime: stopwatch.elapsedMilliseconds.toDouble(),
      );

      // Update tracking
      _latestFrame = frame;
      _frameHistory.add(frame);
      _totalObjectsDetected += objects.length;
      
      // Update object frequency tracking
      for (final obj in objects) {
        _objectFrequency[obj.label] = (_objectFrequency[obj.label] ?? 0) + 1;
        _firstSeen.putIfAbsent(obj.label, () => DateTime.now());
      }
      
      // Maintain history size
      if (_frameHistory.length > 30) {
        _frameHistory.removeAt(0);
      }
      
      // Track detection count
      _detectionCountHistory.add(objects.length.toDouble());
      if (_detectionCountHistory.length > 20) {
        _detectionCountHistory.removeAt(0);
      }
      
      // Track inference time
      _inferenceTimes.add(stopwatch.elapsedMilliseconds.toDouble());
      if (_inferenceTimes.length > 20) {
        _inferenceTimes.removeAt(0);
      }
      
      _framesProcessed++;

      LoggerService.debug('YOLO detection: ${objects.length} objects in ${stopwatch.elapsedMilliseconds}ms');
      
      notifyListeners();
      return frame;
    } catch (e, stack) {
      _error = 'YOLO detection failed: $e';
      LoggerService.error('YOLO detection failed', error: e, stack: stack);
      rethrow;
    } finally {
      _isProcessing = false;
    }
  }

  /// Preprocesses camera image for YOLO input.
  Future<Float32List> _preprocessImage(CameraImage image) async {
    return compute(_preprocessImageIsolate, {
      'width': image.width,
      'height': image.height,
      'planes': image.planes.map((p) => p.bytes).toList(),
      'format': image.format.raw,
    });
  }

  /// Runs YOLO detection on preprocessed image.
  Future<List<List<double>>> _runDetection(Float32List input) async {
    if (_interpreter == null) {
      throw MlInferenceException('YOLO interpreter not initialized');
    }

    // YOLOv11 outputs multiple tensors for different scales
    final outputs = List.generate(
      _interpreter!.getOutputTensors().length,
      (_) => <List<List<double>>>[],
    );

    try {
      _interpreter!.runForMultipleInputs([input], outputs);
      return _flattenOutputs(outputs);
    } catch (e) {
      throw MlInferenceException('YOLO inference failed: $e');
    }
  }

  /// Flattens multiple YOLO outputs into a single detection list.
  List<List<double>> _flattenOutputs(List<List<List<List<double>>>> outputs) {
    final detections = <List<double>>[];

    for (final output in outputs) {
      for (final detection in output) {
        for (final box in detection) {
          // YOLO format: [x, y, w, h, conf, class1, class2, ...]
          if (box.length >= 6) {
            final confidence = box[4];
            if (confidence > confidenceThreshold) {
              detections.add(List<double>.from(box));
            }
          }
        }
      }
    }

    return detections;
  }

  /// Applies Non-Maximum Suppression to remove overlapping boxes.
  Future<List<List<double>>> _applyNMS(List<List<double>> detections) async {
    return compute(_applyNMSIsolate, {
      'detections': detections,
      'nmsThreshold': nmsThreshold,
      'confidenceThreshold': confidenceThreshold,
    });
  }

  /// Converts detections to DetectedObject instances.
  Future<List<DetectedObject>> _processDetections(
    List<List<double>> detections,
    double imageWidth,
    double imageHeight,
  ) async {
    final objects = <DetectedObject>[];

    for (final detection in detections) {
      final x = detection[0]; // center x
      final y = detection[1]; // center y
      final w = detection[2]; // width
      final h = detection[3]; // height
      final confidence = detection[4];

      // Find class with highest probability
      double maxClassProb = 0.0;
      int classIndex = 0;
      
      for (int i = 5; i < detection.length; i++) {
        if (detection[i] > maxClassProb) {
          maxClassProb = detection[i];
          classIndex = i - 5;
        }
      }

      // Scale to original image coordinates
      final left = (x - w / 2) * imageWidth;
      final top = (y - h / 2) * imageHeight;
      final width = w * imageWidth;
      final height = h * imageHeight;

      // Create bounding box
      final boundingBox = Rect.fromLTWH(
        left.clamp(0.0, imageWidth),
        top.clamp(0.0, imageHeight),
        width.clamp(0.0, imageWidth - left),
        height.clamp(0.0, imageHeight - top),
      );

      // Get class name
      final className = classIndex < _cocoLabels.length 
          ? _cocoLabels[classIndex] 
          : 'unknown';

      // Estimate distance and depth
      final distance = _estimateDistance(className, h);
      final smoothedDistance = _getSmoothedDistance(className, distance);
      final depth = _estimateDepth(smoothedDistance);

      // Create detected object
      objects.add(DetectedObject.basic(
        label: className,
        confidence: confidence * maxClassProb,
        boundingBox: boundingBox,
        distance: smoothedDistance,
        depth: depth,
      ));
    }

    return objects;
  }

  /// Estimates distance to object based on bounding box height and real-world size.
  double _estimateDistance(String label, double normalizedHeight) {
    if (normalizedHeight <= 0) return 0.0;
    
    final realHeight = _realWorldHeights[label] ?? 1.0; // Default 1m if unknown
    
    // Simple monocular depth formula: distance = (realHeight * focalLength) / imageHeight
    // Using normalized coordinates where image height is 1.0
    return (realHeight * _focalLengthFactor) / normalizedHeight;
  }

  /// Smooths distance measurements using a moving average cache.
  double _getSmoothedDistance(String label, double currentDistance) {
    if (!_distanceCache.containsKey(label)) {
      _distanceCache[label] = [];
    }
    
    final history = _distanceCache[label]!;
    history.add(currentDistance);
    
    if (history.length > _maxCacheSize) {
      history.removeAt(0);
    }
    
    // Return average of recent measurements
    return history.reduce((a, b) => a + b) / history.length;
  }

  /// Estimates a relative depth score [0, 1] based on distance.
  /// 1.0 is very close, 0.0 is very far.
  double _estimateDepth(double distance) {
    if (distance <= 0) return 0.0;
    // Assume 10 meters is "far" (0.0) and 0.5 meters is "close" (1.0)
    const maxDistance = 10.0;
    const minDistance = 0.5;
    
    final normalized = (distance - minDistance) / (maxDistance - minDistance);
    return (1.0 - normalized).clamp(0.0, 1.0);
  }

  /// Gets detection statistics.
  Map<String, dynamic> get detectionStats => {
        'totalObjects': _totalObjectsDetected,
        'framesProcessed': _framesProcessed,
        'objectsPerFrame': _framesProcessed > 0 
            ? _totalObjectsDetected / _framesProcessed 
            : 0.0,
        'averageInferenceTime': averageInferenceTime,
        'objectFrequency': _objectFrequency,
      };

  /// Gets recent detection frames.
  List<DetectionFrame> getRecentFrames([int count = 10]) {
    return _frameHistory.sublist(
      max(0, _frameHistory.length - count),
    );
  }

  /// Gets most frequently detected objects.
  List<MapEntry<String, int>> getMostFrequentObjects([int count = 10]) {
    final sorted = _objectFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(count).toList();
  }

  /// Filters objects by priority for accessibility.
  List<DetectedObject> filterPriorityObjects(List<DetectedObject> objects) {
    return objects
        .where((obj) => _priorityObjects.contains(obj.label))
        .toList()
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
  }

  /// Resets internal state.
  void _resetState() {
    _frameHistory.clear();
    _objectFrequency.clear();
    _firstSeen.clear();
    _distanceCache.clear();
    _inferenceTimes.clear();
    _detectionCountHistory.clear();
    _framesProcessed = 0;
    _totalObjectsDetected = 0;
    _latestFrame = null;
  }

  /// Clears detection history.
  void clearHistory() {
    _frameHistory.clear();
    _objectFrequency.clear();
    _firstSeen.clear();
    _distanceCache.clear();
    LoggerService.info('YOLO detection history cleared');
  }

  /// Unloads the YOLO model to free resources.
  Future<void> unloadModel() async {
    LoggerService.info('Unloading YOLO model');
    _interpreter?.close();
    _interpreter = null;
    _isModelLoaded = false;
    _resetState();
    notifyListeners();
  }

  @override
  void dispose() {
    LoggerService.info('Disposing YOLO detection service');
    _interpreter?.close();
    _interpreter = null;
    _resetState();
    super.dispose();
  }
}

/// Preprocesses image for YOLO in isolate.
Float32List _preprocessImageIsolate(Map<String, dynamic> data) {
  final width = data['width'] as int;
  final height = data['height'] as int;
  final planes = (data['planes'] as List).cast<Uint8List>();
  final format = data['format'] as int;

  // Create image from camera data
  img.Image? image;
  
  // Handle YUV420 format
  if (format == 35 || format == 842094169) {
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

  // Resize to YOLO input size (640x640)
  final resized = img.copyResize(image, width: 640, height: 640);
  
  // Convert to normalized Float32List
  return _imageToFloat32List(resized);
}

/// Applies Non-Maximum Suppression in isolate.
List<List<double>> _applyNMSIsolate(Map<String, dynamic> data) {
  final detections = (data['detections'] as List).cast<List<double>>();
  final nmsThreshold = data['nmsThreshold'] as double;
  final confidenceThreshold = data['confidenceThreshold'] as double;

  // Filter by confidence first
  final filtered = detections
      .where((d) => d[4] > confidenceThreshold)
      .toList();

  // Sort by confidence (descending)
  filtered.sort((a, b) => b[4].compareTo(a[4]));

  final selected = <List<double>>[];
  final used = List<bool>.filled(filtered.length, false);

  for (int i = 0; i < filtered.length; i++) {
    if (used[i]) continue;

    selected.add(filtered[i]);
    used[i] = true;

    for (int j = i + 1; j < filtered.length; j++) {
      if (used[j]) continue;

      final iou = _calculateIoU(filtered[i], filtered[j]);
      if (iou > nmsThreshold) {
        used[j] = true;
      }
    }
  }

  return selected;
}

/// Calculates Intersection over Union (IoU) for two boxes.
double _calculateIoU(List<double> box1, List<double> box2) {
  final x1 = box1[0] - box1[2] / 2;
  final y1 = box1[1] - box1[3] / 2;
  final x2 = box1[0] + box1[2] / 2;
  final y2 = box1[1] + box1[3] / 2;

  final x3 = box2[0] - box2[2] / 2;
  final y3 = box2[1] - box2[3] / 2;
  final x4 = box2[0] + box2[2] / 2;
  final y4 = box2[1] + box2[3] / 2;

  final intersectionX = max(0, min(x2, x4) - max(x1, x3));
  final intersectionY = max(0, min(y2, y4) - max(y1, y3));
  final intersectionArea = intersectionX * intersectionY;

  final area1 = (x2 - x1) * (y2 - y1);
  final area2 = (x4 - x3) * (y4 - y3);
  final unionArea = area1 + area2 - intersectionArea;

  return unionArea > 0 ? intersectionArea / unionArea : 0.0;
}

// Reuse helper functions from CNN service
img.Image _convertYUV420toImage(int width, int height, List<Uint8List> planes) {
  // Same implementation as CNN service
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

int _packRGB(int r, int g, int b) {
  return 0xFF000000 | ((r & 0xFF) << 16) | ((g & 0xFF) << 8) | (b & 0xFF);
}

Float32List _imageToFloat32List(img.Image image) {
  final inputSize = 640;
  final result = Float32List(1 * inputSize * inputSize * 3);
  
  for (int y = 0; y < inputSize; y++) {
    for (int x = 0; x < inputSize; x++) {
      final pixel = image.getPixelSafe(x, y);
      
      final r = ((pixel >> 16) & 0xFF) / 255.0;
      final g = ((pixel >> 8) & 0xFF) / 255.0;
      final b = (pixel & 0xFF) / 255.0;
      
      // YOLO normalization (0-1 range)
      final index = (y * inputSize + x) * 3;
      result[index] = r.toDouble();
      result[index + 1] = g.toDouble();
      result[index + 2] = b.toDouble();
    }
  }
  
  return result;
}

/// Exception for YOLO-specific errors.
class YoloException implements Exception {
  final String message;
  const YoloException(this.message);

  @override
  String toString() => 'YoloException: $message';
}