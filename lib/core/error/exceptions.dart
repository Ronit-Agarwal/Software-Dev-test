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
  String toString() => 'SignSyncException [$code]: $message';
}

/// Exception thrown when TTS operations fail.
class TtsException extends SignSyncException {
  const TtsException(
    String message, {
    String? code,
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message,
          code: code ?? 'TTS_ERROR',
          originalError: originalError,
          stackTrace: stackTrace,
        );
}

/// Exception thrown when ML orchestrator operations fail.
class MlOrchestratorException extends SignSyncException {
  const MlOrchestratorException(
    String message, {
    String? code,
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message,
          code: code ?? 'ML_ORCHESTRATOR_ERROR',
          originalError: originalError,
          stackTrace: stackTrace,
        );
}

/// Exception thrown when Gemini AI operations fail.
class GeminiAiException extends SignSyncException {
  const GeminiAiException(
    String message, {
    String? code,
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message,
          code: code ?? 'GEMINI_AI_ERROR',
          originalError: originalError,
          stackTrace: stackTrace,
        );
}

/// Exception thrown when storage operations fail.
class StorageException extends SignSyncException {
  const StorageException(
    String message, {
    String? code,
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message,
          code: code ?? 'STORAGE_ERROR',
          originalError: originalError,
          stackTrace: stackTrace,
        );
}

/// Exception thrown when ML operations fail.
class MLException extends SignSyncException {
  final String operation;
  final String? modelName;

  const MLException({
    required String message,
    required this.operation,
    this.modelName,
    String? code,
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message,
          code: code ?? 'ML_ERROR',
          originalError: originalError,
          stackTrace: stackTrace,
        );
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
          message,
          code: code ?? 'PERMISSION_DENIED',
          originalError: originalError,
          stackTrace: stackTrace,
        );

  @override
  String toString() => 'PermissionException [$permissionType]: $message';
}

/// Exception thrown when a camera operation fails.
class CameraException extends SignSyncException {
  const CameraException(
    String code,
    String message, {
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message,
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
          message,
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
          message,
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
          message,
          code: code ?? 'API_ERROR',
          originalError: originalError,
          stackTrace: stackTrace,
        );

  factory ApiException.fromHttpResponse(int statusCode, String body) {
    return ApiException(
      message: 'HTTP $statusCode: ${_parseErrorBody(body)}',
      statusCode: statusCode,
      code: 'HTTP_${statusCode}',
    );
  }

  static String _parseErrorBody(String body) {
    // Simple parsing - in production, parse JSON error response
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
          message,
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
          message,
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
          message,
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
          '${resourceType.charAt(0).toUpperCase()}${resourceType.substring(1)} not found',
          code: code ?? 'NOT_FOUND',
          originalError: originalError,
          stackTrace: stackTrace,
        );
}

/// Exception thrown when an operation times out.
class TimeoutException extends SignSyncException {
  final Duration? timeoutDuration;

  const TimeoutException({
    required String operation,
    this.timeoutDuration,
    String? code,
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          '$operation timed out${timeoutDuration != null ? ' after ${timeoutDuration!.inSeconds}s' : ''}',
          code: code ?? 'TIMEOUT',
          originalError: originalError,
          stackTrace: stackTrace,
        );
}

/// Extension to capitalize strings.
extension _Capitalize on String {
  String charAt(int index) => this[index];
  String get first => isEmpty ? '' : this[0];
  String get substring => this;
}
