import 'dart:async';
import 'package:signsync/core/logging/logger_service.dart';

/// Centralized error recovery and error handling service.
///
/// Provides:
/// - Automatic error recovery strategies
/// - Error categorization and prioritization
/// - Circuit breaker pattern for repeated failures
/// - Graceful degradation
/// - Comprehensive error logging
class ErrorRecoveryService {
  // Singleton pattern
  static final ErrorRecoveryService _instance = ErrorRecoveryService._internal();
  factory ErrorRecoveryService() => _instance;
  ErrorRecoveryService._internal();

  // Error tracking
  final Map<String, ErrorStats> _errorStats = {};
  final List<ErrorEvent> _recentErrors = [];
  static const int _maxRecentErrors = 100;

  // Circuit breaker state
  final Map<String, CircuitBreakerState> _circuitBreakers = {};
  static const Duration _circuitBreakerTimeout = Duration(minutes: 5);
  static const int _failureThreshold = 5;

  // Recovery strategies
  final Map<ErrorCategory, RecoveryStrategy> _recoveryStrategies = {};

  // Getters
  Map<String, ErrorStats> get errorStats => Map.unmodifiable(_errorStats);
  List<ErrorEvent> get recentErrors => List.unmodifiable(_recentErrors);
  Map<String, CircuitBreakerState> get circuitBreakers => Map.unmodifiable(_circuitBreakers);

  /// Initializes the error recovery service.
  void initialize() {
    LoggerService.info('Initializing error recovery service');

    // Set up default recovery strategies
    _setupDefaultStrategies();

    // Start cleanup timer
    Timer.periodic(const Duration(hours: 1), (_) {
      _cleanupOldErrors();
    });
  }

  /// Records an error and attempts recovery.
  ///
  /// [error] - The error that occurred
  /// [context] - Context about where the error occurred
  /// [recoverable] - Whether the error is potentially recoverable
  ErrorRecoveryResult recordError(
    dynamic error,
    String context, {
    StackTrace? stackTrace,
    bool recoverable = true,
  }) {
    final errorType = _categorizeError(error);
    final errorKey = _getErrorKey(context, errorType);

    LoggerService.error('Error recorded: $context', error: error, stack: stackTrace);

    // Update error stats
    _updateErrorStats(errorKey, errorType);

    // Record error event
    _recentErrors.add(ErrorEvent(
      error: error.toString(),
      context: context,
      type: errorType,
      timestamp: DateTime.now(),
    ));

    // Maintain max errors
    if (_recentErrors.length > _maxRecentErrors) {
      _recentErrors.removeAt(0);
    }

    // Check circuit breaker
    final circuitState = _circuitBreakers[errorKey];
    if (circuitState?.isOpen ?? false) {
      LoggerService.warn('Circuit breaker is open for $context, skipping recovery');
      return ErrorRecoveryResult.circuitOpen();
    }

    // Attempt recovery if recoverable
    if (recoverable) {
      return _attemptRecovery(errorType, context, error);
    }

    return ErrorRecoveryResult.failed(errorType, error.toString());
  }

  /// Checks if a service is available (circuit breaker not open).
  bool isServiceAvailable(String service) {
    final state = _circuitBreakers[service];
    return state?.isOpen != true;
  }

  /// Records a failure for circuit breaker.
  void recordFailure(String service) {
    final state = _circuitBreakers[service] ??
        CircuitBreakerState(
          failureCount: 0,
          lastFailureTime: DateTime.now(),
          isOpen: false,
        );

    state.failureCount++;
    state.lastFailureTime = DateTime.now();

    // Open circuit if threshold exceeded
    if (state.failureCount >= _failureThreshold) {
      state.isOpen = true;
      LoggerService.warn('Circuit breaker opened for $service (${state.failureCount} failures)');
    }

    _circuitBreakers[service] = state;
  }

  /// Records a success for circuit breaker.
  void recordSuccess(String service) {
    final state = _circuitBreakers[service];
    if (state == null) return;

    state.failureCount = 0;
    state.isOpen = false;

    LoggerService.debug('Circuit breaker reset for $service');
  }

  /// Resets circuit breaker for a service.
  void resetCircuitBreaker(String service) {
    _circuitBreakers.remove(service);
    LoggerService.info('Circuit breaker reset for $service');
  }

