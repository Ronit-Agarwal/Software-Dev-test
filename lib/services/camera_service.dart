import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:signsync/core/error/exceptions.dart';
import 'package:signsync/core/logging/logger_service.dart';
import 'package:signsync/models/camera_state.dart';
import 'package:signsync/services/permissions_service.dart';
import 'package:signsync/utils/memory_monitor.dart';
import 'package:signsync/utils/retry_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing camera functionality with comprehensive lifecycle management.
///
/// This service handles camera initialization, stream management,
/// frame extraction, and provides access to camera controllers for ML inference.
class CameraService with ChangeNotifier {
  // Controllers and state
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  CameraDescription? _selectedCamera;
  CameraState _state = CameraState.initializing;
  String? _error;

  // Permission and preferences
  final PermissionsService _permissionsService;
  bool _cameraEnabled = true;
  CameraLensDirection _preferredCameraDirection = CameraLensDirection.back;

  // Performance monitoring
  int _frameCount = 0;
  DateTime _lastFpsUpdate = DateTime.now();
  double _currentFps = 0.0;

  // Retry logic
  int _retryCount = 0;
  static const int _maxRetries = 3;
  Timer? _retryTimer;

  // Initialization timeout
  Timer? _initTimeout;
  static const Duration _initTimeoutDuration = Duration(seconds: 10);

  // Flash control
  bool _isFlashOn = false;

  // Lifecycle handling
  bool _isAppInBackground = false;

  // Low-light handling
  bool _lowLightDetected = false;
  double _currentExposure = 0.0;
  final List<double> _brightnessHistory = [];
  static const double _lowLightThreshold = 30.0; // Average pixel brightness below this is low light
  static const int _brightnessCheckInterval = 30; // Check every 30 frames

  // Memory-aware mode
  bool _memoryOptimizationEnabled = false;
  final MemoryMonitor _memoryMonitor = MemoryMonitor();
  ResolutionPreset _cachedResolution = ResolutionPreset.medium;

  // Getters
  CameraController? get controller => _controller;
  CameraDescription? get selectedCamera => _selectedCamera;
  CameraState get state => _state;
  String? get error => _error;
  List<CameraDescription> get availableCameras => _cameras;
  bool get isInitialized => _state == CameraState.ready || _state == CameraState.streaming;
  bool get isStreaming => _state == CameraState.streaming;
  bool get isCameraEnabled => _cameraEnabled;
  double get currentFps => _currentFps;
  bool get hasFlash => _controller?.value.flashMode != null;
  bool get isFlashOn => _isFlashOn;
  bool get lowLightDetected => _lowLightDetected;
  double get currentExposure => _currentExposure;
  bool get memoryOptimizationEnabled => _memoryOptimizationEnabled;

  /// Creates a new CameraService instance.
  CameraService({PermissionsService? permissionsService})
      : _permissionsService = permissionsService ?? PermissionsService();

  /// Initializes the camera service.
  ///
  /// This method must be called before any other camera operations.
  /// It handles permission checks, camera enumeration, and preference loading.
  Future<void> initialize() async {
    if (_state == CameraState.initializing) {
      LoggerService.info('Camera service initializing...');
    }

    try {
      _setState(CameraState.initializing);
      _error = null;
      _retryCount = 0;

      // Initialize memory monitor
      await _memoryMonitor.initialize();

      // Set up memory callbacks
      _memoryMonitor.addMemoryCriticalCallback(_handleLowMemory);
      _memoryMonitor.addMemoryWarningCallback(_handleMemoryWarning);

      // Check if low-RAM device
      if (_memoryMonitor.isLowRamDevice) {
        LoggerService.info('Low-RAM device detected, enabling memory optimization');
        _memoryOptimizationEnabled = true;
        _cachedResolution = ResolutionPreset.low;
      }

      // Load camera preferences
      await _loadCameraPreferences();

      // Check and request permissions
      final hasPermission = await _checkAndRequestPermission();
      if (!hasPermission) {
        _setState(CameraState.permissionDenied);
        throw const CameraException(
          'permission_denied',
          'Camera permission is required to use camera features',
        );
      }

      // Get available cameras
      _cameras = await availableCameras();
      LoggerService.debug('Found ${_cameras.length} cameras');

      if (_cameras.isEmpty) {
        _setState(CameraState.noCamerasAvailable);
        throw const CameraException(
          'no_cameras',
          'No cameras available on this device',
        );
      }

      // Select the preferred camera
      await _selectPreferredCamera();

      _setState(CameraState.ready);
      LoggerService.info('Camera service initialized successfully');

      // Start initialization timeout
      _initTimeout = Timer(_initTimeoutDuration, () {
        if (_state == CameraState.initializing) {
          LoggerService.warn('Camera initialization timed out');
          _setError('Camera initialization timed out. Please try again.');
        }
      });

    } catch (e, stack) {
      _handleError(e, stack, 'initialize');
    }
  }

