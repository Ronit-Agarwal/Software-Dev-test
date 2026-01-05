import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:signsync/core/logging/logger_service.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Monitors memory usage and provides alerts for low memory conditions.
///
/// Features:
/// - Memory usage tracking
/// - Low memory warnings
/// - Automatic memory cleanup callbacks
/// - Configurable thresholds
/// - Platform-specific memory monitoring
class MemoryMonitor with ChangeNotifier {
  // Singleton pattern
  static final MemoryMonitor _instance = MemoryMonitor._internal();
  factory MemoryMonitor() => _instance;
  MemoryMonitor._internal();

  // Memory thresholds (percentage of available memory)
  static const double _warningThreshold = 0.80;  // 80%
  static const double _criticalThreshold = 0.90; // 90%

  // State
  bool _isMonitoring = false;
  Timer? _monitorTimer;
  MemoryLevel _currentLevel = MemoryLevel.normal;
  double _memoryUsage = 0.0;
  double _availableMemoryMB = 0.0;
  int _totalMemoryMB = 0;

  // Callbacks
  final List<VoidCallback> _onMemoryWarningCallbacks = [];
  final List<VoidCallback> _onMemoryCriticalCallbacks = [];
  final List<VoidCallback> _onMemoryRecoveredCallbacks = [];

  // Device info
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  int? _lowRamThresholdMB;
  bool _isLowRamDevice = false;

  // Memory monitoring interval
  static const Duration _monitorInterval = Duration(seconds: 5);

  // Getters
  bool get isMonitoring => _isMonitoring;
  MemoryLevel get currentLevel => _currentLevel;
  double get memoryUsage => _memoryUsage;
  double get availableMemoryMB => _availableMemoryMB;
  int get totalMemoryMB => _totalMemoryMB;
  bool get isLowRamDevice => _isLowRamDevice;

  /// Initializes the memory monitor.
  Future<void> initialize() async {
    if (_isMonitoring) {
      LoggerService.warn('Memory monitor already initialized');
      return;
    }

    try {
      LoggerService.info('Initializing memory monitor');

      // Detect low RAM device
      await _detectDeviceCapabilities();

      // Start monitoring
      _startMonitoring();

      _isMonitoring = true;
      LoggerService.info('Memory monitor initialized (low RAM: $_isLowRamDevice)');
    } catch (e, stack) {
      LoggerService.error('Failed to initialize memory monitor', error: e, stack: stack);
    }
  }

  /// Detects device capabilities including RAM.
  Future<void> _detectDeviceCapabilities() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        _totalMemoryMB = androidInfo.totalPhysicalMemory ~/ (1024 * 1024);

        // Determine low RAM threshold (less than 3GB is considered low RAM)
        _lowRamThresholdMB = 3072; // 3GB
        _isLowRamDevice = _totalMemoryMB < _lowRamThresholdMB;

        LoggerService.info('Device RAM: ${_totalMemoryMB}MB (low RAM: $_isLowRamDevice)');
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        // iOS doesn't provide RAM directly, estimate based on device
        final modelName = iosInfo.machineName.toLowerCase();

        // Older iPhone models have less RAM
        _isLowRamDevice = modelName.contains('iphone 6') ||
                          modelName.contains('iphone 7') ||
                          modelName.contains('iphone 8') ||
                          modelName.contains('iphone se');

