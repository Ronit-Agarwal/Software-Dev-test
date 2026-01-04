import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// Represents the current state of the camera.
///
/// This enum is used to track the camera's lifecycle and provide
/// appropriate UI feedback for each state.
enum CameraState {
  /// Initial state before any initialization
  initializing,

  /// Camera is being started
  starting,

  /// Camera is ready but not streaming
  ready,

  /// Camera stream is being prepared
  preparingStream,

  /// Camera is actively streaming frames
  streaming,

  /// Camera initialization is being retried
  retrying,

  /// Camera permission was denied
  permissionDenied,

  /// No cameras are available on the device
  noCamerasAvailable,

  /// Camera was disabled by the user
  disabled,

  /// An error occurred
  error,

  /// Camera has been disposed
  disposed,
}

/// Configuration for frame extraction from camera stream.
class FrameExtractorConfig with EquatableMixin {
  /// Target frames per second (default: 30)
  final int targetFps;

  /// Target frame width for ML processing (default: 640)
  final int targetWidth;

  /// Target frame height for ML processing (default: 480)
  final int targetHeight;

  /// Maximum frames to keep in circular buffer (default: 30)
  final int maxBufferSize;

  /// Whether to enable adaptive frame skipping (default: true)
  final bool adaptiveFrameSkip;

  /// Whether to run frame processing in isolate (default: true)
  final bool useIsolate;

  const FrameExtractorConfig({
    this.targetFps = 30,
    this.targetWidth = 640,
    this.targetHeight = 480,
    this.maxBufferSize = 30,
    this.adaptiveFrameSkip = true,
    this.useIsolate = true,
  });

  FrameExtractorConfig copyWith({
    int? targetFps,
    int? targetWidth,
    int? targetHeight,
    int? maxBufferSize,
    bool? adaptiveFrameSkip,
    bool? useIsolate,
  }) {
    return FrameExtractorConfig(
      targetFps: targetFps ?? this.targetFps,
      targetWidth: targetWidth ?? this.targetWidth,
      targetHeight: targetHeight ?? this.targetHeight,
      maxBufferSize: maxBufferSize ?? this.maxBufferSize,
      adaptiveFrameSkip: adaptiveFrameSkip ?? this.adaptiveFrameSkip,
      useIsolate: useIsolate ?? this.useIsolate,
    );
  }

  @override
  List<Object?> get props => [
        targetFps,
        targetWidth,
        targetHeight,
        maxBufferSize,
        adaptiveFrameSkip,
        useIsolate,
      ];
}

/// Represents a captured camera frame with metadata.
///
/// This class wraps the camera image with additional information
/// needed for ML inference and temporal analysis.
class CameraFrame with EquatableMixin {
  /// The camera image data
  final Uint8List? imageData;

  /// Frame width in pixels
  final int width;

  /// Frame height in pixels
  final int height;

  /// Timestamp when the frame was captured
  final DateTime timestamp;

  /// Format of the image (e.g., YUV420)
  final int format;

  /// Plane data for YUV images
  final List<Plane> planes;

  /// Processing latency in milliseconds
  final int processingLatencyMs;

  /// Sequence number for frame ordering
  final int sequenceNumber;