  /// Starts the camera with the specified resolution.
  ///
  /// [resolution] - The desired image resolution.
  /// [enableAudio] - Whether to enable audio streaming.
  Future<void> startCamera({
    ResolutionPreset? resolution,
    bool enableAudio = false,
  }) async {
    if (!_cameraEnabled) {
      LoggerService.warn('Camera is disabled');
      return;
    }

    if (_state == CameraState.streaming) {
      LoggerService.info('Camera already streaming');
      return;
    }

    // Use cached resolution for memory optimization if not specified
    final actualResolution = resolution ?? _cachedResolution;

    try {
      _setState(CameraState.starting);
      _error = null;

      // Cancel any pending retry
      _retryTimer?.cancel();

      // Dispose existing controller if any
      if (_controller != null) {
        await _disposeController();
      }

      // Set timeout for camera start
      _initTimeout?.cancel();
      _initTimeout = Timer(_initTimeoutDuration, () {
        if (_state == CameraState.starting) {
          LoggerService.warn('Camera start timed out');
          _setError('Camera start timed out. Please try again.');
          _setState(CameraState.error);
        }
      });

      LoggerService.info('Starting camera with resolution: $actualResolution (memory optimized: $_memoryOptimizationEnabled)');

      _controller = CameraController(
        _selectedCamera!,
        actualResolution,
        enableAudio: enableAudio,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _controller!.initialize();
      await _controller!.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);

      // Adjust for low-light conditions if needed
      if (_lowLightDetected) {
        await _adjustForLowLight();
      }

      _setState(CameraState.ready);
      _initTimeout?.cancel();
      LoggerService.info('Camera started successfully');

      notifyListeners();
    } catch (e, stack) {
      _initTimeout?.cancel();
      await _handleStartError(e, stack);
    }
  }

  /// Starts streaming camera frames for ML inference.
  ///
  /// [onFrame] - Callback for each frame.
  /// [resolution] - The resolution for inference frames.
  Future<void> startStreaming({
    required void Function(CameraImage image) onFrame,
    ResolutionPreset? resolution,
  }) async {
    if (!_cameraEnabled) {
      LoggerService.warn('Camera is disabled, cannot start streaming');
      return;
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      _setState(CameraState.error);
      throw const CameraException(
        'not_ready',
        'Camera is not ready for streaming',
      );
    }

    try {
      LoggerService.info('Starting camera streaming');
      _setState(CameraState.preparingStream);

      // Reset performance counters
      _frameCount = 0;
      _lastFpsUpdate = DateTime.now();
      _currentFps = 0.0;
      _brightnessHistory.clear();

      await _controller!.startImageStream((image) {
        _frameCount++;
        _updateFps();

        // Check low-light conditions periodically
        if (_frameCount % _brightnessCheckInterval == 0) {
          _checkLightingConditions(image);
        }

        onFrame(image);
      });

      _setState(CameraState.streaming);
      notifyListeners();
      LoggerService.info('Camera streaming started');
    } catch (e, stack) {
      _setState(CameraState.error);
      _error = e.toString();
      LoggerService.error('Failed to start camera streaming', error: e, stack: stack);
      await _retryOperation('startStreaming');
      rethrow;
    }
  }

