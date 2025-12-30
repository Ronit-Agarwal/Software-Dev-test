import 'dart:async';
import 'dart:collection';
import 'dart:io' show Platform, ProcessInfo;
import 'dart:math';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:signsync/core/error/exceptions.dart';
import 'package:signsync/core/logging/logger_service.dart';
import 'package:signsync/models/app_mode.dart';
import 'package:signsync/models/asl_sign.dart';
import 'package:signsync/models/cnn_inference.dart';
import 'package:signsync/services/asl_sign_dictionary_service.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

@immutable
class CnnInferenceConfig {
  final String modelAssetPath;
  final int inputSize;
  final bool useImageNetNormalization;
  final double confidenceThreshold;
  final int topK;
  final int smoothingWindow;
  final int minConsistentFrames;
  final double targetFps;

  const CnnInferenceConfig({
    this.modelAssetPath = 'assets/models/asl_resnet50_fp16.tflite',
    this.inputSize = 224,
    this.useImageNetNormalization = true,
    this.confidenceThreshold = 0.85,
    this.topK = 5,
    this.smoothingWindow = 5,
    this.minConsistentFrames = 3,
    this.targetFps = 18,
  });

  Duration get minInferenceInterval {
    final ms = (1000 / targetFps).round().clamp(1, 1000);
    return Duration(milliseconds: ms);
  }
}

/// Service for ML inference operations.
///
/// This implementation focuses on real-time ASL *static* recognition using a
/// ResNet-50 CNN exported to TensorFlow Lite.
///
/// Key requirements handled here:
/// - Lazy model loading from assets (cached after the first load)
/// - Robust camera-frame preprocessing (YUV420 -> RGB, resize -> 224x224, normalize)
/// - Frame throttling + single-item queue to avoid bottlenecks
/// - Confidence filtering + temporal smoothing across consecutive frames
/// - Dictionary mapping (class index -> ASL sign metadata)
/// - Latency tracking (preprocess + inference + total)
class MlInferenceService with ChangeNotifier {
  final AslSignDictionaryService _dictionary;

  CnnInferenceConfig _cnnConfig;

  // Interpreter lifecycle
  Interpreter? _aslInterpreter;
  Future<void>? _aslLoadFuture;
  bool _isAslModelLoaded = false;

  // Model I/O specs (read after load)
  List<int> _inputShape = const [];
  TfLiteType? _inputType;
  List<int> _outputShape = const [];
  TfLiteType? _outputType;

  // Streaming state
  bool _isProcessing = false;
  DateTime? _lastInferenceEnd;
  CameraImage? _queuedFrame;
  int _queuedRotation = 0;
  bool _queuedMirror = false;

  // Temporal smoothing
  final Queue<CnnPrediction> _recentTop1 = ListQueue<CnnPrediction>();

  // Public state
  InferenceResult? _latestResult;
  AppMode _currentMode = AppMode.translation;
  String? _error;

  // Performance tracking
  CnnLatencyMetrics? _lastLatency;
  int _consecutiveFailures = 0;

  MlInferenceService({
    AslSignDictionaryService? dictionary,
    CnnInferenceConfig cnnConfig = const CnnInferenceConfig(),
  })  : _dictionary = dictionary ?? AslSignDictionaryService(),
        _cnnConfig = cnnConfig;

  bool get isModelLoaded => _isAslModelLoaded;
  bool get isProcessing => _isProcessing;
  InferenceResult? get latestResult => _latestResult;
  AppMode get currentMode => _currentMode;
  String? get error => _error;
  CnnLatencyMetrics? get lastLatency => _lastLatency;

  double get confidenceThreshold => _cnnConfig.confidenceThreshold;

  Duration get _effectiveMinInferenceInterval {
    final base = _cnnConfig.minInferenceInterval;
    final last = _lastLatency?.totalMs;
    if (last == null || last <= 100) return base;

    // Back off slightly above observed latency to avoid growing a backlog.
    final ms = max(base.inMilliseconds, (last * 1.2).round());
    return Duration(milliseconds: ms);
  }

  Future<void> initialize({AppMode mode = AppMode.translation}) async {
    _error = null;
    _currentMode = mode;

    if (mode == AppMode.translation) {
      await _ensureAslModelLoaded();
    }

    notifyListeners();
  }

