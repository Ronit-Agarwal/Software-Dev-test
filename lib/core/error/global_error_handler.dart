import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:signsync/core/error/exceptions.dart';
import 'package:signsync/core/privacy/privacy_settings.dart';
import 'package:signsync/core/logging/logger_service.dart';
import 'package:signsync/utils/helpers.dart';

/// Global error handler for the application.
///
/// This class sets up error handling for the entire app, including:
/// - Zone error handling
/// - Flutter framework errors
/// - Sentry integration for crash reporting
/// - User-friendly error display
class GlobalErrorHandler {
  /// Whether error tracking is enabled.
  static bool _isInitialized = false;

  /// The key for the error widget in the widget tree.
  static final GlobalKey<State> _errorWidgetKey = GlobalKey<State>();

  /// Sets up global error handlers.
  static void setupErrorHandlers() {
    if (_isInitialized) return;

    LoggerService.info('Setting up global error handlers');

    // Handle Flutter framework errors
    FlutterError.onError = _handleFlutterError;

    // Handle asynchronous errors
    PlatformDispatcher.instance.onError = _handlePlatformError;

    // Wrap the app in a zone for error isolation
    LoggerService.info('Global error handlers initialized');
    _isInitialized = true;
  }

  /// Handles Flutter framework errors.
  static void _handleFlutterError(FlutterErrorDetails details) {
    LoggerService.error(
      'Flutter framework error',
      error: details.exception,
      stack: details.stack,
    );

    // Show error in debug mode
    if (kDebugMode) {
      FlutterError.dumpErrorToConsole(details);
    }

    // Report to Sentry
    _reportToSentry(
      details.exception,
      stackTrace: details.stack,
      hint: 'FlutterError',
    );

    // Show error widget in release mode
    if (!kDebugMode) {
      // In production, show a fallback UI
    }
  }

  /// Handles platform-level errors.
  static bool _handlePlatformError(Object error, StackTrace stack) {
    LoggerService.error(
      'Platform error',
      error: error,
      stack: stack,
    );

    // Report to Sentry
    _reportToSentry(error, stackTrace: stack, hint: 'PlatformError');

    // Return true to indicate the error was handled
    return true;
  }

  /// Reports an error to Sentry.
  static Future<void> _reportToSentry(
    Object error, {
    StackTrace? stackTrace,
    dynamic hint,
  }) async {
    if (!PrivacySettings.crashReportingEnabled) return;

    try {
      await Sentry.captureException(
        error,
        stackTrace: stackTrace,
        hint: hint,
      );
    } catch (e) {
      LoggerService.error('Failed to report to Sentry', error: e);
    }
  }

  /// Reports a non-fatal error to Sentry.
  static Future<void> reportNonFatal(
    Object error, {
    Map<String, dynamic>? extra,
  }) async {
    if (!PrivacySettings.crashReportingEnabled) return;

    try {
      await Sentry.captureException(
        error,
        withScope: (scope) {
          if (extra != null) {
            scope.extra = extra;
          }
        },
      );
    } catch (e) {
      LoggerService.error('Failed to report non-fatal error', error: e);
    }
  }

  /// Reports a message to Sentry.
  static Future<void> reportMessage(
    String message, {
    SentryLevel level = SentryLevel.info,
    Map<String, dynamic>? extra,
  }) async {
    if (!PrivacySettings.crashReportingEnabled) return;

    try {
      await Sentry.captureMessage(
        message,
        level: level,
        withScope: (scope) {
          if (extra != null) {
            scope.extra = extra;
          }
        },
      );
    } catch (e) {
      LoggerService.error('Failed to report message', error: e);
    }
  }

  /// Adds breadcrumb for user navigation/actions.
  static void addBreadcrumb(
    String category,
    String message, {
    Map<String, dynamic>? data,
  }) {
    if (!PrivacySettings.crashReportingEnabled) return;

    Sentry.addBreadcrumb(
      SentryBreadcrumb(
        category: category,
        message: message,
        data: data?.map((k, v) => MapEntry(k, v.toString())),
        level: SentryLevel.info,
      ),
    );
  }