  /// Stops streaming camera frames.
  Future<void> stopStreaming() async {
    if (_state != CameraState.streaming) {
      LoggerService.warn('Camera is not streaming, cannot stop');
      return;
    }

    try {
      LoggerService.info('Stopping camera streaming');
      await _controller?.stopImageStream();
      _setState(CameraState.ready);
      notifyListeners();
      LoggerService.info('Camera streaming stopped');
    } catch (e, stack) {
      LoggerService.error('Failed to stop camera streaming', error: e, stack: stack);
      _setState(CameraState.error);
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
    final newCamera = _cameras[nextIndex];

    LoggerService.info('Switching from ${_selectedCamera?.name} to ${newCamera.name}');

    // Save preference
    _preferredCameraDirection = newCamera.lensDirection;
    await _saveCameraPreferences();

    _selectedCamera = newCamera;

    // Restart camera with new description
    if (_controller != null && _controller!.value.isInitialized) {
      final wasStreaming = _state == CameraState.streaming;
      if (wasStreaming) {
        await stopStreaming();
      }
      await startCamera();
      notifyListeners();
      LoggerService.info('Camera restarted after switch');
    }
  }

  /// Toggles the camera on/off.
  Future<void> toggleCamera() async {
    _cameraEnabled = !_cameraEnabled;

    if (!_cameraEnabled) {
      if (_state == CameraState.streaming) {
        await stopStreaming();
      }
      if (_controller != null) {
        await _disposeController();
      }
      _setState(CameraState.disabled);
    } else {
      await startCamera();
    }

    notifyListeners();
    LoggerService.info('Camera toggled: $_cameraEnabled');
  }

  /// Toggles the flash/torch.
  Future<void> toggleFlash() async {
    if (_controller == null) return;

    _isFlashOn = !_isFlashOn;
    await _controller!.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
    LoggerService.debug('Flash toggled: $_isFlashOn');
    notifyListeners();
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

  /// Gets the exposure offset range.
  (double min, double max) get exposureOffsetRange {
    if (_controller == null) return (0.0, 0.0);
    return (
      _controller!.value.getMinExposureOffset(),
      _controller!.value.getMaxExposureOffset(),
    );
  }

  /// Called when app goes to background.
  Future<void> onAppBackground() async {
    if (_isAppInBackground) return;
    _isAppInBackground = true;

    LoggerService.info('App going to background, pausing camera');
    if (_state == CameraState.streaming) {
      await stopStreaming();
    }
  }

  /// Called when app returns from background.
  Future<void> onAppForeground() async {
    if (!_isAppInBackground) return;
    _isAppInBackground = false;

    LoggerService.info('App returning to foreground, resuming camera');
    if (_cameraEnabled && _controller != null) {
      try {
        await startCamera();
        LoggerService.info('Camera resumed after background');
      } catch (e, stack) {
        LoggerService.error('Failed to resume camera', error: e, stack: stack);
        _setError('Failed to resume camera. Please try again.');
      }
    }
  }

  /// Cleans up the camera resources.
  Future<void> dispose() async {
    LoggerService.info('Disposing camera service');
    _initTimeout?.cancel();
    _retryTimer?.cancel();
    _memoryMonitor.clearCallbacks();
    _memoryMonitor.stopMonitoring();
    await _disposeController();
    _cameraEnabled = true;
    _setState(CameraState.disposed);
    notifyListeners();
  }

  Future<void> _disposeController() async {
    if (_controller != null) {
      if (_state == CameraState.streaming) {
        try {
          await _controller!.stopImageStream();
        } catch (_) {}
      }
      try {
        await _controller!.dispose();
      } catch (_) {}
      _controller = null;
    }
  }

  Future<bool> _checkAndRequestPermission() async {
    try {
      await _permissionsService.initialize();
      if (_permissionsService.hasCameraPermission) {
        return true;
      }

      // Request permission
      final granted = await _permissionsService.requestCameraPermission();
      return granted;
    } catch (e, stack) {
      LoggerService.error('Permission check failed', error: e, stack: stack);
      return false;
    }
  }

  Future<void> _loadCameraPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cameraDirection = prefs.getString('preferred_camera_direction');
      if (cameraDirection != null) {
        _preferredCameraDirection = CameraLensDirection.values.firstWhere(
          (e) => e.toString() == cameraDirection,
          orElse: () => CameraLensDirection.back,
        );
      }
    } catch (e) {
      LoggerService.warn('Failed to load camera preferences', error: e);
    }
  }