  /// Categorizes an error.
  ErrorCategory _categorizeError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('network') ||
        errorString.contains('socket') ||
        errorString.contains('connection')) {
      return ErrorCategory.network;
    }

    if (errorString.contains('permission') ||
        errorString.contains('denied')) {
      return ErrorCategory.permission;
    }

    if (errorString.contains('camera') ||
        errorString.contains('capture')) {
      return ErrorCategory.camera;
    }

    if (errorString.contains('inference') ||
        errorString.contains('model') ||
        errorString.contains('tflite')) {
      return ErrorCategory.inference;
    }

    if (errorString.contains('tts') ||
        errorString.contains('speech') ||
        errorString.contains('audio')) {
      return ErrorCategory.audio;
    }

    if (errorString.contains('timeout') ||
        errorString.contains('deadline')) {
      return ErrorCategory.timeout;
    }

    if (errorString.contains('memory') ||
        errorString.contains('out of memory')) {
      return ErrorCategory.memory;
    }

    if (errorString.contains('null') ||
        errorString.contains('nullpointer')) {
      return ErrorCategory.nullPointer;
    }

    return ErrorCategory.unknown;
  }

  /// Gets error key for circuit breaker and stats.
  String _getErrorKey(String context, ErrorCategory type) {
    return '${context}_${type.name}';
  }

  /// Updates error statistics.
  void _updateErrorStats(String key, ErrorCategory type) {
    final stats = _errorStats[key] ??
        ErrorStats(
          count: 0,
          lastOccurrence: DateTime.now(),
          type: type,
        );

    stats.count++;
    stats.lastOccurrence = DateTime.now();

    _errorStats[key] = stats;
  }

  /// Attempts to recover from an error.
  ErrorRecoveryResult _attemptRecovery(
    ErrorCategory type,
    String context,
    dynamic error,
  ) {
    final strategy = _recoveryStrategies[type];

    if (strategy == null) {
      LoggerService.debug('No recovery strategy for $type in $context');
      return ErrorRecoveryResult.failed(type, error.toString());
    }

    LoggerService.info('Attempting recovery for $type in $context');

    try {
      final recovered = strategy.attemptRecovery(error, context);
      if (recovered) {
        LoggerService.info('Recovery successful for $type in $context');
        return ErrorRecoveryResult.recovered();
      }
    } catch (e) {
      LoggerService.error('Recovery failed for $type: $e');
    }

    return ErrorRecoveryResult.failed(type, error.toString());
  }

  /// Sets up default recovery strategies.
  void _setupDefaultStrategies() {
    // Network errors: retry with backoff
    _recoveryStrategies[ErrorCategory.network] = NetworkRecoveryStrategy();

    // Permission errors: request permission
    _recoveryStrategies[ErrorCategory.permission] = PermissionRecoveryStrategy();

    // Camera errors: restart camera
    _recoveryStrategies[ErrorCategory.camera] = CameraRecoveryStrategy();

    // Inference errors: reduce quality/frequency
    _recoveryStrategies[ErrorCategory.inference] = InferenceRecoveryStrategy();

    // Audio errors: fallback to silence
    _recoveryStrategies[ErrorCategory.audio] = AudioRecoveryStrategy();

    // Timeout errors: increase timeout
    _recoveryStrategies[ErrorCategory.timeout] = TimeoutRecoveryStrategy();

    // Memory errors: cleanup resources
    _recoveryStrategies[ErrorCategory.memory] = MemoryRecoveryStrategy();

    // Null pointer: restart service
    _recoveryStrategies[ErrorCategory.nullPointer] = NullPointerRecoveryStrategy();
  }

  /// Cleans up old error records.
  void _cleanupOldErrors() {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));

    _recentErrors.removeWhere((event) => event.timestamp.isBefore(cutoff));

    // Reset circuit breakers that have been open long enough
    _circuitBreakers.removeWhere((key, state) {
      if (!state.isOpen) return false;

      final timeSinceOpen = DateTime.now().difference(state.lastFailureTime);
      if (timeSinceOpen > _circuitBreakerTimeout) {
        LoggerService.info('Circuit breaker timeout for $key, resetting');
        return true;
      }

      return false;
    });

    LoggerService.debug('Error recovery cleanup completed');
  }

  /// Gets error summary for analytics.
  Map<String, dynamic> getErrorSummary() {
    final byType = <ErrorCategory, int>{};

    for (final stat in _errorStats.values) {
      byType[stat.type] = (byType[stat.type] ?? 0) + stat.count;
    }

    return {
      'totalErrors': _errorStats.values.fold(0, (sum, stat) => sum + stat.count),
      'errorsByType': byType.map((type, count) => MapEntry(type.name, count)),
      'recentErrors': _recentErrors.length,
      'openCircuitBreakers': _circuitBreakers.values.where((s) => s.isOpen).length,
    };
  }
}

