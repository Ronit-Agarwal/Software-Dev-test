import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:signsync/core/logging/logger_service.dart';
import 'package:signsync/models/camera_state.dart';

/// Service for extracting and processing frames from the camera stream.
///
/// This service handles:
/// - Frame extraction at configurable FPS (30fps target)
/// - Circular buffer for temporal analysis
/// - Frame timestamp tracking for latency measurement
/// - Frame size standardization (640x480)
/// - Frame skipping for performance on low-end devices
/// - Performance monitoring (FPS, memory usage)
///
/// The frame format specifications:
/// - Input: CameraImage (YUV420 format from camera plugin)
/// - Output: Standardized CameraFrame with RGB conversion
/// - Target resolution: 640x480 pixels
/// - Target FPS: 30 frames per second
class FrameExtractor with ChangeNotifier {
  // Configuration
  FrameExtractorConfig _config;
  final void Function(CameraFrame frame) _onFrame;
  final void Function(FramePerformanceMetrics metrics)? _onPerformanceUpdate;

  // State
  bool _isRunning = false;
  bool _isPaused = false;
  CameraProcessingMode _processingMode = CameraProcessingMode.aslTranslation;

  // Frame handling
  CameraImage? _latestFrame;
  final Object _frameLock = Object();

  // Performance monitoring
  final Stopwatch _fpsStopwatch = Stopwatch();
  int _frameCount = 0;
  int _skippedFrameCount = 0;
  int _totalFramesProcessed = 0;
  int _totalFramesSkipped = 0;
  final List<double> _fpsHistory = [];
  final List<double> _latencyHistory = [];
  int _processingStartTime = 0;

  // Circular buffer for temporal analysis
  final FrameBuffer _frameBuffer;

  // Isolate for heavy processing
  Isolate? _processingIsolate;
  ReceivePort? _receivePort;
  SendPort? _isolateSendPort;

  // Adaptive frame skipping
  int _consecutiveLowFpsFrames = 0;
  bool _isLowPerformanceMode = false;

  // Timer for periodic tasks
  Timer? _performanceTimer;

  // Getters
  bool get isRunning => _isRunning;
  bool get isPaused => _isPaused;
  CameraProcessingMode get processingMode => _processingMode;
  FrameBuffer get frameBuffer => _frameBuffer;
  FramePerformanceMetrics get performanceMetrics => _calculateMetrics();
  int get bufferedFrames => _frameBuffer.length;

  /// Creates a new FrameExtractor instance.
  ///
  /// [config] - Configuration for frame extraction parameters.
  /// [onFrame] - Callback invoked for each extracted frame.
  /// [onPerformanceUpdate] - Optional callback for performance updates.
  FrameExtractor({
    FrameExtractorConfig config = const FrameExtractorConfig(),
    required void Function(CameraFrame frame) onFrame,
    void Function(FramePerformanceMetrics metrics)? onPerformanceUpdate,
  })  : _config = config,
        _onFrame = onFrame,
        _onPerformanceUpdate = onPerformanceUpdate,
        _frameBuffer = FrameBuffer(capacity: config.maxBufferSize);

  /// Updates the frame extractor configuration.
  void updateConfig(FrameExtractorConfig newConfig) {
    if (_isRunning) {
      LoggerService.warn('Cannot update config while frame extractor is running');
      return;
    }
    _config = newConfig;
    _frameBuffer.clear();
    _frameBuffer._capacity = newConfig.maxBufferSize;
    notifyListeners();
  }

  /// Sets the processing mode for camera frames.
  void setProcessingMode(CameraProcessingMode mode) {
    _processingMode = mode;
    LoggerService.info('Processing mode set to: $mode');
    notifyListeners();

    // Adjust configuration based on mode
    switch (mode) {
      case CameraProcessingMode.aslTranslation:
        _config = _config.copyWith(
          targetFps: 30,
          targetWidth: 640,
          targetHeight: 480,
        );
        break;
      case CameraProcessingMode.objectDetection:
        _config = _config.copyWith(
          targetFps: 24,
          targetWidth: 640,
          targetHeight: 480,
        );
        break;
      case CameraProcessingMode.soundDetection:
        // No frame processing needed in sound detection mode
        _config = _config.copyWith(targetFps: 0);
        break;
    }
  }

  /// Starts the frame extractor.
  Future<void> start() async {
    if (_isRunning) {
      LoggerService.warn('Frame extractor already running');
      return;
    }

    LoggerService.info('Starting frame extractor with config: $_config');
    _isRunning = true;
    _isPaused = false;

    // Reset performance counters
    _frameCount = 0;
    _skippedFrameCount = 0;
    _totalFramesProcessed = 0;
    _totalFramesSkipped = 0;
    _fpsHistory.clear();
    _latencyHistory.clear();
    _consecutiveLowFpsFrames = 0;
    _isLowPerformanceMode = false;

    // Start performance monitoring timer
    _performanceTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _reportPerformance(),
    );

