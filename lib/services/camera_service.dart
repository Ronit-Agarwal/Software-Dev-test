import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:signsync/core/error/exceptions.dart';
import 'package:signsync/core/logging/logger_service.dart';
import 'package:signsync/models/detected_object.dart';

/// Service for managing camera functionality.
///
/// This service handles camera initialization, stream management,
/// and provides access to camera controllers for ML inference.
class CameraService with ChangeNotifier {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  CameraDescription? _selectedCamera;
  bool _isInitialized = false;
  bool _isStreaming = false;
  String? _error;

  // Getters
  CameraController? get controller => _controller;
  CameraDescription? get selectedCamera => _selectedCamera;
  bool get isInitialized => _isInitialized;
  bool get isStreaming => _isStreaming;
  String? get error => _error;
  List<CameraDescription> get availableCameras => _cameras;

  /// Initializes the camera service.
  ///
  /// This method must be called before any other camera operations.
  Future<void> initialize() async {
    if (_isInitialized) {
      LoggerService.warn('Camera service already initialized');
      return;
    }

    try {
      LoggerService.info('Initializing camera service');
      _error = null;

      // Get available cameras
      _cameras = await availableCameras();
      LoggerService.debug('Found ${_cameras.length} cameras');

      if (_cameras.isEmpty) {
        throw const CameraException(
          'no_cameras',
          'No cameras available on this device',
        );
      }

      // Select the back camera by default
      _selectedCamera = _cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );
      LoggerService.info('Selected camera: ${_selectedCamera?.name}');

      _isInitialized = true;
      notifyListeners();
      LoggerService.info('Camera service initialized successfully');
    } catch (e, stack) {
      _error = e.toString();
      LoggerService.error('Failed to initialize camera service', error: e, stack: stack);
      rethrow;
    }
  }

  /// Starts the camera with the specified resolution.
  ///
  /// [resolution] - The desired image resolution.
  /// [enableAudio] - Whether to enable audio streaming.
  Future<void> startCamera({
    ResolutionPreset resolution = ResolutionPreset.medium,
    bool enableAudio = false,
  }) async {
    if (!_isInitialized) {
      throw const CameraException(
        'not_initialized',
        'Camera service must be initialized before starting the camera',
      );
    }

    if (_controller != null) {
      LoggerService.warn('Camera already started, disposing existing controller');
      await _disposeController();
    }

    try {
      LoggerService.info('Starting camera with resolution: $resolution');
      _error = null;

      _controller = CameraController(
        _selectedCamera!,
        resolution,
        enableAudio: enableAudio,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _controller!.initialize();
      notifyListeners();
      LoggerService.info('Camera started successfully');
    } catch (e, stack) {
      _error = e.toString();
      LoggerService.error('Failed to start camera', error: e, stack: stack);
      await _disposeController();
      rethrow;
    }
  }

  /// Starts streaming camera frames for ML inference.
  ///
  /// [onFrame] - Callback for each frame.
  /// [resolution] - The resolution for inference frames.
  Future<void> startStreaming({
    required void Function(CameraImage image) onFrame,
    ResolutionPreset resolution = ResolutionPreset.low,
  }) async {
    if (_controller == null || !_controller!.value.isInitialized) {
      throw const CameraException(
        'not_ready',
        'Camera is not ready for streaming',
      );
    }

    try {
      LoggerService.info('Starting camera streaming');
      _isStreaming = true;

      await _controller!.startImageStream(onFrame);
      notifyListeners();
      LoggerService.info('Camera streaming started');
    } catch (e, stack) {
      _error = e.toString();
      LoggerService.error('Failed to start camera streaming', error: e, stack: stack);
      _isStreaming = false;
      rethrow;
    }
  }

  /// Stops streaming camera frames.
  Future<void> stopStreaming() async {
    if (!_isStreaming) {
      LoggerService.warn('Camera is not streaming');
      return;
    }

    try {
      LoggerService.info('Stopping camera streaming');
      await _controller?.stopImageStream();
      _isStreaming = false;
      notifyListeners();
      LoggerService.info('Camera streaming stopped');
    } catch (e, stack) {
      LoggerService.error('Failed to stop camera streaming', error: e, stack: stack);
      _isStreaming = false;
      rethrow;
    }
  }

  /// Switches to the next available camera.
  Future<void> switchCamera() async {
    if (_cameras.length <= 1) {
      LoggerService.warn('Only one camera available, cannot switch');
      return;
    }

    final currentIndex = _cameras.indexOf(_selectedCamera!);
    final nextIndex = (currentIndex + 1) % _cameras.length;
    _selectedCamera = _cameras[nextIndex];
    LoggerService.info('Switched to camera: ${_selectedCamera?.name}');

    // Restart camera with new description
    if (_controller != null && _controller!.value.isInitialized) {
      final wasStreaming = _isStreaming;
      await stopStreaming();
      await startCamera();
      notifyListeners();
      LoggerService.info('Camera restarted after switch');
    }
  }

  /// Captures a single image.
  ///
  /// Returns the path to the saved image.
  Future<String> captureImage() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      throw const CameraException(
        'not_ready',
        'Camera is not ready for image capture',
      );
    }

    try {
      LoggerService.info('Capturing image');
      final XFile imageFile = await _controller!.takePicture();
      LoggerService.info('Image captured: ${imageFile.path}');
      return imageFile.path;
    } catch (e, stack) {
      LoggerService.error('Failed to capture image', error: e, stack: stack);
      throw CameraException('capture_failed', 'Failed to capture image: $e');
    }
  }

  /// Gets the current camera rotation in degrees.
  int get rotationDegrees {
    if (_controller == null) return 0;
    return _controller!.value.sensorOrientation;
  }

  /// Gets the image format group.
  ImageFormatGroup get imageFormatGroup {
    if (_controller == null) return ImageFormatGroup.yuv420;
    return _controller!.value.imageFormatGroup;
  }

  /// Sets the zoom level.
  Future<void> setZoomLevel(double zoom) async {
    if (_controller == null || !_controller!.value.isInitialized) {
      throw const CameraException(
        'not_ready',
        'Camera is not ready',
      );
    }

    final minZoom = _controller!.value.getMinZoomLevel();
    final maxZoom = _controller!.value.getMaxZoomLevel();
    final clampedZoom = zoom.clamp(minZoom, maxZoom);

    try {
      await _controller!.setZoomLevel(clampedZoom);
      LoggerService.debug('Zoom set to: $clampedZoom');
    } catch (e, stack) {
      LoggerService.error('Failed to set zoom level', error: e, stack: stack);
      rethrow;
    }
  }

  /// Sets the exposure mode.
  Future<void> setExposureMode(ExposureMode mode) async {
    if (_controller == null) return;
    await _controller!.setExposureMode(mode);
  }

  /// Sets the focus point.
  Future<void> setFocusPoint(Offset point) async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    await _controller!.setFocusPoint(point);
  }

  /// Gets the exposure offset range.
  (double min, double max) get exposureOffsetRange {
    if (_controller == null) return (0.0, 0.0);
    return (
      _controller!.value.getMinExposureOffset(),
      _controller!.value.getMaxExposureOffset(),
    );
  }

  /// Cleans up the camera resources.
  Future<void> dispose() async {
    LoggerService.info('Disposing camera service');
    await _disposeController();
    _isInitialized = false;
    _isStreaming = false;
    notifyListeners();
  }

  Future<void> _disposeController() async {
    if (_controller != null) {
      if (_isStreaming) {
        try {
          await _controller!.stopImageStream();
        } catch (_) {}
      }
      await _controller!.dispose();
      _controller = null;
    }
  }

  /// Checks if flash is available.
  bool get hasFlash => _controller?.value.flashMode != null;

  /// Toggles the flash.
  Future<void> toggleFlash() async {
    if (_controller == null) return;

    final currentMode = _controller!.value.flashMode;
    FlashMode nextMode;

    switch (currentMode) {
      case FlashMode.off:
        nextMode = FlashMode.always;
        break;
      case FlashMode.always:
        nextMode = FlashMode.auto;
        break;
      case FlashMode.auto:
        nextMode = FlashMode.off;
        break;
      case FlashMode.torch:
        nextMode = FlashMode.off;
        break;
    }

    await _controller!.setFlashMode(nextMode);
    LoggerService.debug('Flash set to: $nextMode');
  }
}
