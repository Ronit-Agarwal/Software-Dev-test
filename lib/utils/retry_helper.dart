import 'dart:async';
import 'dart:math';
import 'package:signsync/core/logging/logger_service.dart';

/// A utility class for retrying operations with exponential backoff.
///
/// Features:
/// - Configurable max retries and delays
/// - Exponential backoff with jitter
/// - Condition-based retry logic
/// - Comprehensive error logging
/// - Timeout support
class RetryHelper {
  final int maxRetries;
  final Duration initialDelay;
  final Duration maxDelay;
  final double backoffMultiplier;
  final bool addJitter;
  final Duration? timeout;

  int _attemptCount = 0;
  DateTime? _lastAttemptTime;
  Timer? _timeoutTimer;

  RetryHelper({
    this.maxRetries = 3,
    this.initialDelay = const Duration(milliseconds: 100),
    this.maxDelay = const Duration(seconds: 10),
    this.backoffMultiplier = 2.0,
    this.addJitter = true,
    this.timeout,
  });

  /// Resets the attempt counter.
  void reset() {
    _attemptCount = 0;
    _lastAttemptTime = null;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }

  /// Gets the current attempt count.
  int get attemptCount => _attemptCount;

  /// Gets the last attempt time.
  DateTime? get lastAttemptTime => _lastAttemptTime;

  /// Calculates the delay for the next retry attempt using exponential backoff.
  Duration _calculateDelay(int attempt) {
    final exponentialDelay = initialDelay * pow(backoffMultiplier, attempt);
    final clampedDelay = Duration(
      milliseconds: exponentialDelay.inMilliseconds.clamp(
        initialDelay.inMilliseconds,
        maxDelay.inMilliseconds,
      ),
    );

    // Add jitter to avoid thundering herd
    if (addJitter) {
      final random = Random();
      final jitter = (clampedDelay.inMilliseconds * 0.1).toInt();
      final jittered = clampedDelay.inMilliseconds + random.nextInt(jitter * 2) - jitter;
      return Duration(milliseconds: jittered);
    }

    return clampedDelay;
  }

  /// Executes an operation with retry logic.
  ///
  /// [operation] - The function to execute
  /// [onError] - Optional callback to handle errors
  /// [shouldRetry] - Optional function to determine if an error is retryable
  /// [onRetry] - Optional callback called before each retry attempt
  /// [onMaxRetriesReached] - Optional callback when max retries is exceeded
  Future<T> execute<T>(
    Future<T> Function() operation, {
    void Function(dynamic error, int attempt)? onError,
    bool Function(dynamic error)? shouldRetry,
    void Function(int attempt, Duration delay)? onRetry,
    void Function(dynamic error)? onMaxRetriesReached,
  }) async {
    dynamic lastError;

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      _attemptCount = attempt;
      _lastAttemptTime = DateTime.now();

      try {
        LoggerService.debug('Retry attempt $attempt of $maxRetries');

        // Execute operation with optional timeout
        if (timeout != null) {
          return await operation().timeout(
            timeout!,
            onTimeout: () => throw TimeoutException(
              operation: 'RetryHelper.execute',
              timeoutDuration: timeout,
            ),
          );
        } else {
          return await operation();
        }
      } catch (error, stack) {
        lastError = error;
        LoggerService.warn('Retry attempt $attempt failed: $error');

        // Call error callback if provided
        onError?.call(error, attempt);

        // Check if we should retry this error
        if (shouldRetry != null && !shouldRetry(error)) {
          LoggerService.debug('Error is not retryable, aborting');
          rethrow;
        }

        // If this was the last attempt, throw
        if (attempt >= maxRetries) {
          LoggerService.error('Max retries ($maxRetries) exceeded');
          onMaxRetriesReached?.call(error);
          rethrow;
        }

        // Calculate delay before next retry
        final delay = _calculateDelay(attempt);
        LoggerService.debug('Waiting ${delay.inMilliseconds}ms before retry');

        // Call retry callback if provided
        onRetry?.call(attempt + 1, delay);

        // Wait before next retry
        await Future.delayed(delay);
      }
    }