  Future<void> _saveCameraPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('preferred_camera_direction', _preferredCameraDirection.toString());
    } catch (e) {
      LoggerService.warn('Failed to save camera preferences', error: e);
    }
  }

  Future<void> _selectPreferredCamera() async {
    try {
      _selectedCamera = _cameras.firstWhere(
        (camera) => camera.lensDirection == _preferredCameraDirection,
        orElse: () => _cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
          orElse: () => _cameras.first,
        ),
      );
      LoggerService.info('Selected camera: ${_selectedCamera?.name}');
    } catch (e) {
      _selectedCamera = _cameras.first;
    }
  }

  void _updateFps() {
    final now = DateTime.now();
    final elapsed = now.difference(_lastFpsUpdate).inMilliseconds;

    if (elapsed >= 1000) {
      _currentFps = (_frameCount * 1000) / elapsed;
      _frameCount = 0;
      _lastFpsUpdate = now;

      LoggerService.debug('Camera FPS: ${_currentFps.toStringAsFixed(1)}');

      // Warn if FPS is too low
      if (_currentFps < 20 && _state == CameraState.streaming) {
        LoggerService.warn('Low FPS detected: ${_currentFps.toStringAsFixed(1)}');
      }
    }
  }

  void _setState(CameraState newState) {
    _state = newState;
    notifyListeners();
  }

  void _setError(String errorMessage) {
    _error = errorMessage;
    LoggerService.error(errorMessage);
    notifyListeners();
  }

  void _handleError(dynamic e, StackTrace stack, String operation) {
    _error = e.toString();
    _setState(CameraState.error);
    LoggerService.error('Camera error in $operation', error: e, stack: stack);
  }

  Future<void> _handleStartError(dynamic e, StackTrace stack) async {
    _error = e.toString();
    LoggerService.error('Failed to start camera', error: e, stack: stack);

    if (_retryCount < _maxRetries) {
      _retryCount++;
      LoggerService.info('Retrying camera start ($_retryCount/$_maxRetries)...');
      _setState(CameraState.retrying);
      _retryTimer = Timer(const Duration(seconds: 1), () async {
        try {
          await startCamera();
        } catch (e, stack) {
          await _handleStartError(e, stack);
        }
      });
    } else {
      _retryCount = 0;
      _setState(CameraState.error);
      throw CameraException(
        'start_failed',
        'Failed to start camera after $_maxRetries attempts: $e',
        originalError: e,
        stackTrace: stack,
      );
    }
  }

  Future<void> _retryOperation(String operation) async {
    if (_retryCount < _maxRetries) {
      _retryCount++;
      LoggerService.info('Retrying $operation ($_retryCount/$_maxRetries)...');
      _setState(CameraState.retrying);
      _retryTimer = Timer(const Duration(seconds: 1), () async {
        try {
          await startCamera();
        } catch (e, stack) {
          await _handleStartError(e, stack);
        }
      });
    } else {
      _retryCount = 0;
    }
  }

  /// Checks lighting conditions from camera frame.
  void _checkLightingConditions(CameraImage image) {
    try {
      // Calculate average brightness from Y-plane (luminance)
      final yPlane = image.planes[0].bytes;
      final stride = image.planes[0].bytesPerRow;

      // Sample pixels for performance (every 100th pixel)
      var totalBrightness = 0;
      var sampleCount = 0;

      for (var i = 0; i < yPlane.length; i += 100) {
        if (i % stride < image.width) {
          totalBrightness += yPlane[i];
          sampleCount++;
        }
      }

      if (sampleCount > 0) {
        final avgBrightness = totalBrightness / sampleCount;
        _brightnessHistory.add(avgBrightness);

        // Keep history limited
        if (_brightnessHistory.length > 10) {
          _brightnessHistory.removeAt(0);
        }

        // Calculate moving average
        final movingAvg = _brightnessHistory.reduce((a, b) => a + b) / _brightnessHistory.length;

        // Check if low light
        final wasLowLight = _lowLightDetected;
        _lowLightDetected = movingAvg < _lowLightThreshold;

        if (_lowLightDetected && !wasLowLight) {
          LoggerService.warn('Low light conditions detected (brightness: ${movingAvg.toStringAsFixed(1)})');
          _onLowLightDetected();
        } else if (!_lowLightDetected && wasLowLight) {
          LoggerService.info('Lighting conditions improved');
          _onLightingImproved();
        }
      }
    } catch (e) {
      LoggerService.warn('Failed to check lighting conditions: $e');
    }
  }

  /// Called when low light is detected.
  Future<void> _onLowLightDetected() async {
    try {
      if (_controller == null || !_controller!.value.isInitialized) return;

      // Enable flash/torch if available
      if (hasFlash) {
        await toggleFlash();
        LoggerService.info('Flash enabled for low light conditions');
      }

      // Increase exposure if supported
      await _adjustExposure(0.5);
    } catch (e) {
      LoggerService.warn('Failed to adjust for low light: $e');
    }
  }

  /// Called when lighting conditions improve.
  Future<void> _onLightingImproved() async {
    try {
      if (_controller == null || !_controller!.value.isInitialized) return;

      // Turn off flash if it was auto-enabled
      if (_isFlashOn) {
        await toggleFlash();
        LoggerService.info('Flash disabled for improved lighting');
      }

      // Reset exposure
      await _adjustExposure(0.0);
    } catch (e) {
      LoggerService.warn('Failed to reset lighting adjustments: $e');
    }
  }

  /// Adjusts camera exposure offset.
  Future<void> _adjustExposure(double offset) async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      final minExposure = _controller!.value.getMinExposureOffset();
      final maxExposure = _controller!.value.getMaxExposureOffset();

      if (minExposure == 0.0 && maxExposure == 0.0) {
        LoggerService.debug('Exposure adjustment not supported');
        return;
      }

      final clampedOffset = offset.clamp(minExposure, maxExposure);
      await _controller!.setExposureOffset(clampedOffset);
      _currentExposure = clampedOffset;

      LoggerService.debug('Exposure adjusted to $clampedOffset');
    } catch (e) {
      LoggerService.warn('Failed to adjust exposure: $e');
    }
  }

  /// Adjusts camera settings for low light conditions.
  Future<void> _adjustForLowLight() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      // Increase exposure
      await _adjustExposure(0.5);

      LoggerService.info('Camera adjusted for low light conditions');
    } catch (e) {
      LoggerService.warn('Failed to adjust camera for low light: $e');
    }
  }

  /// Handles low memory conditions.
  void _handleLowMemory() {
    LoggerService.warn('Low memory detected, optimizing camera');

    // Reduce resolution
    if (_cachedResolution.index > ResolutionPreset.low.index) {
      _cachedResolution = ResolutionPreset.low;

      // Restart camera with lower resolution if streaming
      if (_state == CameraState.streaming) {
        stopStreaming().then((_) => startCamera());
      }

      LoggerService.info('Camera resolution reduced to conserve memory');
    }
  }

  /// Handles memory warning conditions.
  void _handleMemoryWarning() {
    LoggerService.info('Memory warning, preparing for optimization');

    // Clean up resources
    _brightnessHistory.clear();

    // Reduce FPS target by stopping/starting
    if (_state == CameraState.streaming) {
      stopStreaming().then((_) => startCamera());
    }
  }
}