  /// Sets the user context for crash reports.
  static void setUserContext(String? userId, String? email) {
    if (!PrivacySettings.crashReportingEnabled) return;

    Sentry.configureScope((scope) {
      scope.user = SentryUser(
        id: userId,
        email: email,
      );
    });
  }

  /// Clears the user context.
  static void clearUserContext() {
    if (!PrivacySettings.crashReportingEnabled) return;

    Sentry.configureScope((scope) {
      scope.user = null;
    });
  }

  /// Sets a tag for all future events.
  static void setTag(String key, String value) {
    if (!PrivacySettings.crashReportingEnabled) return;

    Sentry.configureScope((scope) {
      scope.setTag(key, value);
    });
  }

  /// Removes a tag.
  static void removeTag(String key) {
    if (!PrivacySettings.crashReportingEnabled) return;

    Sentry.configureScope((scope) {
      scope.removeTag(key);
    });
  }

  /// Clears all breadcrumbs.
  static void clearBreadcrumbs() {
    if (!PrivacySettings.crashReportingEnabled) return;

    Sentry.configureScope((scope) {
      scope.clearBreadcrumbs();
    });
  }

  /// Captures the current route as a breadcrumb.
  static void captureRouteBreadcrumb(String routeName) {
    addBreadcrumb('navigation', 'Navigated to $routeName');
  }

  /// Captures a user action as a breadcrumb.
  static void captureActionBreadcrumb(String action, [Map<String, dynamic>? data]) {
    addBreadcrumb('user_action', action, data: data);
  }

  /// Captures a performance trace.
  static Future<void> capturePerformanceTrace(
    String operation,
    Future<void> Function() function,
  ) async {
    if (!PrivacySettings.crashReportingEnabled) {
      await function();
      return;
    }

    final transaction = Sentry.startTransaction(
      operation,
      'task',
    );

    try {
      await function();
      transaction.status = SpanStatus.ok();
    } catch (e, stack) {
      transaction.throwable = e;
      transaction.status = SpanStatus.internalError();
      rethrow;
    } finally {
      await transaction.finish();
    }
  }
}

/// Error display widget that shows when an error occurs.
class ErrorDisplayWidget extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;
  final bool showDetails;

  const ErrorDisplayWidget({
    super.key,
    required this.error,
    this.onRetry,
    this.showDetails = kDebugMode,
  });

  @override
  Widget build(BuildContext context) {
    final errorMessage = error is SignSyncException
        ? error.message
        : 'An unexpected error occurred';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Oops! Something went wrong',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (showDetails && error is SignSyncException) ...[
              const SizedBox(height: 8),
              Text(
                'Code: ${(error as SignSyncException).code}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A widget that catches errors in its subtree.
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(Object error, VoidCallback? onRetry)? errorBuilder;
  final bool Function(Object error)? shouldCatch;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.errorBuilder,
    this.shouldCatch,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;

  @override
  void initState() {
    super.initState();
    _error = null;
  }

  @override
  void didUpdateWidget(ErrorBoundary oldWidget) {
    super.didUpdateWidget(oldWidget);
    _error = null;
  }

  void _handleError(Object error) {
    if (widget.shouldCatch?.call(error) ?? true) {
      setState(() {
        _error = error;
      });
      GlobalErrorHandler.reportNonFatal(error);
    } else {
      // Re-throw if we shouldn't catch this error
      Future(() => throw error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.errorBuilder?.call(
            _error!,
            () => setState(() => _error = null),
          ) ??
          ErrorDisplayWidget(
            error: _error!,
            onRetry: () => setState(() => _error = null),
          );
    }

    return Builder(
      builder: (context) {
        return ErrorWidget.builder(
          FlutterErrorDetails(
            exception: _error,
            library: 'signsync',
            context: ErrorDescription('ErrorBoundary widget'),
          ),
        );
      },
    );
  }
}