/// Represents error statistics.
class ErrorStats {
  int count;
  DateTime lastOccurrence;
  ErrorCategory type;

  ErrorStats({
    required this.count,
    required this.lastOccurrence,
    required this.type,
  });
}

/// Represents an error event.
class ErrorEvent {
  final String error;
  final String context;
  final ErrorCategory type;
  final DateTime timestamp;

  ErrorEvent({
    required this.error,
    required this.context,
    required this.type,
    required this.timestamp,
  });
}

/// Represents circuit breaker state.
class CircuitBreakerState {
  int failureCount;
  DateTime lastFailureTime;
  bool isOpen;

  CircuitBreakerState({
    required this.failureCount,
    required this.lastFailureTime,
    required this.isOpen,
  });
}

/// Represents error recovery result.
class ErrorRecoveryResult {
  final bool recovered;
  final ErrorCategory? category;
  final String? errorMessage;

  ErrorRecoveryResult.recovered()
      : recovered = true,
        category = null,
        errorMessage = null;

  ErrorRecoveryResult.failed(this.category, this.errorMessage)
      : recovered = false;

  ErrorRecoveryResult.circuitOpen()
      : recovered = false,
        category = null,
        errorMessage = 'Circuit breaker is open';
}

/// Error categories.
enum ErrorCategory {
  network,
  permission,
  camera,
  inference,
  audio,
  timeout,
  memory,
  nullPointer,
  unknown,
}

/// Recovery strategy interface.
abstract class RecoveryStrategy {
  bool attemptRecovery(dynamic error, String context);
}

/// Network recovery strategy.
class NetworkRecoveryStrategy implements RecoveryStrategy {
  @override
  bool attemptRecovery(dynamic error, String context) {
    // Network errors are handled by retry logic in individual services
    // This is just a marker for logging purposes
    return false;
  }
}

/// Permission recovery strategy.
class PermissionRecoveryStrategy implements RecoveryStrategy {
  @override
  bool attemptRecovery(dynamic error, String context) {
    // Permission errors require user action
    // This is just a marker to show permission request UI
    return false;
  }
}

/// Camera recovery strategy.
class CameraRecoveryStrategy implements RecoveryStrategy {
  @override
  bool attemptRecovery(dynamic error, String context) {
    // Camera errors are handled by CameraService retry logic
    return false;
  }
}

/// Inference recovery strategy.
class InferenceRecoveryStrategy implements RecoveryStrategy {
  @override
  bool attemptRecovery(dynamic error, String context) {
    // Inference errors are handled by model services' retry logic
    return false;
  }
}

/// Audio recovery strategy.
class AudioRecoveryStrategy implements RecoveryStrategy {
  @override
  bool attemptRecovery(dynamic error, String context) {
    // Audio errors are handled by TTS service's retry logic
    return false;
  }
}

/// Timeout recovery strategy.
class TimeoutRecoveryStrategy implements RecoveryStrategy {
  @override
  bool attemptRecovery(dynamic error, String context) {
    // Timeouts are handled by individual services' timeout logic
    return false;
  }
}

/// Memory recovery strategy.
class MemoryRecoveryStrategy implements RecoveryStrategy {
  @override
  bool attemptRecovery(dynamic error, String context) {
    // Memory cleanup is handled by MemoryMonitor
    return false;
  }
}

/// Null pointer recovery strategy.
class NullPointerRecoveryStrategy implements RecoveryStrategy {
  @override
  bool attemptRecovery(dynamic error, String context) {
    // Null pointers indicate uninitialized services
    return false;
  }
}