    // This should never be reached, but just in case
    throw lastError;
  }

  /// Executes an operation with a specific condition for retrying.
  ///
  /// [operation] - The function to execute
  /// [condition] - Function that returns true if the operation should retry
  /// [onRetry] - Optional callback called before each retry attempt
  Future<T> executeWithCondition<T>(
    Future<T> Function() operation,
    bool Function(T result) condition, {
    void Function(int attempt, Duration delay)? onRetry,
  }) async {
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      _attemptCount = attempt;
      _lastAttemptTime = DateTime.now();

      try {
        final result = await operation();

        // Check if condition is met
        if (condition(result)) {
          // Condition met, return result
          LoggerService.debug('Condition met on attempt $attempt');
          return result;
        }

        // Condition not met, retry if we have attempts left
        if (attempt >= maxRetries) {
          LoggerService.warn('Condition not met after $maxRetries attempts');
          return result;
        }

        // Calculate delay before next retry
        final delay = _calculateDelay(attempt);
        LoggerService.debug('Condition not met, retrying in ${delay.inMilliseconds}ms');
        onRetry?.call(attempt + 1, delay);
        await Future.delayed(delay);
      } catch (error, stack) {
        // On error, just retry
        if (attempt >= maxRetries) {
          rethrow;
        }

        final delay = _calculateDelay(attempt);
        LoggerService.debug('Error on attempt $attempt, retrying in ${delay.inMilliseconds}ms: $error');
        onRetry?.call(attempt + 1, delay);
        await Future.delayed(delay);
      }
    }

    throw StateError('Unreachable code');
  }

  /// Creates a stream that retries operations on failure.
  Stream<T> retryStream<T>(
    Stream<T> Function() streamFactory, {
    bool Function(dynamic error)? shouldRetry,
  }) async* {
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      _attemptCount = attempt;
      _lastAttemptTime = DateTime.now();

      try {
        yield* streamFactory();
        return;
      } catch (error, stack) {
        LoggerService.warn('Stream retry attempt $attempt failed: $error');

        if (shouldRetry != null && !shouldRetry(error)) {
          rethrow;
        }

        if (attempt >= maxRetries) {
          rethrow;
        }

        final delay = _calculateDelay(attempt);
        await Future.delayed(delay);
      }
    }
  }

  /// Cleans up resources.
  void dispose() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }
}

/// Helper function to create a retry helper with common configurations.
class RetryHelpers {
  /// Creates a retry helper for network operations.
  static RetryHelper network({
    int maxRetries = 3,
    Duration timeout = const Duration(seconds: 30),
  }) {
    return RetryHelper(
      maxRetries: maxRetries,
      initialDelay: const Duration(milliseconds: 500),
      maxDelay: const Duration(seconds: 5),
      backoffMultiplier: 2.0,
      timeout: timeout,
    );
  }

  /// Creates a retry helper for ML inference operations.
  static RetryHelper mlInference({
    int maxRetries = 2,
    Duration timeout = const Duration(milliseconds: 500),
  }) {
    return RetryHelper(
      maxRetries: maxRetries,
      initialDelay: const Duration(milliseconds: 50),
      maxDelay: const Duration(milliseconds: 200),
      backoffMultiplier: 1.5,
      timeout: timeout,
    );
  }

  /// Creates a retry helper for camera operations.
  static RetryHelper camera({
    int maxRetries = 3,
    Duration timeout = const Duration(seconds: 10),
  }) {
    return RetryHelper(
      maxRetries: maxRetries,
      initialDelay: const Duration(milliseconds: 200),
      maxDelay: const Duration(seconds: 2),
      backoffMultiplier: 2.0,
      timeout: timeout,
    );
  }

  /// Creates a retry helper for TTS operations.
  static RetryHelper tts({
    int maxRetries = 2,
    Duration timeout = const Duration(seconds: 5),
  }) {
    return RetryHelper(
      maxRetries: maxRetries,
      initialDelay: const Duration(milliseconds: 100),
      maxDelay: const Duration(seconds: 1),
      backoffMultiplier: 1.5,
      timeout: timeout,
    );
  }

  /// Determines if an error is retryable.
  static bool isRetryableError(dynamic error) {
    // Network errors are typically retryable
    if (error.toString().contains('network') ||
        error.toString().contains('socket') ||
        error.toString().contains('timeout') ||
        error.toString().contains('connection')) {
      return true;
    }

    // Temporary errors
    if (error.toString().contains('temporary') ||
        error.toString().contains('unavailable')) {
      return true;
    }

    return false;
  }
}