    _fpsStopwatch.start();
    notifyListeners();
    LoggerService.info('Frame extractor started');
  }

  /// Stops the frame extractor.
  Future<void> stop() async {
    if (!_isRunning) {
      LoggerService.warn('Frame extractor not running');
      return;
    }

    LoggerService.info('Stopping frame extractor');
    _isRunning = false;
    _isPaused = false;

    _fpsStopwatch.stop();
    _performanceTimer?.cancel();
    _performanceTimer = null;

    // Clear buffer
    _frameBuffer.clear();

    // Stop isolate if running
    await _stopIsolate();

    notifyListeners();
    LoggerService.info('Frame extractor stopped');
  }

  /// Pauses frame extraction.
  void pause() {
    if (!_isRunning || _isPaused) return;

    LoggerService.info('Pausing frame extraction');
    _isPaused = true;
    notifyListeners();
  }

  /// Resumes frame extraction.
  void resume() {
    if (!_isRunning || !_isPaused) return;

    LoggerService.info('Resuming frame extraction');
    _isPaused = false;
    notifyListeners();
  }

  /// Processes a camera frame.
  ///
  /// This method is called by the camera service when a new frame is available.
  void processFrame(CameraImage image, {int sequenceNumber = 0}) {
    if (!_isRunning || _isPaused) return;

    if (_processingMode == CameraProcessingMode.soundDetection) {
      return; // Skip frame processing in sound detection mode
    }

    // Store the latest frame (Dart is single-threaded, so no locks needed)
    _latestFrame = image;

    if (_latestFrame == null) return;

    // Check if we should skip this frame for performance
    if (_shouldSkipFrame()) {
      _skippedFrameCount++;
      _totalFramesSkipped++;
      return;
    }

    // Calculate processing latency
    final processingLatency = _processingStartTime > 0
        ? DateTime.now().millisecondsSinceEpoch - _processingStartTime
        : 0;

    // Create CameraFrame
    final cameraFrame = CameraFrame.fromCameraImage(
      _latestFrame!,
      sequenceNumber: sequenceNumber,
      processingLatencyMs: processingLatency,
    );

    // Add to buffer
    _frameBuffer.add(cameraFrame);

    // Call the frame callback
    try {
      _onFrame(cameraFrame);
      _totalFramesProcessed++;
      _frameCount++;
    } catch (e, stack) {
      LoggerService.error('Error in frame callback', error: e, stack: stack);
    }

    // Update performance tracking
    _updatePerformanceTracking();
  }

  /// Gets the latest frame for processing.
  CameraImage? getLatestFrame() {
    return _latestFrame;
  }

  /// Returns the standardized frame size.
  (int width, int height) get standardizedSize {
    return (_config.targetWidth, _config.targetHeight);
  }

  /// Starts the processing isolate for heavy frame operations.
  Future<void> _startIsolate() async {
    if (!_config.useIsolate) return;

    try {
      _receivePort = ReceivePort();
      _processingIsolate = await Isolate.spawn(
        _frameProcessingIsolate,
        _IsolateConfig(
          sendPort: _receivePort!.sendPort,
          targetWidth: _config.targetWidth,
          targetHeight: _config.targetHeight,
        ),
      );

      _receivePort!.listen((message) {
        if (message is SendPort) {
          _isolateSendPort = message;
        }
      });

      LoggerService.info('Frame processing isolate started');
    } catch (e, stack) {
      LoggerService.error('Failed to start isolate', error: e, stack: stack);
    }
  }

  /// Stops the processing isolate.
  Future<void> _stopIsolate() async {
    _processingIsolate?.kill();
    _processingIsolate = null;
    _receivePort?.close();
    _receivePort = null;
    _isolateSendPort = null;
  }

  /// Determines if a frame should be skipped for performance.
  bool _shouldSkipFrame() {
    if (!_config.adaptiveFrameSkip) return false;

    // Check if we're in low performance mode
    if (_isLowPerformanceMode) {
      // Skip every other frame in low performance mode
      return _frameCount % 2 == 0;
    }

    // Check if FPS is below threshold
    if (_fpsHistory.isNotEmpty) {
      final avgFps = _fpsHistory.reduce((a, b) => a + b) / _fpsHistory.length;
      if (avgFps < 20) {
        _consecutiveLowFpsFrames++;
        if (_consecutiveLowFpsFrames >= 3) {
          _isLowPerformanceMode = true;
          LoggerService.warn('Entering low performance mode');
        }
        return true;
      }
    }

    _consecutiveLowFpsFrames = 0;
    return false;
  }

  /// Updates performance tracking.
  void _updatePerformanceTracking() {
    final elapsed = _fpsStopwatch.elapsedMilliseconds;
    if (elapsed >= 1000) {
      final fps = _frameCount * 1000.0 / elapsed;
      _fpsHistory.add(fps);

      // Keep last 30 FPS readings for averaging
      if (_fpsHistory.length > 30) {
        _fpsHistory.removeAt(0);
      }

      _frameCount = 0;
      _fpsStopwatch.reset();
    }
  }

  /// Calculates current performance metrics.
  FramePerformanceMetrics _calculateMetrics() {
    final avgFps = _fpsHistory.isNotEmpty
        ? _fpsHistory.reduce((a, b) => a + b) / _fpsHistory.length
        : 0.0;

    final minFps = _fpsHistory.isNotEmpty ? _fpsHistory.reduce((a, b) => a < b ? a : b) : 0.0;
    final maxFps = _fpsHistory.isNotEmpty ? _fpsHistory.reduce((a, b) => a > b ? a : b) : 0.0;

    final avgLatency = _latencyHistory.isNotEmpty
        ? _latencyHistory.reduce((a, b) => a + b) / _latencyHistory.length
        : 0.0;

    // Check if performance is degraded
    final isDegraded = avgFps < 20 || avgLatency > 100;

    return FramePerformanceMetrics(
      currentFps: avgFps,
      averageFps: avgFps,
      minFps: minFps,
      maxFps: maxFps,
      totalFramesProcessed: _totalFramesProcessed,
      totalFramesSkipped: _totalFramesSkipped,
      currentMemoryBytes: _frameBuffer.length * _estimateFrameMemory(),
      peakMemoryBytes: _totalFramesProcessed * _estimateFrameMemory(),
      averageLatencyMs: avgLatency,
      isDegraded: isDegraded,
    );
  }

  /// Estimates memory usage per frame in bytes.
  int _estimateFrameMemory() {
    // Estimate based on target resolution and format
    final pixels = _config.targetWidth * _config.targetHeight;
    // RGB format: 3 bytes per pixel + overhead
    return pixels * 4 + 1024;
  }

  /// Reports performance metrics to the callback.
  void _reportPerformance() {
    if (!_isRunning) return;

    final metrics = _calculateMetrics();
    _onPerformanceUpdate?.call(metrics);

    // Log warning if performance is degraded
    if (metrics.isDegraded) {
      LoggerService.warn('Performance degraded: ${metrics.summary}');
    }

    // Auto-recover from low performance mode if FPS improves
    if (_isLowPerformanceMode && metrics.currentFps >= 25) {
      _isLowPerformanceMode = false;
      _consecutiveLowFpsFrames = 0;
      LoggerService.info('Recovered from low performance mode');
    }
  }

  /// Clears the frame buffer.
  void clearBuffer() {
    _frameBuffer.clear();
    LoggerService.info('Frame buffer cleared');
    notifyListeners();
  }

  /// Gets recent frames for analysis.
  List<CameraFrame> getRecentFrames([int count = 5]) {
    return _frameBuffer.getRecentFrames(count);
  }

  /// Gets frames within a time window.
  List<CameraFrame> getFramesWithin(Duration duration) {
    return _frameBuffer.getFramesWithin(duration);
  }
}

