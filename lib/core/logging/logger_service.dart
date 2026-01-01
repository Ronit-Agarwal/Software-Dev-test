import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Service for structured logging throughout the app.
///
/// This service provides a consistent logging interface that supports:
/// - Multiple log levels (debug, info, warning, error)
/// - Console output in debug mode
/// - Crash reporting integration with Sentry
/// - Structured logging for debugging and analytics
class LoggerService {
  static Logger? _logger;
  static bool _isInitialized = false;

  /// Initializes the logging service.
  static Future<void> initialize() async {
    if (_isInitialized) return;

    LoggerService._logger = Logger(
      printer: PrettyPrinter(
        methodCount: 2,
        errorMethodCount: 5,
        lineLength: 80,
        colors: kDebugMode,
        printEmojis: true,
        dateTimeFormat: DateTimeFormat.dateAndTime,
      ),
      level: kDebugMode ? Level.debug : Level.error,
    );

    // Initialize Sentry for crash reporting
    try {
      await SentryFlutter.init(
        (options) {
          options.dsn = kDebugMode ? '' : '';
          options.tracesSampleRate = kDebugMode ? 1.0 : 0.1;
          options.sampleRate = kDebugMode ? 1.0 : 0.1;
          options.attachStacktrace = true;
          options.sendDefaultPii = false;
        },
      );
      _isInitialized = true;
      LoggerService.info('Logger service initialized');
    } catch (e) {
      // Sentry initialization failed, continue without it
      _isInitialized = true;
      LoggerService.warn('Sentry initialization failed, continuing without crash reporting');
    }
  }

  /// Logs a debug message.
  static void debug(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) {
    _log(
      Level.debug,
      message,
      error: error,
      stackTrace: stackTrace,
      extra: extra,
    );
  }

  /// Logs an info message.
  static void info(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) {
    _log(
      Level.info,
      message,
      error: error,
      stackTrace: stackTrace,
      extra: extra,
    );
  }

  /// Logs a warning message.
  static void warn(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) {
    _log(
      Level.warning,
      message,
      error: error,
      stackTrace: stackTrace,
      extra: extra,
    );
  }

  /// Logs an error message.
  static void error(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) {
    _log(
      Level.error,
      message,
      error: error,
      stackTrace: stackTrace,
      extra: extra,
    );
  }

  /// Logs a verbose message.
  static void verbose(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) {
    _log(
      Level.verbose,
      message,
      error: error,
      stackTrace: stackTrace,
      extra: extra,
    );
  }

  /// Internal log method.
  static void _log(
    Level level,
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) {
    if (_logger == null) return;

    final logMessage = _formatMessage(message, extra);

    switch (level) {
      case Level.debug:
      case Level.verbose:
        _logger!.d(logMessage, error: error, stackTrace: stackTrace);
        break;
      case Level.info:
        _logger!.i(logMessage, error: error, stackTrace: stackTrace);
        break;
      case Level.warning:
        _logger!.w(logMessage, error: error, stackTrace: stackTrace);
        break;
      case Level.error:
      case Level.wtf:
        _logger!.e(logMessage, error: error, stackTrace: stackTrace);
        break;
      case Level.nothing:
        break;
    }

    // Report errors to Sentry
    if (level == Level.error || level == Level.wtf) {
      _reportToSentry(message, error: error, stackTrace: stackTrace);
    }
  }

  /// Formats the log message with extra context.
  static String _formatMessage(String message, Map<String, dynamic>? extra) {
    if (extra == null || extra.isEmpty) return message;

    final extraString = extra.entries
        .map((e) => '${e.key}=${e.value}')
        .join(', ');

    return '$message [$extraString]';
  }

  /// Reports an error to Sentry.
  static Future<void> _reportToSentry(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
  }) async {
    try {
      if (error != null) {
        await Sentry.captureException(
          error,
          stackTrace: stackTrace,
          withScope: (scope) {
            scope.extra = {'log_message': message};
          },
        );
      } else {
        await Sentry.captureMessage(
          message,
          level: SentryLevel.error,
        );
      }
    } catch (e) {
      // Silently fail - logging shouldn't crash the app
    }
  }

  /// Creates a performance trace for timing operations.
  static PerformanceTrace trace(String operation) {
    return PerformanceTrace(operation);
  }

  /// Clears all logger state.
  static void reset() {
    _logger = null;
    _isInitialized = false;
  }
}