  const CameraFrame({
    this.imageData,
    required this.width,
    required this.height,
    DateTime? timestamp,
    this.format = 0,
    this.planes = const [],
    this.processingLatencyMs = 0,
    this.sequenceNumber = 0,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Creates a CameraFrame from a CameraImage.
  factory CameraFrame.fromCameraImage(
    CameraImage image, {
    int sequenceNumber = 0,
    int processingLatencyMs = 0,
  }) {
    return CameraFrame(
      width: image.width,
      height: image.height,
      timestamp: DateTime.now(),
      format: image.format.raw,
      planes: image.planes,
      processingLatencyMs: processingLatencyMs,
      sequenceNumber: sequenceNumber,
    );
  }

  /// Returns the aspect ratio of the frame.
  double get aspectRatio => width / height;

  /// Returns true if this is a YUV image.
  bool get isYuv => format == 35 || format == 842094169;

  /// Converts YUV420 to RGB (simplified).
  Uint8List? toRgb() {
    if (imageData == null) return null;
    return imageData;
  }

  @override
  List<Object?> get props => [
        imageData,
        width,
        height,
        timestamp,
        format,
        planes,
        processingLatencyMs,
        sequenceNumber,
      ];
}

/// Performance metrics for frame processing.
class FramePerformanceMetrics with EquatableMixin {
  /// Current FPS
  final double currentFps;

  /// Average FPS over the session
  final double averageFps;

  /// Minimum FPS observed
  final double minFps;

  /// Maximum FPS observed
  final double maxFps;

  /// Total frames processed
  final int totalFramesProcessed;

  /// Total frames skipped
  final int totalFramesSkipped;

  /// Current memory usage in bytes
  final int currentMemoryBytes;

  /// Peak memory usage in bytes
  final int peakMemoryBytes;

  /// Processing latency in milliseconds
  final double averageLatencyMs;

  /// Whether performance is degraded
  final bool isDegraded;

  const FramePerformanceMetrics({
    this.currentFps = 0.0,
    this.averageFps = 0.0,
    this.minFps = double.infinity,
    this.maxFps = 0.0,
    this.totalFramesProcessed = 0,
    this.totalFramesSkipped = 0,
    this.currentMemoryBytes = 0,
    this.peakMemoryBytes = 0,
    this.averageLatencyMs = 0.0,
    this.isDegraded = false,
  });

  FramePerformanceMetrics copyWith({
    double? currentFps,
    double? averageFps,
    double? minFps,
    double? maxFps,
    int? totalFramesProcessed,
    int? totalFramesSkipped,
    int? currentMemoryBytes,
    int? peakMemoryBytes,
    double? averageLatencyMs,
    bool? isDegraded,
  }) {
    return FramePerformanceMetrics(
      currentFps: currentFps ?? this.currentFps,
      averageFps: averageFps ?? this.averageFps,
      minFps: minFps ?? this.minFps,
      maxFps: maxFps ?? this.maxFps,
      totalFramesProcessed: totalFramesProcessed ?? this.totalFramesProcessed,
      totalFramesSkipped: totalFramesSkipped ?? this.totalFramesSkipped,
      currentMemoryBytes: currentMemoryBytes ?? this.currentMemoryBytes,
      peakMemoryBytes: peakMemoryBytes ?? this.peakMemoryBytes,
      averageLatencyMs: averageLatencyMs ?? this.averageLatencyMs,
      isDegraded: isDegraded ?? this.isDegraded,
    );
  }

  /// Updates metrics with a new FPS value.
  FramePerformanceMetrics withFps(double fps) {
    return copyWith(
      currentFps: fps,
      minFps: min(fps, minFps),
      maxFps: max(fps, maxFps),
    );
  }

  /// Returns a human-readable summary.
  String get summary {
    return 'FPS: ${currentFps.toStringAsFixed(1)} (avg: ${averageFps.toStringAsFixed(1)}, '
        'min: ${minFps.toStringAsFixed(1)}, max: ${maxFps.toStringAsFixed(1)}) | '
        'Frames: $totalFramesProcessed processed, $totalFramesSkipped skipped | '
        'Memory: ${(currentMemoryBytes / 1024 / 1024).toStringAsFixed(2)}MB peak: ${(peakMemoryBytes / 1024 / 1024).toStringAsFixed(2)}MB | '
        'Latency: ${averageLatencyMs.toStringAsFixed(1)}ms';
  }

  @override
  List<Object?> get props => [
        currentFps,
        averageFps,
        minFps,
        maxFps,
        totalFramesProcessed,
        totalFramesSkipped,
        currentMemoryBytes,
        peakMemoryBytes,
        averageLatencyMs,
        isDegraded,
      ];
}

/// Mode-specific camera processing configuration.
enum CameraProcessingMode {
  /// Full-frame processing for ASL translation (hands/upper body focus)
  aslTranslation,

  /// Full-frame processing for object detection
  objectDetection,

  /// No video processing needed (audio-only mode)
  soundDetection,
}

/// Circular buffer for temporal frame analysis.
class FrameBuffer with ChangeNotifier {
  int _capacity;
  final List<CameraFrame> _frames = [];
  int _maxLatencyMs = 0;

  FrameBuffer({int capacity = 30}) : _capacity = capacity;

  /// Maximum number of frames the buffer can hold.
  int get capacity => _capacity;

  /// Updates the buffer capacity.
  ///
  /// If the new capacity is smaller than the current length, oldest frames are
  /// dropped to fit.
  void setCapacity(int capacity) {
    _capacity = max(1, capacity);
    if (_frames.length > _capacity) {
      _frames.removeRange(0, _frames.length - _capacity);
    }
    notifyListeners();
  }

  /// Current number of frames in the buffer.
  int get length => _frames.length;

  /// Whether the buffer is empty.
  bool get isEmpty => _frames.isEmpty;

  /// Whether the buffer is full.
  bool get isFull => _frames.length >= _capacity;

  /// Maximum latency observed in the buffer.
  int get maxLatencyMs => _maxLatencyMs;

  /// Gets all frames in the buffer (oldest to newest).
  List<CameraFrame> get frames => List.unmodifiable(_frames);

  /// Gets the newest frame (most recent).
  CameraFrame? get newest => _frames.isNotEmpty ? _frames.last : null;

  /// Gets the oldest frame.
  CameraFrame? get oldest => _frames.isNotEmpty ? _frames.first : null;

  /// Adds a new frame to the buffer.
  ///
  /// If the buffer is full, the oldest frame is removed.
  void add(CameraFrame frame) {
    if (_frames.length >= _capacity) {
      _frames.removeAt(0);
    }
    _frames.add(frame);

    if (frame.processingLatencyMs > _maxLatencyMs) {
      _maxLatencyMs = frame.processingLatencyMs;
    }

    notifyListeners();
  }

  /// Clears all frames from the buffer.
  void clear() {
    _frames.clear();
    _maxLatencyMs = 0;
    notifyListeners();
  }

  /// Gets frames within a time window.
  List<CameraFrame> getFramesWithin(Duration duration) {
    final cutoff = DateTime.now().subtract(duration);
    return _frames.where((frame) => frame.timestamp.isAfter(cutoff)).toList();
  }

  /// Gets the most recent N frames.
  List<CameraFrame> getRecentFrames(int count) {
    final startIndex = max(0, _frames.length - count);
    return _frames.sublist(startIndex);
  }
}