/// Configuration passed to the isolate.
class _IsolateConfig {
  final SendPort sendPort;
  final int targetWidth;
  final int targetHeight;

  _IsolateConfig({
    required this.sendPort,
    required this.targetWidth,
    required this.targetHeight,
  });
}

/// Isolate entry point for frame processing.
void _frameProcessingIsolate(_IsolateConfig config) {
  final receivePort = ReceivePort();

  receivePort.listen((message) async {
    if (message is _ProcessFrameMessage) {
      try {
        // Process frame in isolate
        final processedData = await _processFrameInIsolate(
          message.imageData,
          config.targetWidth,
          config.targetHeight,
        );

        // Send result back
        config.sendPort.send(_IsolateResult(
          sequenceNumber: message.sequenceNumber,
          processedData: processedData,
        ));
      } catch (e) {
        config.sendPort.send(_IsolateError(
          sequenceNumber: message.sequenceNumber,
          error: e.toString(),
        ));
      }
    }
  });

  // Send the receive port send port back to main isolate
  config.sendPort.send(receivePort.sendPort);
}

/// Message sent to isolate for processing.
class _ProcessFrameMessage {
  final Uint8List imageData;
  final int sequenceNumber;

  _ProcessFrameMessage({
    required this.imageData,
    required this.sequenceNumber,
  });
}

/// Result from isolate processing.
class _IsolateResult {
  final int sequenceNumber;
  final Uint8List processedData;

  _IsolateResult({
    required this.sequenceNumber,
    required this.processedData,
  });
}

/// Error from isolate processing.
class _IsolateError {
  final int sequenceNumber;
  final String error;

  _IsolateError({
    required this.sequenceNumber,
    required this.error,
  });
}

/// Processes frame data in isolate.
Future<Uint8List> _processFrameInIsolate(
  Uint8List data,
  int targetWidth,
  int targetHeight,
) async {
  // Simulate processing (actual implementation would resize, normalize, etc.)
  await Future.delayed(const Duration(milliseconds: 1));
  return data;
}