/// A utility class for timing operations.
class PerformanceTrace {
  final String _operation;
  final Stopwatch _stopwatch;
  final Map<String, dynamic> _metrics;

  PerformanceTrace(this._operation)
      : _stopwatch = Stopwatch(),
        _metrics = <String, dynamic>{};

  /// Starts the trace.
  void start() {
    _stopwatch.start();
  }

  /// Stops the trace and logs the duration.
  void stop({Map<String, dynamic>? extra}) {
    _stopwatch.stop();
    final duration = _stopwatch.elapsedMilliseconds;
    
    LoggerService.info(
      'Performance: $_operation completed',
      extra: {
        'duration_ms': duration,
        ...?extra,
        ...?_metrics,
      },
    );
  }

  /// Adds a metric to the trace.
  void addMetric(String key, dynamic value) {
    _metrics[key] = value;
  }

  /// Gets the elapsed time in milliseconds.
  int get elapsedMilliseconds => _stopwatch.elapsedMilliseconds;

  /// Gets the elapsed time as a duration.
  Duration get elapsed => _stopwatch.elapsed;

  /// Logs the current progress.
  void logProgress(String message) {
    LoggerService.debug(
      '$_operation: $message (${_stopwatch.elapsedMilliseconds}ms)',
    );
  }
}

/// Analytics event tracking.
///
/// This class provides methods for tracking user events for analytics.
class AnalyticsEvent {
  // App lifecycle events
  static const String appOpened = 'app_opened';
  static const String appClosed = 'app_closed';
  static const String appBackgrounded = 'app_backgrounded';
  static const String appForegrounded = 'app_foregrounded';

  // Feature usage events
  static const String translationStarted = 'translation_started';
  static const String translationStopped = 'translation_stopped';
  static const String objectDetectionStarted = 'object_detection_started';
  static const String objectDetectionStopped = 'object_detection_stopped';
  static const String soundAlertsStarted = 'sound_alerts_started';
  static const String soundAlertsStopped = 'sound_alerts_stopped';

  // User action events
  static const String cameraToggled = 'camera_toggled';
  static const String flashToggled = 'flash_toggled';
  static const String settingsOpened = 'settings_opened';
  static const String permissionsGranted = 'permissions_granted';
  static const String permissionsDenied = 'permissions_denied';

  // Error events
  static const String errorOccurred = 'error_occurred';
  static const String inferenceFailed = 'inference_failed';
  static const String cameraFailed = 'camera_failed';
  static const String audioFailed = 'audio_failed';

  /// Logs an analytics event.
  static void log(
    String eventName, {
    Map<String, dynamic>? parameters,
  }) {
    LoggerService.debug(
      'Analytics: $eventName',
      extra: parameters,
    );

    // In production, send to analytics backend
  }

  /// Logs the app was opened.
  static void logAppOpened() {
    log(appOpened);
  }

  /// Logs the app was closed.
  static void logAppClosed() {
    log(appClosed);
  }

  /// Logs translation started.
  static void logTranslationStarted() {
    log(translationStarted);
  }

  /// Logs translation stopped.
  static void logTranslationStopped({required int durationMs}) {
    log(translationStopped, parameters: {'duration_ms': durationMs});
  }

  /// Logs object detection started.
  static void logObjectDetectionStarted() {
    log(objectDetectionStarted);
  }

  /// Logs object detection stopped.
  static void logObjectDetectionStopped({required int objectCount}) {
    log(objectDetectionStopped, parameters: {'object_count': objectCount});
  }

  /// Logs sound alerts started.
  static void logSoundAlertsStarted() {
    log(soundAlertsStarted);
  }

  /// Logs sound alerts stopped.
  static void logSoundAlertsStopped({required int durationMs}) {
    log(soundAlertsStopped, parameters: {'duration_ms': durationMs});
  }

  /// Logs a feature was used.
  static void logFeatureUsed(String featureName) {
    log('feature_used', parameters: {'feature': featureName});
  }

  /// Logs a screen view.
  static void logScreenView(String screenName) {
    log('screen_view', parameters: {'screen': screenName});
    GlobalErrorHandler.addBreadcrumb('navigation', 'Viewed $screenName');
  }
}