        LoggerService.info('iOS device: $modelName (low RAM: $_isLowRamDevice)');
      }
    } catch (e) {
      LoggerService.warn('Failed to detect device capabilities: $e');
      // Default to not low RAM
      _isLowRamDevice = false;
    }
  }

  /// Starts monitoring memory usage.
  void _startMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer = Timer.periodic(_monitorInterval, (_) {
      _updateMemoryUsage();
    });
  }

  /// Stops monitoring memory usage.
  void stopMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
    _isMonitoring = false;
    LoggerService.info('Memory monitor stopped');
  }

  /// Updates memory usage and triggers callbacks if needed.
  void _updateMemoryUsage() {
    try {
      // Get current memory usage (platform-specific)
      final usage = _getCurrentMemoryUsage();
      _memoryUsage = usage;

      // Check memory level
      final newLevel = _determineMemoryLevel();

      // Trigger callbacks based on level changes
      if (newLevel != _currentLevel) {
        _handleMemoryLevelChange(newLevel, _currentLevel);
        _currentLevel = newLevel;
        notifyListeners();
      }

      // Log if memory is critical
      if (_currentLevel == MemoryLevel.critical) {
        LoggerService.warn('Memory usage is critical: ${(_memoryUsage * 100).toStringAsFixed(1)}%');
      }
    } catch (e) {
      LoggerService.warn('Failed to update memory usage: $e');
    }
  }

  /// Gets current memory usage as a percentage.
  double _getCurrentMemoryUsage() {
    // On web, use browser memory info
    if (kIsWeb) {
      return _getWebMemoryUsage();
    }

    // On native platforms, use process info
    return ProcessInfo.currentRss / (1024 * 1024 * _totalMemoryMB);
  }

  /// Gets web memory usage.
  double _getWebMemoryUsage() {
    try {
      // Access performance.memory if available (Chrome)
      final jsPerformance = _getJsPerformance();
      if (jsPerformance != null && jsPerformance['memory'] != null) {
        final used = jsPerformance['memory']['usedJSHeapSize'] as int;
        final total = jsPerformance['memory']['totalJSHeapSize'] as int;
        return used / total;
      }
    } catch (e) {
      LoggerService.warn('Failed to get web memory usage: $e');
    }

    return 0.5; // Default estimate
  }

  /// Gets JS performance object.
  Map<String, dynamic>? _getJsPerformance() {
    // This would require js interop, simplified for now
    return null;
  }

  /// Determines the current memory level.
  MemoryLevel _determineMemoryLevel() {
    if (_isLowRamDevice) {
      // Stricter thresholds for low RAM devices
      if (_memoryUsage > 0.85) return MemoryLevel.critical;
      if (_memoryUsage > 0.75) return MemoryLevel.warning;
      return MemoryLevel.normal;
    } else {
      // Standard thresholds
      if (_memoryUsage > _criticalThreshold) return MemoryLevel.critical;
      if (_memoryUsage > _warningThreshold) return MemoryLevel.warning;
      return MemoryLevel.normal;
    }
  }

  /// Handles memory level changes and triggers callbacks.
  void _handleMemoryLevelChange(MemoryLevel newLevel, MemoryLevel oldLevel) {
    LoggerService.info('Memory level changed from $oldLevel to $newLevel (${(_memoryUsage * 100).toStringAsFixed(1)}%)');

    // Critical level reached
    if (newLevel == MemoryLevel.critical && oldLevel != MemoryLevel.critical) {
      _triggerCallbacks(_onMemoryCriticalCallbacks);
      LoggerService.warn('CRITICAL: Memory usage is ${(_memoryUsage * 100).toStringAsFixed(1)}%');

      // Suggest cleanup
      _suggestMemoryCleanup();
    }

    // Warning level reached
    if (newLevel == MemoryLevel.warning && oldLevel == MemoryLevel.normal) {
      _triggerCallbacks(_onMemoryWarningCallbacks);
      LoggerService.warn('WARNING: Memory usage is ${(_memoryUsage * 100).toStringAsFixed(1)}%');
    }

    // Memory recovered from warning/critical
    if (newLevel == MemoryLevel.normal && oldLevel != MemoryLevel.normal) {
      _triggerCallbacks(_onMemoryRecoveredCallbacks);
      LoggerService.info('Memory usage recovered to ${(_memoryUsage * 100).toStringAsFixed(1)}%');
    }
  }

  /// Triggers a list of callbacks.
  void _triggerCallbacks(List<VoidCallback> callbacks) {
    for (final callback in callbacks) {
      try {
        callback();
      } catch (e) {
        LoggerService.error('Memory callback failed', error: e);
      }
    }
  }

  /// Suggests memory cleanup operations.
  void _suggestMemoryCleanup() {
    LoggerService.info('Suggesting memory cleanup...');

    // Log suggestions for cleanup
    final suggestions = [
      'Clear image caches',
      'Unload unused ML models',
      'Reduce processing frequency',
      'Clear frame buffers',
      'Close unused streams',
    ];

    for (final suggestion in suggestions) {
      LoggerService.debug('- $suggestion');
    }
  }

  /// Adds a callback for memory warning events.
  void addMemoryWarningCallback(VoidCallback callback) {
    _onMemoryWarningCallbacks.add(callback);
  }

  /// Adds a callback for memory critical events.
  void addMemoryCriticalCallback(VoidCallback callback) {
    _onMemoryCriticalCallbacks.add(callback);
  }

  /// Adds a callback for memory recovered events.
  void addMemoryRecoveredCallback(VoidCallback callback) {
    _onMemoryRecoveredCallbacks.add(callback);
  }

  /// Removes all callbacks.
  void clearCallbacks() {
    _onMemoryWarningCallbacks.clear();
    _onMemoryCriticalCallbacks.clear();
    _onMemoryRecoveredCallbacks.clear();
  }

  /// Forces an immediate memory cleanup check.
  void forceCleanupCheck() {
    _updateMemoryUsage();
  }

  /// Gets memory statistics.
  Map<String, dynamic> get statistics => {
        'memoryUsage': _memoryUsage,
        'availableMemoryMB': _availableMemoryMB,
        'totalMemoryMB': _totalMemoryMB,
        'currentLevel': _currentLevel.toString(),
        'isLowRamDevice': _isLowRamDevice,
        'isMonitoring': _isMonitoring,
      };

  @override
  void dispose() {
    stopMonitoring();
    clearCallbacks();
    super.dispose();
  }
}

/// Memory level enumeration.
enum MemoryLevel {
  normal,
  warning,
  critical,
}

/// Extension for memory level display.
extension MemoryLevelExtension on MemoryLevel {
  String get displayName {
    switch (this) {
      case MemoryLevel.normal:
        return 'Normal';
      case MemoryLevel.warning:
        return 'Warning';
      case MemoryLevel.critical:
        return 'Critical';
    }
  }

  String get description {
    switch (this) {
      case MemoryLevel.normal:
        return 'Memory usage is within normal limits';
      case MemoryLevel.warning:
        return 'Memory usage is high. Consider cleaning up resources';
      case MemoryLevel.critical:
        return 'Memory usage is critical. Immediate cleanup required';
    }
  }
}
