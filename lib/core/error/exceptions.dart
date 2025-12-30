/// Custom exception classes for the application.
///
/// This file defines a hierarchy of exceptions for different error scenarios,
/// making it easier to handle and identify errors throughout the app.
abstract class SignSyncException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;
  final StackTrace? stackTrace;

  const SignSyncException({
    required this.message,
    this.code,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() => 'SignSyncException${code != null ? ' [$code]' : ''}: $message';
}

/// Exception thrown when a permission is denied or not granted.
class PermissionException extends SignSyncException {
  final String permissionType;

  const PermissionException(
    String message, {
    required this.permissionType,
    String? code,
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message: message,
          code: code ?? 'PERMISSION_DENIED',
          originalError: originalError,
          stackTrace: stackTrace,
        );

  @override
  String toString() => 'PermissionException [$permissionType]${code != null ? ' [$code]' : ''}: $message';
}

/// Exception thrown when a camera operation fails.
class CameraException extends SignSyncException {
  const CameraException(
    String code,
    String message, {
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message: message,
          code: code,
          originalError: originalError,
          stackTrace: stackTrace,
        );
}

/// Exception thrown when an audio operation fails.
class AudioException extends SignSyncException {
  const AudioException(
    String message, {
    String? code,
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message: message,
          code: code ?? 'AUDIO_ERROR',
          originalError: originalError,
          stackTrace: stackTrace,
        );
}

/// Exception thrown when ML inference fails.
class InferenceException extends SignSyncException {
  const InferenceException(
    String message, {
    String? code,
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message: message,
          code: code ?? 'INFERENCE_ERROR',
          originalError: originalError,
          stackTrace: stackTrace,
        );
}

/// Exception thrown when an API call fails.
class ApiException extends SignSyncException {
  final int? statusCode;

  const ApiException({
    required String message,
    this.statusCode,
    String? code,
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message: message,
          code: code ?? 'API_ERROR',
          originalError: originalError,
          stackTrace: stackTrace,
        );

  factory ApiException.fromHttpResponse(int statusCode, String body) {
    return ApiException(
      message: 'HTTP $statusCode: ${_parseErrorBody(body)}',
      statusCode: statusCode,
      code: 'HTTP_$statusCode',
    );
  }

  static String _parseErrorBody(String body) {
    return body.length > 100 ? '${body.substring(0, 100)}...' : body;
  }
}

/// Exception thrown when a navigation operation fails.
class NavigationException extends SignSyncException {
  const NavigationException(
    String message, {
    String? code,
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message: message,
          code: code ?? 'NAVIGATION_ERROR',
          originalError: originalError,
          stackTrace: stackTrace,
        );
}

/// Exception thrown when state management operations fail.
class StateException extends SignSyncException {
  const StateException(
    String message, {
    String? code,
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message: message,
          code: code ?? 'STATE_ERROR',
          originalError: originalError,
          stackTrace: stackTrace,
        );
}

/// Exception thrown when validation fails.
class ValidationException extends SignSyncException {
  final String? fieldName;

  const ValidationException(
    String message, {
    this.fieldName,
    String? code,
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message: message,
          code: code ?? 'VALIDATION_ERROR',
          originalError: originalError,
          stackTrace: stackTrace,
        );

  @override
  String toString() {
    final field = fieldName != null ? '[$fieldName] ' : '';
    return 'ValidationException $field$message';
  }
}

/// Exception thrown when a resource is not found.
class NotFoundException extends SignSyncException {
  final String resourceType;
  final dynamic resourceId;

  const NotFoundException({
    required this.resourceType,
    this.resourceId,
    String? code,
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message: '${resourceType[0].toUpperCase()}${resourceType.substring(1)} not found',
          code: code ?? 'NOT_FOUND',
          originalError: originalError,
          stackTrace: stackTrace,
        );
}

/// Exception thrown when an operation times out.
class OperationTimeoutException extends SignSyncException {
  final Duration? timeoutDuration;

  const OperationTimeoutException({
    required String operation,
    this.timeoutDuration,
    String? code,
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message:
              '$operation timed out${timeoutDuration != null ? ' after ${timeoutDuration!.inSeconds}s' : ''}',
          code: code ?? 'TIMEOUT',
          originalError: originalError,
          stackTrace: stackTrace,
        );
}