  Future<void> switchMode(AppMode mode) async {
    if (_currentMode == mode) return;

    LoggerService.info('Switching ML mode from $_currentMode to $mode');
    _currentMode = mode;

    if (mode == AppMode.translation) {
      await _ensureAslModelLoaded();
    }

    notifyListeners();
  }

  /// For real-time camera streaming.
  ///
  /// This method is designed to be called directly from the camera image stream.
  /// It will:
  /// - throttle inference to ~targetFps
  /// - keep only the latest frame in a 1-item queue
  /// - run preprocessing + inference sequentially (never concurrently)
  void submitCameraFrame(
    CameraImage image, {
    int rotationDegrees = 0,
    bool mirror = false,
  }) {
    if (_currentMode != AppMode.translation) return;

    // Keep only the newest frame; drop older frames to avoid backlog.
    _queuedFrame = image;
    _queuedRotation = rotationDegrees;
    _queuedMirror = mirror;

    if (_isProcessing) return;

    // Throttle to target FPS, with an adaptive backoff when inference latency
    // exceeds the 100ms target.
    final lastEnd = _lastInferenceEnd;
    if (lastEnd != null && DateTime.now().difference(lastEnd) < _effectiveMinInferenceInterval) {
      return;
    }

    unawaited(_drainFrameQueue());
  }

  /// One-off inference API (still safe and uses the same pipeline).
  Future<InferenceResult> processImage(
    dynamic image, {
    AppMode? mode,
    int rotationDegrees = 0,
    bool mirror = false,
  }) async {
    final inferenceMode = mode ?? _currentMode;

    try {
      if (inferenceMode == AppMode.translation) {
        if (image is CameraImage) {
          return _inferAslFromCameraImage(
            image,
            rotationDegrees: rotationDegrees,
            mirror: mirror,
          );
        }

        if (image is Uint8List) {
          return _inferAslFromRgbBytes(image);
        }

        return InferenceResult.error('Unsupported image input type: ${image.runtimeType}');
      }

      // Non-translation inference modes are stubs for now.
      return InferenceResult.success(data: null, confidence: 0.0);
    } catch (e, stack) {
      _error = e.toString();
      LoggerService.error('Inference failed', error: e, stack: stack);
      return InferenceResult.error(_error!);
    } finally {
      notifyListeners();
    }
  }

  Future<void> unloadModel() async {
    LoggerService.info('Unloading ML model');
    _aslInterpreter?.close();
    _aslInterpreter = null;
    _isAslModelLoaded = false;
    _aslLoadFuture = null;
    _recentTop1.clear();
    _latestResult = null;
    notifyListeners();
  }

  void reset() {
    _latestResult = null;
    _error = null;
    _recentTop1.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _aslInterpreter?.close();
    super.dispose();
  }

  Future<void> _ensureAslModelLoaded() async {
    _aslLoadFuture ??= _loadAslModel();
    return _aslLoadFuture!;
  }

  Future<void> _loadAslModel() async {
    try {
      LoggerService.info('Loading ASL TFLite model', extra: {
        'asset': _cnnConfig.modelAssetPath,
      });

      await _dictionary.ensureLoaded();

      final rawAsset = await rootBundle.load(_cnnConfig.modelAssetPath);
      final interpreterOptions = InterpreterOptions()
        ..threads = max(1, min(2, Platform.numberOfProcessors));

      _aslInterpreter = Interpreter.fromBuffer(
        rawAsset.buffer.asUint8List(),
        options: interpreterOptions,
      );

      final input = _aslInterpreter!.getInputTensor(0);
      final output = _aslInterpreter!.getOutputTensor(0);

      _inputShape = input.shape;
      _inputType = input.type;
      _outputShape = output.shape;
      _outputType = output.type;

      _isAslModelLoaded = true;
      _error = null;
      _consecutiveFailures = 0;

      LoggerService.info('ASL model loaded', extra: {
        'input_shape': _inputShape,
        'input_type': _inputType.toString(),
        'output_shape': _outputShape,
        'output_type': _outputType.toString(),
        if (!kIsWeb) 'rss_mb': (ProcessInfo.currentRss / 1024 / 1024).toStringAsFixed(1),
      });
    } catch (e, stack) {
      _isAslModelLoaded = false;
      _error = 'Failed to load ASL model: $e';
      LoggerService.error('ASL model load failed', error: e, stack: stack);
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> _drainFrameQueue() async {
    if (_isProcessing) return;

    final frame = _queuedFrame;
    if (frame == null) return;

    _queuedFrame = null;

    try {
      _isProcessing = true;
      notifyListeners();

      final result = await _inferAslFromCameraImage(
        frame,
        rotationDegrees: _queuedRotation,
        mirror: _queuedMirror,
      );

      _latestResult = result;
      notifyListeners();
    } catch (e, stack) {
      LoggerService.error('Streaming inference failed', error: e, stack: stack);
    } finally {
      _isProcessing = false;
      _lastInferenceEnd = DateTime.now();
      notifyListeners();

      // If a new frame arrived while we were processing, run again immediately
      // (throttling will still apply).
      if (_queuedFrame != null) {
        final lastEnd = _lastInferenceEnd;
        if (lastEnd == null || DateTime.now().difference(lastEnd) >= _effectiveMinInferenceInterval) {
          unawaited(_drainFrameQueue());
        }
      }
    }
  }

  Future<InferenceResult> _inferAslFromCameraImage(
    CameraImage image, {
    required int rotationDegrees,
    required bool mirror,
  }) async {
    await _ensureAslModelLoaded();

    final interpreter = _aslInterpreter;
    if (interpreter == null) {
      throw const InferenceException('ASL model interpreter not available');
    }

    final total = Stopwatch()..start();
    final preprocess = Stopwatch()..start();

    final inputSize = _cnnConfig.inputSize;
    final inputType = _inputType ?? TfLiteType.float32;

    final inputBuffer = _preprocessYuv420ToModelInput(
      image,
      inputSize: inputSize,
      rotationDegrees: rotationDegrees,
      mirror: mirror,
      inputType: inputType,
      useImageNetNormalization: _cnnConfig.useImageNetNormalization,
    );

    preprocess.stop();

    final inference = Stopwatch()..start();

    final outputScores = _runInterpreter(interpreter, inputBuffer);

    inference.stop();
    total.stop();

    final latency = CnnLatencyMetrics(
      preprocessMs: preprocess.elapsedMilliseconds,
      inferenceMs: inference.elapsedMilliseconds,
      totalMs: total.elapsedMilliseconds,
    );
    _lastLatency = latency;

    final result = _postProcessScores(outputScores, latency: latency);
    _consecutiveFailures = 0;

    // Adaptive frame skipping: if we consistently exceed 100ms total, effectively
    // lower the throughput by postponing the next run.
    if (latency.totalMs > 100) {
      LoggerService.warn('ASL inference latency above target', extra: {
        'total_ms': latency.totalMs,
        'pre_ms': latency.preprocessMs,
        'infer_ms': latency.inferenceMs,
      });
    }

    return result;
  }

  Future<InferenceResult> _inferAslFromRgbBytes(Uint8List rgbBytes) async {
    await _ensureAslModelLoaded();

    final decoded = img.decodeImage(rgbBytes);
    if (decoded == null) {
      return InferenceResult.error('Failed to decode RGB bytes');
    }

    final resized = img.copyResize(decoded, width: _cnnConfig.inputSize, height: _cnnConfig.inputSize);
    final buffer = Float32List(_cnnConfig.inputSize * _cnnConfig.inputSize * 3);

    final mean = _cnnConfig.useImageNetNormalization
        ? const [0.485, 0.456, 0.406]
        : const [0.0, 0.0, 0.0];
    final std = _cnnConfig.useImageNetNormalization
        ? const [0.229, 0.224, 0.225]
        : const [1.0, 1.0, 1.0];

    var i = 0;
    for (var y = 0; y < resized.height; y++) {
      for (var x = 0; x < resized.width; x++) {
        final p = resized.getPixel(x, y);
        final r = p.r / 255.0;
        final g = p.g / 255.0;
        final b = p.b / 255.0;

        buffer[i++] = (r - mean[0]) / std[0];
        buffer[i++] = (g - mean[1]) / std[1];
        buffer[i++] = (b - mean[2]) / std[2];
      }
    }

    final interpreter = _aslInterpreter;
    if (interpreter == null) {
      throw const InferenceException('ASL model interpreter not available');
    }

    final total = Stopwatch()..start();
    final inference = Stopwatch()..start();
    final scores = _runInterpreter(interpreter, buffer);
    inference.stop();
    total.stop();

    final latency = CnnLatencyMetrics(preprocessMs: 0, inferenceMs: inference.elapsedMilliseconds, totalMs: total.elapsedMilliseconds);
    return _postProcessScores(scores, latency: latency);
  }

  /// Runs inference and returns the output scores as a flat list.
  ///
  /// Handles float and uint8 outputs.
  List<double> _runInterpreter(Interpreter interpreter, Object inputBuffer) {
    try {
      final outputTensor = interpreter.getOutputTensor(0);
      final shape = outputTensor.shape;
      final numElements = shape.fold<int>(1, (a, b) => a * b);

      // Most classification heads output [1, numClasses]. We store flat data to
      // simplify top-k extraction.
      final Float32List outFloat = Float32List(numElements);
      final Uint8List outUint8 = Uint8List(numElements);

      final Object output;
      if (outputTensor.type == TfLiteType.uint8) {
        output = outUint8.reshape(shape);
      } else {
        output = outFloat.reshape(shape);
      }

      final inputTensor = interpreter.getInputTensor(0);
      final input = inputBuffer is Uint8List
          ? (inputBuffer as Uint8List).reshape(inputTensor.shape)
          : (inputBuffer as Float32List).reshape(inputTensor.shape);

      interpreter.run(input, output);

      if (outputTensor.type == TfLiteType.uint8) {
        // If a quantized model is used, dequantize with scale/zeroPoint.
        final q = outputTensor.params;
        return outUint8
            .map((v) => (v - q.zeroPoint) * q.scale)
            .toList(growable: false);
      }

      return outFloat.toList(growable: false);
    } catch (e, stack) {
      _consecutiveFailures++;
      LoggerService.error('Interpreter run failed', error: e, stack: stack);

      // Attempt a single reload if interpreter becomes invalid/corrupted.
      if (_consecutiveFailures <= 1) {
        LoggerService.warn('Retrying after interpreter failure (reload)');
        _aslInterpreter?.close();
        _aslInterpreter = null;
        _aslLoadFuture = null;
        _isAslModelLoaded = false;
        unawaited(_ensureAslModelLoaded());
      }

      rethrow;
    }
  }

  /// Post-processes raw scores:
  /// - apply softmax if needed (heuristic)
  /// - extract top-k
  /// - temporal smoothing across last N frames
  /// - confidence filtering
  InferenceResult _postProcessScores(
    List<double> scores, {
    required CnnLatencyMetrics latency,
  }) {
    if (scores.isEmpty) {
      return const InferenceResult(data: null, confidence: 0.0);
    }

    // Heuristic: if scores are not in [0..1] or don't sum to ~1, assume logits.
    final maxScore = scores.reduce(max);
    final minScore = scores.reduce(min);
    final sum = scores.fold<double>(0.0, (a, b) => a + b);

    List<double> probs = scores;
    if (minScore < 0 || maxScore > 1.0 || (sum < 0.8 || sum > 1.2)) {
      probs = _softmax(scores);
    }

    final topK = _topK(probs, k: _cnnConfig.topK);

    if (topK.isEmpty) {
      return const InferenceResult(data: null, confidence: 0.0);
    }

    // Add current top-1 to smoothing buffer.
    _recentTop1.add(topK.first);
    while (_recentTop1.length > _cnnConfig.smoothingWindow) {
      _recentTop1.removeFirst();
    }

    final smoothed = _smoothedTop1();
    if (smoothed == null) {
      return const InferenceResult(data: null, confidence: 0.0);
    }

    if (smoothed.confidence < _cnnConfig.confidenceThreshold) {
      return InferenceResult(data: null, confidence: smoothed.confidence);
    }

    final entry = _dictionary.byIndex(smoothed.index) ?? _dictionary.fuzzyMatch(smoothed.label);

    final word = entry?.word.isNotEmpty == true ? entry!.word : smoothed.label;
    final category = entry?.category ?? (word.length == 1 ? 'letter' : 'word');

    final sign = AslSign(
      id: 'cnn_${smoothed.index}',
      letter: category == 'letter' ? word.toUpperCase() : '',
      word: category == 'letter' ? word.toUpperCase() : word.toLowerCase(),
      description: entry?.description ?? 'Recognized ASL sign',
      confidence: smoothed.confidence,
      synonyms: entry?.synonyms ?? const [],
      category: category,
    );

    final result = AslCnnResult(
      sign: sign,
      topK: topK,
      latency: latency,
      phoneticHint: entry?.phonetic,
    );

    return InferenceResult.success(data: result, confidence: smoothed.confidence);
  }

  CnnPrediction? _smoothedTop1() {
    if (_recentTop1.isEmpty) return null;

    final sums = <int, double>{};
    final counts = <int, int>{};
    final labels = <int, String>{};

    for (final p in _recentTop1) {
      sums[p.index] = (sums[p.index] ?? 0) + p.confidence;
      counts[p.index] = (counts[p.index] ?? 0) + 1;
      labels[p.index] = p.label;
    }

    int? bestIndex;
    double bestAvg = -1;

    sums.forEach((index, sum) {
      final c = counts[index] ?? 0;
      if (c == 0) return;
      final avg = sum / c;
      if (avg > bestAvg) {
        bestAvg = avg;
        bestIndex = index;
      }
    });

    if (bestIndex == null) return null;

    final consistentCount = counts[bestIndex] ?? 0;
    if (consistentCount < _cnnConfig.minConsistentFrames) {
      return null;
    }

    return CnnPrediction(
      index: bestIndex!,
      label: labels[bestIndex] ?? 'class_$bestIndex',
      confidence: bestAvg,
    );
  }

  static List<double> _softmax(List<double> logits) {
    final maxLogit = logits.reduce(max);
    final exps = logits.map((x) => exp(x - maxLogit)).toList(growable: false);
    final sum = exps.fold<double>(0.0, (a, b) => a + b);
    if (sum == 0) return List<double>.filled(logits.length, 0);
    return exps.map((e) => e / sum).toList(growable: false);
  }

  List<CnnPrediction> _topK(List<double> probs, {required int k}) {
    final indexed = List<(int index, double score)>.generate(
      probs.length,
      (i) => (i, probs[i]),
      growable: false,
    );

    indexed.sort((a, b) => b.$2.compareTo(a.$2));

    final out = <CnnPrediction>[];
    final take = min(k, indexed.length);
    for (var i = 0; i < take; i++) {
      final idx = indexed[i].$1;
      final score = indexed[i].$2;
      final entry = _dictionary.byIndex(idx);
      final label = entry?.word.isNotEmpty == true ? entry!.word : entry?.label ?? 'class_$idx';
      out.add(CnnPrediction(index: idx, label: label, confidence: score));
    }

    return out;
  }

  /// Preprocess pipeline (camera -> model input)
  ///
  /// 1) Accept a CameraImage in YUV420 format.
  /// 2) Convert from YUV420 to RGB.
  /// 3) Resize to the model input size (default 224x224).
  /// 4) Normalize:
  ///    - If ImageNet normalization is enabled, apply mean/std:
  ///      mean = [0.485, 0.456, 0.406], std = [0.229, 0.224, 0.225]
  ///    - Otherwise, keep 0..1 floats.
  /// 5) Return a flat tensor buffer in NHWC order.
  ///
  /// Notes on performance:
  /// - This implementation performs resize + YUV->RGB conversion in a single
  ///   loop (sampling the source image directly for each output pixel). This
  ///   avoids allocating a full-sized RGB frame.
  Object _preprocessYuv420ToModelInput(
    CameraImage image, {
    required int inputSize,
    required int rotationDegrees,
    required bool mirror,
    required TfLiteType inputType,
    required bool useImageNetNormalization,
  }) {
    if (image.format.group != ImageFormatGroup.yuv420 || image.planes.length < 3) {
      throw InferenceException(
        'Unsupported camera format: ${image.format.group} / planes=${image.planes.length}',
      );
    }

    final srcW = image.width;
    final srcH = image.height;

    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final yBytes = yPlane.bytes;
    final uBytes = uPlane.bytes;
    final vBytes = vPlane.bytes;

    final yRowStride = yPlane.bytesPerRow;
    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 1;

    // If the model is quantized (uint8 input), we feed raw 0..255 bytes.
    // For float models, we feed normalized Float32 in NHWC.
    final totalValues = inputSize * inputSize * 3;

    final mean = useImageNetNormalization
        ? const [0.485, 0.456, 0.406]
        : const [0.0, 0.0, 0.0];
    final std = useImageNetNormalization
        ? const [0.229, 0.224, 0.225]
        : const [1.0, 1.0, 1.0];

    final isQuantized = inputType == TfLiteType.uint8;

    if (isQuantized) {
      final out = Uint8List(totalValues);

      var i = 0;
      for (var y = 0; y < inputSize; y++) {
        for (var x = 0; x < inputSize; x++) {
          final (sx, sy) = _mapOutputToSource(
            x: x,
            y: y,
            outW: inputSize,
            outH: inputSize,
            srcW: srcW,
            srcH: srcH,
            rotationDegrees: rotationDegrees,
            mirror: mirror,
          );

          final yp = yRowStride * sy + sx;
          final uvIndex = uvRowStride * (sy >> 1) + (sx >> 1) * uvPixelStride;

          final yValue = yBytes[yp];
          final uValue = uBytes[uvIndex];
          final vValue = vBytes[uvIndex];

          final (r, g, b) = _yuvToRgb(yValue, uValue, vValue);

          out[i++] = r;
          out[i++] = g;
          out[i++] = b;
        }
      }

      return out;
    }

    final out = Float32List(totalValues);

    var i = 0;
    for (var y = 0; y < inputSize; y++) {
      for (var x = 0; x < inputSize; x++) {
        final (sx, sy) = _mapOutputToSource(
          x: x,
          y: y,
          outW: inputSize,
          outH: inputSize,
          srcW: srcW,
          srcH: srcH,
          rotationDegrees: rotationDegrees,
          mirror: mirror,
        );

        final yp = yRowStride * sy + sx;
        final uvIndex = uvRowStride * (sy >> 1) + (sx >> 1) * uvPixelStride;

        final yValue = yBytes[yp];
        final uValue = uBytes[uvIndex];
        final vValue = vBytes[uvIndex];

        final (r8, g8, b8) = _yuvToRgb(yValue, uValue, vValue);

        final r = r8 / 255.0;
        final g = g8 / 255.0;
        final b = b8 / 255.0;

        out[i++] = (r - mean[0]) / std[0];
        out[i++] = (g - mean[1]) / std[1];
        out[i++] = (b - mean[2]) / std[2];
      }
    }

    return out;
  }

  static (int sx, int sy) _mapOutputToSource({
    required int x,
    required int y,
    required int outW,
    required int outH,
    required int srcW,
    required int srcH,
    required int rotationDegrees,
    required bool mirror,
  }) {
    // Nearest-neighbor sampling.
    var sx = (x * srcW / outW).floor().clamp(0, srcW - 1);
    var sy = (y * srcH / outH).floor().clamp(0, srcH - 1);

    // Apply mirroring (useful for front camera).
    if (mirror) {
      sx = (srcW - 1 - sx).clamp(0, srcW - 1);
    }

    // Apply rotation (sensor orientation / UI orientation).
    switch ((rotationDegrees % 360 + 360) % 360) {
      case 90:
        return (sx: sy, sy: (srcW - 1 - sx).clamp(0, srcH - 1));
      case 180:
        return (
          sx: (srcW - 1 - sx).clamp(0, srcW - 1),
          sy: (srcH - 1 - sy).clamp(0, srcH - 1),
        );
      case 270:
        return (sx: (srcH - 1 - sy).clamp(0, srcW - 1), sy: sx);
      default:
        return (sx: sx, sy: sy);
    }
  }

  static (int r, int g, int b) _yuvToRgb(int y, int u, int v) {
    // Conversion based on standard YUV420 to RGB formula.
    final yf = y.toDouble();
    final uf = (u - 128).toDouble();
    final vf = (v - 128).toDouble();

    int r = (yf + 1.402 * vf).round();
    int g = (yf - 0.344136 * uf - 0.714136 * vf).round();
    int b = (yf + 1.772 * uf).round();

    r = r.clamp(0, 255);
    g = g.clamp(0, 255);
    b = b.clamp(0, 255);

    return (r: r, g: g, b: b);
  }
}
